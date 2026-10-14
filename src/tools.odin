package pangolin

import "core:math"
import "core:slice"
import rl "vendor:raylib"

canvas_vp: Rect

hover_px: IVec
hover_valid: bool // mouse is over the canvas viewport

Drag :: struct {
	active:     bool,
	btn:        int,
	tool:       Tool,
	start:      IVec,
	cur:        IVec,
	last:       IVec,
	sel_base:   []u8,
	sel_moving: bool,
	sel_mode:   Sel_Mode,
	lasso:      [dynamic]IVec,
	mv_orig:    []Color,
	mv_sel:     []u8,
	mv_copy:    bool,
	pan_active: bool,
}

drag: Drag

draw_tool :: proc(t: Tool) -> bool {
	#partial switch t {
	case .Pencil, .Eraser, .Line, .Rect, .Ellipse, .Curve, .Bucket, .Spray:
		return true
	}
	return false
}

// Tool in effect right now, considering temporary overrides (Space = hand, Alt = picker).
eff_tool :: proc() -> Tool {
	if drag.active {
		return drag.tool
	}
	if rl.IsKeyDown(.SPACE) && ui.focus_id == 0 && dialog.kind == .None {
		return .Hand
	}
	if ui.alt && draw_tool(cur_tool) && cur_tool != .Eraser {
		return .Picker
	}
	return cur_tool
}

screen_to_canvas :: proc(sx, sy: i32) -> IVec {
	return IVec{int(math.floor((f32(sx) - doc.ox) / doc.zoom)), int(math.floor((f32(sy) - doc.oy) / doc.zoom))}
}

px_valid :: proc(p: IVec) -> bool {
	return p.x >= 0 && p.y >= 0 && p.x < doc.w && p.y < doc.h
}

pick_color :: proc(p: IVec, btn: int) {
	if !px_valid(p) {
		return
	}
	doc_refresh_comp(doc)
	c := doc.comp[p.y * doc.w + p.x]
	if btn == 0 {
		set_fg(c)
	} else {
		bg = c
	}
}

snap_line :: proc(start, cur: IVec) -> IVec {
	dx := cur.x - start.x
	dy := cur.y - start.y
	ax, ay := abs(dx), abs(dy)
	if ay * 2 < ax {
		return IVec{cur.x, start.y}
	}
	if ax * 2 < ay {
		return IVec{start.x, cur.y}
	}
	m := (ax + ay) / 2
	return IVec{start.x + (dx < 0 ? -m : m), start.y + (dy < 0 ? -m : m)}
}

shape_corners :: proc(t: Tool, start, cur: IVec) -> (a, b: IVec) {
	a, b = start, cur
	if t == .Line {
		if ui.shift {
			b = snap_line(start, cur)
		}
		return
	}
	if ui.shift {
		dx, dy := cur.x - start.x, cur.y - start.y
		m := max(abs(dx), abs(dy))
		b = IVec{start.x + (dx < 0 ? -m : m), start.y + (dy < 0 ? -m : m)}
	}
	if ui.ctrl {
		a = IVec{start.x - (b.x - start.x), start.y - (b.y - start.y)}
	}
	return
}

draw_shape :: proc(t: Tool, start, cur: IVec) {
	a, b := shape_corners(t, start, cur)
	edge_plot := opts.brush_size > 1 ? brush_stamp : stroke_plot
	switch t {
	case .Line:
		line_points(a.x, a.y, b.x, b.y, edge_plot)
	case .Rect:
		if opts.fill_shape {
			rect_points(a.x, a.y, b.x, b.y, true, stroke_plot)
		}
		if !opts.fill_shape || opts.brush_size > 1 {
			rect_points(a.x, a.y, b.x, b.y, false, edge_plot)
		}
	case .Ellipse:
		ellipse_points(a.x, a.y, b.x, b.y, opts.fill_shape, stroke_plot, edge_plot)
	case .Curve, .Pencil, .Eraser, .Bucket, .Picker, .Select_Rect, .Select_Ellipse, .Lasso, .Wand, .Move, .Spray, .Hand, .Zoom:
	}
	doc.comp_dirty = true
}

sel_mode_now :: proc() -> Sel_Mode {
	if ui.shift && ui.alt {
		return .Intersect
	}
	if ui.shift {
		return .Add
	}
	if ui.alt {
		return .Subtract
	}
	return opts.sel_mode
}

