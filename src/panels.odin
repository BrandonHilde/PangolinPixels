package pangolin

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

MENU_H :: 16
OPT_H :: 22
TAB_H :: 16
STATUS_H :: 14
TOOLBAR_W :: 54
RIGHT_W :: 196
TIMELINE_H :: 130

PALETTE_PRESET_ID :: u32(0xA11E77E1)

// ---------------------------------------------------------------------------
// Top-level layout
// ---------------------------------------------------------------------------

main_ui :: proc() {
	W, H := i32(ui.w), i32(ui.h)
	fill_rect(Rect{0, 0, W, H}, C_BG)

	menubar := Rect{0, 0, W, MENU_H}
	optbar := Rect{0, MENU_H, W, OPT_H}
	status := Rect{0, H - STATUS_H, W, STATUS_H}
	body := Rect{0, MENU_H + OPT_H, W, H - MENU_H - OPT_H - STATUS_H}

	right := cut_right(&body, RIGHT_W)
	toolbar := cut_left(&body, TOOLBAR_W)
	timeline := Rect{}
	if show_timeline {
		timeline = cut_bottom(&body, TIMELINE_H)
	}
	tabs := cut_top(&body, TAB_H)
	viewport := body

	// canvas first so that panels can overdraw its borders
	canvas_update(viewport)
	render_canvas(viewport)

	panel_tabs(tabs)
	panel_toolbar(toolbar)
	panel_options(optbar)
	panel_right(right)
	if show_timeline {
		panel_timeline(timeline)
	}
	panel_status(status, viewport)
	panel_menubar(menubar)
}

// ---------------------------------------------------------------------------
// Menu bar
// ---------------------------------------------------------------------------

MENU_TITLES := [?]string{"File", "Edit", "Sprite", "Layer", "Frame", "Select", "View", "Help"}

menu_build :: proc(idx: int) {
	item :: popup_item
	switch idx {
	case 0:
		item("New...", cmd = .New)
		item("Open...", cmd = .Open)
		popup_sep()
		item("Save", cmd = .Save)
		item("Save As...", cmd = .Save_As)
		popup_sep()
		item("Import Image...", cmd = .Import_Image)
		item("Import as Layer...", cmd = .Import_Layer)
		item("Import Sprite Sheet...", cmd = .Import_Sheet)
		popup_sep()
		item("Export...", cmd = .Export)
		popup_sep()
		item("Load Palette...", cmd = .Palette_Load)
		item("Save Palette...", cmd = .Palette_Save)
		popup_sep()
		item("Close", cmd = .Close_Doc)
		item("Exit", cmd = .Exit)
	case 1:
		item("Undo", cmd = .Undo, enabled = len(doc.undo) > 0)
		item("Redo", cmd = .Redo, enabled = len(doc.redo) > 0)
		popup_sep()
		item("Cut", cmd = .Cut)
		item("Copy", cmd = .Copy)
		item("Paste", cmd = .Paste, enabled = clip.pix != nil)
		item("Delete", cmd = .Delete)
		popup_sep()
		item("Fill with Foreground", cmd = .Fill_Fg)
		item("Fill with Background", cmd = .Fill_Bg)
		popup_sep()
		item("Flip Horizontal", cmd = .Flip_H)
		item("Flip Vertical", cmd = .Flip_V)
		item("Hue / Saturation...", cmd = .Adjust)
		item("Invert Colors", cmd = .Invert_Colors)
		item("Grayscale", cmd = .Grayscale)
		item("Outline...", cmd = .Outline)
		item("Replace Color...", cmd = .Replace_Color)
	case 2:
		item("Canvas Size...", cmd = .Canvas_Size)
		item("Scale Sprite...", cmd = .Scale_Sprite)
		item("Crop to Selection", cmd = .Crop_Sel)
		item("Trim Transparent Edges", cmd = .Trim)
		popup_sep()
		item("Rotate 90 CW", cmd = .Rotate_CW)
		item("Rotate 90 CCW", cmd = .Rotate_CCW)
		item("Rotate 180", cmd = .Rotate_180)
		item("Flip Sprite Horizontal", cmd = .Flip_Sprite_H)
		item("Flip Sprite Vertical", cmd = .Flip_Sprite_V)
		popup_sep()
		item("Palette from Sprite", cmd = .Palette_From_Sprite)
	case 3:
		item("New Layer", cmd = .Layer_New)
		item("Duplicate Layer", cmd = .Layer_Dup)
		item("Delete Layer", cmd = .Layer_Del)
		popup_sep()
		item("Move Up", cmd = .Layer_Up)
		item("Move Down", cmd = .Layer_Down)
		item("Merge Down", cmd = .Layer_Merge)
		item("Flatten", cmd = .Layer_Flatten)
		popup_sep()
		item("Properties...", cmd = .Layer_Props)
		item("Toggle Visibility", cmd = .Layer_Vis)
		item("Toggle Lock", cmd = .Layer_Lock)
	case 4:
		item("New Frame", cmd = .Frame_New)
		item("Duplicate Frame", cmd = .Frame_Dup)
		item("Delete Frame", cmd = .Frame_Del)
		popup_sep()
		item("Move Left", cmd = .Frame_Left)
		item("Move Right", cmd = .Frame_Right)
		item("Reverse Frames", cmd = .Frame_Reverse)
		popup_sep()
		item("Frame Properties...", cmd = .Frame_Props)
		item("Tags...", cmd = .Tags)
		popup_sep()
		item(playing ? "Pause" : "Play", cmd = .Play)
		item("Next Frame", cmd = .Frame_Next)
		item("Previous Frame", cmd = .Frame_Prev)
		item("First Frame", cmd = .Frame_First)
		item("Last Frame", cmd = .Frame_Last)
	case 5:
		item("Select All", cmd = .Select_All)
		item("Deselect", cmd = .Deselect)
		item("Invert Selection", cmd = .Invert_Sel)
		item("Select Opaque Pixels", cmd = .Select_Opaque)
	case 6:
		item("Zoom In", cmd = .Zoom_In)
		item("Zoom Out", cmd = .Zoom_Out)
		item("Fit to Window", cmd = .Zoom_Fit)
		item("100%", cmd = .Zoom_1)
		item("200%", cmd = .Zoom_2)
		item("400%", cmd = .Zoom_4)
		item("800%", cmd = .Zoom_8)
		item("1600%", cmd = .Zoom_16)
		popup_sep()
		item("Pixel Grid", cmd = .Toggle_Pixel_Grid, checked = opts.pixel_grid)
		item("Grid", cmd = .Toggle_Grid, checked = opts.grid)
		item("Grid Settings...", cmd = .Grid_Settings)
		item("Onion Skin", cmd = .Toggle_Onion, checked = opts.onion)
		item("Symmetry Horizontal", cmd = .Toggle_Sym_X, checked = opts.sym_x)
		item("Symmetry Vertical", cmd = .Toggle_Sym_Y, checked = opts.sym_y)
		item("Cycle Tiled Mode", cmd = .Cycle_Tile, checked = opts.tile != .Off)
		item("Canvas Background...", cmd = .Canvas_Bg)
		item("Transparency Checkers", cmd = .Toggle_Checks, checked = opts.show_checks)
		popup_sep()
		item("Timeline", cmd = .Toggle_Timeline, checked = show_timeline)
		item("Preview", cmd = .Toggle_Preview, checked = show_preview)
		item("Preferences...", cmd = .Preferences)
	case 7:
		item("Keyboard Shortcuts", cmd = .Help_Keys)
		item("About", cmd = .About)
	}
}

