package pangolin

import "core:math"
import "core:slice"

// Operations that act on the active cel, restricted to the selection if present.

in_sel :: proc(i: int) -> bool {
	return doc.sel == nil || doc.sel[i] != 0
}

edit_begin :: proc() -> (pix: []Color, ok: bool) {
	if !can_edit() {
		return nil, false
	}
	history_push(doc)
	return cel_write(doc, doc.active_layer, doc.active_frame), true
}

edit_clear :: proc() {
	pix, ok := edit_begin()
	if !ok {
		return
	}
	for i in 0 ..< len(pix) {
		if in_sel(i) {
			pix[i] = {}
		}
	}
	doc_touch(doc)
}

edit_fill :: proc(c: Color) {
	pix, ok := edit_begin()
	if !ok {
		return
	}
	for i in 0 ..< len(pix) {
		if in_sel(i) {
			pix[i] = c
		}
	}
	doc_touch(doc)
}

edit_copy :: proc(cut: bool) {
	x0, y0, x1, y1 := 0, 0, doc.w - 1, doc.h - 1
	if doc.sel != nil {
		bx0, by0, bx1, by1, ok := sel_bounds(doc.sel, doc.w, doc.h)
		if !ok {
			return
		}
		x0, y0, x1, y1 = bx0, by0, bx1, by1
	}
	if clip.pix != nil {
		delete(clip.pix)
	}
	cw, ch := x1 - x0 + 1, y1 - y0 + 1
	clip = Clip {
		w   = cw,
		h   = ch,
		x   = x0,
		y   = y0,
		pix = make([]Color, cw * ch),
	}
	src := cel_read(doc, doc.active_layer, doc.active_frame)
	for y in y0 ..= y1 {
		for x in x0 ..= x1 {
			i := y * doc.w + x
			if in_sel(i) {
				clip.pix[(y - y0) * cw + (x - x0)] = src[i]
			}
		}
	}
	if cut {
		edit_clear()
		set_status("Cut")
	} else {
		set_status("Copied")
	}
}

edit_paste :: proc() {
	if clip.pix == nil {
		set_status("Clipboard is empty")
		return
	}
	pix, ok := edit_begin()
	if !ok {
		return
	}
	px, py := clip.x, clip.y
	if px >= doc.w || py >= doc.h || px + clip.w <= 0 || py + clip.h <= 0 {
		px, py = 0, 0
	}
	mask := make([]u8, doc.w * doc.h)
	for y in 0 ..< clip.h {
		for x in 0 ..< clip.w {
			c := clip.pix[y * clip.w + x]
			nx, ny := px + x, py + y
			if c.a == 0 || nx < 0 || ny < 0 || nx >= doc.w || ny >= doc.h {
				continue
			}
			i := ny * doc.w + nx
			pix[i] = blend_px(pix[i], c, 1, .Normal)
			mask[i] = 1
		}
	}
	doc_sel_set(doc, mask)
	doc_touch(doc)
	cur_tool = .Move
	set_status("Pasted - drag to move")
}

edit_flip :: proc(horiz: bool) {
	pix, ok := edit_begin()
	if !ok {
		return
	}
	if doc.sel != nil {
		x0, y0, x1, y1, bok := sel_bounds(doc.sel, doc.w, doc.h)
		if !bok {
			return
		}
		tmp := slice.clone(pix, context.temp_allocator)
		for i in 0 ..< len(pix) {
			if doc.sel[i] != 0 {
				pix[i] = {}
			}
		}
		for y in y0 ..= y1 {
			for x in x0 ..= x1 {
				i := y * doc.w + x
				if doc.sel[i] == 0 {
					continue
				}
				nx := horiz ? x0 + x1 - x : x
				ny := horiz ? y : y0 + y1 - y
				j := ny * doc.w + nx
				pix[j] = blend_px(pix[j], tmp[i], 1, .Normal)
			}
		}
		flip_mask(doc.sel, doc.w, doc.h, x0, y0, x1, y1, horiz)
		doc.sel_dirty = true
	} else {
		flip_pixels(pix, doc.w, doc.h, 0, 0, doc.w - 1, doc.h - 1, horiz)
	}
	doc_touch(doc)
}

edit_invert_colors :: proc() {
	pix, ok := edit_begin()
	if !ok {
		return
	}
	for i in 0 ..< len(pix) {
		if in_sel(i) && pix[i].a != 0 {
			pix[i].r = 255 - pix[i].r
			pix[i].g = 255 - pix[i].g
			pix[i].b = 255 - pix[i].b
		}
	}
	doc_touch(doc)
}

edit_grayscale :: proc() {
	pix, ok := edit_begin()
	if !ok {
		return
	}
	for i in 0 ..< len(pix) {
		if in_sel(i) && pix[i].a != 0 {
			g := u8(0.299 * f32(pix[i].r) + 0.587 * f32(pix[i].g) + 0.114 * f32(pix[i].b))
			pix[i].r, pix[i].g, pix[i].b = g, g, g
		}
	}
	doc_touch(doc)
}

