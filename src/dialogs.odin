package pangolin

import "core:fmt"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

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
	Confirm,
	Message,
	Shortcuts,
	About,
	Grid,
	Prefs,
	Outline,
	Replace_Color,
	Canvas_Bg,
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

ui_scale_pref := 0 // 0 = auto

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
	case .None, .Message, .Shortcuts, .About, .Confirm:
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
		dialog.a = int(l.opacity)
		dialog.b = int(l.blend)
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
	case .Prefs:
		dialog.a = ui_scale_pref
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
	if dialog.orig != nil {
		delete(dialog.orig)
		dialog.orig = nil
	}
}

dialog_close :: proc() {
	dialog_release()
	dialog.kind = .None
}

// Draws the dim background and window frame; returns the content area.
dialog_frame :: proc(title: string, w, h: i32) -> Rect {
	ui.layer = 2
	fill_rect(Rect{0, 0, i32(ui.w), i32(ui.h)}, Color{0, 0, 0, 140})
	x := (i32(ui.w) - w) / 2
	y := (i32(ui.h) - h) / 2
	fill_rect(Rect{x + 3, y + 3, w, h}, Color{0, 0, 0, 100})
	box := Rect{x, y, w, h}
	fill_rect(box, C_PANEL)
	outline_rect(box, C_BORDER)
	fill_rect(Rect{x, y, w, 16}, C_PANEL_DK)
	hline(x, y + 16, w, C_BORDER)
	text(x + 8, y + 4, title, C_TEXT)
	return Rect{x + 10, y + 24, w - 20, h - 34}
}

// OK / Cancel row at the bottom of the content area.
dialog_buttons :: proc(c: Rect, ok_label := "OK", cancel_label := "Cancel") -> (ok, cancel: bool) {
	y := c.y + c.h - 16
	r := Rect{c.x + c.w - 60, y, 60, 16}
	if button(r, ok_label) {
		ok = true
	}
	if cancel_label != "" {
		if button(Rect{r.x - 66, y, 60, 16}, cancel_label) {
			cancel = true
		}
	}
	if ui.focus_id == 0 {
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) {
			ok = true
		}
		if rl.IsKeyPressed(.ESCAPE) && cancel_label != "" {
			cancel = true
		}
	}
	return
}

row_int :: proc(c: Rect, y: i32, label: string, v: ^int, lo, hi: int, tip := "") -> bool {
	text(c.x, y + 3, label, C_TEXT)
	return field_int(Rect{c.x + 110, y, 72, 14}, v, lo, hi, tip)
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
	}
}

dlg_new :: proc() {
	c := dialog_frame("New Sprite", 250, 160)
	y := c.y
	row_int(c, y, "Width", &dialog.a, 1, 4096)
	y += 20
	row_int(c, y, "Height", &dialog.b, 1, 4096)
	y += 22
	sizes := [?]int{16, 32, 64, 128, 256}
	for s, i in sizes {
		if button(Rect{c.x + i32(i) * 44, y, 42, 14}, fmt.tprintf("%d", s)) {
			dialog.a, dialog.b = s, s
		}
	}
	y += 22
	text(c.x, y + 3, "Background", C_TEXT)
	nv, ch := combo(Rect{c.x + 110, y, 110, 14}, BG_FILL_NAMES[:], dialog.c)
	if ch {
		dialog.c = nv
	}
	ok, cancel := dialog_buttons(c)
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
	row_int(c, y, "Width", &dialog.a, 1, 8192)
	y += 20
	row_int(c, y, "Height", &dialog.b, 1, 8192)
	y += 22
	text(c.x, y + 3, "Anchor", C_TEXT)
	for i in 0 ..< 9 {
		r := Rect{c.x + 110 + i32(i % 3) * 18, y + i32(i / 3) * 18, 16, 16}
		if icon_button(r, dialog.c == i ? .Check : .Minus, "", dialog.c == i) {
			dialog.c = i
		}
	}
	ok, cancel := dialog_buttons(c)
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
	if row_int(c, y, "Width", &dialog.a, 1, 8192) && dialog.flag {
		dialog.b = max(int(f32(dialog.a) * dialog.ratio + 0.5), 1)
	}
	y += 20
	if row_int(c, y, "Height", &dialog.b, 1, 8192) && dialog.flag {
		dialog.a = max(int(f32(dialog.b) / dialog.ratio + 0.5), 1)
	}
	y += 22
	checkbox(c.x, y, "Lock aspect ratio", &dialog.flag)
	y += 18
	pcts := [?]int{50, 200, 300, 400}
	for p, i in pcts {
		if button(Rect{c.x + i32(i) * 44, y, 42, 14}, fmt.tprintf("%d%%", p)) {
			dialog.a = max(doc.w * p / 100, 1)
			dialog.b = max(doc.h * p / 100, 1)
		}
	}
	ok, cancel := dialog_buttons(c)
	if cancel {
		dialog_close()
	}
	if ok {
		doc_scale(doc, dialog.a, dialog.b)
		doc.view_init = false
		dialog_close()
	}
}