panel_menubar :: proc(r: Rect) {
	// The menubar stays interactive while a menu is open, but not under dialogs.
	if ui.input_layer < 2 {
		ui.layer = ui.input_layer
	} else {
		ui.layer = -1
	}
	fill_rect(r, C_PANEL_DK)
	hline(r.x, r.y + r.h - 1, r.w, C_BORDER)
	x := r.x + 4
	for title, i in MENU_TITLES {
		w := text_w(title) + 14
		br := Rect{x, r.y, w, r.h - 1}
		id := make_id(br, title)
		hover := ui_hover(br)
		is_open := popup.open && popup.menu_idx == i
		if hover || is_open {
			fill_rect(br, is_open ? C_ACTIVE : C_HOVER)
		}
		text(br.x + 7, br.y + 4, title, C_TEXT)
		if hover {
			if ui.pressed[0] {
				if is_open {
					popup_close()
				} else {
					popup_begin(id, br, 0, i)
					menu_build(i)
				}
			} else if popup.open && popup.menu_idx >= 0 && popup.menu_idx != i {
				popup_begin(id, br, 0, i)
				menu_build(i)
			}
		}
		x += w
	}
	// document title on the right
	t := doc_display_name(doc)
	text(r.x + r.w - text_w(t) - 8, r.y + 4, t, C_TEXT_DIM)
}

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

panel_tabs :: proc(r: Rect) {
	ui.layer = 0
	fill_rect(r, C_PANEL_DK)
	hline(r.x, r.y + r.h - 1, r.w, C_BORDER)
	x := r.x + 2
	close_idx := -1
	switch_idx := -1
	for d, i in docs {
		name := doc_display_name(d)
		w := text_w(name) + 34
		tr := Rect{x, r.y + 1, w, r.h - 1}
		if x + w > r.x + r.w - 20 {
			break
		}
		active := d == doc
		hover := ui_hover(tr)
		fill_rect(tr, active ? C_PANEL : (hover ? C_HOVER : C_PANEL_DK))
		if active {
			hline(tr.x, tr.y, tr.w, C_ACCENT)
		}
		text(tr.x + 6, tr.y + 4, name, active ? C_TEXT : C_TEXT_DIM)
		cr := Rect{tr.x + tr.w - 16, tr.y + 2, 12, 12}
		chover := ui_hover(cr)
		icon(.Close, cr.x, cr.y, chover ? C_DANGER : C_TEXT_DIM)
		if ui.pressed[0] && ui_hover(tr) {
			if chover {
				close_idx = i
			} else {
				switch_idx = i
			}
		}
		if ui.pressed[2] && hover {
			close_idx = i
		}
		x += w + 1
	}
	if close_idx >= 0 {
		request_close(docs[close_idx])
	} else if switch_idx >= 0 {
		switch_doc(switch_idx)
	}
	if icon_button(Rect{r.x + r.w - 18, r.y + 2, 16, 13}, .Plus, "New sprite") {
		run_cmd(.New)
	}
}

// ---------------------------------------------------------------------------
// Toolbar
// ---------------------------------------------------------------------------

TOOL_ICONS := [Tool]Icon {
	.Pencil         = .Pencil,
	.Eraser         = .Eraser,
	.Line           = .Line,
	.Rect           = .Rect,
	.Ellipse        = .Ellipse,
	.Curve          = .Curve,
	.Bucket         = .Bucket,
	.Picker         = .Picker,
	.Select_Rect    = .Sel_Rect,
	.Select_Ellipse = .Sel_Ellipse,
	.Lasso          = .Lasso,
	.Wand           = .Wand,
	.Move           = .Move,
	.Spray          = .Spray,
	.Hand           = .Hand,
	.Zoom           = .Zoom,
}

panel_toolbar :: proc(r: Rect) {
	ui.layer = 0
	fill_rect(r, C_PANEL)
	vline(r.x + r.w - 1, r.y, r.h, C_BORDER)
	t := eff_tool()
	for tool in Tool {
		i := i32(tool)
		br := Rect{r.x + 3 + (i % 2) * 25, r.y + 4 + (i / 2) * 25, 24, 24}
		if icon_button(br, TOOL_ICONS[tool], TOOL_NAMES[tool], t == tool) {
			select_tool(tool)
		}
	}
}

