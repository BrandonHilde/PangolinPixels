package pangolin

import "core:fmt"
import "core:strconv"
import "core:strings"

// User-editable tool groups shown in the left panel. A group's hotkey selects its first tool
// (or the one last used from it); pressing it again cycles through the group's tools.
// A group holding colours instead of tools is a colour group: its hotkey cycles the
// foreground colour and leaves the tool alone. A pattern group's hotkey cycles the dither
// pattern the same way. Switches (Grid, Symmetry, ...) sit among the tools and flip on and off.

MAX_TOOL_GROUPS :: 12
MAX_GROUP_COLORS :: 64

// The brush settings a group can keep for itself.
Brush_Opts :: struct {
	size:       int,
	round:      bool,
	pixel_perf: bool,
	fill:       bool,
	pattern:    Pattern,
	ink:        Ink,
	spray_dens: int,
}

Tool_Group :: struct {
	key:      KeyboardKey, // KEY_NULL: no hotkey
	tools:    [dynamic]Tool,
	colors:   [dynamic]Color,
	patterns: [dynamic]Pattern,
	last:     Tool, // last tool picked from this group
	name:     Name, // empty: "Group"
	// with `own`, the group keeps its own brush settings: they are loaded while one of its tools is
	// in use, and the other groups share theirs (`shared_brush`)
	own:      bool,
	brush:    Brush_Opts,
}

tool_groups: [dynamic]Tool_Group
active_group := -1 // group the active tool was last picked from, or -1
group_key_wait := -1 // group waiting for a hotkey press, or -1
shared_brush: Brush_Opts // settings of the groups without their own, kept here while an own-settings group is active

brush_get :: proc() -> Brush_Opts {
	return {opts.brush_size, opts.brush_round, opts.pixel_perf, opts.fill_shape, opts.pattern, opts.ink, opts.spray_dens}
}

brush_put :: proc(b: Brush_Opts) {
	opts.brush_size = clamp(b.size, 1, 64)
	opts.brush_round, opts.pixel_perf, opts.fill_shape = b.round, b.pixel_perf, b.fill
	opts.pattern, opts.ink = b.pattern, b.ink
	opts.spray_dens = clamp(b.spray_dens, 1, 100)
}

group_owns :: proc(gi: int) -> bool {
	return gi >= 0 && gi < len(tool_groups) && tool_groups[gi].own
}

// Stores the live brush settings where they belong: the active group's own, or the shared ones.
brush_sync :: proc() {
	if group_owns(active_group) {
		tool_groups[active_group].brush = brush_get()
	} else {
		shared_brush = brush_get()
	}
}

// Makes `gi` (or no group, -1) the active group, swapping brush settings when either keeps its own.
group_enter :: proc(gi: int) {
	if gi == active_group do return
	brush_sync()
	was_own := group_owns(active_group)
	active_group = gi
	if group_owns(gi) {
		brush_put(tool_groups[gi].brush)
	} else if was_own {
		brush_put(shared_brush)
	}
}

// Turns a group's own brush settings on (starting from the live ones) or off.
group_set_own :: proc(gi: int, on: bool) {
	g := &tool_groups[gi]
	if g.own == on do return
	brush_sync()
	if gi == active_group {
		if on {
			g.brush = brush_get()
		} else {
			brush_put(shared_brush)
		}
	} else if on {
		g.brush = shared_brush
	}
	g.own = on
}

// Group the active tool belongs to: the active group if it holds the tool, else the first that does.
current_group :: proc() -> int {
	if active_group >= 0 && active_group < len(tool_groups) && tool_group_has(&tool_groups[active_group], cur_tool) {
		return active_group
	}
	for &g, i in tool_groups {
		if tool_group_has(&g, cur_tool) do return i
	}
	return -1
}

