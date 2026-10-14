package pangolin

import "core:fmt"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

// Tiny key=value preferences file stored next to the executable.

prefs_path :: proc() -> string {
	return fmt.tprintf("%spangolin.cfg", string(rl.GetApplicationDirectory()))
}

// Settings file used before the app was renamed; read once if the new one does not exist.
prefs_legacy_path :: proc() -> string {
	return fmt.tprintf("%spixel.cfg", string(rl.GetApplicationDirectory()))
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
	fmt.sbprintf(&sb, "timeline=%d\n", b2i(show_timeline))
	fmt.sbprintf(&sb, "preview=%d\n", b2i(show_preview))
	fmt.sbprintf(&sb, "grid_w=%d\n", opts.grid_w)
	fmt.sbprintf(&sb, "grid_h=%d\n", opts.grid_h)
	fmt.sbprintf(&sb, "brush_size=%d\n", opts.brush_size)
	fmt.sbprintf(&sb, "pixel_perfect=%d\n", b2i(opts.pixel_perf))
	write_file(prefs_path(), transmute([]u8)strings.to_string(sb))
}

prefs_load :: proc() {
	path := prefs_path()
	if !rl.FileExists(strings.clone_to_cstring(path, context.temp_allocator)) {
		path = prefs_legacy_path()
		if !rl.FileExists(strings.clone_to_cstring(path, context.temp_allocator)) {
			return
		}
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
		val, vok := strconv.parse_int(strings.trim_space(line[eq + 1:]))
		if !vok {
			continue
		}
		switch key {
		case "ui_scale":
			ui_scale_pref = clamp(val, 0, 4)
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
		case "timeline":
			show_timeline = val != 0
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
		}
	}
}