// ---------------------------------------------------------------------------
// Tool options bar
// ---------------------------------------------------------------------------

panel_options :: proc(r: Rect) {
	ui.layer = 0
	fill_rect(r, C_PANEL)
	hline(r.x, r.y + r.h - 1, r.w, C_BORDER)
	x := r.x + 6
	y := r.y + 4
	t := eff_tool()

	size_slider :: proc(x: ^i32, y: i32) {
		slider(Rect{x^, y, 80, 14}, &opts.brush_size, 1, 64, "Size", "Brush size ([ and ])")
		x^ += 86
		if icon_button(Rect{x^, y, 14, 14}, .Frame, "Square brush", !opts.brush_round) {
			opts.brush_round = false
		}
		if icon_button(Rect{x^ + 15, y, 14, 14}, .Ellipse, "Round brush", opts.brush_round) {
			opts.brush_round = true
		}
		x^ += 36
	}

	switch t {
	case .Pencil:
		size_slider(&x, y)
		checkbox(x, y + 1, "Pixel-perfect", &opts.pixel_perf, "Remove L-shaped corners while drawing")
		x += 90
		options_ink_pattern(&x, y)
	case .Eraser:
		size_slider(&x, y)
		options_ink_pattern(&x, y)
	case .Line:
		size_slider(&x, y)
		options_ink_pattern(&x, y)
		text(x, y + 3, "Shift: snap angle", C_TEXT_DIM)
		x += 100
	case .Rect, .Ellipse:
		size_slider(&x, y)
		checkbox(x, y + 1, "Filled", &opts.fill_shape)
		x += 52
		options_ink_pattern(&x, y)
		text(x, y + 3, "Shift: square  Ctrl: from center", C_TEXT_DIM)
		x += 190
	case .Curve:
		size_slider(&x, y)
		options_ink_pattern(&x, y)
		text(x, y + 3, "Drag a line, then drag the handles. Enter: apply  Esc: cancel", C_TEXT_DIM)
		x += 330
	case .Spray:
		size_slider(&x, y)
		slider(Rect{x, y, 90, 14}, &opts.spray_dens, 1, 100, "Density")
		x += 96
		options_ink_pattern(&x, y)
	case .Bucket:
		slider(Rect{x, y, 100, 14}, &opts.tolerance, 0, 255, "Tolerance")
		x += 106
		checkbox(x, y + 1, "Contiguous", &opts.contiguous)
		x += 78
		options_ink_pattern(&x, y)
	case .Wand:
		slider(Rect{x, y, 100, 14}, &opts.tolerance, 0, 255, "Tolerance")
		x += 106
		checkbox(x, y + 1, "Contiguous", &opts.contiguous)
		x += 78
		options_sel_mode(&x, y)
	case .Select_Rect, .Select_Ellipse, .Lasso:
		options_sel_mode(&x, y)
		text(x, y + 3, "Shift: add  Alt: subtract", C_TEXT_DIM)
		x += 140
	case .Move:
		text(x, y + 3, "Drag to move the selection (or the whole cel). Alt: copy. Arrows nudge.", C_TEXT_DIM)
		x += 330
	case .Picker:
		text(x, y + 3, "Click: foreground  Right click: background", C_TEXT_DIM)
		x += 230
	case .Hand:
		text(x, y + 3, "Drag to pan. Space or middle mouse works with any tool.", C_TEXT_DIM)
		x += 280
	case .Zoom:
		text(x, y + 3, "Click to zoom in, right click to zoom out. Mouse wheel works anywhere.", C_TEXT_DIM)
		x += 320
	}

	// global toggles on the right
	rx := r.x + r.w - 4
	rx -= 16
	toggle_button(Rect{rx, y, 16, 14}, .Grid, &opts.grid, "Show custom grid (Ctrl+')")
	rx -= 17
	toggle_button(Rect{rx, y, 16, 14}, .Pixel_Grid, &opts.pixel_grid, "Show pixel borders when zoomed in (Ctrl+Shift+')")
	rx -= 17
	if icon_button(Rect{rx, y, 16, 14}, .Onion, "Onion skin (Alt+O)", opts.onion) {
		run_cmd(.Toggle_Onion)
	}
	rx -= 17
	rx -= 76
	tv, tch := combo(Rect{rx, y, 76, 14}, TILE_NAMES[:], int(opts.tile), "Tiled mode (Shift+T)")
	if tch {
		opts.tile = Tile_Mode(tv)
	}
	rx -= 17
	toggle_button(Rect{rx, y, 16, 14}, .Sym_Y, &opts.sym_y, "Mirror vertically (Shift+Y)")
	rx -= 17
	toggle_button(Rect{rx, y, 16, 14}, .Sym_X, &opts.sym_x, "Mirror horizontally (Shift+X)")
	rx -= 22
	swr := Rect{rx, y, 20, 14}
	bgid := make_id(swr, "canvasbg")
	bclick, _, bhover := button_behavior(bgid, swr, "Canvas background color")
	if bg_mode == 0 {
		draw_checker(swr, 4)
	} else {
		fill_rect(swr, canvas_bg_color())
	}
	outline_rect(swr, bhover ? C_ACCENT : C_BORDER)
	if bclick {
		run_cmd(.Canvas_Bg)
	}
}

TILE_NAMES := [?]string{"Tile: off", "Tile: X", "Tile: Y", "Tile: X+Y"}

options_ink_pattern :: proc(x: ^i32, y: i32) {
	pv, pch := combo(Rect{x^, y, 84, 14}, pattern_names(), int(opts.pattern), "Pattern / dither")
	if pch {
		opts.pattern = Pattern(pv)
	}
	x^ += 90
	iv, ich := combo(Rect{x^, y, 74, 14}, INK_NAMES[:], int(opts.ink), "Ink mode")
	if ich {
		opts.ink = Ink(iv)
	}
	x^ += 80
}

