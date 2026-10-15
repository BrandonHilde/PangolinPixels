package pangolin

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import win "core:sys/windows"
import rl "vendor:raylib"

// ---------------------------------------------------------------------------
// Native file dialogs
// ---------------------------------------------------------------------------

Filter :: struct {
	name, pattern: string,
}

FILTERS_OPEN := [?]Filter {
	{"All supported", "*.pxl;*.png;*.jpg;*.jpeg;*.bmp;*.tga;*.gif;*.qoi;*.gpl"},
	{"Pixel project (*.pxl)", "*.pxl"},
	{"Images", "*.png;*.jpg;*.jpeg;*.bmp;*.tga;*.gif;*.qoi"},
	{"All files", "*.*"},
}
FILTERS_PXL := [?]Filter{{"Pixel project (*.pxl)", "*.pxl"}}
FILTERS_PNG := [?]Filter{{"PNG image (*.png)", "*.png"}}
FILTERS_GIF := [?]Filter{{"GIF animation (*.gif)", "*.gif"}}
FILTERS_IMG := [?]Filter{{"Images", "*.png;*.jpg;*.jpeg;*.bmp;*.tga;*.gif;*.qoi"}, {"All files", "*.*"}}
FILTERS_GPL := [?]Filter{{"GIMP palette (*.gpl)", "*.gpl"}, {"All files", "*.*"}}

native_dialog :: proc(save: bool, title: string, filters: []Filter, def_ext, initial: string) -> (path: string, ok: bool) {
	when ODIN_OS == .Windows {
		return native_dialog_windows(save, title, filters, def_ext, initial)
	} else {
		return native_dialog_zenity(save, title, filters, def_ext, initial)
	}
}

when ODIN_OS == .Windows {
	native_dialog_windows :: proc(save: bool, title: string, filters: []Filter, def_ext, initial: string) -> (path: string, ok: bool) {
		buf := make([]u16, 32768, context.temp_allocator)
		if initial != "" {
			w := win.utf8_to_utf16(initial, context.temp_allocator)
			copy(buf[:len(buf) - 1], w)
		}
		fbuf := make([dynamic]u16, context.temp_allocator)
		for f in filters {
			append(&fbuf, ..win.utf8_to_utf16(f.name, context.temp_allocator))
			append(&fbuf, 0)
			append(&fbuf, ..win.utf8_to_utf16(f.pattern, context.temp_allocator))
			append(&fbuf, 0)
		}
		append(&fbuf, 0)
		append(&fbuf, 0)

		ofn := win.OPENFILENAMEW {
			lStructSize  = size_of(win.OPENFILENAMEW),
			hwndOwner    = win.HWND(rl.GetWindowHandle()),
			lpstrFilter  = win.wstring(raw_data(fbuf)),
			lpstrFile    = raw_data(buf),
			nMaxFile     = u32(len(buf)),
			lpstrTitle   = win.utf8_to_wstring(title),
			Flags        = win.OFN_EXPLORER | win.OFN_NOCHANGEDIR | win.OFN_HIDEREADONLY | (save ? win.OFN_OVERWRITEPROMPT : (win.OFN_FILEMUSTEXIST | win.OFN_PATHMUSTEXIST)),
			lpstrDefExt  = def_ext != "" ? win.utf8_to_wstring(def_ext) : nil,
		}
		r := save ? win.GetSaveFileNameW(&ofn) : win.GetOpenFileNameW(&ofn)
		if !r {
			return "", false
		}
		s, err := win.wstring_to_utf8(win.wstring(raw_data(buf)), -1, context.allocator)
		if err != nil {
			return "", false
		}
		return s, true
	}
}

