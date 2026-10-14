package pangolin

import "core:fmt"
import "core:strings"

// Open documents and the active one.
docs: [dynamic]^Doc
doc: ^Doc

cur_tool: Tool = .Pencil
prev_tool: Tool = .Pencil

fg: Color = {0, 0, 0, 255}
bg: Color = {255, 255, 255, 255}
// HSV of the foreground colour (kept separately so hue survives grey colours).
fg_h, fg_s, fg_v: f32

opts := Options {
	brush_size  = 1,
	pixel_perf  = false,
	tolerance   = 0,
	contiguous  = true,
	spray_dens  = 30,
	onion_prev  = 1,
	onion_next  = 0,
	pixel_grid  = true,
	grid_w      = 16,
	grid_h      = 16,
	show_checks = true,
	sym_guides  = true,
	ink         = .Normal,
	pattern     = .Solid,
}

// Status bar message
status_msg: Name
status_t: f32

// Playback
playing: bool
play_timer: f32
play_dir: int = 1
play_tag: int = -1 // -1 = whole animation

// UI toggles
show_timeline := true
show_preview := true
preview_zoom := 0 // 0 = auto
bg_mode := 0 // canvas background: 0 checker, 1 black, 2 white, 3 gray, 4 custom colour
bg_custom := Color{40, 40, 56, 255}

// Internal clipboard (RGBA region + mask)
Clip :: struct {
	w, h: int,
	x, y: int, // original position
	pix:  []Color,
}
clip: Clip

want_quit: bool

set_status :: proc(s: string) {
	name_set(&status_msg, s)
	status_t = 4
}

set_statusf :: proc(format: string, args: ..any) {
	set_status(fmt.tprintf(format, ..args))
}

set_fg :: proc(c: Color) {
	fg = c
	h, s, v := rgb_to_hsv(c)
	if s > 0.001 && v > 0.001 {
		fg_h = h
	}
	fg_s, fg_v = s, v
}

set_fg_hsv :: proc(h, s, v: f32, a: u8) {
	fg_h, fg_s, fg_v = h, s, v
	fg = hsv_to_rgb(h, s, v, a)
}

doc_title :: proc(d: ^Doc) -> string {
	return name_str(&d.title)
}

add_doc :: proc(d: ^Doc) {
	append(&docs, d)
	doc = d
	stop_playback()
	doc_fit_view_next(d)
}

doc_fit_view_next :: proc(d: ^Doc) {
	d.view_init = false
}

switch_doc :: proc(i: int) {
	if i >= 0 && i < len(docs) {
		curve_commit()
		doc = docs[i]
		stop_playback()
		doc.comp_dirty = true
	}
}

doc_index :: proc(d: ^Doc) -> int {
	for x, i in docs {
		if x == d {
			return i
		}
	}
	return -1
}

close_doc :: proc(d: ^Doc) {
	curve_commit()
	i := doc_index(d)
	if i < 0 {
		return
	}
	ordered_remove(&docs, i)
	doc_destroy(d)
	if len(docs) == 0 {
		nd := doc_new(64, 64)
		append(&docs, nd)
		doc = nd
	} else {
		doc = docs[clamp(i, 0, len(docs) - 1)]
	}
	doc.comp_dirty = true
	doc.view_init = false
	stop_playback()
}

set_frame :: proc(f: int) {
	nf := clamp(f, 0, len(doc.frames) - 1)
	if nf != doc.active_frame {
		curve_commit()
		doc.active_frame = nf
		doc.comp_dirty = true
	}
}

stop_playback :: proc() {
	playing = false
	play_timer = 0
	play_dir = 1
}

// Range of frames used for playback.
play_range :: proc() -> (lo, hi: int, dir: Tag_Dir) {
	lo, hi = 0, len(doc.frames) - 1
	dir = .Forward
	if play_tag >= 0 && play_tag < len(doc.tags) {
		t := doc.tags[play_tag]
		lo = clamp(t.from, 0, len(doc.frames) - 1)
		hi = clamp(t.to, lo, len(doc.frames) - 1)
		dir = t.dir
	}
	return
}

playback_update :: proc(dt: f32) {
	if !playing {
		return
	}
	lo, hi, dir := play_range()
	if lo == hi {
		set_frame(lo)
		return
	}
	play_timer += dt
	for {
		dur := f32(max(doc.frames[doc.active_frame].duration, 10)) / 1000
		if play_timer < dur {
			break
		}
		play_timer -= dur
		f := doc.active_frame
		if f < lo || f > hi {
			f = dir == .Reverse ? hi : lo
			set_frame(f)
			continue
		}
		switch dir {
		case .Forward:
			f += 1
			if f > hi {
				f = lo
			}
		case .Reverse:
			f -= 1
			if f < lo {
				f = hi
			}
		case .Ping_Pong:
			f += play_dir
			if f > hi {
				play_dir = -1
				f = hi - 1
			} else if f < lo {
				play_dir = 1
				f = lo + 1
			}
		}
		set_frame(f)
	}
}

// Display name with modified marker.
doc_display_name :: proc(d: ^Doc) -> string {
	return fmt.tprintf("%s%s", name_str(&d.title), d.modified ? "*" : "")
}

path_basename :: proc(p: string) -> string {
	i := strings.last_index_any(p, "/\\")
	if i >= 0 {
		return p[i + 1:]
	}
	return p
}

path_stem :: proc(p: string) -> string {
	b := path_basename(p)
	i := strings.last_index_byte(b, '.')
	if i > 0 {
		return b[:i]
	}
	return b
}

path_ext :: proc(p: string) -> string {
	b := path_basename(p)
	i := strings.last_index_byte(b, '.')
	if i >= 0 {
		return b[i:]
	}
	return ""
}

path_dir :: proc(p: string) -> string {
	i := strings.last_index_any(p, "/\\")
	if i >= 0 {
		return p[:i]
	}
	return ""
}