INK_NAMES := [?]string{"Ink: Normal", "Ink: Replace", "Ink: Lock A"}

pattern_names :: proc() -> []string {
	@(static) names: [len(Pattern)]string
	for n, i in PATTERN_NAMES {
		names[int(i)] = n
	}
	return names[:]
}

options_sel_mode :: proc(x: ^i32, y: i32) {
	labels := [?]string{"New", "Add", "Sub", "And"}
	for l, i in labels {
		if button(Rect{x^ + i32(i) * 30, y, 28, 14}, l, "", true, int(opts.sel_mode) == i) {
			opts.sel_mode = Sel_Mode(i)
		}
	}
	x^ += 126
}

// ---------------------------------------------------------------------------
// Right panel: colour picker, palette, preview
// ---------------------------------------------------------------------------

drag_area :: proc(r: Rect, id: u32) -> (active: bool, fx, fy: f32) {
	if ui_hover(r) && ui.pressed[0] {
		ui.active_id = id
	}
	if ui.active_id == id && ui.down[0] {
		fx = clamp(f32(ui.mx - r.x) / f32(max(r.w - 1, 1)), 0, 1)
		fy = clamp(f32(ui.my - r.y) / f32(max(r.h - 1, 1)), 0, 1)
		active = true
	}
	return
}

draw_checker :: proc(r: Rect, cell: i32 = 4) {
	rl.DrawTexturePro(
		tex_checker,
		{0, 0, f32(r.w) / f32(cell), f32(r.h) / f32(cell)},
		to_rl(r),
		{},
		0,
		rl.WHITE,
	)
}

hex_buf: Name