// Linux/BSD file picker backed by the Zenity or KDialog helper if present.
when ODIN_OS != .Windows {
	// Zenity's `--file-filter` wants space-separated globs, e.g. "*.png *.jpg".
	zenity_pattern :: proc(p: string, alloc: runtime.Allocator) -> string {
		out, _ := strings.replace_all(p, ";", " ", alloc)
		return out
	}

	native_dialog_zenity :: proc(save: bool, title: string, filters: []Filter, def_ext, initial: string) -> (path: string, ok: bool) {
		// Zenity
		{
			cmd := make([dynamic]string, context.temp_allocator)
			append(&cmd, "zenity", "--file-selection")
			append(&cmd, fmt.tprintf("--title=%s", title))
			if save {
				append(&cmd, "--save", "--confirm-overwrite")
			}
			if initial != "" {
				append(&cmd, fmt.tprintf("--filename=%s", initial))
			}
			for f in filters {
				pat := zenity_pattern(f.pattern, context.temp_allocator)
				append(&cmd, fmt.tprintf("--file-filter=%s | %s", f.name, pat))
			}
			if out, code, err := run_dialog(cmd[:]); err == nil {
				if code != 0 {
					return "", false
				}
				return clone_trim(out), true
			}
		}
		// KDialog fallback
		{
			cmd := make([dynamic]string, context.temp_allocator)
			append(&cmd, "kdialog", fmt.tprintf("--title=%s", title))
			if save {
				append(&cmd, "--getsavefilename")
			} else {
				append(&cmd, "--getopenfilename")
			}
			dir := initial
			pattern_spec := "All files (*)"
			if len(filters) > 0 {
				pattern_spec = fmt.tprintf("%s (%s)", filters[0].name, zenity_pattern(filters[0].pattern, context.temp_allocator))
			}
			append(&cmd, dir, pattern_spec)
			if out, code, err := run_dialog(cmd[:]); err == nil {
				if code != 0 {
					return "", false
				}
				return clone_trim(out), true
			}
		}
		return "", false
	}

	run_dialog :: proc(cmd: []string) -> (stdout: string, exit_code: int, err: os.Error) {
		state, out, _ := os.process_exec({command = cmd}, context.temp_allocator) or_return
		return string(out), state.exit_code, nil
	}

	clone_trim :: proc(s: string) -> string {
		return strings.clone(strings.trim_space(s))
	}
}

// ---------------------------------------------------------------------------
// Binary helpers
// ---------------------------------------------------------------------------

Writer :: struct {
	b: [dynamic]u8,
}

w8 :: proc(w: ^Writer, v: u8) {
	append(&w.b, v)
}

w16 :: proc(w: ^Writer, v: u16) {
	append(&w.b, u8(v), u8(v >> 8))
}

w32 :: proc(w: ^Writer, v: u32) {
	append(&w.b, u8(v), u8(v >> 8), u8(v >> 16), u8(v >> 24))
}

wstr :: proc(w: ^Writer, s: string) {
	n := min(len(s), 255)
	w8(w, u8(n))
	append(&w.b, ..transmute([]u8)s[:n])
}

wcol :: proc(w: ^Writer, c: Color) {
	append(&w.b, c.r, c.g, c.b, c.a)
}

Reader :: struct {
	d:   []u8,
	pos: int,
	bad: bool,
}

r8 :: proc(r: ^Reader) -> u8 {
	if r.pos >= len(r.d) {
		r.bad = true
		return 0
	}
	v := r.d[r.pos]
	r.pos += 1
	return v
}

r16 :: proc(r: ^Reader) -> u16 {
	a := u16(r8(r))
	b := u16(r8(r))
	return a | b << 8
}

r32 :: proc(r: ^Reader) -> u32 {
	a := u32(r16(r))
	b := u32(r16(r))
	return a | b << 16
}

rstr :: proc(r: ^Reader) -> string {
	n := int(r8(r))
	if r.pos + n > len(r.d) {
		r.bad = true
		return ""
	}
	s := string(r.d[r.pos:r.pos + n])
	r.pos += n
	return s
}

rcol :: proc(r: ^Reader) -> Color {
	c: Color
	c.r = r8(r)
	c.g = r8(r)
	c.b = r8(r)
	c.a = r8(r)
	return c
}

// ---------------------------------------------------------------------------
// Project format (.pxl)
// ---------------------------------------------------------------------------

PXL_MAGIC :: "PXLA"
PXL_VERSION :: 1