dlg_layer_props :: proc() {
	c := dialog_frame("Layer Properties", 270, 170)
	y := c.y
	text(c.x, y + 3, "Name", C_TEXT)
	text_field(Rect{c.x + 70, y, 170, 14}, &dialog.name)
	y += 20
	text(c.x, y + 3, "Opacity", C_TEXT)
	slider(Rect{c.x + 70, y, 170, 14}, &dialog.a, 0, 255, "")
	y += 20
	text(c.x, y + 3, "Blend", C_TEXT)
	nv, ch := combo(Rect{c.x + 70, y, 110, 14}, blend_names_slice(), dialog.b)
	if ch {
		dialog.b = nv
	}
	y += 22
	checkbox(c.x, y, "Visible", &dialog.flag)
	checkbox(c.x + 80, y, "Locked", &dialog.flag2)
	ok, cancel := dialog_buttons(c)
	if cancel {
		dialog_close()
	}
	if ok {
		history_push(doc)
		l := &doc.layers[doc.active_layer]
		l.name = dialog.name
		l.opacity = u8(dialog.a)
		l.blend = Blend(dialog.b)
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
	row_int(c, y, "Duration (ms)", &dialog.a, 10, 60000)
	y += 22
	checkbox(c.x, y, "Apply to all frames", &dialog.flag)
	ok, cancel := dialog_buttons(c)
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

dlg_tags :: proc() {
	rows := max(len(doc.tags), 1)
	h := i32(70 + rows * 20)
	c := dialog_frame("Animation Tags", 440, h)
	y := c.y
	if len(doc.tags) == 0 {
		text(c.x, y + 3, "No tags yet. Tags name a range of frames for playback.", C_TEXT_DIM)
		y += 20
	}
	del := -1
	for &t, i in doc.tags {
		text_field(Rect{c.x, y, 100, 14}, &t.name)
		tf := t.from + 1
		tt := t.to + 1
		text(c.x + 108, y + 3, "from", C_TEXT_DIM)
		if field_int(Rect{c.x + 134, y, 36, 14}, &tf, 1, len(doc.frames)) {
			t.from = tf - 1
			if t.to < t.from do t.to = t.from
		}
		text(c.x + 176, y + 3, "to", C_TEXT_DIM)
		if field_int(Rect{c.x + 192, y, 36, 14}, &tt, 1, len(doc.frames)) {
			t.to = tt - 1
			if t.from > t.to do t.from = t.to
		}
		combo_enum(Rect{c.x + 234, y, 80, 14}, TAG_DIR_NAMES, &t.dir)
		// color swatch cycles through hues
		sw := Rect{c.x + 320, y, 14, 14}
		fill_rect(sw, t.color)
		outline_rect(sw, C_BORDER)
		if in_rect(sw, ui.mx, ui.my) && ui.pressed[0] && ui.layer == ui.input_layer {
			h, s, v := rgb_to_hsv(t.color)
			t.color = hsv_to_rgb(h + 40, s, v)
		}
		if icon_button(Rect{c.x + 340, y, 16, 14}, .Trash, "Delete tag") {
			del = i
		}
		y += 20
	}
	if del >= 0 {
		ordered_remove(&doc.tags, del)
		if play_tag >= len(doc.tags) {
			play_tag = -1
		}
	}
	if button(Rect{c.x, c.y + c.h - 16, 80, 16}, "Add tag") {
		t := Tag {
			from  = doc.active_frame,
			to    = doc.active_frame,
			color = hsv_to_rgb(f32(len(doc.tags)) * 55, 0.6, 0.9),
		}
		name_set(&t.name, fmt.tprintf("Tag %d", len(doc.tags) + 1))
		append(&doc.tags, t)
	}
	ok, _ := dialog_buttons(c, "Close", "")
	if ok {
		doc.modified = true
		dialog_close()
	}
}

dlg_adjust :: proc() {
	c := dialog_frame("Hue / Saturation / Brightness", 280, 140)
	y := c.y
	changed := false
	text(c.x, y + 3, "Hue", C_TEXT)
	changed |= slider(Rect{c.x + 80, y, 170, 14}, &dialog.a, -180, 180, "")
	y += 20
	text(c.x, y + 3, "Saturation", C_TEXT)
	changed |= slider(Rect{c.x + 80, y, 170, 14}, &dialog.b, -100, 100, "")
	y += 20
	text(c.x, y + 3, "Brightness", C_TEXT)
	changed |= slider(Rect{c.x + 80, y, 170, 14}, &dialog.c, -100, 100, "")
	if changed && dialog.orig != nil {
		pix := cel_write(doc, doc.active_layer, doc.active_frame)
		edit_adjust(dialog.orig, pix, dialog.a, dialog.b, dialog.c)
		doc_touch(doc)
	}
	ok, cancel := dialog_buttons(c)
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
	text(c.x, y + 3, "Format", C_TEXT)
	nv, ch := combo(Rect{c.x + 80, y, 170, 14}, export_format_names(), fmt_idx)
	if ch {
		fmt_idx = nv
	}
	y += 22
	row_int(c, y, "Scale", &dialog.a, 1, 32)
	text(c.x + 190, y + 3, "x", C_TEXT_DIM)
	y += 22
	format := Export_Format(fmt_idx)
	#partial switch format {
	case .Sheet:
		text(c.x, y + 3, "Layout", C_TEXT)
		combo_enum(Rect{c.x + 80, y, 170, 14}, SHEET_LAYOUT_NAMES, &export_layout)
	case .GIF:
		checkbox(c.x, y, "Loop forever", &export_gif_loop)
	}
	if format != .PNG && len(doc.tags) > 0 && play_tag >= 0 {
		checkbox(c.x, y + 16, "Only the selected tag", &export_range_tag)
	}
	ok, cancel := dialog_buttons(c, "Export")
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
	row_int(c, y, "Frame width", &dialog.a, 1, 8192)
	y += 20
	row_int(c, y, "Frame height", &dialog.b, 1, 8192)
	ok, cancel := dialog_buttons(c, "Import")
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
	c := dialog_frame("Unsaved Changes", 300, 90)
	text(c.x, c.y + 2, fmt.tprintf("Save changes to \"%s\"?", name_str(&d.title)), C_TEXT)
	y := c.y + c.h - 16
	proceed := false
	if button(Rect{c.x, y, 70, 16}, "Save") {
		if file_save(d, false) {
			proceed = true
		} else {
			dialog_close()
			return
		}
	}
	if button(Rect{c.x + 76, y, 90, 16}, "Don't Save") {
		proceed = true
	}
	if button(Rect{c.x + 172, y, 70, 16}, "Cancel") || rl.IsKeyPressed(.ESCAPE) {
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
	ok, _ := dialog_buttons(c, "OK", "")
	if ok {
		dialog_close()
	}
}

dlg_shortcuts :: proc() {
	c := dialog_frame("Keyboard Shortcuts", 620, 330)
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
		name, _ := strings.replace_all(fmt.tprintf("%v", s.cmd), "_", " ", context.temp_allocator)
		text(x + 78, y, name, C_TEXT)
	}
	ok, _ := dialog_buttons(c, "Close", "")
	if ok || rl.IsKeyPressed(.ESCAPE) {
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
	text(tx, c.y + 50, "symmetry, tiling, palettes, GIF/PNG export.", C_TEXT)
	text(tx, c.y + 68, "Written in Odin with raylib.", C_TEXT_DIM)
	ok, _ := dialog_buttons(c, "Close", "")
	if ok {
		dialog_close()
	}
}

dlg_grid :: proc() {
	c := dialog_frame("Grid Settings", 250, 160)
	y := c.y
	row_int(c, y, "Grid width", &dialog.a, 1, 1024)
	y += 20
	row_int(c, y, "Grid height", &dialog.b, 1, 1024)
	y += 20
	row_int(c, y, "Offset X", &dialog.c, 0, 1024)
	y += 20
	row_int(c, y, "Offset Y", &dialog.d, 0, 1024)
	y += 20
	checkbox(c.x, y, "Show grid", &dialog.flag)
	ok, cancel := dialog_buttons(c)
	if cancel {
		dialog_close()
	}
	if ok {
		opts.grid_w, opts.grid_h = dialog.a, dialog.b
		opts.grid_ox, opts.grid_oy = dialog.c, dialog.d
		opts.grid = dialog.flag
		dialog_close()
	}
}

UI_SCALE_NAMES := [?]string{"Auto", "1x", "2x", "3x", "4x"}
BG_MODE_NAMES := [?]string{"Checkerboard", "Black", "White", "Gray", "Custom color"}

dlg_prefs :: proc() {
	c := dialog_frame("Preferences", 280, 150)
	y := c.y
	text(c.x, y + 3, "UI scale", C_TEXT)
	nv, ch := combo(Rect{c.x + 110, y, 100, 14}, UI_SCALE_NAMES[:], dialog.a)
	if ch {
		dialog.a = nv
	}
	y += 20
	text(c.x, y + 3, "Canvas background", C_TEXT)
	nv2, ch2 := combo(Rect{c.x + 110, y, 100, 14}, BG_MODE_NAMES[:], dialog.b)
	if ch2 {
		dialog.b = nv2
	}
	y += 22
	checkbox(c.x, y, "Show pixel grid when zoomed in", &opts.pixel_grid)
	y += 16
	checkbox(c.x, y, "Show symmetry guides", &opts.sym_guides)
	ok, cancel := dialog_buttons(c)
	if cancel {
		dialog_close()
	}
	if ok {
		ui_scale_pref = dialog.a
		bg_mode = dialog.b
		dialog_close()
	}
}

dlg_outline :: proc() {
	c := dialog_frame("Outline", 250, 110)
	y := c.y
	text(c.x, y + 3, "Adds an outline using the foreground colour", C_TEXT_DIM)
	y += 18
	checkbox(c.x, y, "Include diagonals", &dialog.flag)
	ok, cancel := dialog_buttons(c)
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
	text(c.x, y + 3, "Replace", C_TEXT)
	fill_rect(Rect{c.x + 70, y, 30, 14}, dialog.col_a)
	outline_rect(Rect{c.x + 70, y, 30, 14}, C_BORDER)
	text(c.x + 108, y + 3, "with", C_TEXT)
	fill_rect(Rect{c.x + 140, y, 30, 14}, dialog.col_b)
	outline_rect(Rect{c.x + 140, y, 30, 14}, C_BORDER)
	y += 20
	text(c.x, y + 3, "(from foreground and background colors)", C_TEXT_DIM)
	y += 18
	row_int(c, y, "Tolerance", &dialog.a, 0, 255)
	ok, cancel := dialog_buttons(c)
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

// Canvas background: checkerboard or any solid colour. Changes apply immediately.
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
		if ui_hover(sr) && ui.pressed[0] {
			bg_custom = pc
			bg_mode = 4
			name_set(&dialog.name, color_hex(pc))
		}
	}
	y += 56

	// hex entry + shortcuts to existing colours
	text(c.x, y + 3, "Color (hex)", C_TEXT)
	hr := Rect{c.x + 76, y, 70, 14}
	hid := make_id(hr, "text")
	if ui.focus_id != hid && bg_mode == 4 {
		name_set(&dialog.name, color_hex(Color{bg_custom.r, bg_custom.g, bg_custom.b, 255}))
	}
	ch, sub := text_field(hr, &dialog.name, "RRGGBB")
	if ch || sub {
		if pc, ok := parse_hex(name_str(&dialog.name)); ok {
			bg_custom = Color{pc.r, pc.g, pc.b, 255}
			bg_mode = 4
		}
	}
	sw := Rect{c.x + 152, y, 22, 14}
	fill_rect(sw, Color{bg_custom.r, bg_custom.g, bg_custom.b, 255})
	outline_rect(sw, C_BORDER)
	y += 22
	if button(Rect{c.x, y, 140, 16}, "Use foreground color") {
		bg_custom = Color{fg.r, fg.g, fg.b, 255}
		bg_mode = 4
		name_set(&dialog.name, color_hex(bg_custom))
	}
	if button(Rect{c.x + 146, y, 134, 16}, "Use background color") {
		bg_custom = Color{bg.r, bg.g, bg.b, 255}
		bg_mode = 4
		name_set(&dialog.name, color_hex(bg_custom))
	}
	y += 22
	checkbox(c.x, y, "Show background behind transparent pixels", &opts.show_checks)
	ok, _ := dialog_buttons(c, "Close", "")
	if ok || rl.IsKeyPressed(.ESCAPE) {
		dialog_close()
	}
}
