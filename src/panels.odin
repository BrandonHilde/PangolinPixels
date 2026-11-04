package pangolin

import "core:fmt"
import "core:math"

import oui "odinui:odinui"

PALETTE_PRESET_ID :: u32(0xA11E77E1)
FILTER_ADD_ID :: u32(0xF117E125)

// ---------------------------------------------------------------------------
// Top-level layout: the theme places the areas (#menubar, #body, #toolbar, #viewport ...) and
// each panel draws into the box it gets.
// ---------------------------------------------------------------------------

panels_init :: proc() {
	oui_slot_register("logo", proc(r: Rect, _: int) {logo_draw(r.x, r.y + (r.h - LOGO_SIZE) / 2, 1)})
	oui_slot_register("color_chips", proc(r: Rect, _: int) {panel_color_chips(r)})
	oui_slot_register("color_picker", proc(r: Rect, _: int) {panel_color_picker(r)})
	oui_slot_register("hex_field", proc(r: Rect, _: int) {panel_hex_field(r)})
	oui_slot_register("palette", proc(r: Rect, _: int) {panel_palette(r)})
	oui_slot_register("recent", proc(r: Rect, _: int) {panel_recent(r)})
	oui_slot_register("filter_list", proc(r: Rect, _: int) {panel_filter_list(r)})
	oui_slot_register("preview", proc(r: Rect, _: int) {panel_preview(r)})
	oui_slot_register("timeline_grid", proc(r: Rect, _: int) {panel_timeline_grid(r)})
	oui_slot_register("files_grid", proc(r: Rect, _: int) {panel_files_grid(r)})
	oui_slot_register("canvas_bg", proc(r: Rect, _: int) {panel_canvas_bg(r)})
	oui_slot_register("cursor_info", proc(r: Rect, _: int) {panel_cursor_info(r)})
	oui_slot_register("groups_bar", proc(r: Rect, _: int) {panel_groups_bar(r)})
	oui_slot_register("viewport", proc(r: Rect, _: int) {panel_viewport(r)})
}

main_ui :: proc() {
	oui.element(uictx, "window", "screen", {id = "window"})
	defer oui.end(uictx)
	panel_menubar()
	panel_options()
	if canvas_mode {
		oui_slot("viewport", "viewport")
		oui_slot("groups-bar", "groups_bar")
		return
	}
	oui.element(uictx, "body", "row", {id = "body"})
	panel_toolbar()
	oui.element(uictx, "center", "column", {id = "center"})
	panel_tabs()
	oui_slot("viewport", "viewport")
	panel_timeline()
	oui.end(uictx)
	panel_right()
	oui.end(uictx)
	panel_status()
}

panel_viewport :: proc(viewport: Rect) {
	// keep the picture where it was on screen when the viewport changes size
	@(static) prev_vp: Rect
	if doc.view_init && prev_vp.w > 0 && (prev_vp.w != viewport.w || prev_vp.h != viewport.h || prev_vp.x != viewport.x || prev_vp.y != viewport.y) {
		doc.ox += f32(viewport.x + viewport.w / 2 - prev_vp.x - prev_vp.w / 2)
		doc.oy += f32(viewport.y + viewport.h / 2 - prev_vp.y - prev_vp.h / 2)
	}
	prev_vp = viewport
	canvas_update(viewport)
	render_canvas(viewport)
}

// ---------------------------------------------------------------------------
// Menu bar
// ---------------------------------------------------------------------------

MENU_TITLES := [?]string{"File", "Edit", "Sprite", "Layer", "Frame", "Select", "View", "Workspaces", "Help"}

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
		item("Convert Image to Pixel Art...", cmd = .Pixel_Art_Convert)
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
		popup_sep()
		item("Convert to Pixel Art...", cmd = .Pixel_Art_Sprite)
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
		item("Snap to Grid", cmd = .Toggle_Snap, checked = opts.snap)
		item("Grid Settings...", cmd = .Grid_Settings)
		item("Onion Skin", cmd = .Toggle_Onion, checked = opts.onion)
		item("Symmetry Horizontal", cmd = .Toggle_Sym_X, checked = opts.sym_x)
		item("Symmetry Vertical", cmd = .Toggle_Sym_Y, checked = opts.sym_y)
		item("Cycle Tiled Mode", cmd = .Cycle_Tile, checked = opts.tile != .Off)
		item("Canvas Background...", cmd = .Canvas_Bg)
		item("Transparency Checkers", cmd = .Toggle_Checks, checked = opts.show_checks)
		popup_sep()
		item("Canvas Mode", cmd = .Toggle_Canvas_Mode, checked = canvas_mode)
		item("Timeline", cmd = .Toggle_Timeline, checked = bottom_mode == .Animation)
		item("File Browser", cmd = .Toggle_Files, checked = bottom_mode == .Files)
		item("Navigator", cmd = .Toggle_Preview, checked = show_preview)
		item("Preferences...", cmd = .Preferences)
	case 7:
		ws_refresh()
		for e, i in ws_entries {
			if i == len(WS_BUILTIN_NAMES) do popup_sep()
			item(e.name, cmd = Cmd(int(Cmd.Ws_First) + i), checked = e.name == ws_current)
		}
		popup_sep()
		item("Manage Workspaces...", cmd = .Ws_Manage)
		item("Import Workspace...", cmd = .Ws_Import)
		item("Export Workspace...", cmd = .Ws_Export)
	case 8:
		item("Keyboard Shortcuts", cmd = .Help_Keys)
		item("About", cmd = .About)
	}
}

menu_request := -1 // a menu to open (--menu)

panel_menubar :: proc() {
	bar := oui.element(uictx, "menubar", "menubar", {id = "menubar"})
	defer oui.end(uictx)
	oui_slot("logo", "logo")
	menu_open := popup.open && popup.menu_idx >= 0
	for title, i in MENU_TITLES {
		is_open := menu_open && popup.menu_idx == i
		n := oui.button_begin(uictx, title, {class = is_open ? "menu-title open" : "menu-title"})
		oui.label(uictx, "t", title)
		oui.end(uictx)
		// menus drop from the bottom of the bar
		r := oui_rect(n)
		br := oui_rect(bar)
		anchor := Rect{r.x, br.y, r.w, br.h - 1}
		id := make_id(anchor, title)
		if n.pressed || menu_request == i {
			menu_request = -1
			popup_begin(id, anchor, 0, i)
			menu_build(i)
		} else if menu_open && ui.input_layer < 2 && in_rect(anchor, ui.mx, ui.my) {
			// while a menu is open the bar takes no clicks: moving along it switches menus,
			// clicking the open one's title closes it
			if ui.pressed[0] && is_open {
				popup_close()
			} else if !is_open {
				popup_begin(id, anchor, 0, i)
				menu_build(i)
			}
		}
	}
	oui.element_leaf(uictx, "spacer", "spacer")
	if c, _ := oui_icon_button("canvas-mode", .Canvas_Mode, "Canvas mode (Tab)", {lit = canvas_mode, enabled = true}); c {
		run_cmd(.Toggle_Canvas_Mode)
	}
	oui.label(uictx, "doc", doc_display_name(doc), {id = "doc-name"})
}

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

