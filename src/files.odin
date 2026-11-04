package pangolin

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strings"
import "core:sync"
import "core:thread"
import sdl "vendor:sdl3"

import oui "odinui:odinui"

// ---------------------------------------------------------------------------
// The bottom panel's switch (animation / files / hidden) and the file browser: thumbnails of the
// images in a folder, which can be dragged onto the canvas or the tab bar.
// ---------------------------------------------------------------------------

Bottom_Mode :: enum {
	Animation,
	Hidden,
	Files,
}

bottom_mode := Bottom_Mode.Animation

bottom_mode_set :: proc(m: Bottom_Mode) {
	if m == bottom_mode do return
	bottom_mode = m
	// look at the folder again whenever the browser comes back
	if m == .Files do files_scanned = false
}

// Stays on the bar when the panel is hidden, so it can always be brought back.
bottom_mode_switch :: proc() {
	Item :: struct {
		key:  string,
		mode: Bottom_Mode,
		ic:   Icon,
		tip:  string,
	}
	items := [?]Item {
		{"mode-anim", .Animation, .Film, "Show the animation timeline"},
		{"mode-files", .Files, .Folder, "Show the file browser"},
		{"mode-hide", .Hidden, .Eye_Off, "Hide this panel"},
	}
	oui.element(uictx, "bottom-mode", "button-group", {id = "bottom-mode"})
	defer oui.end(uictx)
	for it in items {
		if c, _ := oui_icon_button(it.key, it.ic, it.tip, {class = "tl-btn", lit = bottom_mode == it.mode, enabled = true}); c {
			bottom_mode_set(it.mode)
		}
	}
}

// ---------------------------------------------------------------------------
// The folder and what is in it
// ---------------------------------------------------------------------------

Thumb_State :: enum {
	None,
	Queued,
	Ready,
	Failed,
}

File_Entry :: struct {
	name, path:   string,
	is_dir:       bool,
	thumb_state:  Thumb_State,
	thumb:        Texture,
	img_w, img_h: int, // the image's own size; the thumbnail may be smaller
}

files_dir: string // "" = no folder open
files: [dynamic]File_Entry
files_scanned: bool
files_gen: int // changes with the list, so late thumbnails of an old one are dropped
files_sel := -1
files_scroll: i32

files_listed :: proc(name: string) -> bool {
	switch lower_ext(name) {
	case ".png", ".jpg", ".jpeg", ".jfif", ".bmp", ".tga", ".gif", ".qoi", ".pxl":
		return true
	}
	return false
}

files_clear :: proc() {
	for &e in files {
		tex_destroy(&e.thumb)
		delete(e.name)
		delete(e.path)
	}
	clear(&files)
	thumb_cancel_all()
	files_gen += 1
	files_sel = -1
	files_scroll = 0
	files_drag = {idx = -1}
}

// Reads the folder again. Folders come first, then files, ignoring case.
files_refresh :: proc() {
	files_clear()
	files_scanned = true
	if files_dir == "" do return
	infos, err := os.read_all_directory_by_path(files_dir, context.temp_allocator)
	if err != nil {
		set_statusf("Cannot read %s", files_dir)
		delete(files_dir)
		files_dir = ""
		return
	}
	for fi in infos {
		if strings.has_prefix(fi.name, ".") do continue
		is_dir := fi.type == .Directory || (fi.type == .Symlink && os.is_directory(fi.fullpath))
		if !is_dir && !files_listed(fi.name) do continue
		append(&files, File_Entry{name = strings.clone(fi.name), path = strings.clone(fi.fullpath), is_dir = is_dir})
	}
	slice.sort_by(files[:], proc(a, b: File_Entry) -> bool {
		if a.is_dir != b.is_dir do return a.is_dir
		return strings.to_lower(a.name, context.temp_allocator) < strings.to_lower(b.name, context.temp_allocator)
	})
}

files_set_dir :: proc(dir: string) {
	nd := strings.clone(dir) // `dir` may be the path of an entry, which the refresh frees
	delete(files_dir)
	files_dir = nd
	files_refresh()
}

// The folder above `dir`, or "" at the top.
files_parent :: proc(dir: string) -> string {
	d := strings.trim_right(dir, "/\\")
	i := strings.last_index_any(d, "/\\")
	if i < 0 do return ""
	if i == 0 do return d[:1]
	if i == 2 && d[1] == ':' do return d[:3]
	return d[:i]
}

