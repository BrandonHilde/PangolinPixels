package pangolin

import "core:math"
import rl "vendor:raylib"

tex_canvas: rl.Texture2D
tex_prev: rl.Texture2D
tex_next: rl.Texture2D
tex_checker: rl.Texture2D
tex_w, tex_h: int
onion_prev_ok, onion_next_ok: bool

make_tex :: proc(w, h: int) -> rl.Texture2D {
	img := rl.GenImageColor(i32(w), i32(h), rl.BLANK)
	t := rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
	rl.SetTextureFilter(t, .POINT)
	return t
}

render_init :: proc() {
	img := rl.GenImageColor(2, 2, rl.BLANK)
	a := Color{204, 204, 212, 255}
	b := Color{150, 150, 162, 255}
	rl.ImageDrawPixel(&img, 0, 0, a)
	rl.ImageDrawPixel(&img, 1, 1, a)
	rl.ImageDrawPixel(&img, 1, 0, b)
	rl.ImageDrawPixel(&img, 0, 1, b)
	tex_checker = rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
	rl.SetTextureFilter(tex_checker, .POINT)
	rl.SetTextureWrap(tex_checker, .REPEAT)
}

textures_ensure :: proc(d: ^Doc) {
	if tex_canvas.id != 0 && tex_w == d.w && tex_h == d.h {
		return
	}
	if tex_canvas.id != 0 {
		rl.UnloadTexture(tex_canvas)
		rl.UnloadTexture(tex_prev)
		rl.UnloadTexture(tex_next)
	}
	tex_canvas = make_tex(d.w, d.h)
	tex_prev = make_tex(d.w, d.h)
	tex_next = make_tex(d.w, d.h)
	tex_w, tex_h = d.w, d.h
	d.comp_dirty = true
}

render_refresh :: proc(d: ^Doc) {
	textures_ensure(d)
	doc_refresh_comp(d)
	if d.tex_dirty {
		d.tex_dirty = false
		rl.UpdateTexture(tex_canvas, raw_data(d.comp))
		onion_prev_ok, onion_next_ok = false, false
		if opts.onion {
			buf := make([]Color, d.w * d.h, context.temp_allocator)
			if d.active_frame > 0 {
				composite(d, d.active_frame - 1, buf)
				rl.UpdateTexture(tex_prev, raw_data(buf))
				onion_prev_ok = true
			}
			if d.active_frame + 1 < len(d.frames) {
				composite(d, d.active_frame + 1, buf)
				rl.UpdateTexture(tex_next, raw_data(buf))
				onion_next_ok = true
			}
		}
	}
}

canvas_bg_color :: proc() -> Color {
	switch bg_mode {
	case 1:
		return Color{0, 0, 0, 255}
	case 2:
		return Color{255, 255, 255, 255}
	case 3:
		return Color{128, 128, 128, 255}
	case 4:
		return Color{bg_custom.r, bg_custom.g, bg_custom.b, 255}
	}
	return Color{}
}

draw_canvas_bg :: proc(dst: rl.Rectangle) {
	if !opts.show_checks {
		return
	}
	if bg_mode == 0 {
		cell: f32 = 8
		rl.DrawTexturePro(tex_checker, {0, 0, dst.width / cell, dst.height / cell}, dst, {}, 0, rl.WHITE)
	} else {
		rl.DrawRectangleRec(dst, canvas_bg_color())
	}
}

draw_cell_outline :: proc(x, y, w, h: f32) {
	rl.DrawRectangleLinesEx({x - 1, y - 1, w + 2, h + 2}, 1, Color{0, 0, 0, 220})
	rl.DrawRectangleLinesEx({x, y, w, h}, 1, Color{255, 255, 255, 230})
}