panel_tabs :: proc() {
	tabs_rect = oui_rect(oui.element(uictx, "tabs", "tabbar", {id = "tabs"}))
	defer oui.end(uictx)
	close_idx := -1
	switch_idx := -1
	for d, i in docs {
		active := d == doc
		t := oui.button_begin(uictx, fmt.tprintf("tab%x", uintptr(d)), {class = active ? "tab active" : "tab"})
		if active do oui.element_leaf(uictx, "accent", "tab-accent")
		oui.label(uictx, "name", doc_display_name(d))
		if c, _ := oui_icon_button("close", .Close, "", {class = "tab-close", enabled = true}); c {
			close_idx = i
		}
		oui.end(uictx)
		if t.pressed do switch_idx = i // a press on the tab itself, not its close button
		if t.hovered && ui.pressed[2] do close_idx = i
	}
	if c, _ := oui_icon_button("new", .Plus, "New sprite", {id = "new-tab", enabled = true}); c {
		run_cmd(.New)
	}
	if close_idx >= 0 {
		request_close(docs[close_idx])
	} else if switch_idx >= 0 {
		switch_doc(switch_idx)
	}
}

// ---------------------------------------------------------------------------
// Toolbar: tool groups
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
	.Grid           = .Grid,
	.Symmetry       = .Sym_X,
	.Tiling         = .Tile,
	.Onion          = .Onion,
}

panel_toolbar :: proc() {
	oui.element(uictx, "toolbar", "toolbar", {id = "toolbar"})
	defer oui.end(uictx)
	t := eff_tool()
	rem_g, rem_t := -1, -1
	cur_group := current_group()
	for &g, gi in tool_groups {
		oui.element(uictx, fmt.tprintf("g%d", gi), "tool-group")
		// header: the name on the left, the hotkey as a keycap on the right
		// (click the keycap for options; right-click the header for rename / remove)
		hdr := oui.element(uictx, "head", "group-head")
		oui.label(uictx, "title", group_title(&g), {class = "group-title"})
		if g.own {
			dot := oui.element_leaf(uictx, "own", "own-dot", {interactive = true})
			oui_tip(dot, "This group keeps its own brush settings (click the hotkey for options)")
		}
		waiting := group_key_wait == gi
		label := waiting ? "..." : (g.key == .KEY_NULL ? "-" : key_name(g.key))
		kc := oui.button_begin(uictx, "key", {class = label == "-" ? "keycap none" : "keycap", checked = waiting})
		oui.label(uictx, "t", label)
		oui.end(uictx)
		oui_tip(kc, "Group hotkey (click for options)")
		oui.end(uictx)
		bid := make_id({}, fmt.tprintf("grpbadge%d", gi))
		if kc.clicked {
			popup_begin(bid, oui_rect(kc), 120)
			popup_item("Assign hotkey...", 0)
			popup_item("Rename...", 3)
			if len(g.colors) == 0 && len(g.patterns) == 0 {
				popup_item("Own brush settings", 4, checked = g.own)
			}
			popup_item("Remove group", 1)
		}
		if ui.popup_result_id == bid {
			switch ui.popup_result_val {
			case 0:
				group_key_wait = gi
				set_statusf("Press a key for this tool group (Esc cancels, Backspace clears)")
			case 3:
				group_rename_open(gi)
			case 4:
				group_set_own(gi, !g.own)
				set_statusf(g.own ? "%s keeps its own brush size, shape, pattern and ink" : "%s shares the brush settings again", group_title(&g))
			case:
				rem_g = gi
			}
			ui.popup_result_id = 0
		}
		// right-click anywhere on the header for a menu (opened on release,
		// since a popup opened on the press would be closed by that same click)
		hid := make_id({}, fmt.tprintf("grphdr%d", gi))
		if hdr.hovered && ui.released[1] && !popup.open {
			popup_begin(hid, Rect{ui.mx, ui.my, 1, 1}, 110)
			popup_item("Rename...", 3)
			popup_item("Remove group", 1)
		}
		if ui.popup_result_id == hid {
			if ui.popup_result_val == 3 {
				group_rename_open(gi)
			} else {
				rem_g = gi
			}
			ui.popup_result_id = 0
		}
		is_colors := len(g.colors) > 0
		is_tools := len(g.tools) > 0
		is_patterns := len(g.patterns) > 0
		oui.element(uictx, "items", "group-items", {class = is_patterns ? "patterns" : ""})
		for tool, ti in g.tools {
			lit := t == tool && cur_group == gi
			if tool_is_toggle(tool) do lit = tool_toggle_on(tool)
			clicked, bn := oui_icon_button(fmt.tprintf("t%d", int(tool)), TOOL_ICONS[tool], TOOL_NAMES[tool], {class = "tool", lit = lit, enabled = true, icon_lg = true})
			if clicked {
				if !tool_is_toggle(tool) do g.last = tool
				select_tool_in_group(tool, gi)
			} else if bn.hovered && ui.pressed[1] && !popup.open {
				rem_g, rem_t = gi, ti
			}
		}
		// patterns are listed one per row, the active one highlighted
		for pat, pi in g.patterns {
			if obutton(PATTERN_NAMES[pat], 0, "Dither pattern (right-click to remove)", true, pat == opts.pattern, key = fmt.tprintf("p%d", pi), class = "pattern-row") {
				opts.pattern = pat
			}
			if oui_last != nil && oui_last.hovered && ui.pressed[1] && !popup.open {
				rem_g, rem_t = gi, pi
			}
		}
		for c, ci in g.colors {
			same := c.r == fg.r && c.g == fg.g && c.b == fg.b
			linked := color_link_g == gi && color_link_i == ci
			class := linked ? "color-chip linked" : (same ? "color-chip same" : "color-chip")
			cn := oui.button_begin(uictx, fmt.tprintf("c%d", ci), {class = class, style = fmt.tprintf("background:#%02x%02x%02x", c.r, c.g, c.b)})
			oui.end(uictx)
			oui_tip(cn, color_hex(c))
			if cn.clicked {
				color_link_set(gi, ci)
			} else if cn.hovered && ui.pressed[1] && !popup.open {
				rem_g, rem_t = gi, ci
			}
		}
		can_add := is_colors ? len(g.colors) < MAX_GROUP_COLORS : (is_patterns ? len(g.patterns) < len(Pattern) : len(g.tools) < len(Tool))
		if can_add {
			tip := "Add tools, switches, colours or dither patterns to this group (right-click an item to remove it)"
			pid := make_id({}, fmt.tprintf("grpadd%d", gi))
			add_clicked, add_node := oui_icon_button("add", .Plus, tip, {class = "tool quiet", enabled = true, icon_lg = true})
			if add_clicked {
				popup_begin(pid, oui_rect(add_node))
				popup_grid(5)
				any_section := false
				if !is_colors && !is_patterns {
					for tool in Tool {
						if !tool_group_has(&g, tool) {
							popup_item_icon(TOOL_NAMES[tool], int(tool), TOOL_ICONS[tool])
						}
					}
					any_section = true
				}
				if !is_tools && !is_patterns {
					if any_section do popup_sep()
					popup_item_swatch("Foreground colour", 100, fg)
					popup_item("All palette colours", 101)
					for p in Palette_Preset {
						popup_item_palette(PALETTE_PRESET_NAMES[p], 200 + int(p), p)
					}
					any_section = true
				}
				if !is_tools && !is_colors {
					if any_section do popup_sep()
					for pat in Pattern {
						if !pattern_in(g.patterns[:], pat) {
							popup_item_half(PATTERN_NAMES[pat], 300 + int(pat))
						}
					}
				}
			}
			if ui.popup_result_id == pid {
				v := ui.popup_result_val
				add_colors :: proc(g: ^Tool_Group, cs: []Color) {
					for c in cs {
						if len(g.colors) >= MAX_GROUP_COLORS do break
						append(&g.colors, Color{c.r, c.g, c.b, 255})
					}
				}
				switch {
				case v < 100:
					append(&g.tools, Tool(v))
					if !tool_is_toggle(Tool(v)) && (len(g.tools) == 1 || tool_is_toggle(g.last)) do g.last = Tool(v)
				case v >= 300:
					append(&g.patterns, Pattern(v - 300))
				case v == 100:
					add_colors(&g, {fg})
				case v == 101:
					add_colors(&g, doc.palette[:])
				case:
					add_colors(&g, palette_preset(Palette_Preset(v - 200)))
				}
				ui.popup_result_id = 0
			}
		}
		oui.end(uictx) // items
		oui.end(uictx) // group
	}
	if rem_g >= 0 {
		color_link_clear() // indices shift
		if rem_t >= 0 {
			rg := &tool_groups[rem_g]
			switch {
			case len(rg.colors) > 0:
				ordered_remove(&rg.colors, rem_t)
			case len(rg.patterns) > 0:
				ordered_remove(&rg.patterns, rem_t)
			case:
				ordered_remove(&rg.tools, rem_t)
			}
		} else {
			tool_group_remove(rem_g)
		}
	}
	if len(tool_groups) < MAX_TOOL_GROUPS {
		if obutton("+ New Group", 0, "Add an empty tool group", id = "new-group") {
			append(&tool_groups, Tool_Group{})
		}
	}
	oui.separator(uictx, "chips-sep")
	oui_slot("color-chips", "color_chips")
}

