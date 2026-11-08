package pangolin

import "core:fmt"
import "core:slice"
import "core:strings"

Dialog_Kind :: enum {
	None,
	New_Sprite,
	Canvas_Size,
	Scale,
	Layer_Props,
	Frame_Props,
	Tags,
	Adjust,
	Export,
	Import_Sheet,
	Pixelate,
	Confirm,
	Message,
	Shortcuts,
	About,
	Grid,
	Prefs,
	Outline,
	Replace_Color,
	Canvas_Bg,
	Group_Rename,
	Workspaces,
	UI_Scale,
}

Dialog :: struct {
	kind:         Dialog_Kind,
	a, b, c, d:   int,
	flag, flag2:  bool,
	ratio:        f32,
	name:         Name,
	msg_title:    Name,
	msg_text:     Name,
	confirm_doc:  ^Doc,
	confirm_quit: bool,
	orig:         []Color,
	col_a, col_b: Color,
}

dialog: Dialog

BG_FILL_NAMES := [?]string{"Transparent", "White", "Black", "Foreground", "Background"}
DIALOG_W_DEFAULT :: 260

dialog_open :: proc(k: Dialog_Kind) {
	dialog_release()
	dialog = Dialog {
		kind      = k,
		msg_title = dialog.msg_title,
		msg_text  = dialog.msg_text,
	}
	switch k {
	case .None, .Message, .Shortcuts, .About, .Confirm, .Pixelate, .Group_Rename, .UI_Scale:
	case .Workspaces:
		ws_refresh()
		for e, i in ws_entries {
			if e.name == ws_current do dialog.a = i
		}
	case .New_Sprite:
		dialog.a, dialog.b = 64, 64
	case .Canvas_Size:
		dialog.a, dialog.b = doc.w, doc.h
		dialog.c = 4
	case .Scale:
		dialog.a, dialog.b = doc.w, doc.h
		dialog.flag = true
		dialog.ratio = f32(doc.h) / f32(doc.w)
	case .Layer_Props:
		l := &doc.layers[doc.active_layer]
		dialog.name = l.name
		dialog.a = opacity_percent(l.opacity)
		dialog.b = int(l.blend)
		if l.is_group do dialog.b = l.pass_through ? 0 : int(l.blend) + 1 // a group's list starts with Pass Through
		dialog.flag = l.visible
		dialog.flag2 = l.locked
	case .Frame_Props:
		dialog.a = doc.frames[doc.active_frame].duration
	case .Tags:
		history_push(doc)
	case .Adjust:
		if can_edit() {
			history_push(doc)
			pix := cel_write(doc, doc.active_layer, doc.active_frame)
			dialog.orig = slice.clone(pix)
		} else {
			dialog.kind = .None
		}
	case .Export:
		dialog.a = 1
	case .Import_Sheet:
		dialog.a, dialog.b = 16, 16
	case .Grid:
		dialog.a, dialog.b = opts.grid_w, opts.grid_h
		dialog.c, dialog.d = opts.grid_ox, opts.grid_oy
		dialog.flag = opts.grid
		dialog.flag2 = opts.snap
	case .Prefs:
		dialog.b = bg_mode
	case .Outline:
		dialog.flag = false
	case .Replace_Color:
		dialog.col_a = fg
		dialog.col_b = bg
		dialog.a = 0
	case .Canvas_Bg:
		name_set(&dialog.name, color_hex(Color{bg_custom.r, bg_custom.g, bg_custom.b, 255}))
	}
}

dialog_release :: proc() {
	if dialog.kind == .Pixelate {
		pixelate_free()
	}
	if dialog.orig != nil {
		delete(dialog.orig)
		dialog.orig = nil
	}
}

dialog_close :: proc() {
	dialog_release()
	dialog.kind = .None
}