panel_right :: proc(r: Rect) {
	ui.layer = 0
	fill_rect(r, C_PANEL)
	vline(r.x, r.y, r.h, C_BORDER)
	area := rect_inset(r, 6)
	area.w -= 0

	// --- colour picker ---------------------------------------------------
	x, y := area.x, area.y
	sv := Rect{x, y, 128, 96}
	hue := Rect{x + 134, y, 12, 96}
	alp := Rect{x + 150, y, 12, 96}

	// saturation / value box
	rl.DrawRectangleGradientH(sv.x, sv.y, sv.w, sv.h, rl.WHITE, hsv_to_rgb(fg_h, 1, 1))
	rl.DrawRectangleGradientV(sv.x, sv.y, sv.w, sv.h, Color{0, 0, 0, 0}, Color{0, 0, 0, 255})
	outline_rect(sv, C_BORDER)
	if act, fx, fy := drag_area(sv, make_id(sv, "sv")); act {
		set_fg_hsv(fg_h, fx, 1 - fy, fg.a)
	}
	cx := sv.x + i32(fg_s * f32(sv.w - 1))
	cy := sv.y + i32((1 - fg_v) * f32(sv.h - 1))
	rl.DrawCircleLines(cx, cy, 3, rl.BLACK)
	rl.DrawCircleLines(cx, cy, 4, rl.WHITE)

	// hue bar
	for i in 0 ..< 6 {
		seg_h := hue.h / 6
		c0 := hsv_to_rgb(f32(i) * 60, 1, 1)
		c1 := hsv_to_rgb(f32(i + 1) * 60, 1, 1)
		rl.DrawRectangleGradientV(hue.x, hue.y + i32(i) * seg_h, hue.w, seg_h + 1, c0, c1)
	}
	outline_rect(hue, C_BORDER)
	if act, _, fy := drag_area(hue, make_id(hue, "hue")); act {
		set_fg_hsv(fy * 359.9, fg_s, fg_v, fg.a)
	}
	hy := hue.y + i32(fg_h / 360 * f32(hue.h - 1))
	hline(hue.x - 2, hy, hue.w + 4, rl.WHITE)
	hline(hue.x - 2, hy + 1, hue.w + 4, rl.BLACK)

	// alpha bar
	draw_checker(alp, 4)
	rl.DrawRectangleGradientV(alp.x, alp.y, alp.w, alp.h, Color{fg.r, fg.g, fg.b, 0}, Color{fg.r, fg.g, fg.b, 255})
	outline_rect(alp, C_BORDER)
	if act, _, fy := drag_area(alp, make_id(alp, "alpha")); act {
		fg.a = u8(fy * 255 + 0.5)
	}
	ay := alp.y + i32(f32(fg.a) / 255 * f32(alp.h - 1))
	hline(alp.x - 2, ay, alp.w + 4, rl.WHITE)
	hline(alp.x - 2, ay + 1, alp.w + 4, rl.BLACK)

	// fg / bg swatches
	y += 102
	fgr := Rect{x, y, 34, 18}
	bgr := Rect{x + 40, y, 34, 18}
	draw_checker(fgr, 4)
	fill_rect(fgr, fg)
	outline_rect(fgr, C_BORDER)
	draw_checker(bgr, 4)
	fill_rect(bgr, bg)
	outline_rect(bgr, C_BORDER)
	text(fgr.x + 2, fgr.y + 20, "FG", C_TEXT_DIM)
	text(bgr.x + 2, bgr.y + 20, "BG", C_TEXT_DIM)
	if ui_hover(bgr) && ui.pressed[0] {
		run_cmd(.Swap_Colors)
	}
	if icon_button(Rect{x + 78, y, 16, 18}, .Swap, "Swap colors (X)") {
		run_cmd(.Swap_Colors)
	}
	// hex entry
	hr := Rect{x + 104, y, 58, 18}
	hid := make_id(hr, "text")
	if ui.focus_id != hid {
		name_set(&hex_buf, color_hex(fg))
	}
	if ch, sub := text_field(hr, &hex_buf, "Hex colour (RRGGBB or RRGGBBAA)"); ch || sub {
		if c, ok := parse_hex(name_str(&hex_buf)); ok {
			set_fg(c)
		}
	}

	// RGB sliders
	y += 34
	rgb := [3]int{int(fg.r), int(fg.g), int(fg.b)}
	names := [3]string{"R", "G", "B"}
	for i in 0 ..< 3 {
		if slider(Rect{x, y + i32(i) * 16, 162, 14}, &rgb[i], 0, 255, names[i]) {
			set_fg(Color{u8(rgb[0]), u8(rgb[1]), u8(rgb[2]), fg.a})
		}
	}
	y += 50

	// --- palette ---------------------------------------------------------
	hline(r.x + 1, y, r.w - 1, C_BORDER)
	y += 4
	text(x, y + 3, "Palette", C_TEXT_DIM)
	bx := area.x + area.w - 16
	if icon_button(Rect{bx, y, 16, 14}, .Minus, "Remove selected swatch", false, len(doc.palette) > 1) {
		if doc.pal_sel >= 0 && doc.pal_sel < len(doc.palette) {
			ordered_remove(&doc.palette, doc.pal_sel)
			doc.pal_sel = clamp(doc.pal_sel, 0, len(doc.palette) - 1)
			doc.modified = true
		}
	}
	bx -= 17
	if icon_button(Rect{bx, y, 16, 14}, .Plus, "Add foreground colour to palette") {
		append(&doc.palette, Color{fg.r, fg.g, fg.b, 255})
		doc.pal_sel = len(doc.palette) - 1
		doc.modified = true
	}
	bx -= 17
	if icon_button(Rect{bx, y, 16, 14}, .Pencil, "Replace selected swatch with foreground", false, len(doc.palette) > 0) {
		if doc.pal_sel >= 0 && doc.pal_sel < len(doc.palette) {
			doc.palette[doc.pal_sel] = Color{fg.r, fg.g, fg.b, 255}
			doc.modified = true
		}
	}
	bx -= 52
	if button(Rect{bx, y, 50, 14}, "Presets", "Load a palette preset") {
		popup_begin(PALETTE_PRESET_ID, Rect{bx, y, 50, 14}, 120)
		for p in Palette_Preset {
			popup_item(PALETTE_PRESET_NAMES[p], int(p))
		}
	}
	if ui.popup_result_id == PALETTE_PRESET_ID {
		palette_set_preset(doc, Palette_Preset(ui.popup_result_val))
		ui.popup_result_id = 0
	}
	y += 18

	cell: i32 = 14
	cols := max(area.w / cell, 1)
	// leave room for the preview below
	prev_h: i32 = (show_preview ? 120 : 0) + FILTER_PANEL_H
	pal_rows := i32((len(doc.palette) + int(cols) - 1) / int(cols))
	pal_h := min(max(r.y + r.h - y - prev_h - 10, cell), max(pal_rows * cell + 2, cell))
	pal := Rect{x, y, area.w, pal_h}
	@(static) pal_scroll: i32
	rows := i32((len(doc.palette) + int(cols) - 1) / int(cols))
	max_scroll := max(rows * cell - pal.h, 0)
	if ui_hover(pal) && ui.wheel != 0 {
		pal_scroll -= i32(ui.wheel) * cell
	}
	pal_scroll = clamp(pal_scroll, 0, max_scroll)
	fill_rect(pal, C_PANEL_DK)
	clip_begin(pal)
	for c, i in doc.palette {
		cxp := pal.x + i32(i % int(cols)) * cell
		cyp := pal.y + i32(i / int(cols)) * cell - pal_scroll
		if cyp + cell < pal.y || cyp > pal.y + pal.h {
			continue
		}
		sr := Rect{cxp, cyp, cell, cell}
		fill_rect(Rect{sr.x, sr.y, sr.w - 1, sr.h - 1}, c)
		if color_eq(c, fg) {
			outline_rect(Rect{sr.x, sr.y, sr.w - 1, sr.h - 1}, rl.WHITE)
		}
		if i == doc.pal_sel {
			outline_rect(Rect{sr.x, sr.y, sr.w - 1, sr.h - 1}, C_ACCENT)
		}
		if ui_hover(sr) && ui_hover(pal) {
			if ui.pressed[0] {
				set_fg(c)
				doc.pal_sel = i
			} else if ui.pressed[1] {
				bg = c
				doc.pal_sel = i
			}
		}
	}
	clip_end()
	outline_rect(pal, C_BORDER)
	y += pal_h + 6

	// --- filters ----------------------------------------------------------
	hline(r.x + 1, y - 3, r.w - 1, C_BORDER)
	panel_filters(Rect{x, y, area.w, FILTER_PANEL_H - 6})
	y += FILTER_PANEL_H

	// --- preview ---------------------------------------------------------
	if show_preview {
		hline(r.x + 1, y - 3, r.w - 1, C_BORDER)
		pr := Rect{x, y, area.w, r.y + r.h - y - 6}
		if pr.h > 24 {
			panel_preview(pr)
		}
	}
}

panel_preview :: proc(r: Rect) {
	fill_rect(r, C_PANEL_DK)
	outline_rect(r, C_BORDER)
	d := doc
	if tex_canvas.id == 0 || tex_w != d.w || tex_h != d.h {
		return
	}
	zx := f32(r.w - 4) / f32(d.w)
	zy := f32(r.h - 4) / f32(d.h)
	z := min(zx, zy)
	if z >= 1 {
		z = f32(int(z))
	}
	w := f32(d.w) * z
	h := f32(d.h) * z
	dst := rl.Rectangle{f32(r.x) + (f32(r.w) - w) / 2, f32(r.y) + (f32(r.h) - h) / 2, w, h}
	dst.x = math.floor(dst.x)
	dst.y = math.floor(dst.y)
	clip_begin(r)
	if bg_mode == 0 {
		draw_checker(Rect{i32(dst.x), i32(dst.y), i32(w), i32(h)}, 4)
	} else {
		fill_rect(Rect{i32(dst.x), i32(dst.y), i32(w), i32(h)}, canvas_bg_color())
	}
	rl.DrawTexturePro(tex_canvas, {0, 0, f32(d.w), f32(d.h)}, dst, {}, 0, rl.WHITE)
	clip_end()
}

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