// Runs each frame while the browser shows.
files_update :: proc() {
	sync.mutex_lock(&folder_mu)
	picked := folder_picked
	folder_picked = ""
	sync.mutex_unlock(&folder_mu)
	if picked != "" {
		files_set_dir(picked)
		delete(picked)
	} else if !files_scanned {
		files_refresh()
	}
}

// The system's folder picker runs on its own thread and answers through this mailbox.
@(private = "file")
folder_mu: sync.Mutex
@(private = "file")
folder_picked: string

files_pick_folder :: proc() {
	picked :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
		context = runtime.default_context()
		if filelist == nil || filelist[0] == nil do return // failed or cancelled
		sync.mutex_lock(&folder_mu)
		delete(folder_picked)
		folder_picked = strings.clone(string(filelist[0]))
		sync.mutex_unlock(&folder_mu)
	}
	start: cstring
	if files_dir != "" do start = strings.clone_to_cstring(files_dir, context.temp_allocator)
	sdl.ShowOpenFolderDialog(picked, nil, gfx.win, start, false)
}

// ---------------------------------------------------------------------------
// Thumbnails: one worker thread decodes them (a folder of photos must not stall the interface),
// the textures are made on the main thread.
// ---------------------------------------------------------------------------

THUMB_MAX :: 256 // longest side in pixels; smaller images are kept as they are, and stay crisp

@(private = "file")
Thumb_Job :: struct {
	gen, index: int,
	path:       string,
}

@(private = "file")
Thumb_Done :: struct {
	gen, index:         int,
	pix:                []Color,
	w, h, img_w, img_h: int,
	ok:                 bool,
}

@(private = "file")
thumb_mu: sync.Mutex // guards the two lists and the focus
@(private = "file")
thumb_focus: int // the first entry in view
@(private = "file")
thumb_jobs: [dynamic]Thumb_Job
@(private = "file")
thumb_done: [dynamic]Thumb_Done
@(private = "file")
thumb_wake: sync.Sema
@(private = "file")
thumb_thread: ^thread.Thread

// Box filter, weighting colours by alpha so transparent pixels do not darken the edges.
thumb_shrink :: proc(pix: []Color, w, h, max_side: int) -> (out: []Color, ow, oh: int) {
	ow = max(w * max_side / max(w, h), 1)
	oh = max(h * max_side / max(w, h), 1)
	out = make([]Color, ow * oh)
	for y in 0 ..< oh {
		y0, y1 := y * h / oh, max((y + 1) * h / oh, y * h / oh + 1)
		for x in 0 ..< ow {
			x0, x1 := x * w / ow, max((x + 1) * w / ow, x * w / ow + 1)
			r, g, b, a: u64
			for sy in y0 ..< y1 {
				for sx in x0 ..< x1 {
					s := pix[sy * w + sx]
					sa := u64(s.a)
					r += u64(s.r) * sa
					g += u64(s.g) * sa
					b += u64(s.b) * sa
					a += sa
				}
			}
			if a > 0 {
				n := u64((x1 - x0) * (y1 - y0))
				out[y * ow + x] = {u8(r / a), u8(g / a), u8(b / a), u8(a / n)}
			}
		}
	}
	return
}

// Loads a file's thumbnail: first frame of a project or GIF. Safe off the main thread.
thumb_load :: proc(path: string) -> (pix: []Color, w, h, img_w, img_h: int, ok: bool) {
	full: []Color
	if lower_ext(path) == ".pxl" {
		data, rok := read_file(path)
		if !rok do return
		defer delete(data)
		d, dok := project_decode(data)
		if !dok do return
		defer doc_destroy(d)
		doc_refresh_comp(d)
		full, img_w, img_h = slice.clone(d.comp), d.w, d.h
	} else {
		lok: bool
		full, img_w, img_h, lok = load_image_pixels(path)
		if !lok do return
	}
	if max(img_w, img_h) <= THUMB_MAX {
		return full, img_w, img_h, img_w, img_h, true
	}
	defer delete(full)
	pix, w, h = thumb_shrink(full, img_w, img_h, THUMB_MAX)
	return pix, w, h, img_w, img_h, true
}