// OK / Cancel row at the bottom of the content area.
dialog_buttons :: proc(c: Rect, ok_tip: string, ok_label := "OK", cancel_label := "Cancel") -> (ok, cancel: bool) {
	y := c.y + c.h - 18
	r := Rect{c.x + c.w - 64, y, 64, 18}
	if button_primary(r, ok_label, {ok_label, ok_tip}) {
		ok = true
	}
	if cancel_label != "" {
		if button(Rect{r.x - 70, y, 64, 18}, cancel_label, {cancel_label, "Close this window without changing anything (Esc)."}) {
			cancel = true
		}
	}
	if ui.focus_id == 0 && !popup.open {
		if IsKeyPressed(.ENTER) || IsKeyPressed(.KP_ENTER) {
			ok = true
		}
		if IsKeyPressed(.ESCAPE) {
			if cancel_label != "" {
				cancel = true
			} else {
				ok = true
			}
		}
	}
	return
}

row_int :: proc(c: Rect, y: i32, name: string, v: ^int, lo, hi: int, desc: string) -> bool {
	tip_text(c.x, y + 3, name, C_TEXT, {name, desc})
	return field_int(Rect{c.x + 110, y, 72, 14}, v, lo, hi, {name, desc})
}

dialogs_run :: proc() {
	if dialog.kind == .None {
		return
	}
	switch dialog.kind {
	case .None:
	case .New_Sprite:
		dlg_new()
	case .Canvas_Size:
		dlg_canvas_size()
	case .Scale:
		dlg_scale()
	case .Layer_Props:
		dlg_layer_props()
	case .Frame_Props:
		dlg_frame_props()
	case .Tags:
		dlg_tags()
	case .Adjust:
		dlg_adjust()
	case .Export:
		dlg_export()
	case .Import_Sheet:
		dlg_import_sheet()
	case .Pixelate:
		dlg_pixelate()
	case .Confirm:
		dlg_confirm()
	case .Message:
		dlg_message()
	case .Shortcuts:
		dlg_shortcuts()
	case .About:
		dlg_about()
	case .Grid:
		dlg_grid()
	case .Prefs:
		dlg_prefs()
	case .Outline:
		dlg_outline()
	case .Replace_Color:
		dlg_replace()
	case .Canvas_Bg:
		dlg_canvas_bg()
	case .Group_Rename:
		dlg_group_rename()
	case .Workspaces:
		dlg_workspaces()
	case .UI_Scale:
		dlg_ui_scale()
	}
}

dlg_new :: proc() {
	c := dialog_frame("New Sprite", 250, 160)
	y := c.y
	row_int(c, y, "Width", &dialog.a, 1, 4096, "The width of the new sprite in pixels.")
	y += 20
	row_int(c, y, "Height", &dialog.b, 1, 4096, "The height of the new sprite in pixels.")
	y += 22
	sizes := [?]int{16, 32, 64, 128, 256}
	for s, i in sizes {
		label := fmt.tprintf("%d", s)
		if button(Rect{c.x + i32(i) * 44, y, 42, 14}, label, {fmt.tprintf("%d x %d", s, s), "Fill in a square size."}) {
			dialog.a, dialog.b = s, s
		}
	}
	y += 22
	BG_TIP :: "What the first layer starts filled with. Foreground and Background are the two colors in use now."
	tip_text(c.x, y + 3, "Background", C_TEXT, {"Background", BG_TIP})
	nv, ch := combo(Rect{c.x + 110, y, 110, 14}, BG_FILL_NAMES[:], dialog.c, {"Background", BG_TIP})
	if ch {
		dialog.c = nv
	}
	ok, cancel := dialog_buttons(c, "Create the sprite in a new tab (Enter).")
	if cancel {
		dialog_close()
	}
	if ok {
		d := doc_new(dialog.a, dialog.b, fmt.tprintf("Sprite-%d", len(docs) + 1))
		fillc: Color
		switch dialog.c {
		case 1:
			fillc = Color{255, 255, 255, 255}
		case 2:
			fillc = Color{0, 0, 0, 255}
		case 3:
			fillc = fg
		case 4:
			fillc = bg
		}
		if fillc.a != 0 {
			for &p in d.layers[0].cels[0].pix {
				p = fillc
			}
		}
		d.modified = false
		add_doc(d)
		dialog_close()
	}
}

