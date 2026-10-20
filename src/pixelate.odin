package pangolin

import "core:fmt"
import "core:slice"
import rl "vendor:raylib"

// Image -> pixel art converter: box-filter the source down to a fixed size, then map
// every pixel onto a palette (optionally dithered). Lives in the .Pixelate dialog.

Pix_Palette :: enum {
	Auto,
	Current,
	DB32,
	Pico8,
	Sweetie16,
	Endesga32,
	Gameboy,
	Grayscale16,
	Rainbow,
}

PIX_PALETTE_NAMES := [Pix_Palette]string {
	.Auto        = "Auto (from image)",
	.Current     = "Current palette",
	.DB32        = "DawnBringer 32",
	.Pico8       = "PICO-8",
	.Sweetie16   = "Sweetie 16",
	.Endesga32   = "Endesga 32",
	.Gameboy     = "Game Boy",
	.Grayscale16 = "Grayscale 16",
	.Rainbow     = "Rainbow",
}

Dither :: enum u8 {
	None,
	Ordered,
	Floyd_Steinberg,
}

DITHER_NAMES := [Dither]string {
	.None            = "None",
	.Ordered         = "Ordered (Bayer)",
	.Floyd_Steinberg = "Floyd-Steinberg",
}

Pixelate :: struct {
	src:          []Color,
	src_w, src_h: int,
	name:         Name,

	// settings
	w, h:         int,
	keep_aspect:  bool,
	pal_kind:     Pix_Palette,
	auto_colors:  int,
	dither:       Dither,

	// results
	scaled:       []Color, // box-filtered, w*h
	out:          []Color, // quantised, w*h
	pal:          [dynamic]Color,
	used_colors:  int,
	scaled_dirty: bool,
	out_dirty:    bool,
	tex_src:      rl.Texture2D,
	tex_out:      rl.Texture2D,
	tex_w, tex_h: int,
}

pixelate: Pixelate

pixelate_free :: proc() {
	p := &pixelate
	delete(p.src)
	delete(p.scaled)
	delete(p.out)
	delete(p.pal)
	if p.tex_src.id != 0 {
		rl.UnloadTexture(p.tex_src)
	}
	if p.tex_out.id != 0 {
		rl.UnloadTexture(p.tex_out)
	}
	// keep the user's last settings for next time
	keep := Pixelate {
		w           = p.w,
		h           = p.h,
		keep_aspect = p.keep_aspect,
		pal_kind    = p.pal_kind,
		auto_colors = p.auto_colors,
		dither      = p.dither,
	}
	p^ = keep
}

// Takes ownership of `src`.
pixelate_begin :: proc(src: []Color, w, h: int, name: string) {
	pixelate_free()
	p := &pixelate
	p.src, p.src_w, p.src_h = src, w, h
	name_set(&p.name, name)
	if p.w == 0 {
		p.w = 64
		p.keep_aspect = true
		p.auto_colors = 16
	}
	if p.keep_aspect {
		pixelate_fit_aspect(true)
	} else if p.h == 0 {
		p.h = 64
	}
	p.scaled_dirty = true
	dialog_open(.Pixelate)
}

pixelate_fit_aspect :: proc(from_width: bool) {
	p := &pixelate
	if p.src_w <= 0 || p.src_h <= 0 {
		return
	}
	if from_width {
		p.h = clamp(int(f32(p.w) * f32(p.src_h) / f32(p.src_w) + 0.5), 1, PIXELATE_MAX)
	} else {
		p.w = clamp(int(f32(p.h) * f32(p.src_w) / f32(p.src_h) + 0.5), 1, PIXELATE_MAX)
	}
}

PIXELATE_MAX :: 1024

// Area-average downscale (alpha weighted, so transparent pixels don't darken edges).
// Output alpha is snapped to fully opaque / fully transparent at 50%.
pixelate_scale :: proc(src: []Color, sw, sh: int, dst: []Color, dw, dh: int) {
	for oy in 0 ..< dh {
		y0 := oy * sh / dh
		y1 := max((oy + 1) * sh / dh, y0 + 1)
		for ox in 0 ..< dw {
			x0 := ox * sw / dw
			x1 := max((ox + 1) * sw / dw, x0 + 1)
			r, g, b, a: u64
			for y in y0 ..< y1 {
				row := src[y * sw:]
				for x in x0 ..< x1 {
					c := row[x]
					ca := u64(c.a)
					r += u64(c.r) * ca
					g += u64(c.g) * ca
					b += u64(c.b) * ca
					a += ca
				}
			}
			n := u64((y1 - y0) * (x1 - x0))
			out: Color
			if a * 2 >= n * 255 && a > 0 {
				out = Color{u8(r / a), u8(g / a), u8(b / a), 255}
			}
			dst[oy * dw + ox] = out
		}
	}
}