// The job closest below the top of the view, so tiles fill in reading order and what was just
// scrolled to does not wait for what was scrolled past.
@(private = "file")
thumb_next_job :: proc() -> (job: Thumb_Job, ok: bool) {
	sync.mutex_lock(&thumb_mu)
	defer sync.mutex_unlock(&thumb_mu)
	best, best_key := -1, max(int)
	for j, i in thumb_jobs {
		d := j.index - thumb_focus
		key := d >= 0 ? d : len(files) - d
		if key < best_key do best, best_key = i, key
	}
	if best < 0 do return
	job, ok = thumb_jobs[best], true
	unordered_remove(&thumb_jobs, best)
	return
}

@(private = "file")
thumb_worker :: proc() {
	for {
		sync.sema_wait(&thumb_wake)
		job, have := thumb_next_job()
		if !have do continue
		r := Thumb_Done{gen = job.gen, index = job.index}
		r.pix, r.w, r.h, r.img_w, r.img_h, r.ok = thumb_load(job.path)
		delete(job.path)
		sync.mutex_lock(&thumb_mu)
		append(&thumb_done, r)
		sync.mutex_unlock(&thumb_mu)
		free_all(context.temp_allocator)
	}
}

@(private = "file")
thumb_request :: proc(index: int, path: string) {
	if thumb_thread == nil {
		thumb_thread = thread.create_and_start(thumb_worker)
	}
	sync.mutex_lock(&thumb_mu)
	append(&thumb_jobs, Thumb_Job{files_gen, index, strings.clone(path)})
	sync.mutex_unlock(&thumb_mu)
	sync.sema_post(&thumb_wake)
}

@(private = "file")
thumb_cancel_all :: proc() {
	sync.mutex_lock(&thumb_mu)
	for j in thumb_jobs do delete(j.path)
	clear(&thumb_jobs)
	sync.mutex_unlock(&thumb_mu)
}

// Turns finished thumbnails into textures, a few a frame.
@(private = "file")
thumb_collect :: proc() {
	batch: [8]Thumb_Done
	n := 0
	sync.mutex_lock(&thumb_mu)
	for n < len(batch) && len(thumb_done) > 0 {
		batch[n] = pop(&thumb_done)
		n += 1
	}
	sync.mutex_unlock(&thumb_mu)
	for r in batch[:n] {
		defer delete(r.pix)
		if r.gen != files_gen || r.index >= len(files) do continue
		e := &files[r.index]
		if !r.ok {
			e.thumb_state = .Failed
			continue
		}
		e.thumb = tex_from_pixels(r.pix, r.w, r.h, r.w == r.img_w ? .Point : .Linear)
		e.img_w, e.img_h = r.img_w, r.img_h
		e.thumb_state = .Ready
	}
}

// ---------------------------------------------------------------------------
// The panel
// ---------------------------------------------------------------------------

FILE_THUMB :: 72 // logical px
FILE_TILE_W :: 84
FILE_TILE_H :: 96
FILE_PAD :: 6

files_bar_controls :: proc() {
	if files_dir == "" do return
	if c, _ := oui_icon_button("files-change", .Folder, "Open another folder", {class = "tl-btn", enabled = true}); c {
		files_pick_folder()
	}
	parent := files_parent(files_dir)
	if c, _ := oui_icon_button("files-up", .Up, "Up one folder", {class = "tl-btn", enabled = parent != ""}); c {
		files_set_dir(parent)
	}
	if c, _ := oui_icon_button("files-refresh", .Refresh, "Read the folder again", {class = "tl-btn", enabled = true}); c {
		files_refresh()
	}
	// (checked again: going up can fail and close the folder)
	if files_dir != "" do oui.label(uictx, "files-path", files_dir, {id = "files-path"})
}

files_body :: proc() {
	if files_dir != "" {
		oui_slot("files-grid", "files_grid")
		return
	}
	oui.element(uictx, "files-empty", "column", {id = "files-empty"})
	defer oui.end(uictx)
	n := oui.button_begin(uictx, "files-open", {id = "files-open", class = "btn"})
	oicon("icon", .Folder)
	oui.label(uictx, "t", "Open Folder")
	oui.end(uictx)
	if n.clicked do files_pick_folder()
	oui.label(uictx, "hint", "Pick a folder of images, then drag them onto the canvas", {class = "dim"})
}

