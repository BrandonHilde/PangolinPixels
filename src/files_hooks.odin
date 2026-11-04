package pangolin

import "core:math"
import "core:slice"

// What the shared file browser (libs/shared/src/files.odin) asks of Pixels: images and projects show up,
// and an image dropped on the canvas becomes a layer where it lands.

FILES_HINT :: "Pick a folder of images, then drag them onto the canvas"

files_listed :: proc(name: string) -> bool {
	ext := lower_ext(name)
	return ext == ".pxl" || is_common_image_ext(ext)
}

// The first frame of a project or an animated image. Safe off the main thread.
files_preview :: proc(path: string) -> (pix: []Color, w, h: int, ok: bool) {
	if lower_ext(path) != ".pxl" do return load_image_pixels(path)
	data, rok := read_file(path)
	if !rok do return
	defer delete(data)
	d, dok := project_decode(data)
	if !dok do return
	defer doc_destroy(d)
	doc_refresh_comp(d)
	return slice.clone(d.comp), d.w, d.h, true
}

files_preview_on_main :: proc(path: string) -> bool {
	return false
}

files_drop_hint :: proc(path: string, on_tabs: bool) -> string {
	if on_tabs do return "Drop to open as a new sprite"
	return lower_ext(path) == ".pxl" ? "Drop to open" : "Drop to add as a layer"
}

files_drop :: proc(path: string, on_tabs: bool) {
	if on_tabs || lower_ext(path) == ".pxl" {
		open_path(path)
		return
	}
	curve_commit()
	stop_playback()
	import_as_layer(path, pointer_to_canvas())
}

// Where an image's top left corner goes when its middle lands on sprite pixel `center`. Some of
// it always stays on the canvas, so a drop beside the sprite does not make an empty layer.
image_place :: proc(w, h: int, center: IVec) -> (x, y: int) {
	return clamp(center.x - w / 2, 1 - w, doc.w - 1), clamp(center.y - h / 2, 1 - h, doc.h - 1)
}

// At the canvas's zoom, cut off where the sprite ends: what the layer will hold. A project opens
// instead of landing here, so it follows the pointer like a drop on the tabs.
files_ghost :: proc(thumb: Texture, img_w, img_h: int) -> bool {
	if files_drag.idx < 0 || lower_ext(files[files_drag.idx].path) == ".pxl" do return false
	z := doc.zoom
	x, y := image_place(img_w, img_h, pointer_to_canvas())
	dst := FRect{doc.ox + f32(x) * z, doc.oy + f32(y) * z, f32(img_w) * z, f32(img_h) * z}
	clip_begin(canvas_vp)
	clip_begin(Rect{i32(math.floor(doc.ox)), i32(math.floor(doc.oy)), i32(math.ceil(f32(doc.w) * z)), i32(math.ceil(f32(doc.h) * z))})
	draw_tex(thumb, {0, 0, f32(thumb.w), f32(thumb.h)}, dst, Color{255, 255, 255, 190})
	clip_end()
	draw_rect_outline(dst, C_ACCENT)
	clip_end()
	return true
}

bottom_has_timeline :: proc() -> bool {
	return true
}
