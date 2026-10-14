package pangolin

import "core:fmt"
import "core:math"
import "core:slice"

MAX_UNDO :: 256

// ---------------------------------------------------------------------------
// Cel buffers (copy-on-write, reference counted)
// ---------------------------------------------------------------------------

cel_new :: proc(n: int) -> ^Cel_Data {
	c := new(Cel_Data)
	c.refs = 1
	c.pix = make([]Color, n)
	return c
}

cel_clone :: proc(c: ^Cel_Data) -> ^Cel_Data {
	n := new(Cel_Data)
	n.refs = 1
	n.pix = slice.clone(c.pix)
	return n
}

cel_release :: proc(c: ^Cel_Data) {
	c.refs -= 1
	if c.refs <= 0 {
		delete(c.pix)
		free(c)
	}
}

layer_make :: proc(name: string, nframes, npix: int) -> Layer {
	l: Layer
	name_set(&l.name, name)
	l.visible = true
	l.opacity = 255
	for _ in 0 ..< nframes {
		append(&l.cels, cel_new(npix))
	}
	return l
}

layer_destroy :: proc(l: ^Layer) {
	for c in l.cels {
		cel_release(c)
	}
	delete(l.cels)
}

// ---------------------------------------------------------------------------
// State snapshots / history
// ---------------------------------------------------------------------------

state_clone :: proc(s: ^State) -> State {
	r: State
	r.w, r.h = s.w, s.h
	r.layers = make([dynamic]Layer, 0, len(s.layers))
	for &l in s.layers {
		nl := l
		nl.cels = make([dynamic]^Cel_Data, 0, len(l.cels))
		for c in l.cels {
			c.refs += 1
			append(&nl.cels, c)
		}
		append(&r.layers, nl)
	}
	r.frames = slice.clone_to_dynamic(s.frames[:])
	r.tags = slice.clone_to_dynamic(s.tags[:])
	if s.sel != nil {
		r.sel = slice.clone(s.sel)
	}
	return r
}

state_destroy :: proc(s: ^State) {
	for &l in s.layers {
		layer_destroy(&l)
	}
	delete(s.layers)
	delete(s.frames)
	delete(s.tags)
	if s.sel != nil {
		delete(s.sel)
	}
	s^ = {}
}

doc_new :: proc(w, h: int, title := "Sprite") -> ^Doc {
	d := new(Doc)
	d.w, d.h = w, h
	append(&d.frames, Frame{100})
	append(&d.layers, layer_make("Layer 1", 1, w * h))
	d.zoom = 1
	for c in palette_preset(.DB32) {
		append(&d.palette, c)
	}
	name_set(&d.title, title)
	d.comp = make([]Color, w * h)
	d.comp_dirty = true
	d.sel_dirty = true
	return d
}

doc_destroy :: proc(d: ^Doc) {
	state_destroy(&d.s)
	for &s in d.undo {
		state_destroy(&s)
	}
	for &s in d.redo {
		state_destroy(&s)
	}
	delete(d.undo)
	delete(d.redo)
	delete(d.palette)
	delete(d.comp)
	delete(d.sel_edges)
	if d.path != "" {
		delete(d.path)
	}
	free(d)
}

// Call after anything that changed pixels.
doc_touch :: proc(d: ^Doc) {
	d.comp_dirty = true
	d.modified = true
}

doc_clamp :: proc(d: ^Doc) {
	d.active_layer = clamp(d.active_layer, 0, len(d.layers) - 1)
	d.active_frame = clamp(d.active_frame, 0, len(d.frames) - 1)
	if len(d.comp) != d.w * d.h {
		delete(d.comp)
		d.comp = make([]Color, d.w * d.h)
	}
	d.comp_dirty = true
	d.sel_dirty = true
}

history_push :: proc(d: ^Doc) {
	append(&d.undo, state_clone(&d.s))
	for len(d.undo) > MAX_UNDO {
		state_destroy(&d.undo[0])
		ordered_remove(&d.undo, 0)
	}
	for &s in d.redo {
		state_destroy(&s)
	}
	clear(&d.redo)
	d.modified = true
}

// Drop the most recent undo entry (used when a stroke turned out to change nothing).
history_discard :: proc(d: ^Doc) {
	if len(d.undo) > 0 {
		s := pop(&d.undo)
		state_destroy(&s)
	}
}