// Picks `t` as a member of group `gi`; without a group, keeps the active group if it holds `t`.
select_tool_in_group :: proc(t: Tool, gi := -1) {
	if tool_is_toggle(t) {
		tool_toggle(t)
		return
	}
	if gi >= 0 {
		group_enter(gi)
	} else if active_group < 0 || active_group >= len(tool_groups) || !tool_group_has(&tool_groups[active_group], t) {
		found := -1
		for &g, i in tool_groups {
			if tool_group_has(&g, t) {
				found = i
				break
			}
		}
		group_enter(found)
	}
	select_tool(t)
}

group_title :: proc(g: ^Tool_Group) -> string {
	if g.name.n > 0 {
		return name_str(&g.name)
	}
	return "Group"
}

// Group names go into the preferences and workspace files, whose fields are split on : and ;
group_clean_name :: proc(s: string) -> string {
	sb := strings.builder_make(context.temp_allocator)
	for r in strings.trim_space(s) {
		if r != ':' && r != ';' && r >= ' ' do strings.write_rune(&sb, r)
	}
	return strings.trim_space(strings.to_string(sb))
}

@(private = "file")
tool_group_free :: proc(g: ^Tool_Group) {
	delete(g.tools)
	delete(g.colors)
	delete(g.patterns)
}

// Removes group `gi`; the live brush settings go back to the shared ones if it kept its own.
tool_group_remove :: proc(gi: int) {
	group_enter(-1)
	color_link_clear()
	group_key_wait = -1
	tool_group_free(&tool_groups[gi])
	ordered_remove(&tool_groups, gi)
}

tool_groups_clear :: proc() {
	group_enter(-1)
	color_link_clear()
	for &g in tool_groups {
		tool_group_free(&g)
	}
	clear(&tool_groups)
}

@(private = "file")
group_add :: proc(key: KeyboardKey, name: string, tools: ..Tool) {
	g := Tool_Group {
		key  = key,
		last = tools[0],
	}
	name_set(&g.name, name)
	append(&g.tools, ..tools)
	append(&tool_groups, g)
}

tool_groups_default :: proc() {
	tool_groups_clear()
	group_add(.ONE, "Draw", .Pencil, .Eraser, .Spray, .Bucket, .Picker)
	group_add(.TWO, "Shapes", .Line, .Rect, .Ellipse, .Curve)
	group_add(.THREE, "Select", .Select_Rect, .Select_Ellipse, .Lasso, .Wand)
	group_add(.FOUR, "View", .Move, .Hand, .Zoom, .Grid, .Onion)
}

tool_group_activate :: proc(gi: int) {
	g := &tool_groups[gi]
	if len(g.colors) > 0 {
		next := 0
		if color_link_g == gi {
			next = (color_link_i + 1) % len(g.colors)
		} else {
			for c, i in g.colors {
				if c.r == fg.r && c.g == fg.g && c.b == fg.b {
					next = (i + 1) % len(g.colors)
					break
				}
			}
		}
		color_link_set(gi, next)
		return
	}
	if len(g.patterns) == 1 {
		// a lone pattern toggles on and off
		opts.pattern = opts.pattern == g.patterns[0] ? .Solid : g.patterns[0]
		set_statusf("Pattern: %s", PATTERN_NAMES[opts.pattern])
		return
	}
	if len(g.patterns) > 0 {
		next := 0
		for p, i in g.patterns {
			if p == opts.pattern {
				next = (i + 1) % len(g.patterns)
				break
			}
		}
		opts.pattern = g.patterns[next]
		set_statusf("Pattern: %s", PATTERN_NAMES[opts.pattern])
		return
	}
	// the hotkey cycles through the real tools; a group of only switches flips its first one
	tools := make([dynamic]Tool, context.temp_allocator)
	for t in g.tools do if !tool_is_toggle(t) do append(&tools, t)
	n := len(tools)
	if n == 0 {
		if len(g.tools) > 0 do tool_toggle(g.tools[0])
		return
	}
	// pressing the hotkey again moves on to the group's next tool
	for t, i in tools {
		if t == cur_tool && current_group() == gi {
			g.last = tools[(i + 1) % n]
			select_tool_in_group(g.last, gi)
			return
		}
	}
	pick := tools[0]
	for t in tools {
		if t == g.last do pick = t
	}
	g.last = pick
	select_tool_in_group(pick, gi)
}