begin_drag :: proc(btn: int, p: IVec) {
	t := eff_tool()
	if playing {
		stop_playback()
	}
	drag.active = true
	drag.btn = btn
	drag.tool = t
	drag.start, drag.cur, drag.last = p, p, p
	drag.sel_moving = false
	main_col := btn == 0 ? fg : bg
	alt_col := btn == 0 ? bg : fg
	switch t {
	case .Pencil, .Eraser, .Spray:
		erase := t == .Eraser
		if erase {
			main_col = Color{0, 0, 0, 255}
		}
		if !stroke_begin(erase, main_col, alt_col) {
			drag.active = false
			return
		}
		if t == .Spray {
			stroke_spray(p.x, p.y)
		} else if ui.shift && doc.have_last_pt {
			stroke_segment(doc.sel_last_pt.x, doc.sel_last_pt.y, p.x, p.y, true)
		} else {
			stroke_segment(p.x, p.y, p.x, p.y, true)
		}
		doc.sel_last_pt = p
		doc.have_last_pt = true
	case .Line, .Rect, .Ellipse:
		if !stroke_begin(false, main_col, alt_col) {
			drag.active = false
			return
		}
		draw_shape(t, p, p)
	case .Curve:
		curve_begin_drag(btn, p, main_col, alt_col)
	case .Bucket:
		drag.active = false
		if !px_valid(p) || !can_edit() {
			return
		}
		if stroke_begin(false, main_col, alt_col) {
			mask := region_select(stroke.orig, doc.w, doc.h, p.x, p.y, opts.tolerance, opts.contiguous, doc.sel)
			stroke_fill_mask(mask)
			delete(mask)
			stroke_end()
		}
	case .Picker:
		pick_color(p, btn)
	case .Select_Rect, .Select_Ellipse, .Lasso:
		drag.sel_mode = sel_mode_now()
		drag.sel_base = doc.sel != nil ? slice.clone(doc.sel) : nil
		history_push(doc)
		if drag.sel_mode == .Replace && doc.sel != nil && px_valid(p) && doc.sel[p.y * doc.w + p.x] != 0 {
			drag.sel_moving = true
		}
		clear(&drag.lasso)
		append(&drag.lasso, p)
	case .Wand:
		drag.active = false
		if !px_valid(p) {
			return
		}
		mode := sel_mode_now()
		pix := cel_read(doc, doc.active_layer, doc.active_frame)
		mask := region_select(pix, doc.w, doc.h, p.x, p.y, opts.tolerance, opts.contiguous, nil)
		nm := sel_combine(doc.sel, mask, mode)
		delete(mask)
		history_push(doc)
		doc_sel_set(doc, nm)
	case .Move:
		if !can_edit() {
			drag.active = false
			return
		}
		history_push(doc)
		pix := cel_write(doc, doc.active_layer, doc.active_frame)
		drag.mv_orig = slice.clone(pix)
		drag.mv_sel = doc.sel != nil ? slice.clone(doc.sel) : nil
		drag.mv_copy = ui.alt
	case .Hand:
		drag.active = false
	case .Zoom:
		drag.active = false
		nz := zoom_step(doc.zoom, btn == 0 ? 1 : -1)
		zoom_at(nz, f32(ui.mx), f32(ui.my))
	}
}