// Foreground / background chips below the tool groups.
panel_color_chips :: proc(r: Rect) {
	bgr := Rect{r.x + 13, r.y + 14, 24, 24}
	fgr := Rect{r.x, r.y, 24, 24}
	chip :: proc(cr: Rect, c: Color, ring: Color) {
		if c.a < 255 {
			clip_begin(rect_inset(cr, 1))
			draw_checker(cr, 3)
			clip_end()
		}
		draw_rrect(f32(cr.x), f32(cr.y), f32(cr.w), f32(cr.h), 4, c)
		draw_rrect_outline(f32(cr.x), f32(cr.y), f32(cr.w), f32(cr.h), 4, ring)
	}
	chip(bgr, bg, ui_hover(bgr) && !ui_hover(fgr) ? WHITE : C_RING_HI)
	draw_shadow(f32(fgr.x), f32(fgr.y + 1), 24, 24, 4, 5, Color{0, 0, 0, 140})
	chip(fgr, fg, WHITE)
	if ui_hover(bgr) && !ui_hover(fgr) {
		tooltip_hover(make_id(bgr, "bgchip"), "Background colour (click to swap)")
		if ui.pressed[0] {
			run_cmd(.Swap_Colors)
		}
	}
}

// ---------------------------------------------------------------------------
// Tool options bar
// ---------------------------------------------------------------------------

INK_NAMES := [?]string{"Ink: Normal", "Ink: Replace", "Ink: Lock A"}
TILE_NAMES := [?]string{"Tile: off", "Tile: X", "Tile: Y", "Tile: X+Y"}

pattern_names :: proc() -> []string {
	@(static) names: [len(Pattern)]string
	for n, i in PATTERN_NAMES {
		names[int(i)] = n
	}
	return names[:]
}