dlg_canvas_size :: proc() {
	c := dialog_frame("Canvas Size", 250, 190)
	y := c.y
	row_int(c, y, "Width", &dialog.a, 1, 8192, "The new canvas width in pixels. Nothing is scaled: the canvas grows, or the sprite is cut off.")
	y += 20
	row_int(c, y, "Height", &dialog.b, 1, 8192, "The new canvas height in pixels. Nothing is scaled: the canvas grows, or the sprite is cut off.")
	y += 22
	ANCHOR_TIP :: "Where the sprite stays when the canvas changes: new space is added, or pixels are cut off, on the other sides."
	tip_text(c.x, y + 3, "Anchor", C_TEXT, {"Anchor", ANCHOR_TIP})
	for i in 0 ..< 9 {
		r := Rect{c.x + 110 + i32(i % 3) * 18, y + i32(i / 3) * 18, 16, 16}
		// (the id comes from the title, and each of the nine has its own place)
		if icon_button(r, dialog.c == i ? .Check : .Minus, {"Anchor", ANCHOR_TIP}, dialog.c == i) {
			dialog.c = i
		}
	}
	ok, cancel := dialog_buttons(c, "Apply this canvas size (Enter). You can undo it.")
	if cancel {
		dialog_close()
	}
	if ok {
		col, row := dialog.c % 3, dialog.c / 3
		ox := (dialog.a - doc.w) * col / 2
		oy := (dialog.b - doc.h) * row / 2
		doc_resize(doc, dialog.a, dialog.b, ox, oy)
		doc.view_init = false
		dialog_close()
	}
}

dlg_scale :: proc() {
	c := dialog_frame("Scale Sprite", 250, 160)
	y := c.y
	if row_int(c, y, "Width", &dialog.a, 1, 8192, "The sprite's new width in pixels. Pixels are repeated or dropped, never blurred.") && dialog.flag {
		dialog.b = max(int(f32(dialog.a) * dialog.ratio + 0.5), 1)
	}
	y += 20
	if row_int(c, y, "Height", &dialog.b, 1, 8192, "The sprite's new height in pixels. Pixels are repeated or dropped, never blurred.") && dialog.flag {
		dialog.a = max(int(f32(dialog.b) / dialog.ratio + 0.5), 1)
	}
	y += 22
	checkbox(c.x, y, "Lock aspect ratio", &dialog.flag, {"Lock aspect ratio", "Keep the width and height in step, so the sprite is not stretched."})
	y += 18
	pcts := [?]int{50, 200, 300, 400}
	for p, i in pcts {
		label := fmt.tprintf("%d%%", p)
		if button(Rect{c.x + i32(i) * 44, y, 42, 14}, label, {label, "Fill in this percentage of the sprite's current size."}) {
			dialog.a = max(doc.w * p / 100, 1)
			dialog.b = max(doc.h * p / 100, 1)
		}
	}
	ok, cancel := dialog_buttons(c, "Scale the sprite to this size (Enter). You can undo it.")
	if cancel {
		dialog_close()
	}
	if ok {
		doc_scale(doc, dialog.a, dialog.b)
		doc.view_init = false
		dialog_close()
	}
}

// Layer opacity is stored 0-255 and shown as a percentage. Rounding both ways keeps a value steady on the way through.
opacity_percent :: proc(o: u8) -> int {
	return (int(o) * 100 + 127) / 255
}

opacity_from_percent :: proc(p: int) -> u8 {
	return u8((p * 255 + 50) / 100)
}

LAYER_OPACITY_TIP :: Tip{"Layer opacity", "How solid this layer is drawn over the ones below it. Its pixels are not changed."}
LAYER_BLEND_TIP :: Tip{"Blend mode", "How this layer's colors mix with the layers below it. Normal just covers them."}