update_drag :: proc(p: IVec) {
	drag.cur = p
	switch drag.tool {
	case .Pencil, .Eraser:
		if p != drag.last {
			stroke_segment(drag.last.x, drag.last.y, p.x, p.y, false)
			drag.last = p
			doc.sel_last_pt = p
		}
	case .Spray:
		stroke_spray(p.x, p.y)
		drag.last = p
	case .Line, .Rect, .Ellipse:
		stroke_reset()
		draw_shape(drag.tool, drag.start, p)
	case .Curve:
		curve_update_drag(p)
	case .Picker:
		pick_color(p, drag.btn)
	case .Select_Rect, .Select_Ellipse, .Lasso:
		w, h := doc.w, doc.h
		shape: []u8
		if drag.sel_moving {
			dx, dy := p.x - drag.start.x, p.y - drag.start.y
			nm := make([]u8, w * h)
			for y in 0 ..< h {
				for x in 0 ..< w {
					if drag.sel_base[y * w + x] != 0 {
						nx, ny := x + dx, y + dy
						if nx >= 0 && ny >= 0 && nx < w && ny < h {
							nm[ny * w + nx] = 1
						}
					}
				}
			}
			doc_sel_set(doc, nm)
			return
		}
		switch drag.tool {
		case .Select_Rect:
			shape = mask_rect(w, h, drag.start.x, drag.start.y, p.x, p.y)
		case .Select_Ellipse:
			shape = mask_ellipse(w, h, drag.start.x, drag.start.y, p.x, p.y)
		case .Lasso:
			if p != drag.last {
				append(&drag.lasso, p)
				drag.last = p
			}
			shape = mask_polygon(w, h, drag.lasso[:])
		case .Pencil, .Eraser, .Line, .Rect, .Ellipse, .Curve, .Bucket, .Picker, .Wand, .Move, .Spray, .Hand, .Zoom:
		}
		nm := sel_combine(drag.sel_base, shape, drag.sel_mode)
		delete(shape)
		doc_sel_set(doc, nm)
	case .Move:
		dx, dy := p.x - drag.start.x, p.y - drag.start.y
		pix := cel_write(doc, doc.active_layer, doc.active_frame)
		nsel := apply_move(pix, drag.mv_orig, drag.mv_sel, doc.w, doc.h, dx, dy, drag.mv_copy)
		if nsel != nil {
			doc_sel_set(doc, nsel)
		}
		doc_touch(doc)
	case .Bucket, .Wand, .Hand, .Zoom:
	}
}

end_drag :: proc() {
	switch drag.tool {
	case .Curve:
		curve.grab = -1
		curve.phase = 1
	case .Pencil, .Eraser, .Line, .Rect, .Ellipse, .Spray:
		stroke_end()
	case .Select_Rect, .Select_Ellipse, .Lasso:
		if drag.start == drag.cur && drag.sel_mode == .Replace && !drag.sel_moving {
			doc_sel_clear(doc)
		}
		if sel_equal(drag.sel_base, doc.sel) {
			history_discard(doc)
		}
		if drag.sel_base != nil {
			delete(drag.sel_base)
			drag.sel_base = nil
		}
	case .Move:
		if drag.cur == drag.start {
			history_discard(doc)
		}
		delete(drag.mv_orig)
		drag.mv_orig = nil
		if drag.mv_sel != nil {
			delete(drag.mv_sel)
			drag.mv_sel = nil
		}
	case .Picker, .Bucket, .Wand, .Hand, .Zoom:
	}
	drag.active = false
}

// Called every frame with the viewport rectangle. Handles pan, zoom and tool input.
canvas_update :: proc(vp: Rect) {
	canvas_vp = vp
	if !doc.view_init {
		view_fit(doc)
	}
	over := ui.layer == ui.input_layer && in_rect(vp, ui.mx, ui.my)
	p := screen_to_canvas(ui.mx, ui.my)
	hover_px = p
	hover_valid = over

	// Zoom with wheel / pan with shift+wheel
	if over && ui.wheel != 0 && ui.focus_id == 0 {
		if ui.shift {
			doc.ox += ui.wheel * 24
		} else if ui.ctrl {
			doc.oy += ui.wheel * 24
		} else {
			zoom_at(zoom_step(doc.zoom, ui.wheel > 0 ? 1 : -1), f32(ui.mx), f32(ui.my))
		}
	}
	if over && ui.wheel_h != 0 {
		doc.ox += ui.wheel_h * 24
	}

	// Panning
	t := eff_tool()
	if !drag.pan_active && over && !drag.active && (ui.pressed[2] || (t == .Hand && ui.pressed[0])) {
		drag.pan_active = true
	}
	if drag.pan_active {
		doc.ox += f32(ui.mx - ui.pmx)
		doc.oy += f32(ui.my - ui.pmy)
		ui.cursor = .RESIZE_ALL
		if !ui.down[2] && !(t == .Hand && ui.down[0]) {
			drag.pan_active = false
		}
		return
	}

	if over && !drag.active {
		switch t {
		case .Hand:
			ui.cursor = .RESIZE_ALL
		case .Zoom:
			ui.cursor = .POINTING_HAND
		case .Picker, .Pencil, .Eraser, .Line, .Rect, .Ellipse, .Curve, .Bucket, .Select_Rect, .Select_Ellipse, .Lasso, .Wand, .Move, .Spray:
			ui.cursor = .CROSSHAIR
		}
		if ui.pressed[0] || ui.pressed[1] {
			begin_drag(ui.pressed[0] ? 0 : 1, p)
		}
	} else if drag.active {
		ui.cursor = .CROSSHAIR
		btn_down := ui.down[drag.btn]
		update_drag(p)
		if !btn_down || ui.released[drag.btn] {
			end_drag()
		}
	}
}