render_canvas :: proc(vp: Rect) {
	d := doc
	fill_rect(vp, C_VIEWPORT)
	clip_begin(vp)
	defer clip_end()
	render_refresh(d)

	z := d.zoom
	cw := f32(d.w) * z
	ch := f32(d.h) * z
	nx, ny := 0, 0
	if opts.tile == .X || opts.tile == .Both {
		nx = 1
	}
	if opts.tile == .Y || opts.tile == .Both {
		ny = 1
	}
	src := rl.Rectangle{0, 0, f32(d.w), f32(d.h)}
	for ty in -ny ..= ny {
		for tx in -nx ..= nx {
			dst := rl.Rectangle{d.ox + f32(tx) * cw, d.oy + f32(ty) * ch, cw, ch}
			if dst.x > f32(vp.x + vp.w) || dst.y > f32(vp.y + vp.h) || dst.x + dst.width < f32(vp.x) || dst.y + dst.height < f32(vp.y) {
				continue
			}
			draw_canvas_bg(dst)
			if opts.onion && tx == 0 && ty == 0 {
				if onion_prev_ok {
					rl.DrawTexturePro(tex_prev, src, dst, {}, 0, Color{255, 110, 110, 100})
				}
				if onion_next_ok {
					rl.DrawTexturePro(tex_next, src, dst, {}, 0, Color{110, 150, 255, 100})
				}
			}
			rl.DrawTexturePro(tex_canvas, src, dst, {}, 0, rl.WHITE)
			if tx != 0 || ty != 0 {
				rl.DrawRectangleRec(dst, Color{0, 0, 0, 40})
			}
		}
	}

	x0 := i32(d.ox)
	y0 := i32(d.oy)
	x1 := i32(d.ox + cw)
	y1 := i32(d.oy + ch)

	// pixel grid
	if opts.pixel_grid && z >= 6 {
		gc := Color{128, 128, 140, 70}
		for i in 1 ..< d.w {
			x := i32(d.ox + f32(i) * z)
			if x >= vp.x && x < vp.x + vp.w {
				vline(x, max(y0, vp.y), min(y1, vp.y + vp.h) - max(y0, vp.y), gc)
			}
		}
		for i in 1 ..< d.h {
			y := i32(d.oy + f32(i) * z)
			if y >= vp.y && y < vp.y + vp.h {
				hline(max(x0, vp.x), y, min(x1, vp.x + vp.w) - max(x0, vp.x), gc)
			}
		}
	}
	// custom grid
	if opts.grid && opts.grid_w > 0 && opts.grid_h > 0 {
		gc := Color{90, 170, 255, 150}
		for gx := opts.grid_ox % opts.grid_w; gx <= d.w; gx += opts.grid_w {
			x := i32(d.ox + f32(gx) * z)
			vline(x, y0, y1 - y0, gc)
		}
		for gy := opts.grid_oy % opts.grid_h; gy <= d.h; gy += opts.grid_h {
			y := i32(d.oy + f32(gy) * z)
			hline(x0, y, x1 - x0, gc)
		}
	}
	// symmetry guides
	if opts.sym_guides {
		sc := Color{255, 90, 200, 200}
		if opts.sym_x {
			vline(i32(d.ox + cw / 2), y0 - 4, y1 - y0 + 8, sc)
		}
		if opts.sym_y {
			hline(x0 - 4, i32(d.oy + ch / 2), x1 - x0 + 8, sc)
		}
	}

	// canvas border
	outline_rect(Rect{x0 - 1, y0 - 1, x1 - x0 + 2, y1 - y0 + 2}, Color{10, 10, 14, 255})

	// selection outline (marching ants)
	doc_rebuild_edges(d)
	if len(d.sel_edges) > 0 {
		phase := int(ui.time * 6)
		zi := max(i32(math.ceil(z)), 1)
		for e in d.sel_edges {
			sx := i32(d.ox + f32(e.x) * z)
			sy := i32(d.oy + f32(e.y) * z)
			if sx > vp.x + vp.w || sy > vp.y + vp.h || sx + zi < vp.x || sy + zi < vp.y {
				continue
			}
			on := ((int(e.x) + int(e.y) + phase) / 2) % 2 == 0
			c := on ? Color{255, 255, 255, 255} : Color{0, 0, 0, 255}
			if e.vert {
				vline(sx, sy, zi, c)
			} else {
				hline(sx, sy, zi, c)
			}
		}
	}

	// bezier curve handles
	if curve.active {
		center :: proc(d: ^Doc, q: IVec) -> (f32, f32) {
			return d.ox + (f32(q.x) + 0.5) * d.zoom, d.oy + (f32(q.y) + 0.5) * d.zoom
		}
		ax, ay := center(d, curve.p[0])
		bx, by := center(d, curve.p[1])
		cx, cy := center(d, curve.p[2])
		ex, ey := center(d, curve.p[3])
		guide := Color{255, 255, 255, 150}
		rl.DrawLineV({ax, ay}, {bx, by}, guide)
		rl.DrawLineV({cx, cy}, {ex, ey}, guide)
		rl.DrawCircleV({bx, by}, 4, Color{0, 0, 0, 230})
		rl.DrawCircleV({bx, by}, 3, Color{255, 120, 200, 255})
		rl.DrawCircleV({cx, cy}, 4, Color{0, 0, 0, 230})
		rl.DrawCircleV({cx, cy}, 3, Color{255, 120, 200, 255})
		for pt in ([2][2]f32{{ax, ay}, {ex, ey}}) {
			rl.DrawRectangleRec({pt.x - 4, pt.y - 4, 8, 8}, Color{0, 0, 0, 230})
			rl.DrawRectangleRec({pt.x - 3, pt.y - 3, 6, 6}, Color{255, 255, 255, 255})
		}
	}

	// brush cursor / hovered pixel
	if hover_valid && !drag.pan_active && ui.focus_id == 0 && ui.layer == ui.input_layer {
		render_cursor(d)
	}
}