rle_encode :: proc(w: ^Writer, pix: []Color) {
	tmp := Writer{}
	tmp.b = make([dynamic]u8, context.temp_allocator)
	i := 0
	for i < len(pix) {
		c := pix[i]
		run := 1
		for i + run < len(pix) && run < 65535 && color_eq(pix[i + run], c) {
			run += 1
		}
		w16(&tmp, u16(run))
		wcol(&tmp, c)
		i += run
	}
	w32(w, u32(len(tmp.b)))
	append(&w.b, ..tmp.b[:])
}

rle_decode :: proc(r: ^Reader, pix: []Color) {
	n := int(r32(r))
	end := r.pos + n
	if end > len(r.d) {
		r.bad = true
		return
	}
	i := 0
	for r.pos < end && i < len(pix) {
		run := int(r16(r))
		c := rcol(r)
		for _ in 0 ..< run {
			if i >= len(pix) {
				break
			}
			pix[i] = c
			i += 1
		}
	}
	r.pos = end
}

project_encode :: proc(d: ^Doc) -> []u8 {
	w := Writer{}
	w.b = make([dynamic]u8, context.temp_allocator)
	append(&w.b, ..transmute([]u8)string(PXL_MAGIC))
	w8(&w, PXL_VERSION)
	w32(&w, u32(d.w))
	w32(&w, u32(d.h))
	w32(&w, u32(len(d.frames)))
	for f in d.frames {
		w32(&w, u32(f.duration))
	}
	w32(&w, u32(len(d.layers)))
	for &l in d.layers {
		wstr(&w, name_str(&l.name))
		flags: u8
		if l.visible do flags |= 1
		if l.locked do flags |= 2
		w8(&w, flags)
		w8(&w, l.opacity)
		w8(&w, u8(l.blend))
		for c in l.cels {
			rle_encode(&w, c.pix)
		}
	}
	w32(&w, u32(len(d.tags)))
	for &t in d.tags {
		wstr(&w, name_str(&t.name))
		w32(&w, u32(t.from))
		w32(&w, u32(t.to))
		w8(&w, u8(t.dir))
		wcol(&w, t.color)
	}
	w32(&w, u32(len(d.palette)))
	for c in d.palette {
		wcol(&w, c)
	}
	return w.b[:]
}

project_decode :: proc(data: []u8) -> (d: ^Doc, ok: bool) {
	if len(data) < 5 || string(data[:4]) != PXL_MAGIC {
		return nil, false
	}
	r := Reader{d = data, pos = 4}
	ver := r8(&r)
	if ver != PXL_VERSION {
		return nil, false
	}
	w := int(r32(&r))
	h := int(r32(&r))
	if w < 1 || h < 1 || w > 8192 || h > 8192 {
		return nil, false
	}
	nd := doc_new(w, h)
	// strip the default layer
	for &l in nd.layers {
		layer_destroy(&l)
	}
	clear(&nd.layers)
	clear(&nd.frames)
	clear(&nd.palette)

	nf := int(r32(&r))
	if nf < 1 || nf > 100000 {
		doc_destroy(nd)
		return nil, false
	}
	for _ in 0 ..< nf {
		append(&nd.frames, Frame{int(r32(&r))})
	}
	nl := int(r32(&r))
	if nl < 1 || nl > 4096 {
		doc_destroy(nd)
		return nil, false
	}
	for _ in 0 ..< nl {
		l: Layer
		name_set(&l.name, rstr(&r))
		flags := r8(&r)
		l.visible = flags & 1 != 0
		l.locked = flags & 2 != 0
		l.opacity = r8(&r)
		l.blend = Blend(min(r8(&r), u8(len(Blend) - 1)))
		for _ in 0 ..< nf {
			c := cel_new(w * h)
			rle_decode(&r, c.pix)
			append(&l.cels, c)
		}
		append(&nd.layers, l)
	}
	nt := int(r32(&r))
	for _ in 0 ..< min(nt, 4096) {
		t: Tag
		name_set(&t.name, rstr(&r))
		t.from = int(r32(&r))
		t.to = int(r32(&r))
		t.dir = Tag_Dir(min(r8(&r), u8(len(Tag_Dir) - 1)))
		t.color = rcol(&r)
		append(&nd.tags, t)
	}
	np := int(r32(&r))
	for _ in 0 ..< min(np, 4096) {
		append(&nd.palette, rcol(&r))
	}
	if r.bad {
		doc_destroy(nd)
		return nil, false
	}
	if len(nd.palette) == 0 {
		for c in palette_preset(.DB32) {
			append(&nd.palette, c)
		}
	}
	nd.modified = false
	return nd, true
}