// hue in degrees, sat/val/contrast in percent (-100..100)
edit_adjust :: proc(src: []Color, dst: []Color, hue, sat, val: int) {
	for i in 0 ..< len(src) {
		c := src[i]
		if c.a == 0 || !in_sel(i) {
			dst[i] = c
			continue
		}
		h, s, v := rgb_to_hsv(c)
		h += f32(hue)
		if sat >= 0 {
			s = s + (1 - s) * f32(sat) / 100
		} else {
			s = s * (1 + f32(sat) / 100)
		}
		if val >= 0 {
			v = v + (1 - v) * f32(val) / 100
		} else {
			v = v * (1 + f32(val) / 100)
		}
		dst[i] = hsv_to_rgb(h, clamp(s, 0, 1), clamp(v, 0, 1), c.a)
	}
}

edit_outline :: proc(col: Color, diagonal: bool) {
	pix, ok := edit_begin()
	if !ok {
		return
	}
	src := slice.clone(pix, context.temp_allocator)
	w, h := doc.w, doc.h
	for y in 0 ..< h {
		for x in 0 ..< w {
			i := y * w + x
			if src[i].a != 0 || !in_sel(i) {
				continue
			}
			hit := false
			for dy in -1 ..= 1 {
				for dx in -1 ..= 1 {
					if dx == 0 && dy == 0 {
						continue
					}
					if !diagonal && dx != 0 && dy != 0 {
						continue
					}
					nx, ny := x + dx, y + dy
					if nx >= 0 && ny >= 0 && nx < w && ny < h && src[ny * w + nx].a != 0 {
						hit = true
					}
				}
			}
			if hit {
				pix[i] = col
			}
		}
	}
	doc_touch(doc)
}

edit_replace_color :: proc(from, to: Color, tol: int) {
	pix, ok := edit_begin()
	if !ok {
		return
	}
	for i in 0 ..< len(pix) {
		if in_sel(i) && color_match(pix[i], from, tol) {
			pix[i] = to
		}
	}
	doc_touch(doc)
}

// Rebuild `pix` from `orig` with the selected pixels (or everything) offset by (dx, dy).
// Returns the translated selection mask (or nil when there was no selection).
apply_move :: proc(pix, orig: []Color, osel: []u8, w, h, dx, dy: int, copy_mode: bool) -> []u8 {
	copy(pix, orig)
	if !copy_mode {
		for i in 0 ..< len(pix) {
			if osel == nil || osel[i] != 0 {
				pix[i] = {}
			}
		}
	}
	nsel: []u8
	if osel != nil {
		nsel = make([]u8, len(osel))
	}
	for y in 0 ..< h {
		ny := y + dy
		if ny < 0 || ny >= h {
			continue
		}
		for x in 0 ..< w {
			nx := x + dx
			if nx < 0 || nx >= w {
				continue
			}
			i := y * w + x
			if osel != nil && osel[i] == 0 {
				continue
			}
			j := ny * w + nx
			pix[j] = blend_px(pix[j], orig[i], 1, .Normal)
			if nsel != nil {
				nsel[j] = 1
			}
		}
	}
	return nsel
}

// One-shot nudge used by the arrow keys.
edit_nudge :: proc(dx, dy: int) {
	pix, ok := edit_begin()
	if !ok {
		return
	}
	orig := slice.clone(pix, context.temp_allocator)
	nsel := apply_move(pix, orig, doc.sel, doc.w, doc.h, dx, dy, false)
	if nsel != nil {
		doc_sel_set(doc, nsel)
	}
	doc_touch(doc)
}

// Shift the whole cel with wrap-around (useful for tiling work).
edit_offset_wrap :: proc(dx, dy: int) {
	pix, ok := edit_begin()
	if !ok {
		return
	}
	orig := slice.clone(pix, context.temp_allocator)
	w, h := doc.w, doc.h
	for y in 0 ..< h {
		for x in 0 ..< w {
			pix[wrap_coord(y + dy, h) * w + wrap_coord(x + dx, w)] = orig[y * w + x]
		}
	}
	doc_touch(doc)
}

// Replace the selection by the opaque pixels of the active cel.
edit_select_opaque :: proc() {
	pix := cel_read(doc, doc.active_layer, doc.active_frame)
	m := make([]u8, doc.w * doc.h)
	for i in 0 ..< len(pix) {
		if pix[i].a != 0 {
			m[i] = 1
		}
	}
	history_push(doc)
	doc_sel_set(doc, m)
}

// Select every pixel of the colour currently under the foreground colour.
edit_select_color :: proc(c: Color, tol: int) {
	pix := cel_read(doc, doc.active_layer, doc.active_frame)
	m := make([]u8, doc.w * doc.h)
	for i in 0 ..< len(pix) {
		if color_match(pix[i], c, tol) {
			m[i] = 1
		}
	}
	history_push(doc)
	doc_sel_set(doc, m)
}

_ :: math