// Median cut: splits the opaque colours into `k` boxes along their widest channel and
// returns each box's average colour.
median_cut :: proc(pix: []Color, k: int, out: ^[dynamic]Color) {
	cols := make([dynamic]Color, 0, len(pix), context.temp_allocator)
	for c in pix {
		if c.a != 0 {
			append(&cols, c)
		}
	}
	if len(cols) == 0 {
		return
	}
	Box :: struct {
		lo, hi: int, // range in cols
	}
	widest :: proc(cs: []Color) -> (ch: int, span: int) {
		mn := [3]u8{255, 255, 255}
		mx := [3]u8{0, 0, 0}
		for c in cs {
			for i in 0 ..< 3 {
				mn[i] = min(mn[i], c[i])
				mx[i] = max(mx[i], c[i])
			}
		}
		for i in 0 ..< 3 {
			if int(mx[i]) - int(mn[i]) > span {
				span = int(mx[i]) - int(mn[i])
				ch = i
			}
		}
		return
	}
	boxes := make([dynamic]Box, 0, k, context.temp_allocator)
	append(&boxes, Box{0, len(cols)})
	for len(boxes) < k {
		// split the box with the largest (span * pixel count)
		best, best_score, best_ch := -1, 0, 0
		for bx, i in boxes {
			if bx.hi - bx.lo < 2 {
				continue
			}
			ch, span := widest(cols[bx.lo:bx.hi])
			score := span * (bx.hi - bx.lo)
			if span > 0 && score > best_score {
				best, best_score, best_ch = i, score, ch
			}
		}
		if best < 0 {
			break
		}
		bx := boxes[best]
		seg := cols[bx.lo:bx.hi]
		switch best_ch {
		case 0:
			slice.sort_by(seg, proc(a, b: Color) -> bool {return a.r < b.r})
		case 1:
			slice.sort_by(seg, proc(a, b: Color) -> bool {return a.g < b.g})
		case:
			slice.sort_by(seg, proc(a, b: Color) -> bool {return a.b < b.b})
		}
		mid := bx.lo + (bx.hi - bx.lo) / 2
		boxes[best] = Box{bx.lo, mid}
		append(&boxes, Box{mid, bx.hi})
	}
	for bx in boxes {
		r, g, b: int
		for c in cols[bx.lo:bx.hi] {
			r += int(c.r)
			g += int(c.g)
			b += int(c.b)
		}
		n := bx.hi - bx.lo
		append(out, Color{u8(r / n), u8(g / n), u8(b / n), 255})
	}
}

BAYER4 := [16]int{0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5}

// Maps `src` onto `pal` into `dst` (same size). Transparent pixels stay transparent.
quantize :: proc(src, dst: []Color, w, h: int, pal: []Color, dither: Dither) {
	if len(pal) == 0 {
		copy(dst, src)
		return
	}
	cache := make(map[u32]Color, 256, context.temp_allocator)
	nearest :: proc(c: Color, pal: []Color, cache: ^map[u32]Color) -> Color {
		key := u32(c.r) << 16 | u32(c.g) << 8 | u32(c.b)
		if m, ok := cache[key]; ok {
			return m
		}
		m := nearest_palette_color(Color{c.r, c.g, c.b, 255}, pal)
		cache[key] = m
		return m
	}
	switch dither {
	case .None:
		for c, i in src {
			dst[i] = c.a == 0 ? Color{} : nearest(c, pal, &cache)
		}
	case .Ordered:
		// spread tuned to the palette density: sparse palettes need a wider threshold
		spread := clamp(f32(255) / f32(max(len(pal), 2)) * 2, 16, 64)
		for y in 0 ..< h {
			for x in 0 ..< w {
				i := y * w + x
				c := src[i]
				if c.a == 0 {
					dst[i] = {}
					continue
				}
				t := (f32(BAYER4[(y & 3) * 4 + (x & 3)]) + 0.5) / 16 - 0.5
				off := t * spread
				q := Color{clamp_u8(f32(c.r) + off), clamp_u8(f32(c.g) + off), clamp_u8(f32(c.b) + off), 255}
				dst[i] = nearest(q, pal, &cache)
			}
		}
	case .Floyd_Steinberg:
		err := make([][3]f32, w * h, context.temp_allocator)
		for c, i in src {
			err[i] = {f32(c.r), f32(c.g), f32(c.b)}
		}
		push :: proc(err: [][3]f32, src: []Color, i: int, e: [3]f32, k: f32) {
			if src[i].a != 0 {
				err[i] += e * k
			}
		}
		for y in 0 ..< h {
			for x in 0 ..< w {
				i := y * w + x
				if src[i].a == 0 {
					dst[i] = {}
					continue
				}
				v := err[i]
				q := Color{clamp_u8(v[0]), clamp_u8(v[1]), clamp_u8(v[2]), 255}
				m := nearest(q, pal, &cache)
				dst[i] = m
				e := v - [3]f32{f32(m.r), f32(m.g), f32(m.b)}
				if x + 1 < w do push(err, src, i + 1, e, 7.0 / 16)
				if y + 1 < h {
					if x > 0 do push(err, src, i + w - 1, e, 3.0 / 16)
					push(err, src, i + w, e, 5.0 / 16)
					if x + 1 < w do push(err, src, i + w + 1, e, 1.0 / 16)
				}
			}
		}
	}
}