// Runs the hotkeys of all groups; returns true if one was handled.
tool_groups_hotkeys :: proc() -> bool {
	if ui.ctrl || ui.alt || ui.shift {
		return false
	}
	for &g, i in tool_groups {
		if g.key != .KEY_NULL && IsKeyPressed(g.key) {
			tool_group_activate(i)
			return true
		}
	}
	return false
}

// While a group is waiting for a hotkey, swallows the next key press. Returns true while waiting.
tool_groups_key_capture :: proc() -> bool {
	if group_key_wait < 0 {
		return false
	}
	if group_key_wait >= len(tool_groups) || IsKeyPressed(.ESCAPE) {
		group_key_wait = -1
		return true
	}
	assign :: proc(k: KeyboardKey) {
		for &o in tool_groups {
			if o.key == k do o.key = .KEY_NULL
		}
		tool_groups[group_key_wait].key = k
		group_key_wait = -1
	}
	if IsKeyPressed(.BACKSPACE) || IsKeyPressed(.DELETE) {
		assign(.KEY_NULL)
		return true
	}
	for i in 0 ..< 128 {
		if group_hotkey_valid(i) && IsKeyPressed(KeyboardKey(i)) {
			assign(KeyboardKey(i))
			return true
		}
	}
	return true
}

// Group hotkeys are digits and letters.
group_hotkey_valid :: proc(k: int) -> bool {
	return (k >= 48 && k <= 57) || (k >= 65 && k <= 90)
}

tool_group_has :: proc(g: ^Tool_Group, t: Tool) -> bool {
	for x in g.tools {
		if x == t do return true
	}
	return false
}

pattern_in :: proc(list: []Pattern, p: Pattern) -> bool {
	for x in list {
		if x == p do return true
	}
	return false
}

// Preferences and workspaces: groups separated by ;, each "<key>:<tools>:<colours>:<patterns>:<name>:<brush>"
// with tools and patterns as enum indices, colours as hex, and <brush> the group's own settings
// (size,round,pixel-perfect,fill,pattern,ink,density) or empty.
tool_groups_serialize :: proc() -> string {
	brush_sync()
	sb := strings.builder_make(context.temp_allocator)
	for &g, i in tool_groups {
		fmt.sbprintf(&sb, "%s%d:", i > 0 ? ";" : "", int(g.key))
		for t, j in g.tools {
			fmt.sbprintf(&sb, "%s%d", j > 0 ? "," : "", int(t))
		}
		fmt.sbprintf(&sb, ":")
		for c, j in g.colors {
			fmt.sbprintf(&sb, "%s%s", j > 0 ? "," : "", color_hex(c))
		}
		fmt.sbprintf(&sb, ":")
		for p, j in g.patterns {
			fmt.sbprintf(&sb, "%s%d", j > 0 ? "," : "", int(p))
		}
		fmt.sbprintf(&sb, ":%s:", name_str(&g.name))
		if g.own {
			b := g.brush
			fmt.sbprintf(&sb, "%d,%d,%d,%d,%d,%d,%d", b.size, int(b.round), int(b.pixel_perf), int(b.fill), int(b.pattern), int(b.ink), b.spray_dens)
		}
	}
	return strings.to_string(sb)
}