dlg_layer_props :: proc() {
	c := dialog_frame("Layer Properties", 270, 170)
	y := c.y
	tip_text(c.x, y + 3, "Name", C_TEXT, {"Layer name", "The name shown in the timeline."})
	text_field(Rect{c.x + 70, y, 170, 14}, &dialog.name, {"Layer name", "The name shown in the timeline."})
	y += 20
	tip_text(c.x, y + 3, "Opacity", C_TEXT, LAYER_OPACITY_TIP)
	slider(Rect{c.x + 70, y, 170, 14}, &dialog.a, 0, 100, "", LAYER_OPACITY_TIP, "%")
	y += 20
	tip_text(c.x, y + 3, "Blend", C_TEXT, LAYER_BLEND_TIP)
	is_group := doc.layers[doc.active_layer].is_group
	nv, ch := combo(Rect{c.x + 70, y, 110, 14}, is_group ? group_blend_names() : blend_names_slice(), dialog.b, is_group ? Tip{"Blend", "Pass Through: the group's layers blend straight into what is below it, each by its own mode. Any other mode (or a filter on the group) combines its layers first, then blends the result in."} : LAYER_BLEND_TIP)
	if ch {
		dialog.b = nv
	}
	y += 22
	checkbox(c.x, y, "Visible", &dialog.flag, {"Visible", "Whether this layer is shown. A hidden layer is left out of exports too."})
	checkbox(c.x + 80, y, "Locked", &dialog.flag2, {"Locked", "Tools can't change a locked layer."})
	ok, cancel := dialog_buttons(c, "Apply these settings to the layer (Enter). You can undo it.")
	if cancel {
		dialog_close()
	}
	if ok {
		history_push(doc)
		l := &doc.layers[doc.active_layer]
		l.name = dialog.name
		if dialog.a != opacity_percent(l.opacity) do l.opacity = opacity_from_percent(dialog.a)
		if l.is_group {
			l.pass_through = dialog.b == 0
			if dialog.b > 0 do l.blend = Blend(dialog.b - 1)
		} else {
			l.blend = Blend(dialog.b)
		}
		l.visible = dialog.flag
		l.locked = dialog.flag2
		doc_touch(doc)
		dialog_close()
	}
}

blend_names_slice :: proc() -> []string {
	@(static) names: [len(Blend)]string
	for n, i in BLEND_NAMES {
		names[int(i)] = n
	}
	return names[:]
}

dlg_frame_props :: proc() {
	c := dialog_frame("Frame Properties", 250, 110)
	y := c.y
	row_int(c, y, "Duration (ms)", &dialog.a, 10, 60000, "How long this frame shows when the animation plays, in thousandths of a second.")
	y += 22
	checkbox(c.x, y, "Apply to all frames", &dialog.flag, {"Apply to all frames", "Give every frame this duration, not just the current one."})
	ok, cancel := dialog_buttons(c, "Apply this duration (Enter). You can undo it.")
	if cancel {
		dialog_close()
	}
	if ok {
		history_push(doc)
		if dialog.flag {
			for &f in doc.frames {
				f.duration = dialog.a
			}
		} else {
			doc.frames[doc.active_frame].duration = dialog.a
		}
		doc.modified = true
		dialog_close()
	}
}

dlg_adjust :: proc() {
	c := dialog_frame("Hue / Saturation / Brightness", 280, 140)
	y := c.y
	changed := false
	HUE_TIP :: Tip{"Hue", "Turn all colors around the color wheel, by this many degrees."}
	SAT_TIP :: Tip{"Saturation", "Make the colors more vivid, or fade them towards gray."}
	VAL_TIP :: Tip{"Brightness", "Make the colors lighter or darker."}
	tip_text(c.x, y + 3, "Hue", C_TEXT, HUE_TIP)
	changed |= slider(Rect{c.x + 80, y, 170, 14}, &dialog.a, -180, 180, "", HUE_TIP)
	y += 20
	tip_text(c.x, y + 3, "Saturation", C_TEXT, SAT_TIP)
	changed |= slider(Rect{c.x + 80, y, 170, 14}, &dialog.b, -100, 100, "", SAT_TIP)
	y += 20
	tip_text(c.x, y + 3, "Brightness", C_TEXT, VAL_TIP)
	changed |= slider(Rect{c.x + 80, y, 170, 14}, &dialog.c, -100, 100, "", VAL_TIP)
	if changed && dialog.orig != nil {
		pix := cel_write(doc, doc.active_layer, doc.active_frame)
		edit_adjust(dialog.orig, pix, dialog.a, dialog.b, dialog.c)
		doc_touch(doc)
	}
	ok, cancel := dialog_buttons(c, "Keep these colors (Enter). You can undo it.")
	if cancel {
		pix := cel_write(doc, doc.active_layer, doc.active_frame)
		copy(pix, dialog.orig)
		history_discard(doc)
		doc.comp_dirty = true
		dialog_close()
	}
	if ok {
		dialog_close()
	}
}