panel_options :: proc() {
	oui.element(uictx, "options", "optionsbar", {id = "options"})
	defer oui.end(uictx)
	t := eff_tool()

	size_slider :: proc() {
		oslider("Size", 80, &opts.brush_size, 1, 64, "Brush size ([ and ])")
		oui.element(uictx, "shape", "button-group")
		if c, _ := oui_icon_button("square", .Frame, "Square brush", {lit = !opts.brush_round, enabled = true}); c {
			opts.brush_round = false
		}
		if c, _ := oui_icon_button("round", .Ellipse, "Round brush", {lit = opts.brush_round, enabled = true}); c {
			opts.brush_round = true
		}
		oui.end(uictx)
	}
	ink_pattern :: proc() {
		if nv, ch := ocombo("pattern", 84, pattern_names(), int(opts.pattern), "Pattern / dither"); ch {
			opts.pattern = Pattern(nv)
		}
		if nv, ch := ocombo("ink", 74, INK_NAMES[:], int(opts.ink), "Ink mode"); ch {
			opts.ink = Ink(nv)
		}
	}
	sel_modes :: proc() {
		labels := [?]string{"New", "Add", "Sub", "And"}
		oui.element(uictx, "sel-mode", "button-group")
		for l, i in labels {
			if obutton(l, 28, "", true, int(opts.sel_mode) == i) {
				opts.sel_mode = Sel_Mode(i)
			}
		}
		oui.end(uictx)
	}

	if options_switch_ui() {
		// a switch's settings take the place of the tool's
	} else do switch t {
	case .Grid, .Symmetry, .Tiling, .Onion:
	case .Pencil:
		size_slider()
		ocheck("Pixel-perfect", &opts.pixel_perf, "Remove L-shaped corners while drawing")
		ink_pattern()
	case .Eraser:
		size_slider()
		ink_pattern()
	case .Line:
		size_slider()
		ink_pattern()
		ohint("Shift: snap angle")
	case .Rect, .Ellipse:
		size_slider()
		ocheck("Filled", &opts.fill_shape)
		ink_pattern()
		ohint("Shift: square   Ctrl: from center")
	case .Curve:
		size_slider()
		ink_pattern()
		ohint("Drag a line, then drag the handles. Enter: apply   Esc: cancel")
	case .Spray:
		size_slider()
		oslider("Density", 90, &opts.spray_dens, 1, 100)
		ink_pattern()
	case .Bucket:
		oslider("Tolerance", 100, &opts.tolerance, 0, 255)
		ocheck("Contiguous", &opts.contiguous)
		ink_pattern()
	case .Wand:
		oslider("Tolerance", 100, &opts.tolerance, 0, 255)
		ocheck("Contiguous", &opts.contiguous)
		sel_modes()
	case .Select_Rect, .Select_Ellipse, .Lasso:
		sel_modes()
		ohint("Shift: add   Alt: subtract")
	case .Move:
		ohint("Drag to move the selection (or the whole cel). Alt: copy. Arrows nudge.")
	case .Picker:
		ohint("Click: foreground   Right click: background")
	case .Hand:
		ohint("Drag to pan. Space or middle mouse works with any tool.")
	case .Zoom:
		ohint("Click to zoom in, right click to zoom out. Mouse wheel works anywhere.")
	}

	// global toggles on the right
	oui.element_leaf(uictx, "spacer", "spacer")
	oui_slot("canvas-bg", "canvas_bg")
	if c, _ := oui_icon_button("sym-x", .Sym_X, "Mirror left / right (Shift+X)", {lit = opts.sym_x, enabled = true}); c {
		run_cmd(.Toggle_Sym_X)
	}
	if c, _ := oui_icon_button("sym-y", .Sym_Y, "Mirror top / bottom (Shift+Y)", {lit = opts.sym_y, enabled = true}); c {
		run_cmd(.Toggle_Sym_Y)
	}
	if nv, ch := ocombo("tile", 76, TILE_NAMES[:], int(opts.tile), "Tiled mode (Shift+T)"); ch {
		opts.tile = Tile_Mode(nv)
		switch_changed(.Tiling)
	}
	if c, _ := oui_icon_button("onion", .Onion, "Onion skin (Alt+O)", {lit = opts.onion, enabled = true}); c {
		run_cmd(.Toggle_Onion)
	}
	if c, _ := oui_icon_button("pixel-grid", .Pixel_Grid, "Show pixel borders when zoomed in (Ctrl+Shift+')", {lit = opts.pixel_grid, enabled = true}); c {
		run_cmd(.Toggle_Pixel_Grid)
	}
	if c, _ := oui_icon_button("grid", .Grid, "Show custom grid (Ctrl+')", {lit = opts.grid, enabled = true}); c {
		run_cmd(.Toggle_Grid)
	}
}

// The canvas background swatch in the options bar: checkers or the solid colour.
panel_canvas_bg :: proc(r: Rect) {
	clicked, _, hover := button_behavior(make_id(r, "canvasbg"), r, "Canvas background color")
	clip_begin(r)
	if bg_mode == 0 {
		draw_checker(r, 3)
	} else {
		fill_rect(r, canvas_bg_color())
	}
	clip_end()
	draw_rrect_outline(f32(r.x), f32(r.y), f32(r.w), f32(r.h), RADIUS, hover ? WHITE : C_RING_HI)
	if clicked {
		run_cmd(.Canvas_Bg)
	}
}

// ---------------------------------------------------------------------------
// Right panel: colour picker, palette, filters, preview
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

hex_buf: Name

// Section heading: a dim caption with a hairline running to the right edge.
osection :: proc(key, title: string) {
	oui.element(uictx, key, "section-head")
	oui.label(uictx, "t", title)
	oui.element_leaf(uictx, "line", "section-line")
	oui.end(uictx)
}

PAL_CELL :: 14
PAL_MAX_ROWS :: 6
palette_area_w: i32 = 216 // width of the palette grid last frame, for its height

panel_right :: proc() {
	d := doc
	oui.element(uictx, "right", "sidepanel", {id = "right"})
	defer oui.end(uictx)

	// --- colour picker ---------------------------------------------------
	osection("color-head", color_linked() != nil ? "Color - editing toolbar colour" : "Color")
	oui_slot("picker", "color_picker")
	oui.element(uictx, "color-row", "row", {id = "color-row"})
	oui.element_leaf(uictx, "fg", "color-chip", {id = "fg-chip", style = fmt.tprintf("background:#%02x%02x%02x", fg.r, fg.g, fg.b)})
	if oswatch_button("bg", bg, "Background colour (click to swap)") do run_cmd(.Swap_Colors)
	if c, _ := oui_icon_button("swap", .Swap, "Swap colors (X)", {id = "swap-colors", enabled = true}); c {
		run_cmd(.Swap_Colors)
	}
	oui_slot("hex", "hex_field")
	otext("alpha", fmt.tprintf("A %d", fg.a), "dim")
	oui.end(uictx)
	rgb := [3]int{int(fg.r), int(fg.g), int(fg.b)}
	names := [3]string{"R", "G", "B"}
	classes := [3]string{"wide ch-r", "wide ch-g", "wide ch-b"}
	for i in 0 ..< 3 {
		if oslider(names[i], 0, &rgb[i], 0, 255, class = classes[i]) {
			picker_set_fg(Color{u8(rgb[0]), u8(rgb[1]), u8(rgb[2]), fg.a})
		}
	}

	// --- palette ---------------------------------------------------------
	oui.element(uictx, "palette-head", "row", {id = "palette-head", class = "panel-head"})
	otext("t", "Palette", "dim")
	oui.element_leaf(uictx, "spacer", "spacer")
	if obutton("Presets", 50, "Load a palette preset") {
		r := oui_rect(oui_last)
		popup_begin(PALETTE_PRESET_ID, r, 120)
		for p in Palette_Preset {
			popup_item(PALETTE_PRESET_NAMES[p], int(p))
		}
	}
	if c, _ := oui_icon_button("replace", .Pencil, "Replace selected swatch with foreground", {enabled = len(d.palette) > 0}); c {
		if d.pal_sel >= 0 && d.pal_sel < len(d.palette) {
			d.palette[d.pal_sel] = Color{fg.r, fg.g, fg.b, 255}
			d.modified = true
		}
	}
	if c, _ := oui_icon_button("add", .Plus, "Add foreground colour to palette", {enabled = true}); c {
		append(&d.palette, Color{fg.r, fg.g, fg.b, 255})
		d.pal_sel = len(d.palette) - 1
		d.modified = true
	}
	if c, _ := oui_icon_button("remove", .Minus, "Remove selected swatch", {enabled = len(d.palette) > 1}); c {
		if d.pal_sel >= 0 && d.pal_sel < len(d.palette) {
			ordered_remove(&d.palette, d.pal_sel)
			d.pal_sel = clamp(d.pal_sel, 0, len(d.palette) - 1)
			d.modified = true
		}
	}
	oui.end(uictx)
	if ui.popup_result_id == PALETTE_PRESET_ID {
		palette_set_preset(d, Palette_Preset(ui.popup_result_val))
		ui.popup_result_id = 0
	}
	// as many rows as the palette needs, up to PAL_MAX_ROWS (scrolled with the wheel beyond that)
	cols := max((palette_area_w - 4) / PAL_CELL, 1)
	rows := clamp(i32((len(d.palette) + int(cols) - 1) / int(cols)), 1, PAL_MAX_ROWS)
	oui_slot("palette", "palette", style = fmt.tprintf("height:%dpx", rows * PAL_CELL + 4))
	oui.element(uictx, "recent-row", "row", {id = "recent-row"})
	otext("t", "Recent", "dim")
	oui_slot("recent", "recent")
	oui.end(uictx)

	// --- filters ---------------------------------------------------------
	oui.element(uictx, "filters-head", "row", {id = "filters-head", class = "panel-head"})
	otext("t", "Filters", "dim")
	oui.element_leaf(uictx, "spacer", "spacer")
	if obutton("Add Filter", 64, "Add a filter to the current layer") {
		popup_begin(FILTER_ADD_ID, oui_rect(oui_last), 100)
		for k in Filter_Kind {
			popup_item(FILTER_INFO[k].name, int(k))
		}
	}
	oui.end(uictx)
	if ui.popup_result_id == FILTER_ADD_ID {
		layer := &d.layers[d.active_layer]
		history_push(d)
		append(&layer.filters, filter_make(Filter_Kind(ui.popup_result_val)))
		doc_touch(d)
		ui.popup_result_id = 0
		filter_scroll = max(i32(len(layer.filters)) * 32, 0) // jump to the new entry
	}
	oui_slot("filter-list", "filter_list")

	// --- preview ---------------------------------------------------------
	if show_preview {
		osection("preview-head", "Navigator")
		oui_slot("preview", "preview")
	}
}