history_undo :: proc(d: ^Doc) -> bool {
	if len(d.undo) == 0 {
		return false
	}
	append(&d.redo, d.s)
	d.s = pop(&d.undo)
	d.modified = true
	doc_clamp(d)
	return true
}

history_redo :: proc(d: ^Doc) -> bool {
	if len(d.redo) == 0 {
		return false
	}
	append(&d.undo, d.s)
	d.s = pop(&d.redo)
	d.modified = true
	doc_clamp(d)
	return true
}

// ---------------------------------------------------------------------------
// Pixel access
// ---------------------------------------------------------------------------

cel_read :: proc(d: ^Doc, l, f: int) -> []Color {
	return d.layers[l].cels[f].pix
}

// Returns a writable buffer, cloning it first when shared with a history snapshot.
cel_write :: proc(d: ^Doc, l, f: int) -> []Color {
	c := d.layers[l].cels[f]
	if c.refs > 1 {
		n := cel_clone(c)
		c.refs -= 1
		d.layers[l].cels[f] = n
		c = n
	}
	d.comp_dirty = true
	return c.pix
}

// ---------------------------------------------------------------------------
// Compositing
// ---------------------------------------------------------------------------

blend_channel :: proc(mode: Blend, d, s: f32) -> f32 {
	switch mode {
	case .Normal:
		return s
	case .Multiply:
		return d * s
	case .Screen:
		return d + s - d * s
	case .Overlay:
		return d < 0.5 ? 2 * d * s : 1 - 2 * (1 - d) * (1 - s)
	case .Darken:
		return min(d, s)
	case .Lighten:
		return max(d, s)
	case .Add:
		return min(d + s, 1)
	case .Subtract:
		return max(d - s, 0)
	case .Difference:
		return abs(d - s)
	}
	return s
}

// Blend src over dst (non-premultiplied RGBA).
blend_px :: proc(dst, src: Color, opacity: f32, mode: Blend) -> Color {
	if src.a == 0 || opacity <= 0 {
		return dst
	}
	sa := f32(src.a) / 255 * opacity
	if dst.a == 0 {
		return Color{src.r, src.g, src.b, u8(sa * 255 + 0.5)}
	}
	if mode == .Normal && sa >= 0.999 {
		return Color{src.r, src.g, src.b, 255}
	}
	da := f32(dst.a) / 255
	ra := sa + da * (1 - sa)
	out: Color
	for i in 0 ..< 3 {
		s := f32(src[i]) / 255
		dc := f32(dst[i]) / 255
		b := blend_channel(mode, dc, s)
		c := ((1 - sa) * da * dc + sa * ((1 - da) * s + da * b)) / ra
		out[i] = u8(clamp(c, 0, 1) * 255 + 0.5)
	}
	out.a = u8(clamp(ra, 0, 1) * 255 + 0.5)
	return out
}

composite :: proc(d: ^Doc, frame: int, out: []Color) {
	for &p in out {
		p = {}
	}
	for &l in d.layers {
		if !l.visible || l.opacity == 0 {
			continue
		}
		src := l.cels[frame].pix
		if l.blend == .Normal && l.opacity == 255 {
			for i in 0 ..< len(out) {
				s := src[i]
				if s.a == 0 {
					continue
				}
				if s.a == 255 {
					out[i] = s
				} else {
					out[i] = blend_px(out[i], s, 1, .Normal)
				}
			}
		} else {
			op := f32(l.opacity) / 255
			for i in 0 ..< len(out) {
				out[i] = blend_px(out[i], src[i], op, l.blend)
			}
		}
	}
}

doc_refresh_comp :: proc(d: ^Doc) {
	if d.comp_dirty {
		if len(d.comp) != d.w * d.h {
			delete(d.comp)
			d.comp = make([]Color, d.w * d.h)
		}
		composite(d, d.active_frame, d.comp)
		d.comp_dirty = false
		d.tex_dirty = true
	}
}

// ---------------------------------------------------------------------------
// Layers
// ---------------------------------------------------------------------------

doc_add_layer :: proc(d: ^Doc) {
	history_push(d)
	l := layer_make(fmt.tprintf("Layer %d", len(d.layers) + 1), len(d.frames), d.w * d.h)
	inject_at(&d.layers, d.active_layer + 1, l)
	d.active_layer += 1
	doc_touch(d)
}