// ---------------------------------------------------------------------------
// Images
// ---------------------------------------------------------------------------

load_image_pixels :: proc(path: string) -> (pix: []Color, w, h: int, ok: bool) {
	cpath := strings.clone_to_cstring(path, context.temp_allocator)
	img := rl.LoadImage(cpath)
	if img.data == nil || img.width <= 0 || img.height <= 0 {
		return
	}
	defer rl.UnloadImage(img)
	rl.ImageFormat(&img, .UNCOMPRESSED_R8G8B8A8)
	w, h = int(img.width), int(img.height)
	pix = make([]Color, w * h)
	src := ([^]Color)(img.data)[:w * h]
	copy(pix, src)
	ok = true
	return
}

save_png :: proc(path: string, pix: []Color, w, h: int) -> bool {
	img := rl.Image {
		data    = raw_data(pix),
		width   = i32(w),
		height  = i32(h),
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}
	return rl.ExportImage(img, strings.clone_to_cstring(path, context.temp_allocator))
}

doc_from_image :: proc(path: string) -> (d: ^Doc, ok: bool) {
	pix, w, h, lok := load_image_pixels(path)
	if !lok {
		return nil, false
	}
	defer delete(pix)
	nd := doc_new(w, h, path_stem(path))
	copy(nd.layers[0].cels[0].pix, pix)
	palette_from_sprite(nd)
	if len(nd.palette) > 64 || len(nd.palette) == 0 {
		palette_set_preset(nd, .DB32)
	}
	nd.modified = false
	return nd, true
}

// ---------------------------------------------------------------------------
// High-level file commands
// ---------------------------------------------------------------------------

show_message :: proc(title, msg: string) {
	name_set(&dialog.msg_title, title)
	name_set(&dialog.msg_text, msg)
	dialog_open(.Message)
}

file_open_dialog :: proc() {
	p, ok := native_dialog(false, "Open", FILTERS_OPEN[:], "", "")
	if ok {
		open_path(p)
		delete(p)
	}
}

lower_ext :: proc(p: string) -> string {
	return strings.to_lower(path_ext(p), context.temp_allocator)
}

open_path :: proc(path: string) {
	// already open? switch to it
	for d, i in docs {
		if d.path == path {
			switch_doc(i)
			return
		}
	}
	ext := lower_ext(path)
	switch ext {
	case ".pxl":
		data, ok := read_file(path)
		if !ok {
			show_message("Open", fmt.tprintf("Cannot read %s", path))
			return
		}
		defer delete(data)
		d, dok := project_decode(data)
		if !dok {
			show_message("Open", "This is not a valid project file.")
			return
		}
		d.path = strings.clone(path)
		name_set(&d.title, path_stem(path))
		add_doc(d)
		set_statusf("Opened %s", path_basename(path))
	case ".gpl":
		if palette_load_gpl(doc, path) {
			set_status("Palette loaded")
		} else {
			show_message("Palette", "Could not read palette.")
		}
	case:
		d, ok := doc_from_image(path)
		if !ok {
			show_message("Open", fmt.tprintf("Cannot open %s", path_basename(path)))
			return
		}
		add_doc(d)
		set_statusf("Imported %s", path_basename(path))
	}
}

file_save :: proc(d: ^Doc, save_as: bool) -> bool {
	path := d.path
	if path == "" || save_as {
		initial := fmt.tprintf("%s.pxl", name_str(&d.title))
		p, ok := native_dialog(true, "Save project", FILTERS_PXL[:], "pxl", initial)
		if !ok {
			return false
		}
		path = p
	}
	data := project_encode(d)
	if !write_file(path, data) {
		show_message("Save", fmt.tprintf("Could not write %s", path))
		return false
	}
	if path != d.path {
		if d.path != "" {
			delete(d.path)
		}
		d.path = strings.clone(path)
		if save_as || true {
			name_set(&d.title, path_stem(path))
		}
	}
	d.modified = false
	set_statusf("Saved %s", path_basename(path))
	return true
}