pixelate_palette :: proc(p: ^Pixelate) {
	clear(&p.pal)
	switch p.pal_kind {
	case .Auto:
		median_cut(p.scaled, p.auto_colors, &p.pal)
	case .Current:
		for c in doc.palette {
			if c.a != 0 {
				append(&p.pal, Color{c.r, c.g, c.b, 255})
			}
		}
	case .DB32, .Pico8, .Sweetie16, .Endesga32, .Gameboy, .Grayscale16, .Rainbow:
		pre := Palette_Preset(int(p.pal_kind) - int(Pix_Palette.DB32))
		for c in palette_preset(pre) {
			append(&p.pal, c)
		}
	}
}

pixelate_update :: proc() {
	p := &pixelate
	if p.scaled_dirty {
		p.scaled_dirty = false
		p.out_dirty = true
		delete(p.scaled)
		delete(p.out)
		p.scaled = make([]Color, p.w * p.h)
		p.out = make([]Color, p.w * p.h)
		pixelate_scale(p.src, p.src_w, p.src_h, p.scaled, p.w, p.h)
	}
	if p.out_dirty {
		p.out_dirty = false
		pixelate_palette(p)
		quantize(p.scaled, p.out, p.w, p.h, p.pal[:], p.dither)
		p.used_colors = pixelate_count_colors(p.out)
		if p.tex_out.id == 0 || p.tex_w != p.w || p.tex_h != p.h {
			if p.tex_out.id != 0 {
				rl.UnloadTexture(p.tex_out)
			}
			p.tex_out = make_tex(p.w, p.h)
			p.tex_w, p.tex_h = p.w, p.h
		}
		rl.UpdateTexture(p.tex_out, raw_data(p.out))
	}
	if p.tex_src.id == 0 {
		img := rl.Image {
			data    = raw_data(p.src),
			width   = i32(p.src_w),
			height  = i32(p.src_h),
			mipmaps = 1,
			format  = .UNCOMPRESSED_R8G8B8A8,
		}
		p.tex_src = rl.LoadTextureFromImage(img)
		rl.SetTextureFilter(p.tex_src, .BILINEAR)
	}
}

// Draws `tex` (tw x th) fitted and centred in `r` over a checkerboard.
pixelate_draw_fit :: proc(r: Rect, tex: rl.Texture2D, tw, th: int, integer_zoom: bool) {
	fill_rect(r, C_PANEL_DK)
	outline_rect(r, C_BORDER)
	if tex.id == 0 || tw <= 0 || th <= 0 {
		return
	}
	z := min(f32(r.w - 4) / f32(tw), f32(r.h - 4) / f32(th))
	if integer_zoom && z >= 1 {
		z = f32(int(z))
	}
	w := i32(f32(tw) * z)
	h := i32(f32(th) * z)
	dst := Rect{r.x + (r.w - w) / 2, r.y + (r.h - h) / 2, max(w, 1), max(h, 1)}
	clip_begin(r)
	draw_checker(dst, 4)
	rl.DrawTexturePro(tex, {0, 0, f32(tw), f32(th)}, to_rl(dst), {}, 0, rl.WHITE)
	clip_end()
}

pixelate_count_colors :: proc(pix: []Color) -> int {
	seen := make(map[u32]bool, 64, context.temp_allocator)
	for c in pix {
		if c.a != 0 {
			seen[color_u32(c)] = true
		}
	}
	return len(seen)
}