tl_scroll_x, tl_scroll_y: i32

panel_timeline :: proc(r: Rect) {
	ui.layer = 0
	fill_rect(r, C_PANEL)
	hline(r.x, r.y, r.w, C_BORDER)
	d := doc

	// control bar
	bar := Rect{r.x + 2, r.y + 3, r.w - 4, 16}
	x := bar.x
	by := bar.y
	b :: proc(x: ^i32, y: i32) -> Rect {
		rc := Rect{x^, y, 18, 16}
		x^ += 19
		return rc
	}
	if badge_button(b(&x, by), .Layer, true, "New layer (Shift+N)") {
		run_cmd(.Layer_New)
	}
	if badge_button(b(&x, by), .Layer, false, "Delete layer", len(d.layers) > 1) {
		run_cmd(.Layer_Del)
	}
	if icon_button(b(&x, by), .Copy, "Duplicate layer") {
		run_cmd(.Layer_Dup)
	}
	if icon_button(b(&x, by), .Up, "Move layer up", false, d.active_layer < len(d.layers) - 1) {
		run_cmd(.Layer_Up)
	}
	if icon_button(b(&x, by), .Down, "Move layer down", false, d.active_layer > 0) {
		run_cmd(.Layer_Down)
	}
	x += 8
	if badge_button(b(&x, by), .Frame, true, "New frame (Alt+N)") {
		run_cmd(.Frame_New)
	}
	if icon_button(b(&x, by), .Copy, "Duplicate frame") {
		run_cmd(.Frame_Dup)
	}
	if badge_button(b(&x, by), .Frame, false, "Delete frame", len(d.frames) > 1) {
		run_cmd(.Frame_Del)
	}
	x += 8
	if icon_button(b(&x, by), .First, "First frame (Home)") {
		run_cmd(.Frame_First)
	}
	if icon_button(b(&x, by), .Left, "Previous frame (,)") {
		run_cmd(.Frame_Prev)
	}
	if icon_button(b(&x, by), playing ? .Stop : .Right, "Play / pause (Enter)", playing) {
		run_cmd(.Play)
	}
	if icon_button(b(&x, by), .Right, "Next frame (.)") {
		run_cmd(.Frame_Next)
	}
	if icon_button(b(&x, by), .Last, "Last frame (End)") {
		run_cmd(.Frame_Last)
	}
	x += 8
	// tag selector for playback
	tag_items := make([dynamic]string, context.temp_allocator)
	append(&tag_items, "All frames")
	for &t in d.tags {
		append(&tag_items, name_str(&t.name))
	}
	tv, tch := combo(Rect{x, by, 100, 16}, tag_items[:], play_tag + 1, "Playback range")
	if tch {
		play_tag = tv - 1
		if play_tag >= 0 && play_tag < len(d.tags) {
			set_frame(d.tags[play_tag].from)
		}
	}
	x += 104
	if button(Rect{x, by, 38, 16}, "Tags", "Edit animation tags") {
		run_cmd(.Tags)
	}
	x += 42
	if button(Rect{x, by, 76, 16}, fmt.tprintf("%d ms", d.frames[d.active_frame].duration), "Frame duration (click to edit)") {
		run_cmd(.Frame_Props)
	}

	body := Rect{r.x, r.y + 22, r.w, r.h - 22}
	hdr_w: i32 = 150
	frame_w: i32 = 16
	row_h: i32 = 14
	hdr_h: i32 = 18
	names := Rect{body.x, body.y + hdr_h, hdr_w, body.h - hdr_h}
	head := Rect{body.x + hdr_w, body.y, body.w - hdr_w, hdr_h}
	grid := Rect{body.x + hdr_w, body.y + hdr_h, body.w - hdr_w, body.h - hdr_h}

	nlayers := i32(len(d.layers))
	nframes := i32(len(d.frames))
	content_w := nframes * frame_w + 20
	content_h := nlayers * row_h

	if (ui_hover(grid) || ui_hover(names) || ui_hover(head)) && ui.wheel != 0 {
		if ui.shift {
			tl_scroll_x -= i32(ui.wheel) * frame_w * 2
		} else {
			tl_scroll_y -= i32(ui.wheel) * row_h
		}
	}
	tl_scroll_x = clamp(tl_scroll_x, 0, max(content_w - grid.w, 0))
	tl_scroll_y = clamp(tl_scroll_y, 0, max(content_h - grid.h, 0))
	// keep the active frame visible while playing / navigating
	fx0 := d.active_frame
	if i32(fx0) * frame_w < tl_scroll_x {
		tl_scroll_x = i32(fx0) * frame_w
	} else if i32(fx0 + 1) * frame_w > tl_scroll_x + grid.w {
		tl_scroll_x = i32(fx0 + 1) * frame_w - grid.w
	}

	fill_rect(Rect{body.x, body.y, hdr_w, hdr_h}, C_PANEL_DK)
	fill_rect(head, C_PANEL_DK)
	fill_rect(names, C_PANEL_DK)
	fill_rect(grid, C_PANEL_DK)
	vline(body.x + hdr_w - 1, body.y, body.h, C_BORDER)
	hline(body.x, body.y + hdr_h - 1, body.w, C_BORDER)

	// header: frame numbers + tags
	clip_begin(head)
	for f in 0 ..< nframes {
		fx := head.x + f * frame_w - tl_scroll_x
		if fx + frame_w < head.x || fx > head.x + head.w {
			continue
		}
		active := int(f) == d.active_frame
		if active {
			fill_rect(Rect{fx, head.y, frame_w, hdr_h - 1}, C_ACTIVE)
		}
		s := fmt.tprintf("%d", f + 1)
		text(fx + (frame_w - text_w(s)) / 2, head.y + 2, s, active ? C_TEXT : C_TEXT_DIM)
		vline(fx + frame_w - 1, head.y, hdr_h, C_BORDER)
	}
	for &t, ti in d.tags {
		tx0 := head.x + i32(t.from) * frame_w - tl_scroll_x
		tw := i32(t.to - t.from + 1) * frame_w
		tr := Rect{tx0, head.y + 11, tw - 1, 6}
		fill_rect(tr, t.color)
		if ti == play_tag {
			outline_rect(Rect{tr.x - 1, tr.y - 1, tr.w + 2, tr.h + 2}, rl.WHITE)
		}
		if ui_hover(tr) && ui.pressed[0] {
			play_tag = play_tag == ti ? -1 : ti
		}
	}
	clip_end()
	// scrubbing on the header numbers
	head_num := Rect{head.x, head.y, head.w, 11}
	hid := make_id(head_num, "scrub")
	if ui_hover(head_num) && ui.pressed[0] {
		ui.active_id = hid
	}
	if ui.active_id == hid && ui.down[0] {
		f := int((ui.mx - head.x + tl_scroll_x) / frame_w)
		set_frame(f)
	}

	// layer rows
	clip_begin(names)
	for i in 0 ..< nlayers {
		li := int(nlayers - 1 - i)
		ry := names.y + i * row_h - tl_scroll_y
		if ry + row_h < names.y || ry > names.y + names.h {
			continue
		}
		l := &d.layers[li]
		row := Rect{names.x, ry, names.w - 1, row_h}
		if li == d.active_layer {
			fill_rect(row, C_ACTIVE)
		} else if ui_hover(row) {
			fill_rect(row, C_PANEL_LT)
		}
		hline(row.x, ry + row_h - 1, row.w, C_BORDER)
		eye := Rect{row.x + 2, ry + 1, 12, 12}
		lock := Rect{row.x + 16, ry + 1, 12, 12}
		icon(.Eye, eye.x, eye.y, l.visible ? C_TEXT : Color{80, 80, 96, 255})
		icon(.Lock, lock.x, lock.y, l.locked ? C_ACCENT : Color{80, 80, 96, 255})
		text(row.x + 34, ry + 3, name_str(&l.name), l.visible ? C_TEXT : C_TEXT_DIM)
		if l.opacity < 255 || l.blend != .Normal {
			text(row.x + row.w - 22, ry + 3, "fx", C_TEXT_DIM)
		}
		if ui_hover(row) && ui_hover(names) && ui.pressed[0] {
			if in_rect(eye, ui.mx, ui.my) {
				l.visible = !l.visible
				d.comp_dirty = true
				d.modified = true
			} else if in_rect(lock, ui.mx, ui.my) {
				l.locked = !l.locked
				d.modified = true
			} else {
				d.active_layer = li
				if ui.dbl_click {
					dialog_open(.Layer_Props)
				}
			}
		}
	}
	clip_end()

	// cells
	clip_begin(grid)
	for i in 0 ..< nlayers {
		li := int(nlayers - 1 - i)
		ry := grid.y + i * row_h - tl_scroll_y
		if ry + row_h < grid.y || ry > grid.y + grid.h {
			continue
		}
		for f in 0 ..< nframes {
			fx := grid.x + f * frame_w - tl_scroll_x
			if fx + frame_w < grid.x || fx > grid.x + grid.w {
				continue
			}
			cr := Rect{fx, ry, frame_w - 1, row_h - 1}
			active_cel := li == d.active_layer && int(f) == d.active_frame
			col := C_PANEL
			if int(f) == d.active_frame || li == d.active_layer {
				col = C_PANEL_LT
			}
			if active_cel {
				col = C_ACTIVE
			}
			fill_rect(cr, col)
			// shared (linked) cels get a small marker
			if d.layers[li].cels[f].refs > 1 && active_cel {
				fill_rect(Rect{cr.x + 5, cr.y + 4, 4, 4}, C_ACCENT)
			}
		}
	}
	// current frame column line
	clip_end()
	gid := make_id(grid, "cells")
	if ui_hover(grid) && ui.pressed[0] {
		ui.active_id = gid
	}
	if ui.active_id == gid && ui.down[0] {
		f := int((ui.mx - grid.x + tl_scroll_x) / frame_w)
		set_frame(f)
		if ui.pressed[0] {
			row := int((ui.my - grid.y + tl_scroll_y) / row_h)
			li := len(d.layers) - 1 - row
			if li >= 0 && li < len(d.layers) {
				d.active_layer = li
			}
			if ui.dbl_click {
				dialog_open(.Frame_Props)
			}
		}
	}
	// outline of the layers header
	text(body.x + 4, body.y + 5, "Layers", C_TEXT_DIM)
}

