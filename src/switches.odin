package pangolin

import oui "odinui:odinui"

// ---------------------------------------------------------------------------
// Switches: Grid, Symmetry, Tiled Mode and Onion Skin are `Tool` values so they can sit in tool
// groups next to the tools. Clicking one turns it on or off instead of becoming the active tool,
// and while it is on, its settings can take over the options bar.
// ---------------------------------------------------------------------------

tool_is_toggle :: proc(t: Tool) -> bool {
	return t >= .Grid
}

tool_toggle_on :: proc(t: Tool) -> bool {
	#partial switch t {
	case .Grid:
		return opts.grid
	case .Symmetry:
		return opts.sym_x || opts.sym_y
	case .Tiling:
		return opts.tile != .Off
	case .Onion:
		return opts.onion
	}
	return false
}

// What Symmetry and Tiled Mode come back as when they are turned on again.
sym_last := [2]bool{true, false}
tile_last := Tile_Mode.Both

// Turns a switch on or off, keeping the options bar in step.
switch_set :: proc(t: Tool, on: bool) {
	#partial switch t {
	case .Grid:
		opts.grid = on
	case .Symmetry:
		if on {
			if !opts.sym_x && !opts.sym_y do opts.sym_x, opts.sym_y = sym_last[0], sym_last[1]
		} else if opts.sym_x || opts.sym_y {
			sym_last = {opts.sym_x, opts.sym_y}
			opts.sym_x, opts.sym_y = false, false
		}
	case .Tiling:
		if on {
			if opts.tile == .Off do opts.tile = tile_last
		} else if opts.tile != .Off {
			tile_last = opts.tile
			opts.tile = .Off
		}
	case .Onion:
		opts.onion = on
		doc.comp_dirty = true
	}
	switch_changed(t)
}

// The options bar shows the last thing picked: a tool, or one of the switches.
options_switch: Tool // the switch whose settings are shown while options_switch_on
options_switch_on: bool

options_show_tool :: proc() {
	options_switch_on = false
}

// Clicking a switch: off -> on (showing its settings); on but not shown -> show its settings;
// on and shown -> off (the tool's settings come back).
tool_toggle :: proc(t: Tool) {
	if tool_toggle_on(t) && !(options_switch_on && options_switch == t) {
		options_switch, options_switch_on = t, true
		return
	}
	switch_set(t, !tool_toggle_on(t))
}

// Keeps the options bar in step with a switch turned on or off from anywhere (menu, shortcut, bar).
switch_changed :: proc(t: Tool) {
	if tool_toggle_on(t) {
		options_switch, options_switch_on = t, true
	} else if options_switch == t {
		options_switch_on = false
	}
}

// Settings of the switch shown in the options bar; false if a tool's settings should show instead.
options_switch_ui :: proc() -> bool {
	if !options_switch_on || !tool_toggle_on(options_switch) {
		return false
	}
	t := options_switch
	oicon("icon", TOOL_ICONS[t], "switch-icon")
	#partial switch t {
	case .Grid:
		otext("title", "Grid", "switch-title")
		oslider("W", 70, &opts.grid_w, 1, 256, "Grid cell width", "px", 2)
		oslider("H", 70, &opts.grid_h, 1, 256, "Grid cell height", "px", 2)
		oslider("X", 64, &opts.grid_ox, 0, max(opts.grid_w - 1, 0), "Grid offset from the left edge", "px")
		oslider("Y", 64, &opts.grid_oy, 0, max(opts.grid_h - 1, 0), "Grid offset from the top edge", "px")
		ocheck("Snap", &opts.snap, "Selections, shapes and moves snap to the grid while it is shown (Ctrl+Shift+;)")
		if obutton("Grid Off", 60, "Hide the grid (Ctrl+')") do switch_set(.Grid, false)
	case .Symmetry:
		otext("title", "Symmetry", "switch-title")
		if c, _ := oui_icon_button("sym-x-opt", .Sym_X, "Mirror left / right (Shift+X)", {lit = opts.sym_x, enabled = true}); c {
			opts.sym_x = !opts.sym_x
		}
		if c, _ := oui_icon_button("sym-y-opt", .Sym_Y, "Mirror top / bottom (Shift+Y)", {lit = opts.sym_y, enabled = true}); c {
			opts.sym_y = !opts.sym_y
		}
		ocheck("Guides", &opts.sym_guides, "Show the mirror lines on the canvas")
		if obutton("Symmetry Off", 84, "Stop mirroring") do switch_set(.Symmetry, false)
	case .Tiling:
		otext("title", "Tiled Mode", "switch-title")
		modes := [?]Tile_Mode{.X, .Y, .Both}
		labels := [?]string{"X", "Y", "X+Y"}
		oui.element(uictx, "tile-mode", "button-group")
		for m, i in modes {
			if obutton(labels[i], 30, "Repeat the sprite around the canvas; drawing wraps across the edges", true, opts.tile == m) {
				opts.tile = m
			}
		}
		oui.end(uictx)
		if obutton("Tiling Off", 66, "Stop tiling (Shift+T cycles)") do switch_set(.Tiling, false)
	case .Onion:
		otext("title", "Onion Skin", "switch-title")
		before, after := opts.onion_prev > 0, opts.onion_next > 0
		ch1 := ocheck("Previous", &before, "Show the previous frame in red")
		ch2 := ocheck("Next", &after, "Show the next frame in blue")
		if ch1 || ch2 {
			opts.onion_prev, opts.onion_next = before ? 1 : 0, after ? 1 : 0
			doc.comp_dirty = true
		}
		oslider("Opacity", 90, &opts.onion_alpha, 5, 100, "How strongly the neighbouring frames show", "%")
		if obutton("Onion Off", 64, "Hide the neighbouring frames (Alt+O)") do switch_set(.Onion, false)
	}
	return true
}