dlg_export :: proc() {
	@(static) fmt_idx: int
	h: i32 = 150
	c := dialog_frame("Export", 290, h)
	y := c.y
	FORMAT_TIP :: "PNG saves the current frame. A sprite sheet puts all frames in one PNG, a PNG sequence saves one file per frame, and a GIF plays as an animation."
	tip_text(c.x, y + 3, "Format", C_TEXT, {"Format", FORMAT_TIP})
	nv, ch := combo(Rect{c.x + 80, y, 170, 14}, export_format_names(), fmt_idx, {"Format", FORMAT_TIP})
	if ch {
		fmt_idx = nv
	}
	y += 22
	row_int(c, y, "Scale", &dialog.a, 1, 32, "How many pixels wide and tall each sprite pixel is in the file. Pixels stay sharp.")
	text(c.x + 190, y + 3, "x", C_TEXT_DIM)
	y += 22
	format := Export_Format(fmt_idx)
	#partial switch format {
	case .Sheet:
		LAYOUT_TIP :: "How the frames are arranged in the image: in one row, in one column, or in a grid that is about square."
		tip_text(c.x, y + 3, "Layout", C_TEXT, {"Layout", LAYOUT_TIP})
		combo_enum(Rect{c.x + 80, y, 170, 14}, SHEET_LAYOUT_NAMES, &export_layout, {"Layout", LAYOUT_TIP})
	case .GIF:
		checkbox(c.x, y, "Loop forever", &export_gif_loop, {"Loop forever", "On: the GIF keeps repeating. Off: it plays once and stops on the last frame."})
	}
	if format != .PNG && len(doc.tags) > 0 && play_tag >= 0 {
		checkbox(c.x, y + 16, "Only the selected tag", &export_range_tag, {"Only the selected tag", "Export just the frames of the tag picked in the timeline, not the whole animation."})
	}
	ok, cancel := dialog_buttons(c, "Choose where to save it (Enter).", "Export")
	if cancel {
		dialog_close()
	}
	if ok {
		scale := dialog.a
		dialog_close()
		export_run(format, scale, false)
	}
}

export_format_names :: proc() -> []string {
	@(static) names: [len(Export_Format)]string
	for n, i in EXPORT_FORMAT_NAMES {
		names[int(i)] = n
	}
	return names[:]
}

dlg_import_sheet :: proc() {
	c := dialog_frame("Import Sprite Sheet", 250, 120)
	y := c.y
	text(c.x, y + 3, "Slice the image into frames", C_TEXT_DIM)
	y += 18
	row_int(c, y, "Frame width", &dialog.a, 1, 8192, "The width of one frame in the sheet, in pixels.")
	y += 20
	row_int(c, y, "Frame height", &dialog.b, 1, 8192, "The height of one frame in the sheet, in pixels.")
	ok, cancel := dialog_buttons(c, "Slice the image and open it as a new sprite with one frame per slice (Enter).", "Import")
	if cancel {
		dialog_close()
	}
	if ok {
		a, b := dialog.a, dialog.b
		dialog_close()
		import_sheet(a, b)
	}
}

dlg_confirm :: proc() {
	d := dialog.confirm_doc
	if d == nil { 	// --dialog opens this window with no sprite to ask about
		dialog_close()
		return
	}
	c := dialog_frame("Unsaved Changes", 300, 90)
	text(c.x, c.y + 2, fmt.tprintf("Save changes to \"%s\"?", name_str(&d.title)), C_TEXT)
	y := c.y + c.h - 18
	proceed := false
	if button_primary(Rect{c.x + c.w - 64, y, 64, 18}, "Save", {"Save", "Save your changes, then go on."}) {
		if file_save(d, false) {
			proceed = true
		} else {
			dialog_close()
			return
		}
	}
	if button(Rect{c.x + c.w - 150, y, 80, 18}, "Don't Save", {"Don't Save", "Go on and lose the changes since you last saved. This can't be undone."}) {
		proceed = true
	}
	if button(Rect{c.x + c.w - 220, y, 64, 18}, "Cancel", {"Cancel", "Keep the sprite open and go back to it (Esc)."}) || IsKeyPressed(.ESCAPE) {
		dialog_close()
		return
	}
	if proceed {
		quit := dialog.confirm_quit
		dialog_close()
		if quit {
			d.modified = false
			request_quit()
		} else {
			close_doc(d)
		}
	}
}