render_cursor :: proc(d: ^Doc) {
	t := eff_tool()
	p := hover_px
	z := d.zoom
	if t == .Hand || t == .Zoom || t == .Move {
		return
	}
	if !px_valid(p) && opts.tile == .Off {
		return
	}
	brush := t == .Pencil || t == .Eraser || t == .Spray || t == .Line || t == .Rect || t == .Ellipse || t == .Curve
	if brush && opts.brush_size > 1 && t != .Spray {
		n := opts.brush_size
		lo := -((n - 1) / 2)
		hi := n / 2
		cc := f32(lo + hi) / 2
		r := f32(n) / 2
		lim := r * r - 0.5
		col := Color{fg.r, fg.g, fg.b, 110}
		if t == .Eraser {
			col = Color{255, 255, 255, 60}
		}
		for dy in lo ..= hi {
			for dx in lo ..= hi {
				if opts.brush_round {
					ddx, ddy := f32(dx) - cc, f32(dy) - cc
					if ddx * ddx + ddy * ddy > lim {
						continue
					}
				}
				rl.DrawRectangleRec({d.ox + f32(p.x + dx) * z, d.oy + f32(p.y + dy) * z, z, z}, col)
			}
		}
		rl.DrawRectangleLinesEx(
			{d.ox + f32(p.x + lo) * z, d.oy + f32(p.y + lo) * z, f32(n) * z, f32(n) * z},
			1,
			Color{255, 255, 255, 160},
		)
		return
	}
	if t == .Spray {
		r := f32(max(opts.brush_size, 2)) / 2
		rl.DrawCircleLines(
			i32(d.ox + (f32(p.x) + 0.5) * z),
			i32(d.oy + (f32(p.y) + 0.5) * z),
			r * z,
			Color{255, 255, 255, 200},
		)
	}
	if brush && t != .Eraser && px_valid(p) {
		rl.DrawRectangleRec({d.ox + f32(p.x) * z, d.oy + f32(p.y) * z, z, z}, Color{fg.r, fg.g, fg.b, 120})
	}
	draw_cell_outline(d.ox + f32(p.x) * z, d.oy + f32(p.y) * z, z, z)
}