tool_groups_parse :: proc(s: string) {
	tool_groups_clear()
	for part in strings.split(s, ";", context.temp_allocator) {
		fields := strings.split(part, ":", context.temp_allocator)
		if len(fields) < 2 || len(tool_groups) >= MAX_TOOL_GROUPS {
			continue
		}
		k, _ := strconv.parse_int(fields[0])
		g: Tool_Group
		if group_hotkey_valid(k) {
			g.key = KeyboardKey(k)
		}
		for ts in strings.split(fields[1], ",", context.temp_allocator) {
			ti, ok := strconv.parse_int(ts)
			if ok && ti >= 0 && ti < len(Tool) && !tool_group_has(&g, Tool(ti)) {
				append(&g.tools, Tool(ti))
			}
		}
		if len(fields) > 2 && len(g.tools) == 0 {
			for cs in strings.split(fields[2], ",", context.temp_allocator) {
				if c, ok := parse_hex(cs); ok && len(g.colors) < MAX_GROUP_COLORS {
					append(&g.colors, Color{c.r, c.g, c.b, 255})
				}
			}
		}
		if len(fields) > 3 && len(g.tools) == 0 && len(g.colors) == 0 {
			for ps in strings.split(fields[3], ",", context.temp_allocator) {
				pi, ok := strconv.parse_int(ps)
				if ok && pi >= 0 && pi < len(Pattern) && !pattern_in(g.patterns[:], Pattern(pi)) {
					append(&g.patterns, Pattern(pi))
				}
			}
		}
		if len(fields) > 4 do name_set(&g.name, group_clean_name(fields[4]))
		if len(fields) > 5 && fields[5] != "" {
			v := [7]int{1, 0, 0, 0, 0, 0, 30}
			for ns, j in strings.split(fields[5], ",", context.temp_allocator) {
				if j < len(v) do v[j], _ = strconv.parse_int(ns)
			}
			g.own = true
			g.brush = {
				size       = clamp(v[0], 1, 64),
				round      = v[1] != 0,
				pixel_perf = v[2] != 0,
				fill       = v[3] != 0,
				pattern    = Pattern(clamp(v[4], 0, len(Pattern) - 1)),
				ink        = Ink(clamp(v[5], 0, len(Ink) - 1)),
				spray_dens = clamp(v[6], 1, 100),
			}
		}
		for t in g.tools {
			if !tool_is_toggle(t) {
				g.last = t
				break
			}
		}
		append(&tool_groups, g)
	}
}

// ---------------------------------------------------------------------------
// Hotkey badge, canvas-mode bar and rename dialog
// ---------------------------------------------------------------------------

// Keyboard-key look for hotkey badges, so they read differently from the tool buttons.
keycap :: proc(r: Rect, label: string, lit, hover: bool) {
	fill := lit ? C_ACTIVE : (hover ? shade(C_HOVER, 1.15) : shade(C_PANEL_LT, 1.18))
	face := Rect{r.x, r.y, r.w, r.h - 2}
	draw_rrect(f32(r.x), f32(r.y + 2), f32(r.w), f32(r.h - 2), RADIUS, C_BORDER) // the key's lower edge
	draw_rrect(f32(face.x), f32(face.y), f32(face.w), f32(face.h), RADIUS, fill)
	draw_rrect_outline(f32(face.x), f32(face.y), f32(face.w), f32(face.h), RADIUS, C_RING_HI)
	text_centered(face, label, label == "-" ? C_TEXT_OFF : (lit ? WHITE : C_TEXT))
}

keycap_w :: proc(label: string) -> i32 {
	return max(18, text_w(label) + 10)
}