// ---------------------------------------------------------------------------
// Status bar
// ---------------------------------------------------------------------------

panel_status :: proc(r: Rect, vp: Rect) {
	ui.layer = 0
	fill_rect(r, C_PANEL_DK)
	hline(r.x, r.y, r.w, C_BORDER)
	ty := r.y + 3
	if status_t > 0 {
		text(r.x + 6, ty, name_str(&status_msg), C_ACCENT)
	} else {
		s := TOOL_NAMES[cur_tool]
		text(r.x + 6, ty, s, C_TEXT_DIM)
	}
	x := r.x + 260
	if hover_valid && px_valid(hover_px) {
		c := doc.comp[hover_px.y * doc.w + hover_px.x]
		textf(x, ty, C_TEXT, "%d, %d", hover_px.x, hover_px.y)
		swr := Rect{x + 60, r.y + 3, 8, 8}
		fill_rect(swr, c)
		outline_rect(swr, C_BORDER)
		text(x + 72, ty, color_hex(c), C_TEXT_DIM)
	}
	if doc.sel != nil {
		x0, y0, x1, y1, ok := sel_bounds(doc.sel, doc.w, doc.h)
		if ok {
			textf(x + 150, ty, C_TEXT_DIM, "Sel %dx%d", x1 - x0 + 1, y1 - y0 + 1)
		}
	}
	// right: size, frame, zoom
	info := fmt.tprintf("%dx%d   Frame %d/%d   %d%%", doc.w, doc.h, doc.active_frame + 1, len(doc.frames), int(doc.zoom * 100))
	text(r.x + r.w - text_w(info) - 8, ty, info, C_TEXT_DIM)
}

