package pangolin

import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"
import "core:strings"

// The UI scale, as a percentage. Below 100% the text is unreadable; above it, steps of a quarter
// keep the sizes of text and icons close to whole numbers of pixels.
UI_SCALE_MIN :: 100
UI_SCALE_MAX :: 400
UI_SCALE_STEP :: 25

// The layout needs this much room, in logical units.
UI_MIN_W :: 900
UI_MIN_H :: 560

ui_scale_round :: proc(pct: f32) -> int {
	return clamp(int(math.round(pct / UI_SCALE_STEP)) * UI_SCALE_STEP, UI_SCALE_MIN, UI_SCALE_MAX)
}

// The size that suits a display: as large as leaves the whole screen 1280 x 720 logical units, so the
// interface takes up about the same share of any monitor, or more if the operating system is set to
// enlarge everything.
ui_scale_auto :: proc(display_w, display_h, os_scale: f32) -> int {
	return ui_scale_round(max(min(display_w / 1280, display_h / 720), os_scale) * 100)
}

// A value from the settings file or --scale. 0 is auto; 1-4 are whole multiples, as settings
// saved before the scale became a percentage have it.
ui_scale_parse :: proc(v: int) -> int {
	if v <= 0 {
		return 0
	}
	return ui_scale_round(f32(v <= 4 ? v * 100 : v))
}

// What the user picked, or what suits the display the window is on.
ui_scale_wanted :: proc() -> int {
	if ui_scale_pref > 0 {
		return ui_scale_pref
	}
	return ui_scale_auto(gfx_display_info())
}

// The largest scale that leaves the layout the room it needs in a window of this size.
ui_scale_fit :: proc(sw, sh: int) -> int {
	pct := min(sw * 100 / UI_MIN_W, sh * 100 / UI_MIN_H)
	return max(pct / UI_SCALE_STEP * UI_SCALE_STEP, UI_SCALE_MIN)
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
	win_w, win_h := 0, 0
	shot_frame := 8
	demo := false
	dlg_arg := -1
	menu_arg := -1
	Script_Click :: struct {
		frame: int,
		pos:   Vec2,
		btn:   int,
	}
	clicks := make([dynamic]Script_Click)
	open_args := make([dynamic]string)
	args := os.args
	for i := 1; i < len(args); i += 1 {
		a := args[i]
		switch {
		case a == "--shot" && i + 1 < len(args):
			shot_path = args[i + 1]
			i += 1
		case a == "--scale" && i + 1 < len(args):
			v, _ := strconv.parse_int(args[i + 1])
			ui_scale_pref = ui_scale_parse(v)
			i += 1
		case a == "--size" && i + 1 < len(args):
			wh := strings.split(args[i + 1], "x", context.temp_allocator)
			if len(wh) == 2 {
				win_w, _ = strconv.parse_int(wh[0])
				win_h, _ = strconv.parse_int(wh[1])
			}
			i += 1
		case a == "--shot-frame" && i + 1 < len(args):
			shot_frame, _ = strconv.parse_int(args[i + 1])
			i += 1
		case a == "--convert" && i + 1 < len(args):
			convert_path = args[i + 1]
			i += 1
		case a == "--demo":
			demo = true
		case a == "--dialog" && i + 1 < len(args):
			dlg_arg, _ = strconv.parse_int(args[i + 1])
			i += 1
		case a == "--menu" && i + 1 < len(args):
			menu_arg, _ = strconv.parse_int(args[i + 1])
			i += 1
		case a == "--clicks" && i + 1 < len(args):
			// "frame:x,y;frame:x,y": left clicks in window pixels (frame:x,y,r for a right click),
			// for checking the interface with --shot
			for part in strings.split(args[i + 1], ";", context.temp_allocator) {
				fp := strings.split(part, ":", context.temp_allocator)
				if len(fp) != 2 do continue
				xy := strings.split(fp[1], ",", context.temp_allocator)
				if len(xy) < 2 do continue
				f, _ := strconv.parse_int(fp[0])
				x, _ := strconv.parse_f32(xy[0])
				y, _ := strconv.parse_f32(xy[1])
				append(&clicks, Script_Click{f, {x, y}, len(xy) > 2 && xy[2] == "r" ? 1 : 0})
			}
			i += 1
		case a == "--selftest":
			os.exit(selftest())
		case:
			append(&open_args, a)
		}
	}

	if !gfx_init(APP_NAME, shot_path != "", win_w, win_h) {
		fmt.eprintln("could not start SDL:", gfx_error())
		os.exit(1)
	}
	defer gfx_shutdown()
	pen_init()

	tool_groups_default()
	if shot_path == "" {
		prefs_load()
	}
	render_init()
	brand_init()
	oui_init()
	panels_init()

	d := doc_new(64, 64, "Sprite-1")
	d.modified = false
	add_doc(d)
	set_fg(Color{0, 0, 0, 255})
	if demo {
		demo_setup()
	}
	for p in open_args {
		open_path(p)
	}
	if convert_path != "" {
		pixelate_open_path(convert_path)
	}
	if dlg_arg > 0 {
		dialog_open(Dialog_Kind(clamp(dlg_arg, 0, len(Dialog_Kind) - 1)))
	}
	frame_no := 0
	last_title: string

	for !want_quit {
		free_all(context.temp_allocator)
		gfx_poll()
		for c in clicks {
			switch frame_no {
			case c.frame - 2 ..< c.frame:
				gfx.mouse = c.pos
			case c.frame:
				gfx.mouse = c.pos
				gfx.m_pressed[c.btn], gfx.m_down[c.btn] = true, true
			case c.frame + 1:
				gfx.mouse = c.pos
				gfx.m_released[c.btn], gfx.m_down[c.btn] = true, false
			}
		}
		if gfx.quit {
			gfx.quit = false
			request_quit()
		}

		sw, sh := int(gfx.pw), int(gfx.ph)
		// never let the logical resolution drop below what the layout needs
		ui.scale = f32(min(ui_scale_wanted(), ui_scale_fit(sw, sh))) / 100
		if ui.scale != gfx.scale {
			views_rescale(gfx.scale, ui.scale)
		}
		gfx_set_scale(ui.scale)
		// rounded up, so that full-window fills reach the last row of pixels at any scale
		ui.w = max(int(math.ceil(f32(sw) / ui.scale)), 1)
		ui.h = max(int(math.ceil(f32(sh) / ui.scale)), 1)

		ui_begin_frame()
		ui.input_layer = (dialog.kind != .None ? 2 : 0) + (popup.open ? 1 : 0)

		for p in gfx.dropped {
			open_path(p)
		}

		shortcuts_update()
		playback_update(ui.dt)
		if status_t > 0 {
			status_t -= ui.dt
		}
		if menu_arg >= 0 && frame_no == 3 {
			menu_request = menu_arg
		}
		gfx_begin(C_BG)
		oui_begin_frame()
		main_ui()
		oui_end_frame()
		oui_render()
		dialogs_run()
		popup_run()
		files_drag_run()
		tooltip_draw()
		if shot_path != "" && frame_no == shot_frame {
			gfx.screenshot = shot_path
		}
		gfx_present()
		ui_end_frame()

		// window title
		title := fmt.tprintf("%s - %s", doc_display_name(doc), APP_NAME)
		if title != last_title {
			gfx_set_title(title)
			delete(last_title)
			last_title = strings.clone(title)
		}

		frame_no += 1
		if shot_path != "" && frame_no == shot_frame + 4 {
			break
		}
	}
	if shot_path == "" {
		prefs_save()
	}
}