// Shown in canvas mode in place of the side panels: every group as `[key] -> current tool`,
// with the group that holds the active tool highlighted.
panel_groups_bar :: proc(r: Rect) {
	ui.layer = 0
	fill_rect(r, C_PANEL_DK)
	hline(r.x, r.y, r.w, C_BORDER)
	ty := r.y + (r.h - FONT_CAP) / 2
	x := r.x + 10
	text(x, ty, "Groups:", C_TEXT_DIM)
	x += text_w("Groups:") + 10
	limit := r.x + r.w - 10
	if status_t > 0 {
		msg := name_str(&status_msg)
		limit -= text_w(msg) + 16
		text(r.x + r.w - 10 - text_w(msg), ty, msg, C_ACCENT)
	}
	ARROW :: "->"
	for &g, gi in tool_groups {
		shown: Tool
		shown_color: Color
		shown_pattern: Pattern
		active := false
		kind := 0 // 1 tool, 2 colour, 3 pattern
		switch {
		case len(g.tools) > 0:
			kind = 1
			if current_group() == gi {
				shown, active = cur_tool, true
			} else if tool_group_has(&g, g.last) && !tool_is_toggle(g.last) {
				shown = g.last
			} else {
				// a group of only switches shows its first one, lit while it is on
				shown = g.tools[0]
				active = tool_is_toggle(shown) && tool_toggle_on(shown)
			}
		case len(g.colors) > 0:
			kind = 2
			shown_color = g.colors[0]
			for c in g.colors {
				if c.r == fg.r && c.g == fg.g && c.b == fg.b {
					shown_color, active = c, true
				}
			}
		case len(g.patterns) > 0:
			kind = 3
			shown_pattern = pattern_in(g.patterns[:], opts.pattern) ? opts.pattern : g.patterns[0]
			active = shown_pattern == opts.pattern
		}
		if kind == 0 do continue

		title := group_title(&g)
		key := g.key == .KEY_NULL ? "" : key_name(g.key)
		// label: the hotkey as a keycap, or the group's name when it has none
		label_w := key == "" ? text_w(title) : keycap_w(key)
		target_w: i32 = kind == 3 ? text_w(PATTERN_NAMES[shown_pattern]) + 4 : 18
		cw := 8 + label_w + 6 + text_w(ARROW) + 6 + target_w + 8
		if x + cw > limit do break
		cell := Rect{x, r.y + 3, cw, r.h - 6}
		tip := key == "" ? title : fmt.tprintf("%s (%s)", title, key)
		clicked, _, hover := button_behavior(make_id(cell, "grpcell"), cell, tip)
		if active {
			draw_rrect(f32(cell.x), f32(cell.y), f32(cell.w), f32(cell.h), RADIUS, C_ACCENT_TINT)
			draw_rrect_outline(f32(cell.x), f32(cell.y), f32(cell.w), f32(cell.h), RADIUS, with_alpha(C_ACCENT, 150))
		} else {
			draw_rrect(f32(cell.x), f32(cell.y), f32(cell.w), f32(cell.h), RADIUS, hover ? C_HOVER : C_PANEL)
			draw_rrect_outline(f32(cell.x), f32(cell.y), f32(cell.w), f32(cell.h), RADIUS, C_RING)
		}
		lx := cell.x + 8
		if key == "" {
			text(lx, ty, title, C_TEXT_DIM)
		} else {
			keycap(Rect{lx, cell.y + 2, label_w, cell.h - 4}, key, active, hover)
		}
		lx += label_w + 6
		text(lx, ty, ARROW, C_TEXT_DIM)
		lx += text_w(ARROW) + 6
		fgc := active ? C_ACCENT : C_TEXT
		switch kind {
		case 1:
			icon_centered(TOOL_ICONS[shown], Rect{lx, cell.y, 18, cell.h}, fgc)
		case 2:
			sw := Rect{lx + 1, cell.y + 4, 16, cell.h - 8}
			draw_rrect(f32(sw.x), f32(sw.y), f32(sw.w), f32(sw.h), 2, shown_color)
			draw_rrect_outline(f32(sw.x), f32(sw.y), f32(sw.w), f32(sw.h), 2, active ? WHITE : C_RING_HI)
		case 3:
			text(lx + 2, ty, PATTERN_NAMES[shown_pattern], fgc)
		}
		if clicked do tool_group_activate(gi)
		x += cw + 6
	}
}

dlg_group_rename :: proc() {
	c := dialog_frame("Rename Group", 280, 84)
	if dialog.a < 0 || dialog.a >= len(tool_groups) {
		dialog_close()
		return
	}
	text(c.x, c.y + 3, "Name", C_TEXT)
	text_field(Rect{c.x + 50, c.y, c.w - 50, 14}, &dialog.name, "Leave empty for the default name")
	ok, cancel := dialog_buttons(c)
	if cancel {
		dialog_close()
	}
	if ok {
		name_set(&tool_groups[dialog.a].name, group_clean_name(name_str(&dialog.name)))
		dialog_close()
	}
}

group_rename_open :: proc(gi: int) {
	dialog_open(.Group_Rename)
	dialog.a = gi
	dialog.name = tool_groups[gi].name
}