dlg_message :: proc() {
	c := dialog_frame(name_str(&dialog.msg_title), 320, 100)
	text(c.x, c.y + 4, name_str(&dialog.msg_text), C_TEXT)
	ok, _ := dialog_buttons(c, "Close this message (Enter or Esc).", "OK", "")
	if ok {
		dialog_close()
	}
}

dlg_shortcuts :: proc() {
	c := dialog_frame("Keyboard Shortcuts", 620, 360)
	cols :: 3
	col_w := c.w / cols
	per_col := (len(SHORTCUTS) + cols - 1) / cols
	for s, i in SHORTCUTS {
		col := i / per_col
		row := i % per_col
		x := c.x + i32(col) * col_w
		y := c.y + i32(row) * 11
		sc := shortcut_text_for(s)
		text(x, y, sc, C_ACCENT)
		name, _ := strings.replace_all(shortcut_label(s.cmd), "_", " ", context.temp_allocator)
		text(x + 78, y, name, C_TEXT)
	}
	// the tool groups' own hotkeys (set in the toolbar)
	sb := strings.builder_make(context.temp_allocator)
	for &g in tool_groups {
		if g.key != .KEY_NULL do fmt.sbprintf(&sb, "%s%s %s", strings.builder_len(sb) > 0 ? "    " : "", key_name(g.key), group_title(&g))
	}
	if strings.builder_len(sb) > 0 {
		tip_text(c.x, c.y + c.h - 30, "Tool groups:", C_TEXT_DIM, {"Tool groups", "The hotkeys of your tool groups. They come before the shortcuts above, so a group can take over a tool's letter."})
		text(c.x + 78, c.y + c.h - 30, strings.to_string(sb), C_ACCENT)
	}
	ok, _ := dialog_buttons(c, "Close this list (Enter or Esc).", "Close", "")
	if ok {
		dialog_close()
	}
}

shortcut_text_for :: proc(s: Shortcut) -> string {
	return fmt.tprintf("%s%s%s%s", s.ctrl ? "Ctrl+" : "", s.shift ? "Shift+" : "", s.alt ? "Alt+" : "", key_name(s.key))
}

dlg_about :: proc() {
	c := dialog_frame("About", 340, 150)
	logo_draw(c.x + 4, c.y + 6, 4)
	tx := c.x + 80
	text(tx, c.y + 6, APP_NAME, C_ACCENT)
	text(tx, c.y + 20, APP_TAGLINE, C_TEXT_DIM)
	text(tx, c.y + 38, "Layers, frames, tags, onion skin, selections,", C_TEXT)
	text(tx, c.y + 50, "mirroring, tiling, palettes, GIF/PNG export.", C_TEXT)
	text(tx, c.y + 68, "Written in Odin with SDL3 and OdinUI.", C_TEXT_DIM)
	ok, _ := dialog_buttons(c, "Close this window (Enter or Esc).", "Close", "")
	if ok {
		dialog_close()
	}
}

dlg_grid :: proc() {
	c := dialog_frame("Grid Settings", 250, 176)
	y := c.y
	row_int(c, y, "Grid width", &dialog.a, 1, 1024, "The width of one grid cell in sprite pixels.")
	y += 20
	row_int(c, y, "Grid height", &dialog.b, 1, 1024, "The height of one grid cell in sprite pixels.")
	y += 20
	row_int(c, y, "Offset X", &dialog.c, 0, 1024, "How far the grid is pushed right from the sprite's left edge, in pixels.")
	y += 20
	row_int(c, y, "Offset Y", &dialog.d, 0, 1024, "How far the grid is pushed down from the sprite's top edge, in pixels.")
	y += 20
	checkbox(c.x, y, "Show grid", &dialog.flag, {"Show grid", "Draw the grid over the sprite (Ctrl+;). It is only a guide and is not part of the sprite."})
	checkbox(c.x + 110, y, "Snap to grid", &dialog.flag2, {"Snap to grid", "Selections, shapes and moves snap to the grid while it is shown (Ctrl+Shift+;)."})
	ok, cancel := dialog_buttons(c, "Apply these grid settings (Enter).")
	if cancel {
		dialog_close()
	}
	if ok {
		opts.grid_w, opts.grid_h = dialog.a, dialog.b
		opts.grid_ox, opts.grid_oy = dialog.c, dialog.d
		opts.snap = dialog.flag2
		switch_set(.Grid, dialog.flag)
		dialog_close()
	}
}