doc_delete_layer :: proc(d: ^Doc) -> bool {
	if len(d.layers) <= 1 {
		return false
	}
	history_push(d)
	layer_destroy(&d.layers[d.active_layer])
	ordered_remove(&d.layers, d.active_layer)
	d.active_layer = clamp(d.active_layer, 0, len(d.layers) - 1)
	doc_touch(d)
	return true
}

doc_dup_layer :: proc(d: ^Doc) {
	history_push(d)
	src := d.layers[d.active_layer]
	nl := src
	nl.cels = make([dynamic]^Cel_Data, 0, len(src.cels))
	for c in src.cels {
		c.refs += 1
		append(&nl.cels, c)
	}
	nm := fmt.tprintf("%s copy", name_str(&src.name))
	name_set(&nl.name, nm)
	inject_at(&d.layers, d.active_layer + 1, nl)
	d.active_layer += 1
	doc_touch(d)
}

doc_move_layer :: proc(d: ^Doc, dir: int) -> bool {
	a := d.active_layer
	b := a + dir
	if b < 0 || b >= len(d.layers) {
		return false
	}
	history_push(d)
	d.layers[a], d.layers[b] = d.layers[b], d.layers[a]
	d.active_layer = b
	doc_touch(d)
	return true
}

doc_merge_down :: proc(d: ^Doc) -> bool {
	i := d.active_layer
	if i <= 0 {
		return false
	}
	history_push(d)
	op := f32(d.layers[i].opacity) / 255
	mode := d.layers[i].blend
	for f in 0 ..< len(d.frames) {
		dst := cel_write(d, i - 1, f)
		src := d.layers[i].cels[f].pix
		for p in 0 ..< len(dst) {
			dst[p] = blend_px(dst[p], src[p], op, mode)
		}
	}
	layer_destroy(&d.layers[i])
	ordered_remove(&d.layers, i)
	d.active_layer = i - 1
	doc_touch(d)
	return true
}

doc_flatten :: proc(d: ^Doc) -> bool {
	if len(d.layers) <= 1 {
		return false
	}
	history_push(d)
	nl := layer_make("Flattened", len(d.frames), d.w * d.h)
	for f in 0 ..< len(d.frames) {
		composite(d, f, nl.cels[f].pix)
	}
	for &l in d.layers {
		layer_destroy(&l)
	}
	clear(&d.layers)
	append(&d.layers, nl)
	d.active_layer = 0
	doc_touch(d)
	return true
}

// ---------------------------------------------------------------------------
// Frames
// ---------------------------------------------------------------------------

tags_on_insert :: proc(d: ^Doc, pos: int) {
	for &t in d.tags {
		if t.from >= pos {
			t.from += 1
		}
		if t.to >= pos {
			t.to += 1
		}
	}
}

tags_on_delete :: proc(d: ^Doc, pos: int) {
	i := 0
	for i < len(d.tags) {
		t := &d.tags[i]
		if t.from > pos {
			t.from -= 1
		}
		if t.to >= pos {
			t.to -= 1
		}
		if t.to < t.from || t.to < 0 {
			ordered_remove(&d.tags, i)
			continue
		}
		t.from = max(t.from, 0)
		i += 1
	}
}

doc_add_frame :: proc(d: ^Doc, duplicate: bool) {
	history_push(d)
	pos := d.active_frame + 1
	for &l in d.layers {
		if duplicate {
			c := l.cels[d.active_frame]
			c.refs += 1
			inject_at(&l.cels, pos, c)
		} else {
			inject_at(&l.cels, pos, cel_new(d.w * d.h))
		}
	}
	inject_at(&d.frames, pos, Frame{d.frames[d.active_frame].duration})
	tags_on_insert(d, pos)
	d.active_frame = pos
	doc_touch(d)
}

doc_delete_frame :: proc(d: ^Doc) -> bool {
	if len(d.frames) <= 1 {
		return false
	}
	history_push(d)
	pos := d.active_frame
	for &l in d.layers {
		cel_release(l.cels[pos])
		ordered_remove(&l.cels, pos)
	}
	ordered_remove(&d.frames, pos)
	tags_on_delete(d, pos)
	d.active_frame = clamp(pos, 0, len(d.frames) - 1)
	doc_touch(d)
	return true
}