panel_files_grid :: proc(r: Rect) {
	thumb_collect()
	fill_rect(r, C_PANEL_DK)
	if len(files) == 0 {
		text_centered(r, "No images in this folder", C_TEXT_DIM)
		return
	}
	cols := max((r.w - FILE_PAD) / FILE_TILE_W, 1)
	rows := (i32(len(files)) + cols - 1) / cols
	max_scroll := max(rows * FILE_TILE_H + FILE_PAD - r.h, 0)
	if ui_hover(r) && ui.wheel != 0 {
		files_scroll -= i32(ui.wheel) * FILE_TILE_H / 2
	}
	files_scroll = clamp(files_scroll, 0, max_scroll)
	sync.mutex_lock(&thumb_mu)
	thumb_focus = int(files_scroll / FILE_TILE_H * cols)
	sync.mutex_unlock(&thumb_mu)

	open_idx := -1 // acted on after the loop: opening a folder replaces the list
	clip_begin(r)
	for &e, i in files {
		tile := Rect{r.x + FILE_PAD + i32(i) % cols * FILE_TILE_W, r.y + FILE_PAD + i32(i) / cols * FILE_TILE_H - files_scroll, FILE_TILE_W - 4, FILE_TILE_H - 4}
		if tile.y + tile.h < r.y || tile.y > r.y + r.h do continue
		if !e.is_dir && e.thumb_state == .None {
			e.thumb_state = .Queued
			thumb_request(i, e.path)
		}
		hover := ui_hover(r) && ui_hover(tile)
		if i == files_sel {
			draw_rrect(f32(tile.x), f32(tile.y), f32(tile.w), f32(tile.h), RADIUS, C_ACCENT_TINT)
			draw_rrect_outline(f32(tile.x), f32(tile.y), f32(tile.w), f32(tile.h), RADIUS, C_ACCENT)
		} else if hover {
			draw_rrect(f32(tile.x), f32(tile.y), f32(tile.w), f32(tile.h), RADIUS, Color{255, 255, 255, 12})
		}
		box := Rect{tile.x + (tile.w - FILE_THUMB) / 2, tile.y + 3, FILE_THUMB, FILE_THUMB}
		file_tile_picture(&e, box)
		label := Rect{tile.x + 3, box.y + box.h + 2, tile.w - 6, 14}
		tw := text_w(e.name)
		if tw < label.w do label.x += (label.w - tw) / 2
		text_clipped(label, e.name, i == files_sel ? C_TEXT : C_TEXT_DIM)
		if hover {
			tip := e.name
			if e.thumb_state == .Ready do tip = fmt.tprintf("%s   %d x %d", e.name, e.img_w, e.img_h)
			tooltip_hover(make_id({}, e.path), tip)
			if ui.pressed[0] {
				if ui.dbl_click && files_sel == i {
					open_idx = i
				} else if !e.is_dir {
					files_drag = {idx = i, x0 = ui.mx, y0 = ui.my}
				}
				files_sel = i
			}
		}
	}
	clip_end()
	// where the view is in the list; the wheel moves it
	if max_scroll > 0 {
		content := max_scroll + r.h
		th := max(r.h * r.h / content, 12)
		ty := r.y + files_scroll * (r.h - th) / max_scroll
		draw_rrect(f32(r.x + r.w - 4), f32(ty), 3, f32(th), 1, C_RING_HI)
	}
	if open_idx >= 0 {
		e := files[open_idx]
		if e.is_dir {
			files_set_dir(e.path)
		} else {
			open_path(e.path)
		}
	}
}

@(private = "file")
file_tile_picture :: proc(e: ^File_Entry, box: Rect) {
	switch {
	case e.is_dir:
		icon_centered(.Folder, box, C_ACCENT, 32)
	case e.thumb_state == .Failed:
		ctl_well(box)
		icon_centered(.Close, box, C_TEXT_OFF)
	case e.thumb_state == .Ready:
		z := min(f32(box.w) / f32(e.img_w), f32(box.h) / f32(e.img_h))
		if z >= 1 do z = math.floor(z) // whole multiples keep small sprites sharp
		w, h := max(f32(e.img_w) * z, 1), max(f32(e.img_h) * z, 1)
		dst := FRect{math.floor(f32(box.x) + (f32(box.w) - w) / 2), math.floor(f32(box.y) + (f32(box.h) - h) / 2), w, h}
		draw_tex_tiled(tex_checker, dst, 8)
		draw_tex(e.thumb, {0, 0, f32(e.thumb.w), f32(e.thumb.h)}, dst)
	case:
		ctl_well(box) // still decoding
	}
}