BG_MODE_NAMES := [?]string{"Checkerboard", "Black", "White", "Gray", "Custom color"}

dlg_prefs :: proc() {
	c := dialog_frame("Preferences", 280, 110)
	y := c.y
	BG_TIP :: "What shows behind transparent pixels. It is only a guide and is not part of the sprite."
	tip_text(c.x, y + 3, "Canvas background", C_TEXT, {"Canvas background", BG_TIP})
	nv2, ch2 := combo(Rect{c.x + 110, y, 100, 14}, BG_MODE_NAMES[:], dialog.b, {"Canvas background", BG_TIP})
	if ch2 {
		dialog.b = nv2
	}
	y += 20
	checkbox(c.x, y, "Show pixel grid when zoomed in", &opts.pixel_grid, {"Pixel grid", "Draw thin lines between the sprite's pixels when zoomed in far enough (Ctrl+Shift+')."})
	y += 16
	checkbox(c.x, y, "Show mirror guides", &opts.sym_guides, {"Mirror guides", "Draw the lines that drawing is mirrored across, while Mirror is on."})
	ok, cancel := dialog_buttons(c, "Keep these settings (Enter).")
	if cancel {
		dialog_close()
	}
	if ok {
		bg_mode = dialog.b
		dialog_close()
	}
}

dlg_outline :: proc() {
	c := dialog_frame("Outline", 250, 110)
	y := c.y
	text(c.x, y + 3, "Adds an outline using the foreground color", C_TEXT_DIM)
	y += 18
	checkbox(c.x, y, "Include diagonals", &dialog.flag, {"Include diagonals", "Also fill pixels that only touch a drawn pixel at a corner, for a thicker, rounder outline."})
	ok, cancel := dialog_buttons(c, "Draw the outline on the current layer (Enter). You can undo it.")
	if cancel {
		dialog_close()
	}
	if ok {
		edit_outline(fg, dialog.flag)
		dialog_close()
	}
}

dlg_replace :: proc() {
	c := dialog_frame("Replace Color", 270, 130)
	y := c.y
	FROM_TIP :: Tip{"Color to replace", "The foreground color when this window opened."}
	TO_TIP :: Tip{"New color", "The background color when this window opened."}
	tip_text(c.x, y + 3, "Replace", C_TEXT, FROM_TIP)
	from_r, to_r := Rect{c.x + 70, y, 30, 14}, Rect{c.x + 140, y, 30, 14}
	fill_rect(from_r, dialog.col_a)
	outline_rect(from_r, C_BORDER)
	tip_area(from_r, "from", FROM_TIP)
	tip_text(c.x + 108, y + 3, "with", C_TEXT, TO_TIP)
	fill_rect(to_r, dialog.col_b)
	outline_rect(to_r, C_BORDER)
	tip_area(to_r, "to", TO_TIP)
	y += 20
	text(c.x, y + 3, "(from foreground and background colors)", C_TEXT_DIM)
	y += 18
	row_int(c, y, "Tolerance", &dialog.a, 0, 255, "How far a color may be from the one to replace and still count. 0 replaces only exact matches.")
	ok, cancel := dialog_buttons(c, "Replace the color on the current layer (Enter). You can undo it.")
	if cancel {
		dialog_close()
	}
	if ok {
		edit_replace_color(dialog.col_a, dialog.col_b, dialog.a)
		dialog_close()
	}
}

// Closing / quitting ------------------------------------------------------------

request_close :: proc(d: ^Doc) {
	if d.modified {
		dialog_open(.Confirm)
		dialog.confirm_doc = d
		dialog.confirm_quit = false
	} else {
		close_doc(d)
	}
}