doc_move_frame :: proc(d: ^Doc, dir: int) -> bool {
	a := d.active_frame
	b := a + dir
	if b < 0 || b >= len(d.frames) {
		return false
	}
	history_push(d)
	for &l in d.layers {
		l.cels[a], l.cels[b] = l.cels[b], l.cels[a]
	}
	d.frames[a], d.frames[b] = d.frames[b], d.frames[a]
	d.active_frame = b
	doc_touch(d)
	return true
}

doc_reverse_frames :: proc(d: ^Doc) {
	history_push(d)
	slice.reverse(d.frames[:])
	for &l in d.layers {
		slice.reverse(l.cels[:])
	}
	d.active_frame = len(d.frames) - 1 - d.active_frame
	doc_touch(d)
}

// ---------------------------------------------------------------------------
// Selection helpers
// ---------------------------------------------------------------------------

sel_bounds :: proc(sel: []u8, w, h: int) -> (x0, y0, x1, y1: int, ok: bool) {
	if sel == nil {
		return
	}
	x0, y0 = w, h
	x1, y1 = -1, -1
	for y in 0 ..< h {
		for x in 0 ..< w {
			if sel[y * w + x] != 0 {
				x0 = min(x0, x)
				y0 = min(y0, y)
				x1 = max(x1, x)
				y1 = max(y1, y)
			}
		}
	}
	ok = x1 >= 0
	return
}

doc_sel_clear :: proc(d: ^Doc) {
	if d.sel != nil {
		delete(d.sel)
		d.sel = nil
	}
	d.sel_dirty = true
}

doc_sel_set :: proc(d: ^Doc, mask: []u8) {
	if d.sel != nil {
		delete(d.sel)
	}
	d.sel = mask
	d.sel_dirty = true
	// An empty mask means "no selection".
	any_set := false
	for v in mask {
		if v != 0 {
			any_set = true
			break
		}
	}
	if !any_set {
		delete(d.sel)
		d.sel = nil
	}
}

doc_sel_all :: proc(d: ^Doc) {
	m := make([]u8, d.w * d.h)
	for &v in m {
		v = 1
	}
	doc_sel_set(d, m)
}

doc_sel_invert :: proc(d: ^Doc) {
	m := make([]u8, d.w * d.h)
	if d.sel == nil {
		for &v in m {
			v = 1
		}
	} else {
		for i in 0 ..< len(m) {
			m[i] = d.sel[i] == 0 ? 1 : 0
		}
	}
	doc_sel_set(d, m)
}

sel_equal :: proc(a, b: []u8) -> bool {
	if a == nil && b == nil {
		return true
	}
	if a == nil || b == nil {
		return false
	}
	if len(a) != len(b) {
		return false
	}
	for i in 0 ..< len(a) {
		if (a[i] != 0) != (b[i] != 0) {
			return false
		}
	}
	return true
}

doc_rebuild_edges :: proc(d: ^Doc) {
	if !d.sel_dirty {
		return
	}
	d.sel_dirty = false
	clear(&d.sel_edges)
	if d.sel == nil {
		return
	}
	w, h := d.w, d.h
	at :: proc(sel: []u8, w, h, x, y: int) -> bool {
		if x < 0 || y < 0 || x >= w || y >= h {
			return false
		}
		return sel[y * w + x] != 0
	}
	for y in 0 ..= h {
		for x in 0 ..= w {
			here := at(d.sel, w, h, x, y)
			if x < w {
				up := at(d.sel, w, h, x, y - 1)
				if here != up {
					append(&d.sel_edges, Sel_Edge{i32(x), i32(y), false})
				}
			}
			if y < h {
				left := at(d.sel, w, h, x - 1, y)
				if here != left {
					append(&d.sel_edges, Sel_Edge{i32(x), i32(y), true})
				}
			}
		}
	}
}

// ---------------------------------------------------------------------------
// Canvas-wide transforms
// ---------------------------------------------------------------------------

// Resize canvas; old content is placed at (ox, oy) in the new canvas.
doc_resize :: proc(d: ^Doc, nw, nh, ox, oy: int) {
	history_push(d)
	ow, oh := d.w, d.h
	for &l in d.layers {
		for f in 0 ..< len(l.cels) {
			old := l.cels[f]
			n := cel_new(nw * nh)
			for y in 0 ..< oh {
				ny := y + oy
				if ny < 0 || ny >= nh {
					continue
				}
				for x in 0 ..< ow {
					nx := x + ox
					if nx < 0 || nx >= nw {
						continue
					}
					n.pix[ny * nw + nx] = old.pix[y * ow + x]
				}
			}
			cel_release(old)
			l.cels[f] = n
		}
	}
	doc_sel_clear(d)
	d.w, d.h = nw, nh
	doc_clamp(d)
	doc_touch(d)
}