// ---------------------------------------------------------------------------
// Layer filters
// ---------------------------------------------------------------------------

FILTER_PANEL_H :: 118
FILTER_ADD_ID :: u32(0xF117E125)

filter_scroll: i32
filter_drag_changed: bool
filter_drag_pushed: bool

// Header with an "Add Filter" button, then the active layer's filter stack.
// Edits go through history_push so they undo like any other change.
panel_filters :: proc(r: Rect) {
	d := doc
	layer := &d.layers[d.active_layer]

	text(r.x, r.y + 3, "Filters", C_TEXT_DIM)
	add_r := Rect{r.x + r.w - 70, r.y, 70, 14}
	if button(add_r, "Add Filter", "Add a filter to the current layer") {
		popup_begin(FILTER_ADD_ID, add_r, 100)
		for k in Filter_Kind {
			popup_item(FILTER_INFO[k].name, int(k))
		}
	}
	if ui.popup_result_id == FILTER_ADD_ID {
		history_push(d)
		append(&layer.filters, filter_make(Filter_Kind(ui.popup_result_val)))
		doc_touch(d)
		ui.popup_result_id = 0
		filter_scroll = max(i32(len(layer.filters)) * 32, 0) // jump to the new entry
	}

	list := Rect{r.x, r.y + 17, r.w, r.h - 17}
	fill_rect(list, C_PANEL_DK)
	if len(layer.filters) == 0 {
		text_clipped(list, "  No filters on this layer", C_TEXT_DIM)
		outline_rect(list, C_BORDER)
		return
	}

	// row heights: name line, plus a slider line for filters with a parameter
	row_h :: proc(f: Layer_Filter) -> i32 {
		return FILTER_INFO[f.kind].has_param ? 32 : 17
	}
	total: i32
	for f in layer.filters {
		total += row_h(f)
	}
	hover_slider := false
	max_scroll := max(total - list.h, 0)
	filter_scroll = clamp(filter_scroll, 0, max_scroll)

	// deferred actions so the list is not modified while iterating
	act_del, act_up, act_down, act_toggle := -1, -1, -1, -1

	clip_begin(list)
	cy := list.y - filter_scroll
	n := len(layer.filters)
	for &f, i in layer.filters {
		h := row_h(f)
		if cy + h < list.y || cy > list.y + list.h {
			cy += h
			continue
		}
		info := FILTER_INFO[f.kind]
		row := Rect{list.x, cy, list.w, h - 1}
		if ui_hover(row) && ui_hover(list) {
			fill_rect(row, C_PANEL)
		}
		eye := Rect{row.x + 1, cy + 1, 15, 14}
		if icon_button(eye, .Eye, f.enabled ? "Disable filter" : "Enable filter", f.enabled) && ui_hover(list) {
			act_toggle = i
		}
		bx := row.x + row.w - 15
		if icon_button(Rect{bx, cy + 1, 14, 14}, .Close, "Remove filter") && ui_hover(list) {
			act_del = i
		}
		bx -= 15
		if icon_button(Rect{bx, cy + 1, 14, 14}, .Down, "Move filter down (applied later)", false, i < n - 1) && ui_hover(list) {
			act_down = i
		}
		bx -= 15
		if icon_button(Rect{bx, cy + 1, 14, 14}, .Up, "Move filter up (applied earlier)", false, i > 0) && ui_hover(list) {
			act_up = i
		}
		text_clipped(Rect{eye.x + eye.w + 4, cy + 1, bx - eye.x - eye.w - 6, 14}, info.name, f.enabled ? C_TEXT : C_TEXT_DIM)
		if info.has_param {
			sr := Rect{row.x + 2, cy + 17, row.w - 4, 13}
			if ui_hover(sr) {
				hover_slider = true
				// one undo step per drag / wheel notch
				if (ui.pressed[0] || ui.wheel != 0) && !filter_drag_pushed {
					history_push(d)
					filter_drag_pushed = true
					filter_drag_changed = false
				}
			}
			if slider(sr, &f.amount, info.lo, info.hi, info.param) {
				filter_drag_changed = true
				doc_touch(d)
			}
		}
		cy += h
	}
	clip_end()
	outline_rect(list, C_BORDER)

	if filter_drag_pushed && !ui.down[0] && ui.wheel == 0 {
		if !filter_drag_changed {
			history_discard(d)
		}
		filter_drag_pushed = false
	}

	if ui_hover(list) && !hover_slider && ui.wheel != 0 {
		filter_scroll = clamp(filter_scroll - i32(ui.wheel) * 17, 0, max_scroll)
	}

	if act_toggle >= 0 {
		history_push(d)
		layer.filters[act_toggle].enabled = !layer.filters[act_toggle].enabled
		doc_touch(d)
	} else if act_del >= 0 {
		history_push(d)
		ordered_remove(&layer.filters, act_del)
		doc_touch(d)
	} else if act_up >= 0 {
		history_push(d)
		layer.filters[act_up], layer.filters[act_up - 1] = layer.filters[act_up - 1], layer.filters[act_up]
		doc_touch(d)
	} else if act_down >= 0 {
		history_push(d)
		layer.filters[act_down], layer.filters[act_down + 1] = layer.filters[act_down + 1], layer.filters[act_down]
		doc_touch(d)
	}
}
