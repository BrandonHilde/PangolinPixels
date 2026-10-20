package pangolin

import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

choose_scale :: proc() -> i32 {
	if ui_scale_pref > 0 {
		return i32(ui_scale_pref)
	}
	mh := rl.GetMonitorHeight(rl.GetCurrentMonitor())
	switch {
	case mh >= 2000:
		return 3
	case mh >= 1350:
		return 2
	}
	return 1
}

// Builds a small sample sprite so the UI can be inspected without user input.
demo_setup :: proc() {
	d := doc
	doc_resize(d, 48, 48, 0, 0)
	d.modified = false
	set_fg(Color{40, 40, 60, 255})
	bgc := Color{250, 220, 120, 255}
	// body
	stroke_begin(false, bgc, bg)
	draw_shape(.Ellipse, {6, 8}, {41, 43})
	opts.fill_shape = true
	draw_shape(.Ellipse, {6, 8}, {41, 43})
	opts.fill_shape = false
	stroke_end()
	doc_add_layer(d)
	stroke_begin(false, Color{40, 40, 60, 255}, bg)
	draw_shape(.Ellipse, {6, 8}, {41, 43})
	stroke_end()
	stroke_begin(false, Color{40, 40, 60, 255}, bg)
	opts.fill_shape = true
	draw_shape(.Rect, {15, 18}, {19, 24})
	draw_shape(.Rect, {28, 18}, {32, 24})
	opts.fill_shape = false
	stroke_end()
	stroke_begin(false, Color{200, 60, 70, 255}, bg)
	line_points(14, 32, 20, 36, stroke_plot)
	line_points(20, 36, 28, 36, stroke_plot)
	line_points(28, 36, 33, 32, stroke_plot)
	stroke_end()
	doc_add_frame(d, true)
	set_frame(0)
	d.active_layer = 1
	// a selection and a tag
	m := mask_rect(d.w, d.h, 10, 10, 30, 20)
	doc_sel_set(d, m)
	t := Tag{from = 0, to = 1, color = Color{90, 200, 120, 255}}
	name_set(&t.name, "walk")
	append(&d.tags, t)
	d.modified = false
	d.undo = d.undo // keep history
	opts.onion = false
	name_set(&d.title, "demo")
}

main :: proc() {
	shot_path := ""
	convert_path := ""
	demo := false
	dlg_arg := 0
	menu_arg := -1
	args := os.args
	for i in 1 ..< len(args) {
		if args[i] == "--shot" && i + 1 < len(args) {
			shot_path = args[i + 1]
		}
		if args[i] == "--convert" && i + 1 < len(args) {
			convert_path = args[i + 1]
		}
		if args[i] == "--demo" {
			demo = true
		}
		if args[i] == "--dialog" && i + 1 < len(args) {
			dlg_arg = int(args[i + 1][0] - '0') * 10 + (len(args[i + 1]) > 1 ? int(args[i + 1][1] - '0') : -0)
			if len(args[i + 1]) == 1 do dlg_arg = int(args[i + 1][0] - '0')
		}
		if args[i] == "--menu" && i + 1 < len(args) {
			menu_arg = int(args[i + 1][0] - '0')
		}
		if args[i] == "--selftest" {
			rl.SetTraceLogLevel(.WARNING)
			os.exit(selftest())
		}
	}

	rl.SetTraceLogLevel(.WARNING)
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 800, APP_NAME)
	defer rl.CloseWindow()
	rl.SetExitKey(.KEY_NULL)
	rl.SetWindowMinSize(820, 520)
	mon := rl.GetCurrentMonitor()
	mw, mh := rl.GetMonitorWidth(mon), rl.GetMonitorHeight(mon)
	if mw > 0 && mh > 0 {
		ww, wh := mw * 85 / 100, mh * 85 / 100
		rl.SetWindowSize(ww, wh)
		rl.SetWindowPosition((mw - ww) / 2, max((mh - wh) / 2, 30))
	}

	prefs_load()
	ui.font = rl.GetFontDefault()
	ui.icons = icons_build_atlas()
	render_init()
	brand_init()

	d := doc_new(64, 64, "Sprite-1")
	d.modified = false
	add_doc(d)
	set_fg(Color{0, 0, 0, 255})
	if demo {
		demo_setup()
	}

	if convert_path != "" {
		pixelate_open_path(convert_path)
	}
	if dlg_arg > 0 {
		dialog_open(Dialog_Kind(dlg_arg))
	}
	rt: rl.RenderTexture2D
	rt_w, rt_h: i32
	frame_no := 0
	last_title: string

	for !want_quit {
		if rl.WindowShouldClose() {
			request_quit()
		}
		free_all(context.temp_allocator)

		sw, sh := rl.GetScreenWidth(), rl.GetScreenHeight()
		ui.scale = choose_scale()
		// never let the logical resolution drop below what the layout needs
		for ui.scale > 1 && (sw / ui.scale < 900 || sh / ui.scale < 560) {
			ui.scale -= 1
		}
		lw, lh := max(sw / ui.scale, 1), max(sh / ui.scale, 1)
		ui.w, ui.h = int(lw), int(lh)
		if rt.id == 0 || rt_w != lw || rt_h != lh {
			if rt.id != 0 {
				rl.UnloadRenderTexture(rt)
			}
			rt = rl.LoadRenderTexture(lw, lh)
			rl.SetTextureFilter(rt.texture, .POINT)
			rt_w, rt_h = lw, lh
		}

		ui_begin_frame()
		ui.input_layer = (dialog.kind != .None ? 2 : 0) + (popup.open ? 1 : 0)

		if rl.IsFileDropped() {
			files := rl.LoadDroppedFiles()
			for i in 0 ..< int(files.count) {
				open_path(string(files.paths[i]))
			}
			rl.UnloadDroppedFiles(files)
		}

		shortcuts_update()
		playback_update(ui.dt)
		if status_t > 0 {
			status_t -= ui.dt
		}

		if menu_arg >= 0 && frame_no == 3 {
			popup_begin(1, Rect{i32(menu_arg) * 48, 0, 40, 15}, 0, menu_arg)
			menu_build(menu_arg)
		}
		rl.BeginTextureMode(rt)
		rl.ClearBackground(C_BG)
		main_ui()
		dialogs_run()
		popup_run()
		tooltip_draw()
		rl.EndTextureMode()

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTexturePro(
			rt.texture,
			{0, 0, f32(lw), -f32(lh)},
			{0, 0, f32(lw * ui.scale), f32(lh * ui.scale)},
			{},
			0,
			rl.WHITE,
		)
		rl.EndDrawing()
		ui_end_frame()

		// window title
		title := fmt.tprintf("%s - %s", doc_display_name(doc), APP_NAME)
		if title != last_title {
			rl.SetWindowTitle(strings.clone_to_cstring(title, context.temp_allocator))
			delete(last_title)
			last_title = strings.clone(title)
		}

		frame_no += 1
		if shot_path != "" {
			if frame_no == 6 {
				rl.TakeScreenshot(strings.clone_to_cstring(shot_path, context.temp_allocator))
			}
			if frame_no == 10 {
				break
			}
		}
	}
	prefs_save()
}
