package pangolin

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// Tiny key=value preferences file stored next to the executable.

prefs_path :: proc() -> string {
	return fmt.tprintf("%spixels.cfg", gfx_app_dir())
}

// The settings file to read in `dir`: the app has had other names, and an older file is read once
// if the current one does not exist. "" if there is none.
prefs_find :: proc(dir: string) -> string {
	for name in ([?]string{"pixels.cfg", "pangolin.cfg", "pixel.cfg"}) {
		path := fmt.tprintf("%s%s", dir, name)
		if os.exists(path) do return path
	}
	return ""
}

prefs_save :: proc() {
	sb := strings.builder_make(context.temp_allocator)
	b2i :: proc(b: bool) -> int {
		return b ? 1 : 0
	}
	fmt.sbprintf(&sb, "ui_scale=%d\n", ui_scale_pref)
	fmt.sbprintf(&sb, "bg_mode=%d\n", bg_mode)
	fmt.sbprintf(&sb, "bg_custom=%d\n", int(bg_custom.r) << 16 | int(bg_custom.g) << 8 | int(bg_custom.b))
	fmt.sbprintf(&sb, "pixel_grid=%d\n", b2i(opts.pixel_grid))
	fmt.sbprintf(&sb, "sym_guides=%d\n", b2i(opts.sym_guides))
	fmt.sbprintf(&sb, "show_checks=%d\n", b2i(opts.show_checks))
	files_prefs_write(&sb)
	fmt.sbprintf(&sb, "preview=%d\n", b2i(show_preview))
	fmt.sbprintf(&sb, "grid_w=%d\n", opts.grid_w)
	fmt.sbprintf(&sb, "grid_h=%d\n", opts.grid_h)
	// the shared brush settings, not those of a group that keeps its own
	groups := tool_groups_serialize()
	fmt.sbprintf(&sb, "brush_size=%d\n", shared_brush.size)
	fmt.sbprintf(&sb, "pixel_perfect=%d\n", b2i(shared_brush.pixel_perf))
	fmt.sbprintf(&sb, "onion_prev=%d\n", opts.onion_prev)
	fmt.sbprintf(&sb, "onion_next=%d\n", opts.onion_next)
	fmt.sbprintf(&sb, "onion_alpha=%d\n", opts.onion_alpha)
	fmt.sbprintf(&sb, "snap=%d\n", b2i(opts.snap))
	fmt.sbprintf(&sb, "groups=%s\n", groups)
	write_file(prefs_path(), transmute([]u8)strings.to_string(sb))
}

prefs_load :: proc() {
	path := prefs_find(gfx_app_dir())
	if path == "" {
		return
	}
	data, ok := read_file(path)
	if !ok {
		return
	}
	defer delete(data)
	text := string(data)
	for line in strings.split_lines_iterator(&text) {
		eq := strings.index_byte(line, '=')
		if eq < 0 {
			continue
		}
		key := strings.trim_space(line[:eq])
		sval := strings.trim_space(line[eq + 1:])
		if key == "groups" {
			tool_groups_parse(sval)
			continue
		}
		if files_prefs_read(key, sval) {
			continue
		}
		val, vok := strconv.parse_int(sval)
		if !vok {
			continue
		}
		switch key {
		case "ui_scale":
			ui_scale_pref = ui_scale_parse(val)
		case "bg_mode":
			bg_mode = clamp(val, 0, 4)
		case "bg_custom":
			bg_custom = Color{u8(val >> 16), u8(val >> 8), u8(val), 255}
		case "pixel_grid":
			opts.pixel_grid = val != 0
		case "sym_guides":
			opts.sym_guides = val != 0
		case "show_checks":
			opts.show_checks = val != 0
		case "timeline": // from before the bottom panel had a file browser
			bottom_mode = val != 0 ? .Animation : .Hidden
		case "preview":
			show_preview = val != 0
		case "grid_w":
			opts.grid_w = clamp(val, 1, 1024)
		case "grid_h":
			opts.grid_h = clamp(val, 1, 1024)
		case "brush_size":
			opts.brush_size = clamp(val, 1, 64)
		case "pixel_perfect":
			opts.pixel_perf = val != 0
		case "onion_prev":
			opts.onion_prev = clamp(val, 0, 1)
		case "onion_next":
			opts.onion_next = clamp(val, 0, 1)
		case "onion_alpha":
			opts.onion_alpha = clamp(val, 5, 100)
		case "snap":
			opts.snap = val != 0
		}
	}
}