// Saturation / value field, hue strip and alpha strip.
panel_color_picker :: proc(r: Rect) {
	sv := Rect{r.x, r.y, r.w - 36, r.h}
	hue := Rect{r.x + r.w - 30, r.y, 12, r.h}
	alp := Rect{r.x + r.w - 12, r.y, 12, r.h}
	draw_gradient(f32(sv.x), f32(sv.y), f32(sv.w), f32(sv.h), WHITE, hsv_to_rgb(fg_h, 1, 1), false)
	draw_gradient(f32(sv.x), f32(sv.y), f32(sv.w), f32(sv.h), Color{0, 0, 0, 0}, Color{0, 0, 0, 255})
	outline_rect(sv, C_RING_HI)
	if act, fx, fy := drag_area(sv, make_id(sv, "sv")); act {
		picker_set_fg_hsv(fg_h, fx, 1 - fy, fg.a)
	}
	cx := sv.x + i32(fg_s * f32(sv.w - 1))
	cy := sv.y + i32((1 - fg_v) * f32(sv.h - 1))
	clip_begin(sv)
	draw_circle_outline(f32(cx) + 0.5, f32(cy) + 0.5, 4, BLACK)
	draw_circle_outline(f32(cx) + 0.5, f32(cy) + 0.5, 5, WHITE)
	clip_end()

	// hue strip
	for i in 0 ..< 6 {
		seg_h := hue.h / 6
		c0 := hsv_to_rgb(f32(i) * 60, 1, 1)
		c1 := hsv_to_rgb(f32(i + 1) * 60, 1, 1)
		draw_gradient(f32(hue.x), f32(hue.y + i32(i) * seg_h), f32(hue.w), f32(seg_h + 1), c0, c1)
	}
	outline_rect(hue, C_RING_HI)
	if act, _, fy := drag_area(hue, make_id(hue, "hue")); act {
		picker_set_fg_hsv(fy * 359.9, fg_s, fg_v, fg.a)
	}

	// alpha strip
	draw_checker(alp, 3)
	draw_gradient(f32(alp.x), f32(alp.y), f32(alp.w), f32(alp.h), Color{fg.r, fg.g, fg.b, 0}, Color{fg.r, fg.g, fg.b, 255})
	outline_rect(alp, C_RING_HI)
	if act, _, fy := drag_area(alp, make_id(alp, "alpha")); act {
		picker_set_fg(Color{fg.r, fg.g, fg.b, u8(fy * 255 + 0.5)})
	}

	// handles on both strips
	clip_begin(rect_inset(r, -4))
	strip_handle :: proc(s: Rect, y: i32) {
		draw_rrect(f32(s.x - 3), f32(y - 2), f32(s.w + 6), 5, 2, WHITE)
		draw_rrect_outline(f32(s.x - 3), f32(y - 2), f32(s.w + 6), 5, 2, Color{0, 0, 0, 160})
	}
	strip_handle(hue, hue.y + i32(fg_h / 360 * f32(hue.h - 1)))
	strip_handle(alp, alp.y + i32(f32(fg.a) / 255 * f32(alp.h - 1)))
	clip_end()
}

panel_hex_field :: proc(hr: Rect) {
	hid := make_id(hr, "text")
	if ui.focus_id != hid {
		name_set(&hex_buf, color_hex(fg))
	}
	if ch, sub := text_field(hr, &hex_buf, "Hex colour (RRGGBB or RRGGBBAA)"); ch || sub {
		if c, ok := parse_hex(name_str(&hex_buf)); ok {
			picker_set_fg(c)
		}
	}
}

panel_palette :: proc(pal: Rect) {
	d := doc
	palette_area_w = pal.w
	cell := i32(PAL_CELL)
	cols := max((pal.w - 4) / cell, 1)
	@(static) pal_scroll: i32
	all_rows := i32((len(d.palette) + int(cols) - 1) / int(cols))
	if ui_hover(pal) && ui.wheel != 0 {
		pal_scroll -= i32(ui.wheel) * cell
	}
	pal_scroll = clamp(pal_scroll, 0, max(all_rows * cell + 4 - pal.h, 0))
	ctl_well(pal)
	clip_begin(rect_inset(pal, 1))
	for c, i in d.palette {
		sr := Rect{pal.x + 2 + i32(i % int(cols)) * cell, pal.y + 2 + i32(i / int(cols)) * cell - pal_scroll, cell, cell}
		if sr.y + cell < pal.y || sr.y > pal.y + pal.h do continue
		draw_rrect(f32(sr.x), f32(sr.y), f32(sr.w - 2), f32(sr.h - 2), 2, c)
		if color_eq(c, fg) {
			draw_rrect_outline(f32(sr.x), f32(sr.y), f32(sr.w - 2), f32(sr.h - 2), 2, WHITE)
		}
		if i == d.pal_sel {
			draw_rrect_outline(f32(sr.x - 1), f32(sr.y - 1), f32(sr.w), f32(sr.h), 3, C_ACCENT)
		}
		if ui_hover(sr) && ui_hover(pal) {
			tooltip_hover(make_id(sr, "sw"), color_hex(c))
			if ui.pressed[0] {
				set_fg(c)
				d.pal_sel = i
			} else if ui.pressed[1] {
				bg = c
				d.pal_sel = i
			}
		}
	}
	clip_end()
}