Import_Kind :: enum {
	Image,
	Layer,
	Sheet,
}

sheet_path: string

file_import_dialog :: proc(kind: Import_Kind) {
	p, ok := native_dialog(false, "Import image", FILTERS_IMG[:], "", "")
	if !ok {
		return
	}
	switch kind {
	case .Image:
		open_path(p)
	case .Layer:
		import_as_layer(p)
	case .Sheet:
		if sheet_path != "" {
			delete(sheet_path)
		}
		sheet_path = p
		dialog_open(.Import_Sheet)
		return
	}
	delete(p)
}

import_as_layer :: proc(path: string) {
	pix, w, h, ok := load_image_pixels(path)
	if !ok {
		show_message("Import", "Cannot read image.")
		return
	}
	defer delete(pix)
	history_push(doc)
	l := layer_make(path_stem(path), len(doc.frames), doc.w * doc.h)
	for y in 0 ..< min(h, doc.h) {
		for x in 0 ..< min(w, doc.w) {
			l.cels[doc.active_frame].pix[y * doc.w + x] = pix[y * w + x]
		}
	}
	inject_at(&doc.layers, doc.active_layer + 1, l)
	doc.active_layer += 1
	doc_touch(doc)
	set_status("Imported as layer")
}

// Slice the image at `sheet_path` into frames of fw x fh.
import_sheet :: proc(fw, fh: int) {
	pix, w, h, ok := load_image_pixels(sheet_path)
	if !ok {
		show_message("Import", "Cannot read image.")
		return
	}
	defer delete(pix)
	fw := clamp(fw, 1, w)
	fh := clamp(fh, 1, h)
	cols, rows := w / fw, h / fh
	if cols < 1 || rows < 1 {
		return
	}
	nd := doc_new(fw, fh, path_stem(sheet_path))
	clear(&nd.frames)
	for &l in nd.layers {
		layer_destroy(&l)
	}
	clear(&nd.layers)
	l := layer_make("Layer 1", 0, 0)
	for ry in 0 ..< rows {
		for cx in 0 ..< cols {
			c := cel_new(fw * fh)
			for y in 0 ..< fh {
				for x in 0 ..< fw {
					c.pix[y * fw + x] = pix[(ry * fh + y) * w + cx * fw + x]
				}
			}
			append(&l.cels, c)
			append(&nd.frames, Frame{100})
		}
	}
	append(&nd.layers, l)
	nd.modified = false
	add_doc(nd)
	set_statusf("Imported %d frames", len(nd.frames))
}

file_palette_load :: proc() {
	p, ok := native_dialog(false, "Load palette", FILTERS_GPL[:], "gpl", "")
	if ok {
		if palette_load_gpl(doc, p) {
			set_status("Palette loaded")
		} else {
			show_message("Palette", "Could not read palette file.")
		}
		delete(p)
	}
}