doc_scale :: proc(d: ^Doc, nw, nh: int) {
	history_push(d)
	ow, oh := d.w, d.h
	for &l in d.layers {
		for f in 0 ..< len(l.cels) {
			old := l.cels[f]
			n := cel_new(nw * nh)
			for y in 0 ..< nh {
				sy := y * oh / nh
				for x in 0 ..< nw {
					sx := x * ow / nw
					n.pix[y * nw + x] = old.pix[sy * ow + sx]
				}
			}
			cel_release(old)
			l.cels[f] = n
		}
	}
	doc_sel_clear(d)
	d.w, d.h = nw, nh
	doc_clamp(d)
	doc_touch(d)
}

// quarter: 1 = 90 CW, 2 = 180, 3 = 90 CCW
doc_rotate :: proc(d: ^Doc, quarter: int) {
	history_push(d)
	ow, oh := d.w, d.h
	nw, nh := ow, oh
	if quarter % 2 == 1 {
		nw, nh = oh, ow
	}
	for &l in d.layers {
		for f in 0 ..< len(l.cels) {
			old := l.cels[f]
			n := cel_new(nw * nh)
			for y in 0 ..< oh {
				for x in 0 ..< ow {
					nx, ny: int
					switch quarter {
					case 1:
						nx, ny = oh - 1 - y, x
					case 2:
						nx, ny = ow - 1 - x, oh - 1 - y
					case:
						nx, ny = y, ow - 1 - x
					}
					n.pix[ny * nw + nx] = old.pix[y * ow + x]
				}
			}
			cel_release(old)
			l.cels[f] = n
		}
	}
	doc_sel_clear(d)
	d.w, d.h = nw, nh
	doc_clamp(d)
	doc_touch(d)
}

doc_flip_sprite :: proc(d: ^Doc, horiz: bool) {
	history_push(d)
	for l in 0 ..< len(d.layers) {
		for f in 0 ..< len(d.frames) {
			pix := cel_write(d, l, f)
			flip_pixels(pix, d.w, d.h, 0, 0, d.w - 1, d.h - 1, horiz)
		}
	}
	if d.sel != nil {
		flip_mask(d.sel, d.w, d.h, 0, 0, d.w - 1, d.h - 1, horiz)
		d.sel_dirty = true
	}
	doc_touch(d)
}

flip_pixels :: proc(pix: []Color, w, h, x0, y0, x1, y1: int, horiz: bool) {
	if horiz {
		for y in y0 ..= y1 {
			for i in 0 ..< (x1 - x0 + 1) / 2 {
				a := y * w + x0 + i
				b := y * w + x1 - i
				pix[a], pix[b] = pix[b], pix[a]
			}
		}
	} else {
		for i in 0 ..< (y1 - y0 + 1) / 2 {
			for x in x0 ..= x1 {
				a := (y0 + i) * w + x
				b := (y1 - i) * w + x
				pix[a], pix[b] = pix[b], pix[a]
			}
		}
	}
}

flip_mask :: proc(m: []u8, w, h, x0, y0, x1, y1: int, horiz: bool) {
	if horiz {
		for y in y0 ..= y1 {
			for i in 0 ..< (x1 - x0 + 1) / 2 {
				a := y * w + x0 + i
				b := y * w + x1 - i
				m[a], m[b] = m[b], m[a]
			}
		}
	} else {
		for i in 0 ..< (y1 - y0 + 1) / 2 {
			for x in x0 ..= x1 {
				a := (y0 + i) * w + x
				b := (y1 - i) * w + x
				m[a], m[b] = m[b], m[a]
			}
		}
	}
}

// Bounding box of non-transparent pixels across all layers and frames.
doc_content_bounds :: proc(d: ^Doc) -> (x0, y0, x1, y1: int, ok: bool) {
	x0, y0 = d.w, d.h
	x1, y1 = -1, -1
	for &l in d.layers {
		for c in l.cels {
			for y in 0 ..< d.h {
				for x in 0 ..< d.w {
					if c.pix[y * d.w + x].a != 0 {
						x0 = min(x0, x)
						y0 = min(y0, y)
						x1 = max(x1, x)
						y1 = max(y1, y)
					}
				}
			}
		}
	}
	ok = x1 >= 0
	return
}