// ---------------------------------------------------------------------------
// Bezier curve tool
//
// 1. Press and drag to place the two end points (like the line tool).
// 2. Press near a handle (the two control points or an end point) and drag to
//    bend the curve. This can be repeated as often as needed.
// 3. Enter (or double click) applies the curve, Escape cancels it. Choosing any
//    other tool or command also applies it.
// ---------------------------------------------------------------------------

Curve :: struct {
	active: bool, // a stroke is open and the curve is waiting to be edited / applied
	phase:  int, // 0 = placing end points, 1 = editing handles
	p:      [4]IVec, // end, control, control, end
	grab:   int,
}

curve: Curve

curve_default_controls :: proc() {
	a, b := curve.p[0], curve.p[3]
	curve.p[1] = IVec{a.x + (b.x - a.x) / 3, a.y + (b.y - a.y) / 3}
	curve.p[2] = IVec{a.x + (b.x - a.x) * 2 / 3, a.y + (b.y - a.y) * 2 / 3}
}

// Sample the cubic bezier densely enough that no gaps remain, dropping repeats.
curve_samples :: proc() -> []IVec {
	pts := make([dynamic]IVec, context.temp_allocator)
	f: [4]Vec2
	for i in 0 ..< 4 {
		f[i] = Vec2{f32(curve.p[i].x), f32(curve.p[i].y)}
	}
	dist :: proc(a, b: Vec2) -> f32 {
		return math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
	}
	n := max(int((dist(f[0], f[1]) + dist(f[1], f[2]) + dist(f[2], f[3])) * 2), 8)
	for i in 0 ..= n {
		t := f32(i) / f32(n)
		u := 1 - t
		b0 := u * u * u
		b1 := 3 * u * u * t
		b2 := 3 * u * t * t
		b3 := t * t * t
		x := b0 * f[0].x + b1 * f[1].x + b2 * f[2].x + b3 * f[3].x
		y := b0 * f[0].y + b1 * f[1].y + b2 * f[2].y + b3 * f[3].y
		q := IVec{int(math.round(x)), int(math.round(y))}
		if len(pts) == 0 || pts[len(pts) - 1] != q {
			append(&pts, q)
		}
	}
	return pts[:]
}

curve_redraw :: proc() {
	if !curve.active {
		return
	}
	stroke_reset()
	pts := curve_samples()
	for q, i in pts {
		if i == 0 {
			stroke_segment(q.x, q.y, q.x, q.y, true)
		} else {
			stroke_segment(pts[i - 1].x, pts[i - 1].y, q.x, q.y, false)
		}
	}
	doc.comp_dirty = true
}

curve_begin_drag :: proc(btn: int, p: IVec, main_col, alt_col: Color) {
	if curve.active && curve.phase == 1 {
		if ui.dbl_click {
			drag.active = false
			curve_commit()
			return
		}
		// grab the closest handle
		best, best_d := 0, max(int)
		for i in 0 ..< 4 {
			dx, dy := curve.p[i].x - p.x, curve.p[i].y - p.y
			d := dx * dx + dy * dy
			if d < best_d {
				best, best_d = i, d
			}
		}
		curve.grab = best
		curve.p[best] = p
		curve_redraw()
		return
	}
	if !stroke_begin(false, main_col, alt_col) {
		drag.active = false
		return
	}
	curve.active = true
	curve.phase = 0
	curve.p[0], curve.p[3] = p, p
	curve.grab = 3
	curve_default_controls()
	curve_redraw()
}

curve_update_drag :: proc(p: IVec) {
	if !curve.active || curve.grab < 0 {
		return
	}
	curve.p[curve.grab] = p
	if curve.phase == 0 {
		curve_default_controls()
	}
	curve_redraw()
}

curve_commit :: proc() {
	if !curve.active {
		return
	}
	curve.active = false
	curve.grab = -1
	stroke_end()
}

curve_cancel :: proc() {
	if !curve.active {
		return
	}
	stroke_reset()
	curve.active = false
	curve.grab = -1
	stroke_end()
	set_status("Curve cancelled")
}