request_quit :: proc() {
	for d, i in docs {
		if d.modified {
			switch_doc(i)
			dialog_open(.Confirm)
			dialog.confirm_doc = d
			dialog.confirm_quit = true
			return
		}
	}
	want_quit = true
}

// Canvas background: checkerboard or any solid color. Changes apply immediately.
CANVAS_BG_PRESETS := [?]u32{
	0x000000, 0x202028, 0x3a3a46, 0x808080, 0xc0c0c0, 0xffffff,
	0x1e2a44, 0x2b4a3a, 0x5a3a3a, 0xf0e6d2, 0xff00ff, 0x00b4a0,
}

dlg_canvas_bg :: proc() {
	c := dialog_frame("Canvas Background", 300, 190)
	y := c.y
	text(c.x, y + 2, "Shown behind your sprite. Not part of the image.", C_TEXT_DIM)
	y += 18

	// checkerboard + preset swatches
	cb := Rect{c.x, y, 38, 20}
	draw_checker(cb, 4)
	outline_rect(cb, bg_mode == 0 ? C_ACCENT : C_BORDER)
	tip_area(cb, "checkers", {"Checkerboard", "The usual pattern for showing what is transparent."})
	if ui_hover(cb) && ui.pressed[0] {
		bg_mode = 0
	}
	if bg_mode == 0 {
		outline_rect(Rect{cb.x - 1, cb.y - 1, cb.w + 2, cb.h + 2}, C_ACCENT)
	}
	for v, i in CANVAS_BG_PRESETS {
		col := i % 6
		row := i / 6
		sr := Rect{c.x + 46 + i32(col) * 24, y + i32(row) * 24 - 2, 22, 22}
		pc := hexc(v)
		fill_rect(sr, pc)
		active := bg_mode == 4 && bg_custom.r == pc.r && bg_custom.g == pc.g && bg_custom.b == pc.b
		outline_rect(sr, active ? C_ACCENT : C_BORDER)
		tip_area(sr, "bg-preset", {color_hex(pc), "Use this color behind transparent pixels."})
		if ui_hover(sr) && ui.pressed[0] {
			bg_custom = pc
			bg_mode = 4
			name_set(&dialog.name, color_hex(pc))
		}
	}
	y += 56

	// hex entry + shortcuts to existing colors
	HEX_TIP :: Tip{"Background color", "Type a color as a hex code: RRGGBB."}
	tip_text(c.x, y + 3, "Color (hex)", C_TEXT, HEX_TIP)
	hr := Rect{c.x + 76, y, 70, 14}
	hid := make_id(hr, "text")
	if ui.focus_id != hid && bg_mode == 4 {
		name_set(&dialog.name, color_hex(Color{bg_custom.r, bg_custom.g, bg_custom.b, 255}))
	}
	ch, sub := text_field(hr, &dialog.name, HEX_TIP)
	if ch || sub {
		if pc, ok := parse_hex(name_str(&dialog.name)); ok {
			bg_custom = Color{pc.r, pc.g, pc.b, 255}
			bg_mode = 4
		}
	}
	sw := Rect{c.x + 152, y, 22, 14}
	fill_rect(sw, Color{bg_custom.r, bg_custom.g, bg_custom.b, 255})
	outline_rect(sw, C_BORDER)
	tip_area(sw, "bg-now", {"Custom color", "The solid color chosen for the background."})
	y += 22
	if button(Rect{c.x, y, 140, 16}, "Use foreground color", {"", "Put the foreground color behind transparent pixels."}) {
		bg_custom = Color{fg.r, fg.g, fg.b, 255}
		bg_mode = 4
		name_set(&dialog.name, color_hex(bg_custom))
	}
	if button(Rect{c.x + 146, y, 134, 16}, "Use background color", {"", "Put the background color behind transparent pixels."}) {
		bg_custom = Color{bg.r, bg.g, bg.b, 255}
		bg_mode = 4
		name_set(&dialog.name, color_hex(bg_custom))
	}
	y += 22
	checkbox(c.x, y, "Show background behind transparent pixels", &opts.show_checks, {"", "Off: transparent pixels show the color around the canvas instead."})
	ok, _ := dialog_buttons(c, "Close this window (Enter or Esc). The background is already applied.", "Close", "")
	if ok {
		dialog_close()
	}
}