// ---------------------------------------------------------------------------
// Dragging a file out of the panel
// ---------------------------------------------------------------------------

Files_Drag :: struct {
	idx:    int, // the entry pressed on, or -1
	x0, y0: i32,
	on:     bool, // it has moved far enough to be a drag rather than a click
}

files_drag := Files_Drag{idx = -1}
tabs_rect: Rect // the tab bar, where a drop opens the file as a new sprite

files_dragging :: proc() -> bool {
	return files_drag.idx >= 0 && files_drag.on
}

// Where an image's top left corner goes when its middle lands on sprite pixel `center`. Some of
// it always stays on the canvas, so a drop beside the sprite does not make an empty layer.
image_place :: proc(w, h: int, center: IVec) -> (x, y: int) {
	return clamp(center.x - w / 2, 1 - w, doc.w - 1), clamp(center.y - h / 2, 1 - h, doc.h - 1)
}

// Follows the pointer and handles the drop; drawn over the rest of the interface.
files_drag_run :: proc() {
	if files_drag.idx < 0 do return
	if canvas_mode || bottom_mode != .Files || files_drag.idx >= len(files) {
		files_drag = {idx = -1}
		return
	}
	if !files_drag.on {
		if ui.down[0] && max(abs(ui.mx - files_drag.x0), abs(ui.my - files_drag.y0)) > 4 {
			files_drag.on = true
		} else {
			if !ui.down[0] do files_drag = {idx = -1}
			return
		}
	}
	e := &files[files_drag.idx]
	is_project := lower_ext(e.path) == ".pxl"
	on_canvas := in_rect(canvas_vp, ui.mx, ui.my)
	on_tabs := in_rect(tabs_rect, ui.mx, ui.my)

	if ui.released[0] {
		path := strings.clone(e.path, context.temp_allocator)
		files_drag = {idx = -1}
		if on_tabs || (on_canvas && is_project) {
			open_path(path)
		} else if on_canvas {
			curve_commit()
			stop_playback()
			import_as_layer(path, pointer_to_canvas())
		}
		return
	}
	if !ui.down[0] { 	// the window lost the mouse
		files_drag = {idx = -1}
		return
	}

	ui.tip = ""
	ui.cursor = .NOT_ALLOWED
	switch {
	case on_tabs:
		ui.tip = "Drop to open as a new sprite"
		ui.cursor = .POINTING_HAND
	case on_canvas && is_project:
		ui.tip = "Drop to open"
		ui.cursor = .POINTING_HAND
	case on_canvas:
		ui.tip = "Drop to add as a layer"
		ui.cursor = .POINTING_HAND
	}
	if e.thumb_state != .Ready do return
	src := FRect{0, 0, f32(e.thumb.w), f32(e.thumb.h)}
	ghost := Color{255, 255, 255, 190}
	if on_canvas && !is_project {
		// at the canvas's zoom, cut off where the sprite ends: what the layer will hold
		z := doc.zoom
		x, y := image_place(e.img_w, e.img_h, pointer_to_canvas())
		dst := FRect{doc.ox + f32(x) * z, doc.oy + f32(y) * z, f32(e.img_w) * z, f32(e.img_h) * z}
		clip_begin(canvas_vp)
		clip_begin(Rect{i32(math.floor(doc.ox)), i32(math.floor(doc.oy)), i32(math.ceil(f32(doc.w) * z)), i32(math.ceil(f32(doc.h) * z))})
		draw_tex(e.thumb, src, dst, ghost)
		clip_end()
		draw_rect_outline(dst, C_ACCENT)
		clip_end()
		return
	}
	z := min(1, 48 / f32(max(e.img_w, e.img_h)))
	draw_tex(e.thumb, src, {f32(ui.mx) + 10, f32(ui.my) + 10, max(f32(e.img_w) * z, 1), max(f32(e.img_h) * z, 1)}, ghost)
}
