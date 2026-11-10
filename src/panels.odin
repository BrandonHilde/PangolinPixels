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
	oui_slot_register("logo", proc(r: Rect, _: int) {
		logo_draw(r.x, r.y + (r.h - LOGO_SIZE) / 2, 1)
		tip_area(r, "logo", {"Pangolin Pixels", "A pixel art and sprite animation editor. Help > About has the details."})
	})
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
	@(static) prev_scale: f32
	if doc.view_init && prev_vp.w > 0 && (prev_vp != viewport || prev_scale != gfx.scale) {
		// the old viewport's centre, in today's units if the UI scale just changed
		k := prev_scale / gfx.scale
		doc.ox += f32(viewport.x) + f32(viewport.w) / 2 - (f32(prev_vp.x) + f32(prev_vp.w) / 2) * k
		doc.oy += f32(viewport.y) + f32(viewport.h) / 2 - (f32(prev_vp.y) + f32(prev_vp.h) / 2) * k
	}
	prev_vp = viewport
	prev_scale = gfx.scale
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
		if len(recent_files) > 0 {
			popup_sep()
			for f, i in recent_files do item(path_basename(f), cmd = Cmd(int(Cmd.Recent_First) + i), tip = f)
			item("Clear Recent Files", cmd = .Recent_Clear)
		}
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
		popup_sep()
		item("Preferences...", cmd = .Preferences)
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
		item("New Group", cmd = .Layer_Group_New)
		item("Group Layer", cmd = .Layer_Group)
		item("Ungroup", cmd = .Layer_Ungroup, enabled = doc.layers[doc.active_layer].is_group)
		popup_sep()
		item("Move Up", cmd = .Layer_Up)
		item("Move Down", cmd = .Layer_Down)
		item(doc.layers[doc.active_layer].is_group ? "Merge Group" : "Merge Down", cmd = .Layer_Merge)
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
		item("Mirror Horizontal", cmd = .Toggle_Sym_X, checked = opts.sym_x)
		item("Mirror Vertical", cmd = .Toggle_Sym_Y, checked = opts.sym_y)
		item("Cycle Tiled Mode", cmd = .Cycle_Tile, checked = opts.tile != .Off)
		item("Canvas Background...", cmd = .Canvas_Bg)
		item("Transparency Checkers", cmd = .Toggle_Checks, checked = opts.show_checks)
		popup_sep()
		item("Canvas Mode", cmd = .Toggle_Canvas_Mode, checked = canvas_mode)
		item("Timeline", cmd = .Toggle_Timeline, checked = bottom_mode == .Animation)
		item("File Browser", cmd = .Toggle_Files, checked = bottom_mode == .Files)
		item("Navigator", cmd = .Toggle_Preview, checked = show_preview)
		item("UI Scale...", cmd = .UI_Scale)
	case 7:
		ws_refresh()
		for e, i in ws_entries {
			if i == len(WS_BUILTIN_NAMES) do popup_sep()
			item(e.name, cmd = Cmd(int(Cmd.Ws_First) + i), checked = e.name == ws_current, tip = e.builtin >= 0 ? WS_BUILTIN_HELP[e.builtin] : "")
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
		oui_tip(n, menu_title_tip(title))
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
	if c, _ := oui_icon_button("canvas-mode", .Canvas_Mode, cmd_tip("Canvas mode", .Toggle_Canvas_Mode), {id = "canvas-mode", lit = canvas_mode, enabled = true}); c {
		run_cmd(.Toggle_Canvas_Mode)
	}
	oui_tip(oui.label(uictx, "doc", doc_display_name(doc), {id = "doc-name"}), {"Current sprite", doc_status(doc)})
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
		oui_tip(t, {"", fmt.tprintf("%s Click to switch to it, middle-click to close it.", doc_status(d))})
		if active do oui.element_leaf(uictx, "accent", "tab-accent")
		oui.label(uictx, "name", doc_display_name(d))
		if c, _ := oui_icon_button("close", .Close, {"Close sprite", "Close this sprite. If it has unsaved changes you are asked first."}, {class = "tab-close", enabled = true}); c {
			close_idx = i
		}
		oui.end(uictx)
		if t.pressed do switch_idx = i // a press on the tab itself, not its close button
		if t.hovered && ui.pressed[2] do close_idx = i
	}
	if c, _ := oui_icon_button("new", .Plus, cmd_tip("New sprite", .New), {id = "new-tab", enabled = true}); c {
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
	panel_element(.Toolbar, "toolbar", "toolbar")
	defer oui.end(uictx)
	t := eff_tool()
	rem_g, rem_t := -1, -1
	cur_group := current_group()
	for &g, gi in tool_groups {
		oui.element(uictx, fmt.tprintf("g%d", gi), "tool-group", {class = g.pen_eraser ? "eraser" : ""})
		// header: the name on the left, the hotkey as a keycap on the right
		// (click the keycap for options; right-click the header for rename / remove)
		hdr := oui.element(uictx, "head", "group-head")
		oui_tip(hdr, {group_title(&g), "A tool group: tools, switches, colors or dither patterns kept together. Right-click here to rename or remove it."})
		oui.label(uictx, "title", group_title(&g), {class = "group-title"})
		if g.own {
			dot := oui.element_leaf(uictx, "own", "own-dot", {interactive = true})
			oui_tip(dot, {"Own brush settings", "This group keeps its own brush size, shape, pattern and ink, loaded when you pick one of its tools. Click the hotkey to change this."})
		}
		waiting := group_key_wait == gi
		label := waiting ? "..." : (g.key == .KEY_NULL ? "-" : key_name(g.key))
		kc := oui.button_begin(uictx, "key", {class = label == "-" ? "keycap none" : "keycap", checked = waiting})
		oui.label(uictx, "t", label)
		oui.end(uictx)
		oui_tip(kc, {"Group hotkey", "Press this key to pick the group's last tool, and again to step through its tools. In a color or pattern group it steps through those instead. Click for options."})
		oui.end(uictx)
		bid := make_id({}, fmt.tprintf("grpbadge%d", gi))
		if kc.clicked {
			popup_begin(bid, oui_rect(kc), 120)
			popup_item("Assign hotkey...", 0, tip = "Choose the key for this group: press a letter or digit next. Esc cancels, Backspace removes the hotkey.")
			popup_item("Rename...", 3, tip = "Give this tool group a different name.")
			if len(g.colors) == 0 && len(g.patterns) == 0 {
				popup_item("Use for pen eraser", 2, checked = g.pen_eraser, tip = "The eraser end of a drawing pen uses this group's tool, which you pick here apart from the pen tip's. Only one group can do this.")
				if !g.pen_eraser do popup_item("Own brush settings", 4, checked = g.own, tip = "Give this group its own brush size, shape, pattern and ink, loaded when you pick one of its tools.")
			}
			popup_item("Remove group", 1, tip = "Remove this tool group from the toolbar. Its tools stay available from their shortcuts and other groups.")
		}
		if ui.popup_result_id == bid {
			switch ui.popup_result_val {
			case 0:
				group_key_wait = gi
				set_statusf("Press a key for this tool group (Esc cancels, Backspace clears)")
			case 2:
				group_set_pen_eraser(gi)
				set_status(g.pen_eraser ? "The pen's eraser end now uses this group's tool" : "The pen's eraser end erases again")
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
			popup_item("Rename...", 3, tip = "Give this tool group a different name.")
			popup_item("Remove group", 1, tip = "Remove this tool group from the toolbar. Its tools stay available from their shortcuts and other groups.")
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
			// the pen-eraser group keeps its own selection, separate from the pen tip's tool
			lit := g.pen_eraser ? g.last == tool : t == tool && cur_group == gi
			if tool_is_toggle(tool) do lit = tool_toggle_on(tool)
			clicked, bn := oui_icon_button(fmt.tprintf("t%d", int(tool)), TOOL_ICONS[tool], tool_tip(tool), {class = "tool", lit = lit, enabled = true, icon_lg = true})
			if clicked {
				if !tool_is_toggle(tool) do g.last = tool
				if tool_is_toggle(tool) || !g.pen_eraser do select_tool_in_group(tool, gi)
			} else if bn.hovered && ui.pressed[1] && !popup.open {
				rem_g, rem_t = gi, ti
			}
		}
		// patterns are listed one per row, the active one highlighted
		for pat, pi in g.patterns {
			if obutton(PATTERN_NAMES[pat], 0, {"", fmt.tprintf("%s Right-click to take it out of this group.", PATTERN_HELP[pat])}, true, pat == opts.pattern, key = fmt.tprintf("p%d", pi), class = "pattern-row") {
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
			oui_tip(cn, {color_hex(c), "Click to make this the foreground color and edit it with the color picker. Right-click to take it out of this group."})
			if cn.clicked {
				color_link_set(gi, ci)
			} else if cn.hovered && ui.pressed[1] && !popup.open {
				rem_g, rem_t = gi, ci
			}
		}
		can_add := is_colors ? len(g.colors) < MAX_GROUP_COLORS : (is_patterns ? len(g.patterns) < len(Pattern) : len(g.tools) < len(Tool))
		if can_add {
			tip := Tip{"Add to group", "Add a tool, switch, color or dither pattern to this group. A group holds only one of those kinds. To take one out again, right-click it."}
			pid := make_id({}, fmt.tprintf("grpadd%d", gi))
			add_clicked, add_node := oui_icon_button("add", .Plus, tip, {class = "tool quiet", enabled = true, icon_lg = true})
			if add_clicked {
				popup_begin(pid, oui_rect(add_node))
				popup_grid(5)
				if !is_colors && !is_patterns {
					popup_column("Tools")
					for tool in Tool {
						if !tool_group_has(&g, tool) {
							popup_item_icon(TOOL_NAMES[tool], int(tool), TOOL_ICONS[tool], TOOL_HELP[tool])
						}
					}
				}
				if !is_tools && !is_patterns {
					popup_column("Colors")
					popup_item_swatch("Foreground color", 100, fg)
					popup.items[len(popup.items) - 1].tip = "Add the foreground color to this group."
					popup_item("All palette colors", 101, tip = "Add all the colors of the current palette to this group.")
					for p in Palette_Preset {
						popup_item_palette(PALETTE_PRESET_NAMES[p], 200 + int(p), palette_preset(p), "Add the colors of this palette to this group.")
					}
				}
				if !is_tools && !is_colors {
					popup_column("Dither patterns")
					for pat in Pattern {
						if !pattern_in(g.patterns[:], pat) {
							popup_item_half(PATTERN_NAMES[pat], 300 + int(pat))
							popup.items[len(popup.items) - 1].tip = PATTERN_HELP[pat]
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
		if obutton("+ New Group", 0, {"", "Add an empty tool group below the others."}, id = "new-group") {
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
	tip_area(fgr, "fgchip", {"Foreground color", "What the left mouse button draws with. Change it in the Color panel on the right."})
	if ui_hover(bgr) && !ui_hover(fgr) {
		tooltip_hover(make_id(bgr, "bgchip"), {"Background color", "What the right mouse button draws with. Click to swap it with the foreground color (X)."})
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
		oslider("Size", 80, &opts.brush_size, 1, 64, {"Brush size ([ and ])", "How wide the brush is, in sprite pixels."})
		oui.element(uictx, "shape", "button-group")
		if c, _ := oui_icon_button("square", .Frame, {"Square brush", "A square brush tip, which keeps edges straight."}, {lit = !opts.brush_round, enabled = true}); c {
			opts.brush_round = false
		}
		if c, _ := oui_icon_button("round", .Ellipse, {"Round brush", "A round brush tip, which is easier on the eye at larger sizes."}, {lit = opts.brush_round, enabled = true}); c {
			opts.brush_round = true
		}
		oui.end(uictx)
	}
	ink_pattern :: proc() {
		if nv, ch := ocombo("pattern", 84, pattern_names(), int(opts.pattern), {"Pattern", "Which pixels the brush paints: all of them, or a repeating dither pattern. Patterns keep to the sprite's pixel grid, so strokes line up."}); ch {
			opts.pattern = Pattern(nv)
		}
		if nv, ch := ocombo("ink", 74, INK_NAMES[:], int(opts.ink), {"Ink", "How paint meets the pixels: Normal blends by the color's alpha, Replace overwrites them, alpha included, and Lock A paints only on what is already drawn."}); ch {
			opts.ink = Ink(nv)
		}
	}
	sel_modes :: proc() {
		labels := [?]string{"New", "Add", "Sub", "And"}
		tips := [?]Tip {
			{"New selection", "A new selection replaces the old one."},
			{"Add to selection", "New selections join the old one. Holding Shift does this with any mode."},
			{"Subtract from selection", "New selections are cut out of the old one. Holding Alt does this with any mode."},
			{"Intersect with selection", "Only the overlap with the old selection is kept. Holding Shift+Alt does this with any mode."},
		}
		oui.element(uictx, "sel-mode", "button-group")
		for l, i in labels {
			if obutton(l, 28, tips[i], true, int(opts.sel_mode) == i) {
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
		ocheck("Pixel-perfect", &opts.pixel_perf, {"", "Remove the extra pixel at L-shaped corners while drawing, so a one pixel line stays clean."})
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
		ocheck("Filled", &opts.fill_shape, {"", "Fill the shape with the color. Off draws only its outline, as wide as the brush."})
		ink_pattern()
		ohint("Shift: square   Ctrl: from center")
	case .Curve:
		size_slider()
		ink_pattern()
		ohint("Drag a line, then drag the handles. Enter: apply   Esc: cancel")
	case .Spray:
		size_slider()
		oslider("Density", 90, &opts.spray_dens, 1, 100, {"Spray density", "How many dots each moment of spraying scatters. The brush size sets how far they spread."})
		ink_pattern()
	case .Bucket:
		oslider("Tolerance", 100, &opts.tolerance, 0, 255, {"Tolerance", "How far a color may be from the one you click and still be filled. 0 takes only exact matches."})
		ocheck("Contiguous", &opts.contiguous, {"", "On: fill only pixels connected to the one you click. Off: fill every matching pixel on the layer."})
		ink_pattern()
	case .Wand:
		oslider("Tolerance", 100, &opts.tolerance, 0, 255, {"Tolerance", "How far a color may be from the one you click and still be selected. 0 takes only exact matches."})
		ocheck("Contiguous", &opts.contiguous, {"", "On: select only pixels connected to the one you click. Off: select every matching pixel on the layer."})
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
	if c, _ := oui_icon_button("sym-x", .Sym_X, cmd_tip("Mirror Horizontal", .Toggle_Sym_X), {lit = opts.sym_x, enabled = true}); c {
		run_cmd(.Toggle_Sym_X)
	}
	if c, _ := oui_icon_button("sym-y", .Sym_Y, cmd_tip("Mirror Vertical", .Toggle_Sym_Y), {lit = opts.sym_y, enabled = true}); c {
		run_cmd(.Toggle_Sym_Y)
	}
	if nv, ch := ocombo("tile", 76, TILE_NAMES[:], int(opts.tile), {"Tiled mode (Shift+T)", "Repeat the sprite around the canvas, across or down or both, and wrap drawing across its edges. For seamless tiles."}); ch {
		opts.tile = Tile_Mode(nv)
		switch_changed(.Tiling)
	}
	if c, _ := oui_icon_button("onion", .Onion, cmd_tip("Onion skin", .Toggle_Onion), {lit = opts.onion, enabled = true}); c {
		run_cmd(.Toggle_Onion)
	}
	if c, _ := oui_icon_button("pixel-grid", .Pixel_Grid, cmd_tip("Pixel grid", .Toggle_Pixel_Grid), {lit = opts.pixel_grid, enabled = true}); c {
		run_cmd(.Toggle_Pixel_Grid)
	}
	if c, _ := oui_icon_button("grid", .Grid, cmd_tip("Grid", .Toggle_Grid), {lit = opts.grid, enabled = true}); c {
		run_cmd(.Toggle_Grid)
	}
}

// The canvas background swatch in the options bar: checkers or the solid colour.
panel_canvas_bg :: proc(r: Rect) {
	clicked, _, hover := button_behavior(make_id(r, "canvasbg"), r, {"Canvas background", cmd_help(.Canvas_Bg)})
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
osection :: proc(key, title: string, tip := Tip{}) {
	oui.element(uictx, key, "section-head")
	oui_tip(oui.label(uictx, "t", title), tip)
	oui.element_leaf(uictx, "line", "section-line")
	oui.end(uictx)
}

PAL_CELL :: 14
PAL_MAX_ROWS :: 6
palette_area_w: i32 = 216 // width of the palette grid last frame, for its height

panel_right :: proc() {
	d := doc
	panel_element(.Right, "right", "sidepanel")
	defer oui.end(uictx)

	// --- colour picker ---------------------------------------------------
	osection("color-head", color_linked() != nil ? "Color - editing toolbar color" : "Color", {"Color", "The color you draw with. While a toolbar color is picked, edits here change that color in its group too."})
	oui_slot("picker", "color_picker")
	oui.element(uictx, "color-row", "row", {id = "color-row"})
	oui_tip(oui.element_leaf(uictx, "fg", "color-chip", {id = "fg-chip", style = fmt.tprintf("background:#%02x%02x%02x", fg.r, fg.g, fg.b), interactive = true}), {"Foreground color", "What the left mouse button draws with."})
	if oswatch_button("bg", bg, {"Background color", "What the right mouse button draws with. Click to swap it with the foreground color."}) do run_cmd(.Swap_Colors)
	if c, _ := oui_icon_button("swap", .Swap, cmd_tip("Swap colors", .Swap_Colors), {id = "swap-colors", enabled = true}); c {
		run_cmd(.Swap_Colors)
	}
	oui_slot("hex", "hex_field")
	otext("alpha", fmt.tprintf("A %d", fg.a), "dim", {"Alpha", "How solid the foreground color is, from 0 (see-through) to 255. Set it with the strip on the right of the picker."})
	oui.end(uictx)
	rgb := [3]int{int(fg.r), int(fg.g), int(fg.b)}
	names := [3]string{"R", "G", "B"}
	rgb_tips := [3]Tip{{"Red", "How much red is in the foreground color."}, {"Green", "How much green is in the foreground color."}, {"Blue", "How much blue is in the foreground color."}}
	classes := [3]string{"wide ch-r", "wide ch-g", "wide ch-b"}
	for i in 0 ..< 3 {
		if oslider(names[i], 0, &rgb[i], 0, 255, rgb_tips[i], class = classes[i]) {
			picker_set_fg(Color{u8(rgb[0]), u8(rgb[1]), u8(rgb[2]), fg.a})
		}
	}

	// --- palette ---------------------------------------------------------
	oui.element(uictx, "palette-head", "row", {id = "palette-head", class = "panel-head"})
	otext("t", "Palette", "dim", {"Palette", "This sprite's own set of colors, saved with it. Click a swatch to draw with it, right-click for the background color."})
	oui.element_leaf(uictx, "spacer", "spacer")
	if obutton("Presets", 50, {"", "Replace this sprite's palette with a ready-made one."}) {
		r := oui_rect(oui_last)
		popup_begin(PALETTE_PRESET_ID, r, 120)
		for p in Palette_Preset {
			popup_item(PALETTE_PRESET_NAMES[p], int(p), tip = "Replace this sprite's palette with this one.")
		}
	}
	if c, _ := oui_icon_button("replace", .Pencil, {"Replace swatch", "Change the selected swatch to the foreground color."}, {enabled = len(d.palette) > 0}); c {
		if d.pal_sel >= 0 && d.pal_sel < len(d.palette) {
			d.palette[d.pal_sel] = Color{fg.r, fg.g, fg.b, 255}
			d.modified = true
		}
	}
	if c, _ := oui_icon_button("add", .Plus, {"Add swatch", "Add the foreground color to the end of the palette."}, {enabled = true}); c {
		append(&d.palette, Color{fg.r, fg.g, fg.b, 255})
		d.pal_sel = len(d.palette) - 1
		d.modified = true
	}
	if c, _ := oui_icon_button("remove", .Minus, {"Remove swatch", "Take the selected swatch out of the palette. What you have drawn is not changed."}, {enabled = len(d.palette) > 1}); c {
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
	otext("t", "Recent", "dim", {"Recent colors", "The colors you painted with last, newest first."})
	oui_slot("recent", "recent")
	oui.end(uictx)

	// --- layer -----------------------------------------------------------
	osection("layer-head", "Layer", {"Current layer", "How the current layer mixes with the ones below. Pick the layer in the timeline."})
	l := &d.layers[d.active_layer]
	oui.element(uictx, "layer-props", "row", {id = "layer-props"})
	if nv, ch := ocombo("blend", 92, blend_names_slice(), int(l.blend), LAYER_BLEND_TIP); ch {
		history_push(d)
		l.blend = Blend(nv)
		doc_touch(d)
	}
	op := opacity_percent(l.opacity)
	// one undo step per drag or wheel gesture, taken before the first change and dropped if nothing changed
	@(static) op_pushed, op_changed: bool
	if on := oui.find_node(uictx.build_parent, "s:Opacity"); on != nil && on.hovered && (ui.pressed[0] || ui.wheel != 0) && !op_pushed {
		history_push(d)
		op_pushed, op_changed = true, false
	}
	if oslider("Opacity", 0, &op, 0, 100, LAYER_OPACITY_TIP, "%", class = "wide") {
		l.opacity = opacity_from_percent(op)
		op_changed = true
		doc_touch(d)
	}
	if op_pushed && !ui.down[0] && ui.wheel == 0 {
		if !op_changed do history_discard(d)
		op_pushed = false
	}
	oui.end(uictx)

	// --- filters ---------------------------------------------------------
	oui.element(uictx, "filters-head", "row", {id = "filters-head", class = "panel-head"})
	otext("t", "Filters", "dim", {"Layer filters", "Effects on the current layer, applied from the top down. They don't change its pixels until you merge or flatten it."})
	oui.element_leaf(uictx, "spacer", "spacer")
	if obutton("Add Filter", 64, {"", "Add a filter to the current layer. Exports show it, and merging makes it permanent."}) {
		popup_begin(FILTER_ADD_ID, oui_rect(oui_last), 100)
		for k in Filter_Kind {
			popup_item(FILTER_INFO[k].name, int(k), tip = FILTER_HELP[k])
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
		osection("preview-head", "Navigator", {"Navigator", "The whole sprite in small. The marked box is the part the canvas shows."})
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
	tip_area(sv, "sv", {"Saturation and brightness", "Click or drag to set the foreground color: left to right is saturation, top to bottom is brightness."})
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
	tip_area(hue, "hue", {"Hue", "Click or drag to pick the kind of color."})
	if act, _, fy := drag_area(hue, make_id(hue, "hue")); act {
		picker_set_fg_hsv(fy * 359.9, fg_s, fg_v, fg.a)
	}

	// alpha strip
	draw_checker(alp, 3)
	draw_gradient(f32(alp.x), f32(alp.y), f32(alp.w), f32(alp.h), Color{fg.r, fg.g, fg.b, 0}, Color{fg.r, fg.g, fg.b, 255})
	outline_rect(alp, C_RING_HI)
	tip_area(alp, "alpha", {"Alpha", "Click or drag to set how solid the foreground color is."})
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
	if ch, sub := text_field(hr, &hex_buf, {"Hex color", "The foreground color as a hex code. Type RRGGBB, or RRGGBBAA to include alpha."}); ch || sub {
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
			tooltip_hover(make_id(sr, "sw"), {color_hex(c), "Click to make this the foreground color, right-click for the background color."})
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
			tooltip_hover(make_id(sr, "rc"), {color_hex(c), "Click to make this the foreground color, right-click for the background color."})
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
	if z * gfx.scale >= 1 {
		z = math.floor(z * gfx.scale) / gfx.scale // a whole number of screen pixels per sprite pixel
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
		tooltip_hover(make_id(r, "navtip"), {"Navigator", "Click or drag to move the view to that part of the sprite."})
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
		tip_area(list, "filters-empty", {"Layer filters", "Effects on the current layer. Use Add Filter above to add one."})
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
		if icon_button(eye, .Eye, {"Filter on or off", "Turn this filter off to see the layer without it, or on again. It stays in the list."}, f.enabled) && ui_hover(inner) {
			act_toggle = i
		}
		bx := row.x + row.w - 17
		if icon_button(Rect{bx, cy + 2, 15, 14}, .Close, {"Remove filter", "Take this filter off the layer."}) && ui_hover(inner) {
			act_del = i
		}
		bx -= 16
		if icon_button(Rect{bx, cy + 2, 15, 14}, .Down, {"Move filter down", "Apply this filter after the one below it. The order can change the result."}, false, i < n - 1) && ui_hover(inner) {
			act_down = i
		}
		bx -= 16
		if icon_button(Rect{bx, cy + 2, 15, 14}, .Up, {"Move filter up", "Apply this filter before the one above it. The order can change the result."}, false, i > 0) && ui_hover(inner) {
			act_up = i
		}
		name_r := Rect{eye.x + eye.w + 5, cy + 2, bx - eye.x - eye.w - 7, 14}
		text_clipped(name_r, info.name, f.enabled ? C_TEXT : C_TEXT_DIM)
		if ui_hover(inner) do tip_area(name_r, "filter-name", {info.name, FILTER_HELP[f.kind]})
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
			if slider(sr, &f.amount, info.lo, info.hi, info.param, {info.name, FILTER_HELP[f.kind]}) {
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
obadge_button :: proc(key: string, ic: Icon, plus: bool, tip: Tip, enabled := true) -> bool {
	n := oui.button_begin(uictx, key, {class = "icon-btn tl-btn", disabled = !enabled})
	oui.label(uictx, "icon", icon_text(ic), {class = "icon"})
	oui.label(uictx, "badge", icon_text(plus ? .Plus : .Minus), {class = "icon badge"})
	oui.end(uictx)
	oui_tip(n, tip)
	return n.clicked && enabled
}

timeline_bar_controls :: proc() {
	d := doc
	tb :: proc(key: string, ic: Icon, tip: Tip, enabled := true, lit := false) -> bool {
		c, _ := oui_icon_button(key, ic, tip, {class = "tl-btn", enabled = enabled, lit = lit})
		return c
	}
	if obadge_button("layer-new", .Layer, true, cmd_tip("New layer", .Layer_New)) do run_cmd(.Layer_New)
	if obadge_button("layer-del", .Layer, false, cmd_tip("Delete layer", .Layer_Del), len(d.layers) > 1) do run_cmd(.Layer_Del)
	if tb("layer-dup", .Copy, cmd_tip("Duplicate layer", .Layer_Dup)) do run_cmd(.Layer_Dup)
	if tb("layer-up", .Up, cmd_tip("Move layer up", .Layer_Up), d.active_layer < len(d.layers) - 1) do run_cmd(.Layer_Up)
	if tb("layer-down", .Down, cmd_tip("Move layer down", .Layer_Down), d.active_layer > 0) do run_cmd(.Layer_Down)
	if tb("layer-merge", .Merge, cmd_tip("Merge down", .Layer_Merge), d.active_layer > 0) do run_cmd(.Layer_Merge)
	oui.element_leaf(uictx, "gap1", "tl-gap")
	if obadge_button("frame-new", .Frame, true, cmd_tip("New frame", .Frame_New)) do run_cmd(.Frame_New)
	if tb("frame-dup", .Copy, cmd_tip("Duplicate frame", .Frame_Dup)) do run_cmd(.Frame_Dup)
	if obadge_button("frame-del", .Frame, false, cmd_tip("Delete frame", .Frame_Del), len(d.frames) > 1) do run_cmd(.Frame_Del)
	oui.element_leaf(uictx, "gap2", "tl-gap")
	if tb("first", .First, cmd_tip("First frame", .Frame_First)) do run_cmd(.Frame_First)
	if tb("prev", .Left, cmd_tip("Previous frame", .Frame_Prev)) do run_cmd(.Frame_Prev)
	if tb("play", playing ? .Stop : .Right, cmd_tip(playing ? "Pause" : "Play", .Play), lit = playing) do run_cmd(.Play)
	if tb("next", .Right, cmd_tip("Next frame", .Frame_Next)) do run_cmd(.Frame_Next)
	if tb("last", .Last, cmd_tip("Last frame", .Frame_Last)) do run_cmd(.Frame_Last)
	oui.element_leaf(uictx, "gap3", "tl-gap")
	timeline_tag_controls()
	if obutton(fmt.tprintf("%d ms", d.frames[d.active_frame].duration), 64, {"Frame duration", "How long the current frame shows when the animation plays. Click to change it."}, key = "duration") {
		run_cmd(.Frame_Props)
	}
}

tl_scroll_x, tl_scroll_y: i32
layer_drag := -1 // layer being dragged in the timeline, or -1
layer_drag_y0: i32
layer_drag_on: bool

panel_timeline_grid :: proc(body: Rect) {
	d := doc
	hdr_w: i32 = min(150, body.w / 2) // the frames keep half of a narrow panel
	frame_w: i32 = 18
	row_h: i32 = 16
	hdr_h: i32 = 20
	names := Rect{body.x, body.y + hdr_h, hdr_w, body.h - hdr_h}
	head := Rect{body.x + hdr_w, body.y, body.w - hdr_w, hdr_h}
	grid := Rect{body.x + hdr_w, body.y + hdr_h, body.w - hdr_w, body.h - hdr_h}

	rows := layer_rows(d) // top first; what is in a closed group is left out
	nlayers := i32(len(rows))
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
	tip_text(body.x + 8, body.y + (hdr_h - FONT_CAP) / 2, "Layers", C_TEXT_DIM, {"Layers", "Each row is a layer, the top one in front. The columns on the right are the frames."})

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
		if ui_hover(tr) do tooltip_hover(make_id(tr, "tag"), {name_str(&t.name), "This tag's range of frames. Click to play only these frames, again to play all."})
		if ui_hover(tr) && ui.pressed[0] {
			play_tag = play_tag == ti ? -1 : ti
		}
	}
	clip_end()
	// scrubbing on the header numbers
	head_num := Rect{head.x, head.y, head.w, hdr_h - 6}
	hid := make_id(head_num, "scrub")
	tip_area(head_num, "scrub", {"Frames", "Click a number to go to that frame, or drag along them to scrub through the animation."})
	if ui_hover(head_num) && ui.pressed[0] {
		ui.active_id = hid
	}
	if ui.active_id == hid && ui.down[0] {
		f := int((ui.mx - head.x + tl_scroll_x) / frame_w)
		set_frame(f)
	}

	// layer rows
	clip_begin(names)
	for li, ii in rows {
		i := i32(ii)
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
		has_fx := l.opacity < 255 || (l.blend != .Normal && !(l.is_group && l.pass_through)) || len(l.filters) > 0
		ind := i32(layer_depth(d.layers[:], li)) * LAYER_INDENT
		fold := Rect{row.x + 36 + ind, ry + 2, 12, 12}
		nx := row.x + 38 + ind
		if l.is_group {
			icon(l.collapsed ? .Right : .Down, fold.x, fold.y, C_TEXT_DIM)
			nx += 14
			if ui_hover(names) do tip_area(fold, "layer-fold", {l.collapsed ? "Open group" : "Close group", "Show or hide the layers in this group here. It doesn't change the picture."})
		}
		shown := l.visible && !layer_hidden(d.layers[:], li)
		text_clipped(Rect{nx, ry, row.x + row.w - (has_fx ? 22 : 4) - nx, row_h}, name_str(&l.name), shown ? C_TEXT : C_TEXT_DIM)
		if has_fx {
			text(row.x + row.w - 18, ry + (row_h - FONT_CAP) / 2, "fx", C_TEXT_DIM)
		}
		if ui_hover(names) {
			tip_area(row, "layer-row", {name_str(&l.name), l.is_group ? "A layer group. Click to pick it, double-click for its properties, right-click for its menu. Drag layers onto it to put them in it; drag it to move it with what is in it. Filters on a group apply to its layers combined." : "Click to work on this layer, double-click for its properties, right-click for its menu. Drag to move it (onto a group to put it in the group). fx means it has an opacity, blend mode or filters."})
			tip_area(eye, "layer-eye", {"Show or hide layer", "A hidden layer is left out of exports too."})
			tip_area(lock, "layer-lock", {"Lock or unlock layer", "Tools can't change a locked layer."})
		}
		if ui_hover(row) && ui_hover(names) && ui.pressed[0] {
			if in_rect(eye, ui.mx, ui.my) {
				l.visible = !l.visible
				d.comp_dirty = true
				d.modified = true
			} else if in_rect(lock, ui.mx, ui.my) {
				l.locked = !l.locked
				d.modified = true
			} else if l.is_group && in_rect(rect_inset(fold, -2), ui.mx, ui.my) {
				l.collapsed = !l.collapsed
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
			popup_item(l.is_group ? "Duplicate Group" : "Duplicate Layer", cmd = .Layer_Dup)
			popup_item(l.is_group ? "Delete Group" : "Delete Layer", cmd = .Layer_Del, enabled = li - layer_span_start(d.layers[:], li) + 1 < len(d.layers))
			popup_item(l.is_group ? "Merge Group" : "Merge Down", cmd = .Layer_Merge, enabled = l.is_group || layer_merge_target(d) >= 0)
			popup_sep()
			popup_item("New Group", cmd = .Layer_Group_New)
			popup_item("Group Layer", cmd = .Layer_Group)
			if l.is_group do popup_item("Ungroup", cmd = .Layer_Ungroup)
			popup_sep()
			popup_item("Visible", cmd = .Layer_Vis, checked = l.visible)
			popup_item("Locked", cmd = .Layer_Lock, checked = l.locked)
			popup_sep()
			popup_item("Properties...", cmd = .Layer_Props)
		}
	}
	// drag a row up or down to reorder; the line shows where it will land
	if layer_drag >= 0 && layer_drag < len(d.layers) && nlayers > 0 {
		if !layer_drag_on && ui.down[0] && abs(ui.my - layer_drag_y0) > 4 {
			layer_drag_on = true
		}
		if layer_drag_on && ui.my - names.y + tl_scroll_y >= nlayers * row_h {
			// below every row: to the bottom, out of any group
			fill_rect(Rect{names.x + 36, names.y + nlayers * row_h - tl_scroll_y - 1, names.w - 37, 2}, C_ACCENT)
			if ui.released[0] do doc_move_to(d, layer_drag, 0, .Bottom)
		} else if layer_drag_on {
			ri := clamp((ui.my - names.y + tl_scroll_y) / row_h, 0, nlayers - 1)
			target := rows[ri]
			within := ui.my - (names.y + ri * row_h - tl_scroll_y) // pointer's height in the row
			drop: Layer_Drop
			switch {
			case d.layers[target].is_group && within > row_h / 4:
				drop = .Into
			case within < row_h / 2:
				drop = .Above
			case:
				drop = .Below
			}
			if target != layer_drag && !(d.layers[layer_drag].is_group && layer_in_group(d.layers[:], target, layer_drag)) {
				ry := names.y + ri * row_h - tl_scroll_y
				ind := i32(layer_depth(d.layers[:], target)) * LAYER_INDENT
				switch drop {
				case .Into:
					outline_rect(rect_inset(Rect{names.x, ry, names.w - 1, row_h}, 1), C_ACCENT)
				case .Above:
					fill_rect(Rect{names.x + 36 + ind, ry - 1, names.w - 37 - ind, 2}, C_ACCENT)
				case .Below, .Bottom:
					fill_rect(Rect{names.x + 36 + ind, ry + row_h - 1, names.w - 37 - ind, 2}, C_ACCENT)
				}
				if ui.released[0] {
					doc_move_to(d, layer_drag, target, drop)
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
	for li, ii in rows {
		i := i32(ii)
		ry := grid.y + i * row_h - tl_scroll_y
		if ry + row_h < grid.y || ry > grid.y + grid.h {
			continue
		}
		if d.layers[li].is_group do continue // a group has no pictures of its own
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
			if ui_hover(grid) {
				tip_area(cr, "cel", {fmt.tprintf("Frame %d, %s", f + 1, name_str(&d.layers[li].name)), "A cel: this layer's picture in this frame. Click to work on it, double-click to set the frame's duration."})
			}
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
			if row >= 0 && row < len(rows) {
				d.active_layer = rows[row]
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
		oui_tip(oui.label(uictx, "tool", name_str(&status_msg), {id = "status-tool", class = "message"}), {"Messages", "Messages from the program appear here, such as why an action could not be done."})
	} else {
		t := eff_tool()
		oui_tip(oui.label(uictx, "tool", fmt.tprintf("%s   %s", TOOL_NAMES[t], TOOL_HINT[t]), {id = "status-tool"}), tool_tip(t))
	}
	oui.separator(uictx, "sep0")
	// the readout under the pointer changes every frame, so it is drawn by hand
	oui_slot("cursor-info", "cursor_info")
	if d.sel != nil {
		x0, y0, x1, y1, ok := sel_bounds(d.sel, d.w, d.h)
		if ok {
			oui.separator(uictx, "sep1")
			oui_tip(oui.label(uictx, "sel", fmt.tprintf("Sel %dx%d", x1 - x0 + 1, y1 - y0 + 1)), {"Selection", "The width and height of what is selected. Ctrl+D clears the selection."})
		}
	}
	oui.element_leaf(uictx, "spacer", "spacer")
	oui_tip(oui.label(uictx, "layer", name_str(&d.layers[d.active_layer].name)), {"Current layer", "The layer you are drawing on. Pick another in the timeline."})
	oui.separator(uictx, "sep2")
	oui_tip(oui.label(uictx, "size", fmt.tprintf("%d x %d", d.w, d.h)), {"Sprite size", "Width by height, in pixels. Change it with Sprite > Canvas Size or Scale Sprite."})
	oui.separator(uictx, "sep3")
	oui_tip(oui.label(uictx, "frame", fmt.tprintf("Frame %d/%d", d.active_frame + 1, len(d.frames))), {"Current frame", "Which frame of the animation you are on, out of how many. The , and . keys step through them."})
	oui.separator(uictx, "sep4")
	oui_tip(oui.label(uictx, "zoom", fmt.tprintf("%d%%", int(d.zoom * gfx.scale * 100 + 0.5)), {class = "strong"}), {"Zoom", "100% shows one sprite pixel as one screen pixel. Use the mouse wheel to zoom, Ctrl+0 to fit the sprite and Ctrl+1 for 100%."})
}

// Pixel position and colour under the pointer, in the status bar.
panel_cursor_info :: proc(r: Rect) {
	d := doc
	tip_area(r, "cursor-info", {"Pointer", "The pixel under the pointer: x and y from the sprite's top left corner, and its color with all layers merged."})
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