// Colours painted with lately: click for the foreground, right click for the background.
panel_recent :: proc(r: Rect) {
	rx := r.x
	for c in recent {
		if rx + 12 > r.x + r.w do break
		sr := Rect{rx, r.y + (r.h - 12) / 2, 12, 12}
		if c.a < 255 do draw_checker(sr, 2)
		draw_rrect(f32(sr.x), f32(sr.y), 12, 12, 2, c)
		draw_rrect_outline(f32(sr.x), f32(sr.y), 12, 12, 2, color_eq(c, fg) ? WHITE : C_RING_HI)
		if ui_hover(sr) {
			tooltip_hover(make_id(sr, "rc"), color_hex(c))
			if ui.pressed[0] do set_fg(c)
			if ui.pressed[1] do bg = c
		}
		rx += 14
	}
}

panel_preview :: proc(r: Rect) {
	ctl_well(r)
	d := doc
	if !tex_valid(tex_canvas) || tex_doc != d || r.h < 8 {
		return
	}
	z := min(f32(r.w - 4) / f32(d.w), f32(r.h - 4) / f32(d.h))
	if z >= 1 {
		z = f32(int(z))
	}
	w := f32(d.w) * z
	h := f32(d.h) * z
	dst := FRect{math.floor(f32(r.x) + (f32(r.w) - w) / 2), math.floor(f32(r.y) + (f32(r.h) - h) / 2), w, h}
	clip_begin(r)
	if bg_mode == 0 {
		draw_tex_tiled(tex_checker, dst, 8)
	} else {
		draw_frect(dst, canvas_bg_color())
	}
	draw_tex(tex_canvas, {0, 0, f32(d.w), f32(d.h)}, dst)
	// the part of the sprite the canvas shows, when it does not show all of it
	vp := canvas_vp
	vr := FRect{dst.x + (f32(vp.x) - d.ox) / d.zoom * z, dst.y + (f32(vp.y) - d.oy) / d.zoom * z, f32(vp.w) / d.zoom * z, f32(vp.h) / d.zoom * z}
	if vr.x > dst.x || vr.y > dst.y || vr.x + vr.w < dst.x + dst.w || vr.y + vr.h < dst.y + dst.h {
		draw_rect_outline(vr, C_ACCENT)
		draw_rect_outline({vr.x + hair(), vr.y + hair(), vr.w - 2 * hair(), vr.h - 2 * hair()}, Color{0, 0, 0, 120})
	}
	clip_end()
	// click or drag to centre the view on that point
	if act, fx, fy := drag_area(r, make_id(r, "nav")); act {
		px := (f32(r.x) + fx * f32(r.w - 1) - dst.x) / z
		py := (f32(r.y) + fy * f32(r.h - 1) - dst.y) / z
		d.ox = f32(vp.x) + f32(vp.w) / 2 - px * d.zoom
		d.oy = f32(vp.y) + f32(vp.h) / 2 - py * d.zoom
		ui.cursor = .RESIZE_ALL
	} else if ui_hover(r) {
		tooltip_hover(make_id(r, "navtip"), "Click or drag to move the view")
	}
}

// ---------------------------------------------------------------------------
// Layer filters
// ---------------------------------------------------------------------------

filter_scroll: i32
filter_drag_changed: bool
filter_drag_pushed: bool

