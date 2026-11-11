package pangolin


tex_canvas: Texture
tex_prev: Texture
tex_next: Texture
tex_checker: Texture
tex_w, tex_h: int
tex_doc: ^Doc // document whose pixels are in tex_canvas
onion_prev_ok, onion_next_ok: bool

render_init :: proc() {
	a := Color{204, 204, 212, 255}
	b := Color{150, 150, 162, 255}
	pix := [4]Color{a, b, b, a}
	tex_checker = tex_from_pixels(pix[:], 2, 2, .Point)
}

textures_ensure :: proc(d: ^Doc) {
	if tex_valid(tex_canvas) && tex_w == d.w && tex_h == d.h && tex_doc == d {
		return
	}
	if !tex_valid(tex_canvas) || tex_w != d.w || tex_h != d.h {
		tex_destroy(&tex_canvas)
		tex_destroy(&tex_prev)
		tex_destroy(&tex_next)
		tex_canvas = tex_create(d.w, d.h, .Point)
		tex_prev = tex_create(d.w, d.h, .Point)
		tex_next = tex_create(d.w, d.h, .Point)
		tex_w, tex_h = d.w, d.h
	}
	// another document's pixels may be in the textures
	tex_doc = d
	d.comp_dirty = true
}

render_refresh :: proc(d: ^Doc) {
	textures_ensure(d)
	doc_refresh_comp(d)
	if d.tex_dirty {
		d.tex_dirty = false
		tex_update(tex_canvas, d.comp)
		onion_prev_ok, onion_next_ok = false, false
		if opts.onion {
			buf := make([]Color, d.w * d.h, context.temp_allocator)
			if opts.onion_prev > 0 && d.active_frame > 0 {
				composite(d, d.active_frame - 1, buf)
				tex_update(tex_prev, buf)
				onion_prev_ok = true
			}
			if opts.onion_next > 0 && d.active_frame + 1 < len(d.frames) {
				composite(d, d.active_frame + 1, buf)
				tex_update(tex_next, buf)
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

draw_canvas_bg :: proc(dst: FRect) {
	if !opts.show_checks {
		return
	}
	if bg_mode == 0 {
		draw_tex_tiled(tex_checker, dst, 16)
	} else {
		draw_frect(dst, canvas_bg_color())
	}
}

draw_checker :: proc(r: Rect, cell: i32 = 4) {
	draw_tex_tiled(tex_checker, FRect{f32(r.x), f32(r.y), f32(r.w), f32(r.h)}, f32(cell) * 2)
}

draw_cell_outline :: proc(x, y, w, h: f32) {
	t := hair()
	draw_rect_outline({x - t, y - t, w + 2 * t, h + 2 * t}, Color{0, 0, 0, 220})
	draw_rect_outline({x, y, w, h}, Color{255, 255, 255, 230})
}

// One logical pixel wide outline (stays visible over zoomed pixels).
draw_rect_lines :: proc(r: FRect, c: Color) {
	draw_rect(r.x, r.y, r.w, 1, c)
	draw_rect(r.x, r.y + r.h - 1, r.w, 1, c)
	draw_rect(r.x, r.y + 1, 1, r.h - 2, c)
	draw_rect(r.x + r.w - 1, r.y + 1, 1, r.h - 2, c)
}

draw_disc :: proc(cx, cy, r: f32, c: Color) {
	draw_rrect(cx - r, cy - r, 2 * r, 2 * r, r, c)
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
	src := FRect{0, 0, f32(d.w), f32(d.h)}
	for ty in -ny ..= ny {
		for tx in -nx ..= nx {
			dst := FRect{d.ox + f32(tx) * cw, d.oy + f32(ty) * ch, cw, ch}
			if dst.x > f32(vp.x + vp.w) || dst.y > f32(vp.y + vp.h) || dst.x + dst.w < f32(vp.x) || dst.y + dst.h < f32(vp.y) {
				continue
			}
			draw_canvas_bg(dst)
			if opts.onion && tx == 0 && ty == 0 {
				oa := u8(clamp(opts.onion_alpha, 0, 100) * 255 / 100)
				if onion_prev_ok {
					draw_tex(tex_prev, src, dst, Color{255, 110, 110, oa})
				}
				if onion_next_ok {
					draw_tex(tex_next, src, dst, Color{110, 150, 255, oa})
				}
			}
			draw_tex(tex_canvas, src, dst)
			if tx != 0 || ty != 0 {
				draw_frect(dst, Color{0, 0, 0, 40})
			}
		}
	}

	// Overlays follow the edges of the sprite's pixels, which need not fall on whole logical units,
	// so they are placed in screen pixels (see `snap`).
	t := hair()
	x0, y0 := snap(d.ox), snap(d.oy)
	x1, y1 := snap(d.ox + cw), snap(d.oy + ch)
	vx0, vy0 := f32(vp.x), f32(vp.y)
	vx1, vy1 := f32(vp.x + vp.w), f32(vp.y + vp.h)

	// pixel grid
	if opts.pixel_grid && z >= 6 {
		gc := Color{128, 128, 140, 70}
		for i in 1 ..< d.w {
			x := snap(d.ox + f32(i) * z)
			if x >= vx0 && x < vx1 {
				draw_rect(x, max(y0, vy0), t, min(y1, vy1) - max(y0, vy0), gc)
			}
		}
		for i in 1 ..< d.h {
			y := snap(d.oy + f32(i) * z)
			if y >= vy0 && y < vy1 {
				draw_rect(max(x0, vx0), y, min(x1, vx1) - max(x0, vx0), t, gc)
			}
		}
	}
	// custom grid
	if opts.grid && opts.grid_w > 0 && opts.grid_h > 0 {
		gc := Color{90, 170, 255, 150}
		for gx := opts.grid_ox % opts.grid_w; gx <= d.w; gx += opts.grid_w {
			draw_rect(snap(d.ox + f32(gx) * z), y0, t, y1 - y0, gc)
		}
		for gy := opts.grid_oy % opts.grid_h; gy <= d.h; gy += opts.grid_h {
			draw_rect(x0, snap(d.oy + f32(gy) * z), x1 - x0, t, gc)
		}
	}
	// symmetry guides
	if opts.sym_guides {
		sc := Color{255, 90, 200, 200}
		if opts.sym_x {
			draw_rect(snap(d.ox + cw / 2), y0 - 4, t, y1 - y0 + 8, sc)
		}
		if opts.sym_y {
			draw_rect(x0 - 4, snap(d.oy + ch / 2), x1 - x0 + 8, t, sc)
		}
	}

	// canvas border
	draw_rect_outline({x0 - t, y0 - t, x1 - x0 + 2 * t, y1 - y0 + 2 * t}, Color{10, 10, 14, 255})

	// selection outline (marching ants)
	doc_rebuild_edges(d)
	if len(d.sel_edges) > 0 {
		phase := int(ui.time * 6)
		zl := max(z, t)
		for e in d.sel_edges {
			sx := snap(d.ox + f32(e.x) * z)
			sy := snap(d.oy + f32(e.y) * z)
			if sx > vx1 || sy > vy1 || sx + zl < vx0 || sy + zl < vy0 {
				continue
			}
			on := ((int(e.x) + int(e.y) + phase) / 2) % 2 == 0
			c := on ? Color{255, 255, 255, 255} : Color{0, 0, 0, 255}
			if e.vert {
				draw_rect(sx, sy, t, zl, c)
			} else {
				draw_rect(sx, sy, zl, t, c)
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
		draw_line({ax, ay}, {bx, by}, guide)
		draw_line({cx, cy}, {ex, ey}, guide)
		draw_disc(bx, by, 4, Color{0, 0, 0, 230})
		draw_disc(bx, by, 3, Color{255, 120, 200, 255})
		draw_disc(cx, cy, 4, Color{0, 0, 0, 230})
		draw_disc(cx, cy, 3, Color{255, 120, 200, 255})
		for pt in ([2][2]f32{{ax, ay}, {ex, ey}}) {
			draw_rect(pt.x - 4, pt.y - 4, 8, 8, Color{0, 0, 0, 230})
			draw_rect(pt.x - 3, pt.y - 3, 6, 6, Color{255, 255, 255, 255})
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
	// the indicator drawn below is the cursor: no system cursor on top of it, unless it is too small on screen to find
	cells := brush ? max(opts.brush_size, t == .Spray ? 2 : 1) : 1
	if f32(cells) * z >= 6 {
		if brush {
			ui.hide_cursor = true
		} else if ui.cursor == .TOOL {
			// the outlined pixel marks the spot; the icon beside it still says which tool is in hand
			ui_tool_cursor(TOOL_ICONS[t], .Tag)
		}
	}
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
				draw_rect(d.ox + f32(p.x + dx) * z, d.oy + f32(p.y + dy) * z, z, z, col)
			}
		}
		draw_rect_lines({d.ox + f32(p.x + lo) * z, d.oy + f32(p.y + lo) * z, f32(n) * z, f32(n) * z}, Color{255, 255, 255, 160})
		return
	}
	if t == .Spray {
		r := f32(max(opts.brush_size, 2)) / 2
		draw_circle_outline(d.ox + (f32(p.x) + 0.5) * z, d.oy + (f32(p.y) + 0.5) * z, r * z, Color{255, 255, 255, 200})
	}
	if brush && t != .Eraser && px_valid(p) {
		draw_rect(d.ox + f32(p.x) * z, d.oy + f32(p.y) * z, z, z, Color{fg.r, fg.g, fg.b, 120})
	}
	draw_cell_outline(d.ox + f32(p.x) * z, d.oy + f32(p.y) * z, z, z)
}