file_palette_save :: proc() {
	p, ok := native_dialog(true, "Save palette", FILTERS_GPL[:], "gpl", "palette.gpl")
	if ok {
		if palette_save_gpl(doc, p) {
			set_status("Palette saved")
		} else {
			show_message("Palette", "Could not write palette file.")
		}
		delete(p)
	}
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

Export_Format :: enum {
	PNG,
	Sheet,
	GIF,
	Sequence,
}

EXPORT_FORMAT_NAMES := [Export_Format]string {
	.PNG      = "PNG (current frame)",
	.Sheet    = "Sprite sheet (PNG)",
	.GIF      = "Animated GIF",
	.Sequence = "PNG sequence",
}

Sheet_Layout :: enum {
	Horizontal,
	Vertical,
	Grid,
}

SHEET_LAYOUT_NAMES := [Sheet_Layout]string {
	.Horizontal = "Horizontal strip",
	.Vertical   = "Vertical strip",
	.Grid       = "Grid (square-ish)",
}

export_layout: Sheet_Layout
export_gif_loop := true
export_range_tag := false

frame_pixels_scaled :: proc(d: ^Doc, f, scale: int) -> []Color {
	base := make([]Color, d.w * d.h, context.temp_allocator)
	composite(d, f, base)
	if scale == 1 {
		return base
	}
	nw, nh := d.w * scale, d.h * scale
	out := make([]Color, nw * nh, context.temp_allocator)
	for y in 0 ..< nh {
		for x in 0 ..< nw {
			out[y * nw + x] = base[(y / scale) * d.w + x / scale]
		}
	}
	return out
}

export_frame_range :: proc(d: ^Doc) -> (lo, hi: int) {
	lo, hi = 0, len(d.frames) - 1
	if export_range_tag && play_tag >= 0 && play_tag < len(d.tags) {
		lo = clamp(d.tags[play_tag].from, 0, hi)
		hi = clamp(d.tags[play_tag].to, lo, hi)
	}
	return
}

export_run :: proc(format: Export_Format, scale: int, _unused: bool) {
	d := doc
	scale := clamp(scale, 1, 32)
	base := name_str(&d.title)
	if d.path != "" {
		base = path_stem(d.path)
	}
	switch format {
	case .PNG:
		p, ok := native_dialog(true, "Export PNG", FILTERS_PNG[:], "png", fmt.tprintf("%s.png", base))
		if !ok do return
		defer delete(p)
		pix := frame_pixels_scaled(d, d.active_frame, scale)
		if save_png(p, pix, d.w * scale, d.h * scale) {
			set_statusf("Exported %s", path_basename(p))
		} else {
			show_message("Export", "Failed to write PNG.")
		}
	case .Sheet:
		p, ok := native_dialog(true, "Export sprite sheet", FILTERS_PNG[:], "png", fmt.tprintf("%s_sheet.png", base))
		if !ok do return
		defer delete(p)
		lo, hi := export_frame_range(d)
		n := hi - lo + 1
		cols, rows := n, 1
		switch export_layout {
		case .Horizontal:
		case .Vertical:
			cols, rows = 1, n
		case .Grid:
			cols = 1
			for cols * cols < n do cols += 1
			rows = (n + cols - 1) / cols
		}
		fw, fh := d.w * scale, d.h * scale
		sw, sh := fw * cols, fh * rows
		sheet := make([]Color, sw * sh, context.temp_allocator)
		for i in 0 ..< n {
			fp := frame_pixels_scaled(d, lo + i, scale)
			ox, oy := (i % cols) * fw, (i / cols) * fh
			for y in 0 ..< fh {
				for x in 0 ..< fw {
					sheet[(oy + y) * sw + ox + x] = fp[y * fw + x]
				}
			}
		}
		if save_png(p, sheet, sw, sh) {
			set_statusf("Exported %d frames to %s", n, path_basename(p))
		} else {
			show_message("Export", "Failed to write PNG.")
		}
	case .GIF:
		p, ok := native_dialog(true, "Export GIF", FILTERS_GIF[:], "gif", fmt.tprintf("%s.gif", base))
		if !ok do return
		defer delete(p)
		data := gif_encode(d, scale, export_gif_loop)
		if write_file(p, data) {
			set_statusf("Exported %s", path_basename(p))
		} else {
			show_message("Export", "Failed to write GIF.")
		}
	case .Sequence:
		p, ok := native_dialog(true, "Export PNG sequence (base name)", FILTERS_PNG[:], "png", fmt.tprintf("%s.png", base))
		if !ok do return
		defer delete(p)
		stem := p[:len(p) - len(path_ext(p))]
		lo, hi := export_frame_range(d)
		count := 0
		for f in lo ..= hi {
			fp := frame_pixels_scaled(d, f, scale)
			name := fmt.tprintf("%s_%03d.png", stem, f - lo)
			if save_png(name, fp, d.w * scale, d.h * scale) {
				count += 1
			}
		}
		set_statusf("Exported %d PNG files", count)
	}
}

// ---------------------------------------------------------------------------
// GIF encoder
// ---------------------------------------------------------------------------

Ucol :: struct {
	rgb:   [3]u8,
	count: int,
	box:   int,
}

Cbox :: struct {
	lo, hi: int, // range in `order`
}

gif_build_palette :: proc(d: ^Doc, comps: [][]Color) -> (pal: [256][3]u8, lookup: map[u32]u8) {
	lookup = make(map[u32]u8, 256, context.temp_allocator)
	counts := make(map[u32]int, 1024, context.temp_allocator)
	for fp in comps {
		for p in fp {
			if p.a >= 128 {
				counts[u32(p.r) << 16 | u32(p.g) << 8 | u32(p.b)] += 1
			}
		}
	}
	ucs := make([dynamic]Ucol, context.temp_allocator)
	for k, v in counts {
		append(&ucs, Ucol{{u8(k >> 16), u8(k >> 8), u8(k)}, v, 0})
	}
	if len(ucs) <= 255 {
		for u, i in ucs {
			pal[i + 1] = u.rgb
			lookup[u32(u.rgb.r) << 16 | u32(u.rgb.g) << 8 | u32(u.rgb.b)] = u8(i + 1)
		}
		return
	}
	// median cut
	order := make([]int, len(ucs), context.temp_allocator)
	for i in 0 ..< len(order) do order[i] = i
	boxes := make([dynamic]Cbox, context.temp_allocator)
	append(&boxes, Cbox{0, len(order)})
	range_of :: proc(ucs: []Ucol, order: []int, b: Cbox) -> (axis, rng: int) {
		mn := [3]int{255, 255, 255}
		mx := [3]int{}
		for i in b.lo ..< b.hi {
			u := ucs[order[i]]
			for c in 0 ..< 3 {
				mn[c] = min(mn[c], int(u.rgb[c]))
				mx[c] = max(mx[c], int(u.rgb[c]))
			}
		}
		for c in 0 ..< 3 {
			if mx[c] - mn[c] > rng {
				rng = mx[c] - mn[c]
				axis = c
			}
		}
		return
	}
	for len(boxes) < 255 {
		best, best_rng, best_axis := -1, 0, 0
		for b, i in boxes {
			if b.hi - b.lo < 2 do continue
			axis, rng := range_of(ucs[:], order, b)
			if rng > best_rng {
				best, best_rng, best_axis = i, rng, axis
			}
		}
		if best < 0 do break
		b := boxes[best]
		sub := order[b.lo:b.hi]
		ax := best_axis
		// sort by chosen axis (closure-free: use a global key)
		gif_sort_axis = ax
		gif_sort_ucs = ucs[:]
		slice.sort_by(sub, proc(a, b: int) -> bool {
			return gif_sort_ucs[a].rgb[gif_sort_axis] < gif_sort_ucs[b].rgb[gif_sort_axis]
		})
		total := 0
		for i in b.lo ..< b.hi do total += ucs[order[i]].count
		acc := 0
		mid := b.lo + 1
		for i in b.lo ..< b.hi - 1 {
			acc += ucs[order[i]].count
			mid = i + 1
			if acc * 2 >= total do break
		}
		boxes[best] = Cbox{b.lo, mid}
		append(&boxes, Cbox{mid, b.hi})
	}
	for b, bi in boxes {
		sum := [3]int{}
		tot := 0
		for i in b.lo ..< b.hi {
			u := ucs[order[i]]
			ucs[order[i]].box = bi
			for c in 0 ..< 3 do sum[c] += int(u.rgb[c]) * u.count
			tot += u.count
		}
		tot = max(tot, 1)
		pal[bi + 1] = {u8(sum[0] / tot), u8(sum[1] / tot), u8(sum[2] / tot)}
	}
	for u in ucs {
		lookup[u32(u.rgb[0]) << 16 | u32(u.rgb[1]) << 8 | u32(u.rgb[2])] = u8(u.box + 1)
	}
	return
}

@(private = "file")
gif_sort_axis: int
@(private = "file")
gif_sort_ucs: []Ucol

Bit_Writer :: struct {
	out:   ^[dynamic]u8,
	acc:   u32,
	nbits: u32,
}

bw_put :: proc(b: ^Bit_Writer, code: u32, size: u32) {
	b.acc |= code << b.nbits
	b.nbits += size
	for b.nbits >= 8 {
		append(b.out, u8(b.acc))
		b.acc >>= 8
		b.nbits -= 8
	}
}

bw_flush :: proc(b: ^Bit_Writer) {
	if b.nbits > 0 {
		append(b.out, u8(b.acc))
		b.acc = 0
		b.nbits = 0
	}
}

lzw_encode :: proc(idx: []u8, out: ^[dynamic]u8) {
	CLEAR :: 256
	EOI :: 257
	bw := Bit_Writer{out = out}
	dict := make(map[u32]u16, 4096, context.temp_allocator)
	next: u32 = 258
	size: u32 = 9
	bw_put(&bw, CLEAR, size)
	if len(idx) == 0 {
		bw_put(&bw, EOI, size)
		bw_flush(&bw)
		return
	}
	prefix := u32(idx[0])
	for i in 1 ..< len(idx) {
		b := idx[i]
		key := prefix << 8 | u32(b)
		if code, ok := dict[key]; ok {
			prefix = u32(code)
			continue
		}
		bw_put(&bw, prefix, size)
		dict[key] = u16(next)
		next += 1
		if next > (1 << size) && size < 12 {
			size += 1
		}
		if next >= 4094 {
			bw_put(&bw, CLEAR, size)
			clear(&dict)
			next = 258
			size = 9
		}
		prefix = u32(b)
	}
	bw_put(&bw, prefix, size)
	bw_put(&bw, EOI, size)
	bw_flush(&bw)
}

gif_encode :: proc(d: ^Doc, scale: int, loop: bool) -> []u8 {
	lo, hi := export_frame_range(d)
	n := hi - lo + 1
	comps := make([][]Color, n, context.temp_allocator)
	for i in 0 ..< n {
		comps[i] = frame_pixels_scaled(d, lo + i, 1)
	}
	pal, lookup := gif_build_palette(d, comps)
	w, h := d.w * scale, d.h * scale
	out := make([dynamic]u8, context.temp_allocator)
	append(&out, ..transmute([]u8)string("GIF89a"))
	ww := Writer{b = out}
	w16(&ww, u16(w))
	w16(&ww, u16(h))
	w8(&ww, 0xF7)
	w8(&ww, 0)
	w8(&ww, 0)
	for i in 0 ..< 256 {
		w8(&ww, pal[i][0])
		w8(&ww, pal[i][1])
		w8(&ww, pal[i][2])
	}
	if loop {
		append(&ww.b, 0x21, 0xFF, 0x0B)
		append(&ww.b, ..transmute([]u8)string("NETSCAPE2.0"))
		append(&ww.b, 3, 1, 0, 0, 0)
	}
	idx := make([]u8, w * h, context.temp_allocator)
	for i in 0 ..< n {
		fp := comps[i]
		for y in 0 ..< h {
			for x in 0 ..< w {
				p := fp[(y / scale) * d.w + x / scale]
				v: u8 = 0
				if p.a >= 128 {
					v = lookup[u32(p.r) << 16 | u32(p.g) << 8 | u32(p.b)]
				}
				idx[y * w + x] = v
			}
		}
		delay := max(d.frames[lo + i].duration / 10, 2)
		append(&ww.b, 0x21, 0xF9, 0x04, (2 << 2) | 1)
		w16(&ww, u16(delay))
		append(&ww.b, 0, 0)
		append(&ww.b, 0x2C)
		w16(&ww, 0)
		w16(&ww, 0)
		w16(&ww, u16(w))
		w16(&ww, u16(h))
		w8(&ww, 0)
		w8(&ww, 8)
		data := make([dynamic]u8, context.temp_allocator)
		lzw_encode(idx, &data)
		pos := 0
		for pos < len(data) {
			chunk := min(255, len(data) - pos)
			w8(&ww, u8(chunk))
			append(&ww.b, ..data[pos:pos + chunk])
			pos += chunk
		}
		w8(&ww, 0)
	}
	w8(&ww, 0x3B)
	return ww.b[:]
}