// The active layer's filter stack. Edits go through history_push so they undo like any other change.
panel_filter_list :: proc(list: Rect) {
	d := doc
	layer := &d.layers[d.active_layer]
	ctl_well(list)
	if len(layer.filters) == 0 {
		text_clipped(Rect{list.x + 6, list.y, list.w - 6, list.h}, "No filters on this layer", C_TEXT_DIM)
		return
	}

	// row heights: name line, plus a slider line for filters with a parameter
	row_h :: proc(f: Layer_Filter) -> i32 {
		return FILTER_INFO[f.kind].has_param ? 34 : 18
	}
	inner := rect_inset(list, 1)
	total: i32
	for f in layer.filters {
		total += row_h(f)
	}
	hover_slider := false
	max_scroll := max(total - inner.h, 0)
	filter_scroll = clamp(filter_scroll, 0, max_scroll)

	// deferred actions so the list is not modified while iterating
	act_del, act_up, act_down, act_toggle := -1, -1, -1, -1

	clip_begin(inner)
	cy := inner.y - filter_scroll
	n := len(layer.filters)
	for &f, i in layer.filters {
		h := row_h(f)
		if cy + h < inner.y || cy > inner.y + inner.h {
			cy += h
			continue
		}
		info := FILTER_INFO[f.kind]
		row := Rect{inner.x, cy, inner.w, h}
		if ui_hover(row) && ui_hover(inner) {
			fill_rect(row, Color{255, 255, 255, 12})
		}
		hline(row.x, cy + h - 1, row.w, C_RING)
		eye := Rect{row.x + 2, cy + 2, 16, 14}
		if icon_button(eye, .Eye, f.enabled ? "Disable filter" : "Enable filter", f.enabled) && ui_hover(inner) {
			act_toggle = i
		}
		bx := row.x + row.w - 17
		if icon_button(Rect{bx, cy + 2, 15, 14}, .Close, "Remove filter") && ui_hover(inner) {
			act_del = i
		}
		bx -= 16
		if icon_button(Rect{bx, cy + 2, 15, 14}, .Down, "Move filter down (applied later)", false, i < n - 1) && ui_hover(inner) {
			act_down = i
		}
		bx -= 16
		if icon_button(Rect{bx, cy + 2, 15, 14}, .Up, "Move filter up (applied earlier)", false, i > 0) && ui_hover(inner) {
			act_up = i
		}
		text_clipped(Rect{eye.x + eye.w + 5, cy + 2, bx - eye.x - eye.w - 7, 14}, info.name, f.enabled ? C_TEXT : C_TEXT_DIM)
		if info.has_param {
			sr := Rect{row.x + 3, cy + 18, row.w - 6, 13}
			if ui_hover(sr) && ui_hover(inner) {
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

	if filter_drag_pushed && !ui.down[0] && ui.wheel == 0 {
		if !filter_drag_changed {
			history_discard(d)
		}
		filter_drag_pushed = false
	}

	if ui_hover(inner) && !hover_slider && ui.wheel != 0 {
		filter_scroll = clamp(filter_scroll - i32(ui.wheel) * 18, 0, max_scroll)
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

// ---------------------------------------------------------------------------
// Timeline: control bar (CSS) and the layer / frame grid (drawn by hand)
// ---------------------------------------------------------------------------

// An icon button with a small + or - badge (new layer, delete frame ...).
obadge_button :: proc(key: string, ic: Icon, plus: bool, tip: string, enabled := true) -> bool {
	n := oui.button_begin(uictx, key, {class = "icon-btn tl-btn", disabled = !enabled})
	oui.label(uictx, "icon", icon_text(ic), {class = "icon"})
	oui.label(uictx, "badge", icon_text(plus ? .Plus : .Minus), {class = "icon badge"})
	oui.end(uictx)
	oui_tip(n, tip)
	return n.clicked && enabled
}

// The panel under the canvas: a bar ending in the mode switch, and the timeline or file browser.
panel_timeline :: proc() {
	if bottom_mode == .Files do files_update()
	oui.element(uictx, "timeline", "timeline", {id = "timeline", class = bottom_mode == .Hidden ? "collapsed" : ""})
	defer oui.end(uictx)
	oui.element(uictx, "bar", "row", {id = "timeline-bar"})
	oui.element(uictx, "tools", "row", {id = "bar-tools"}) // clipped first when the window is narrow
	switch bottom_mode {
	case .Animation:
		timeline_bar_controls()
	case .Files:
		files_bar_controls()
	case .Hidden:
	}
	oui.end(uictx)
	bottom_mode_switch()
	oui.end(uictx)
	switch bottom_mode {
	case .Animation:
		oui_slot("timeline-grid", "timeline_grid")
	case .Files:
		files_body()
	case .Hidden:
	}
}

timeline_bar_controls :: proc() {
	d := doc
	tb :: proc(key: string, ic: Icon, tip: string, enabled := true, lit := false) -> bool {
		c, _ := oui_icon_button(key, ic, tip, {class = "tl-btn", enabled = enabled, lit = lit})
		return c
	}
	if obadge_button("layer-new", .Layer, true, "New layer (Shift+N)") do run_cmd(.Layer_New)
	if obadge_button("layer-del", .Layer, false, "Delete layer", len(d.layers) > 1) do run_cmd(.Layer_Del)
	if tb("layer-dup", .Copy, "Duplicate layer") do run_cmd(.Layer_Dup)
	if tb("layer-up", .Up, "Move layer up", d.active_layer < len(d.layers) - 1) do run_cmd(.Layer_Up)
	if tb("layer-down", .Down, "Move layer down", d.active_layer > 0) do run_cmd(.Layer_Down)
	if tb("layer-merge", .Merge, "Merge down, applying filters (Ctrl+E)", d.active_layer > 0) do run_cmd(.Layer_Merge)
	oui.element_leaf(uictx, "gap1", "tl-gap")
	if obadge_button("frame-new", .Frame, true, "New frame (Alt+N)") do run_cmd(.Frame_New)
	if tb("frame-dup", .Copy, "Duplicate frame") do run_cmd(.Frame_Dup)
	if obadge_button("frame-del", .Frame, false, "Delete frame", len(d.frames) > 1) do run_cmd(.Frame_Del)
	oui.element_leaf(uictx, "gap2", "tl-gap")
	if tb("first", .First, "First frame (Home)") do run_cmd(.Frame_First)
	if tb("prev", .Left, "Previous frame (,)") do run_cmd(.Frame_Prev)
	if tb("play", playing ? .Stop : .Right, "Play / pause (Enter)", lit = playing) do run_cmd(.Play)
	if tb("next", .Right, "Next frame (.)") do run_cmd(.Frame_Next)
	if tb("last", .Last, "Last frame (End)") do run_cmd(.Frame_Last)
	oui.element_leaf(uictx, "gap3", "tl-gap")
	// tag selector for playback
	tag_items := make([dynamic]string, context.temp_allocator)
	append(&tag_items, "All frames")
	for &t in d.tags {
		append(&tag_items, name_str(&t.name))
	}
	if nv, ch := ocombo("tag", 100, tag_items[:], play_tag + 1, "Playback range"); ch {
		play_tag = nv - 1
		if play_tag >= 0 && play_tag < len(d.tags) {
			set_frame(d.tags[play_tag].from)
		}
	}
	if obutton("Tags", 38, "Edit animation tags") do run_cmd(.Tags)
	if obutton(fmt.tprintf("%d ms", d.frames[d.active_frame].duration), 64, "Frame duration (click to edit)", key = "duration") {
		run_cmd(.Frame_Props)
	}
}

tl_scroll_x, tl_scroll_y: i32
layer_drag := -1 // layer being dragged in the timeline, or -1
layer_drag_y0: i32
layer_drag_on: bool

panel_timeline_grid :: proc(body: Rect) {
	d := doc
	hdr_w: i32 = 150
	frame_w: i32 = 18
	row_h: i32 = 16
	hdr_h: i32 = 20
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

	fill_rect(body, C_PANEL_DK)
	vline(body.x + hdr_w - 1, body.y, body.h, C_RING_HI)
	hline(body.x, body.y + hdr_h - 1, body.w, C_RING_HI)
	text(body.x + 8, body.y + (hdr_h - FONT_CAP) / 2, "Layers", C_TEXT_DIM)

	// header: frame numbers + tags
	clip_begin(head)
	for f in 0 ..< nframes {
		fx := head.x + f * frame_w - tl_scroll_x
		if fx + frame_w < head.x || fx > head.x + head.w {
			continue
		}
		active := int(f) == d.active_frame
		if active {
			draw_rrect(f32(fx + 1), f32(head.y + 1), f32(frame_w - 2), f32(hdr_h - 3), RADIUS, C_ACTIVE)
		}
		s := fmt.tprintf("%d", f + 1)
		text(fx + (frame_w - text_w(s)) / 2, head.y + 3, s, active ? WHITE : C_TEXT_DIM)
		vline(fx + frame_w - 1, head.y, hdr_h, C_RING)
	}
	for &t, ti in d.tags {
		tx0 := head.x + i32(t.from) * frame_w - tl_scroll_x
		tw := i32(t.to - t.from + 1) * frame_w
		tr := Rect{tx0 + 1, head.y + hdr_h - 6, tw - 2, 4}
		draw_rrect(f32(tr.x), f32(tr.y), f32(tr.w), f32(tr.h), 2, t.color)
		if ti == play_tag {
			draw_rrect_outline(f32(tr.x - 1), f32(tr.y - 1), f32(tr.w + 2), f32(tr.h + 2), 2, WHITE)
		}
		if ui_hover(tr) && ui.pressed[0] {
			play_tag = play_tag == ti ? -1 : ti
		}
	}
	clip_end()
	// scrubbing on the header numbers
	head_num := Rect{head.x, head.y, head.w, hdr_h - 6}
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
			fill_rect(row, C_ACCENT_TINT)
			fill_rect(Rect{row.x, row.y, 2, row.h}, C_ACCENT)
		} else if ui_hover(row) {
			fill_rect(row, Color{255, 255, 255, 12})
		}
		hline(row.x, ry + row_h - 1, row.w, C_RING)
		eye := Rect{row.x + 5, ry + 2, 12, 12}
		lock := Rect{row.x + 20, ry + 2, 12, 12}
		icon(.Eye, eye.x, eye.y, l.visible ? C_TEXT : C_TEXT_OFF)
		icon(.Lock, lock.x, lock.y, l.locked ? C_ACCENT : C_TEXT_OFF)
		text_clipped(Rect{row.x + 38, ry, row.w - 60, row_h}, name_str(&l.name), l.visible ? C_TEXT : C_TEXT_DIM)
		if l.opacity < 255 || l.blend != .Normal || len(l.filters) > 0 {
			text(row.x + row.w - 18, ry + (row_h - FONT_CAP) / 2, "fx", C_TEXT_DIM)
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
				layer_drag, layer_drag_y0, layer_drag_on = li, ui.my, false
				if ui.dbl_click {
					dialog_open(.Layer_Props)
				}
			}
		}
		// right-click: select the layer and open its menu (on release, so the press doesn't close it)
		if ui_hover(row) && ui_hover(names) && ui.released[1] && !popup.open {
			d.active_layer = li
			popup_begin(make_id(names, "layermenu"), Rect{ui.mx, ui.my, 1, 1}, 150)
			popup_item("New Layer", cmd = .Layer_New)
			popup_item("Duplicate Layer", cmd = .Layer_Dup)
			popup_item("Delete Layer", cmd = .Layer_Del, enabled = len(d.layers) > 1)
			popup_item("Merge Down", cmd = .Layer_Merge, enabled = li > 0)
			popup_sep()
			popup_item("Visible", cmd = .Layer_Vis, checked = l.visible)
			popup_item("Locked", cmd = .Layer_Lock, checked = l.locked)
			popup_sep()
			popup_item("Properties...", cmd = .Layer_Props)
		}
	}
	// drag a row up or down to reorder; the line shows where it will land
	if layer_drag >= 0 && layer_drag < int(nlayers) {
		if !layer_drag_on && ui.down[0] && abs(ui.my - layer_drag_y0) > 4 {
			layer_drag_on = true
		}
		if layer_drag_on {
			ri := clamp((ui.my - names.y + tl_scroll_y) / row_h, 0, nlayers - 1)
			target := int(nlayers - 1 - ri)
			if target != layer_drag {
				ly := names.y + (target > layer_drag ? ri : ri + 1) * row_h - tl_scroll_y
				fill_rect(Rect{names.x, ly - 1, names.w - 1, 2}, C_ACCENT)
				if ui.released[0] {
					doc_move_layer_to(d, layer_drag, target)
				}
			}
		}
		if !ui.down[0] {
			layer_drag, layer_drag_on = -1, false
		}
	} else {
		layer_drag, layer_drag_on = -1, false
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
			cr := Rect{fx + 1, ry + 1, frame_w - 2, row_h - 2}
			active_cel := li == d.active_layer && int(f) == d.active_frame
			col := C_PANEL
			if int(f) == d.active_frame || li == d.active_layer {
				col = C_PANEL_LT
			}
			if active_cel {
				col = C_ACTIVE
			}
			draw_rrect(f32(cr.x), f32(cr.y), f32(cr.w), f32(cr.h), 2, col)
			// shared (linked) cels get a small marker
			if d.layers[li].cels[f].refs > 1 && active_cel {
				draw_rrect(f32(cr.x + cr.w / 2 - 2), f32(cr.y + cr.h / 2 - 2), 4, 4, 1, C_ACCENT)
			}
		}
	}
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
}

// ---------------------------------------------------------------------------
// Status bar
// ---------------------------------------------------------------------------

panel_status :: proc() {
	d := doc
	oui.element(uictx, "status", "statusbar", {id = "status"})
	defer oui.end(uictx)
	if status_t > 0 {
		oui.label(uictx, "tool", name_str(&status_msg), {id = "status-tool", class = "message"})
	} else {
		oui.label(uictx, "tool", TOOL_NAMES[cur_tool], {id = "status-tool"})
	}
	oui.separator(uictx, "sep0")
	// the readout under the pointer changes every frame, so it is drawn by hand
	oui_slot("cursor-info", "cursor_info")
	if d.sel != nil {
		x0, y0, x1, y1, ok := sel_bounds(d.sel, d.w, d.h)
		if ok {
			oui.separator(uictx, "sep1")
			oui.label(uictx, "sel", fmt.tprintf("Sel %dx%d", x1 - x0 + 1, y1 - y0 + 1))
		}
	}
	oui.element_leaf(uictx, "spacer", "spacer")
	oui.label(uictx, "layer", name_str(&d.layers[d.active_layer].name))
	oui.separator(uictx, "sep2")
	oui.label(uictx, "size", fmt.tprintf("%d x %d", d.w, d.h))
	oui.separator(uictx, "sep3")
	oui.label(uictx, "frame", fmt.tprintf("Frame %d/%d", d.active_frame + 1, len(d.frames)))
	oui.separator(uictx, "sep4")
	oui.label(uictx, "zoom", fmt.tprintf("%d%%", int(d.zoom * 100 + 0.5)), {class = "strong"})
}

// Pixel position and colour under the pointer, in the status bar.
panel_cursor_info :: proc(r: Rect) {
	d := doc
	if !hover_valid || !px_valid(hover_px) do return
	ty := r.y + (r.h - FONT_CAP) / 2
	doc_refresh_comp(d)
	c := d.comp[hover_px.y * d.w + hover_px.x]
	textf(r.x, ty, C_TEXT, "%d, %d", hover_px.x, hover_px.y)
	swr := Rect{r.x + 64, r.y + (r.h - 10) / 2, 10, 10}
	draw_checker(swr, 2)
	draw_rrect(f32(swr.x), f32(swr.y), 10, 10, 2, c)
	draw_rrect_outline(f32(swr.x), f32(swr.y), 10, 10, 2, C_RING_HI)
	text(r.x + 80, ty, color_hex(c), C_TEXT_DIM)
}