dlg_pixelate :: proc() {
	p := &pixelate
	pixelate_update()

	c := dialog_frame("Convert Image to Pixel Art", 500, 340)
	left := Rect{c.x, c.y, 196, c.h - 22}
	right := Rect{c.x + 206, c.y, c.w - 206, c.h - 22}

	// original
	text(left.x, left.y, fmt.tprintf("Original  %dx%d", p.src_w, p.src_h), C_TEXT_DIM)
	pixelate_draw_fit(Rect{left.x, left.y + 12, left.w, 110}, p.tex_src, p.src_w, p.src_h, false)

	y := left.y + 130
	if row_int(left, y, "Width", &p.w, 1, PIXELATE_MAX) {
		if p.keep_aspect do pixelate_fit_aspect(true)
		p.scaled_dirty = true
	}
	y += 20
	if row_int(left, y, "Height", &p.h, 1, PIXELATE_MAX) {
		if p.keep_aspect do pixelate_fit_aspect(false)
		p.scaled_dirty = true
	}
	y += 20
	if checkbox(left.x, y, "Keep aspect ratio", &p.keep_aspect) && p.keep_aspect {
		pixelate_fit_aspect(true)
		p.scaled_dirty = true
	}
	y += 20
	// quick sizes
	sizes := [?]int{16, 32, 64, 128}
	bx := left.x
	for s in sizes {
		if button(Rect{bx, y, 45, 14}, fmt.tprintf("%d", s), fmt.tprintf("%d pixels wide", s), true, p.w == s) {
			p.w = s
			if p.keep_aspect {
				pixelate_fit_aspect(true)
			} else {
				p.h = s
			}
			p.scaled_dirty = true
		}
		bx += 50
	}
	y += 22
	text(left.x, y + 3, "Palette", C_TEXT)
	if combo_enum(Rect{left.x + 60, y, left.w - 60, 14}, PIX_PALETTE_NAMES, &p.pal_kind) {
		p.out_dirty = true
	}
	y += 20
	if p.pal_kind == .Auto {
		text(left.x, y + 3, "Colors", C_TEXT)
		if slider(Rect{left.x + 60, y, left.w - 60, 14}, &p.auto_colors, 2, 64, "") {
			p.out_dirty = true
		}
		y += 20
	}
	text(left.x, y + 3, "Dither", C_TEXT)
	if combo_enum(Rect{left.x + 60, y, left.w - 60, 14}, DITHER_NAMES, &p.dither) {
		p.out_dirty = true
	}

	// result preview
	text(right.x, right.y, fmt.tprintf("Pixel art  %dx%d  -  %d colors used", p.w, p.h, p.used_colors), C_TEXT_DIM)
	pal_h: i32 = 30
	pixelate_draw_fit(Rect{right.x, right.y + 12, right.w, right.h - 12 - pal_h - 4}, p.tex_out, p.w, p.h, true)

	// palette swatches
	sw := Rect{right.x, right.y + right.h - pal_h, right.w, pal_h}
	fill_rect(sw, C_PANEL_DK)
	outline_rect(sw, C_BORDER)
	if n := len(p.pal); n > 0 {
		per_row := max(n <= 32 ? (n + 1) / 2 : 32, 1)
		rows := (n + per_row - 1) / per_row
		cw := (sw.w - 4) / i32(per_row)
		ch := (sw.h - 4) / i32(rows)
		for col, i in p.pal {
			cx := sw.x + 2 + i32(i % per_row) * cw
			cy := sw.y + 2 + i32(i / per_row) * ch
			fill_rect(Rect{cx, cy, cw - 1, ch - 1}, col)
		}
	} else {
		text_centered(sw, "Palette is empty", C_TEXT_DIM)
	}

	ok, cancel := dialog_buttons(c, "Create")
	if cancel {
		dialog_close()
	}
	if ok {
		pixelate_create()
		dialog_close()
	}
}

// Opens the converted image as a new sprite whose palette is the one used.
pixelate_create :: proc() {
	p := &pixelate
	pixelate_update()
	nd := doc_new(p.w, p.h, fmt.tprintf("%s pixel", name_str(&p.name)))
	copy(nd.layers[0].cels[0].pix, p.out)
	if len(p.pal) > 0 {
		clear(&nd.palette)
		for c in p.pal {
			append(&nd.palette, c)
		}
	}
	nd.modified = true
	add_doc(nd)
	set_statusf("Converted to %dx%d pixel art", p.w, p.h)
}

pixelate_open_dialog :: proc() {
	path, ok := native_dialog(false, "Convert image to pixel art", FILTERS_IMG[:], "", "")
	if !ok {
		return
	}
	pixelate_open_path(path)
	delete(path)
}

pixelate_open_path :: proc(path: string) {
	pix, w, h, lok := load_image_pixels(path)
	if !lok {
		show_message("Convert to Pixel Art", "Cannot read image.")
		return
	}
	pixelate_begin(pix, w, h, path_stem(path))
}

// Converts what is currently visible in `d` (active frame, filters applied).
pixelate_from_doc :: proc(d: ^Doc) {
	pix := make([]Color, d.w * d.h)
	composite(d, d.active_frame, pix)
	pixelate_begin(pix, d.w, d.h, name_str(&d.title))
}