doc_trim :: proc(d: ^Doc) -> bool {
	x0, y0, x1, y1, ok := doc_content_bounds(d)
	if !ok {
		return false
	}
	if x0 == 0 && y0 == 0 && x1 == d.w - 1 && y1 == d.h - 1 {
		return false
	}
	doc_resize(d, x1 - x0 + 1, y1 - y0 + 1, -x0, -y0)
	return true
}

doc_crop_selection :: proc(d: ^Doc) -> bool {
	x0, y0, x1, y1, ok := sel_bounds(d.sel, d.w, d.h)
	if !ok {
		return false
	}
	doc_resize(d, x1 - x0 + 1, y1 - y0 + 1, -x0, -y0)
	return true
}

// ---------------------------------------------------------------------------
// Colour helpers
// ---------------------------------------------------------------------------

color_eq :: proc(a, b: Color) -> bool {
	return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a
}

color_u32 :: proc(c: Color) -> u32 {
	return u32(c.r) << 24 | u32(c.g) << 16 | u32(c.b) << 8 | u32(c.a)
}

color_hex :: proc(c: Color) -> string {
	if c.a == 255 {
		return fmt.tprintf("%02X%02X%02X", c.r, c.g, c.b)
	}
	return fmt.tprintf("%02X%02X%02X%02X", c.r, c.g, c.b, c.a)
}

// Returns false if the string is not valid hex (RGB, RRGGBB or RRGGBBAA, optional #).
parse_hex :: proc(s: string) -> (c: Color, ok: bool) {
	t := s
	if len(t) > 0 && t[0] == '#' {
		t = t[1:]
	}
	hexv :: proc(ch: u8) -> (v: u8, ok: bool) {
		switch ch {
		case '0' ..= '9':
			return ch - '0', true
		case 'a' ..= 'f':
			return ch - 'a' + 10, true
		case 'A' ..= 'F':
			return ch - 'A' + 10, true
		}
		return 0, false
	}
	vals: [8]u8
	n := len(t)
	if n != 3 && n != 6 && n != 8 {
		return
	}
	for i in 0 ..< n {
		v, vok := hexv(t[i])
		if !vok {
			return
		}
		vals[i] = v
	}
	if n == 3 {
		c = Color{vals[0] * 17, vals[1] * 17, vals[2] * 17, 255}
	} else {
		c = Color{vals[0] << 4 | vals[1], vals[2] << 4 | vals[3], vals[4] << 4 | vals[5], 255}
		if n == 8 {
			c.a = vals[6] << 4 | vals[7]
		}
	}
	ok = true
	return
}

rgb_to_hsv :: proc(c: Color) -> (h, s, v: f32) {
	r, g, b := f32(c.r) / 255, f32(c.g) / 255, f32(c.b) / 255
	mx := max(r, max(g, b))
	mn := min(r, min(g, b))
	d := mx - mn
	v = mx
	s = mx == 0 ? 0 : d / mx
	if d == 0 {
		h = 0
	} else if mx == r {
		h = math.mod((g - b) / d, 6)
	} else if mx == g {
		h = (b - r) / d + 2
	} else {
		h = (r - g) / d + 4
	}
	h *= 60
	if h < 0 {
		h += 360
	}
	return
}

hsv_to_rgb :: proc(h, s, v: f32, a: u8 = 255) -> Color {
	hh := math.mod(h, 360)
	if hh < 0 {
		hh += 360
	}
	c := v * s
	x := c * (1 - abs(math.mod(hh / 60, 2) - 1))
	m := v - c
	r, g, b: f32
	switch int(hh / 60) {
	case 0:
		r, g, b = c, x, 0
	case 1:
		r, g, b = x, c, 0
	case 2:
		r, g, b = 0, c, x
	case 3:
		r, g, b = 0, x, c
	case 4:
		r, g, b = x, 0, c
	case:
		r, g, b = c, 0, x
	}
	return Color{u8((r + m) * 255 + 0.5), u8((g + m) * 255 + 0.5), u8((b + m) * 255 + 0.5), a}
}
