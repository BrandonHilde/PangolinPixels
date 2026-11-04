package pangolin

import "core:bytes"
import "core:fmt"
import "core:image"
import "core:image/qoi"
import "core:math/rand"
import "core:os"
import "core:slice"
import "core:strings"

@(private = "file")
fails: int

@(private = "file")
check :: proc(cond: bool, what: string) {
	if cond {
		fmt.printf("  ok   %s\n", what)
	} else {
		fmt.printf("  FAIL %s\n", what)
		fails += 1
	}
}

cel_px :: proc(d: ^Doc, l, f, x, y: int) -> Color {
	return d.layers[l].cels[f].pix[y * d.w + x]
}

selftest :: proc() -> int {
	fmt.println("== self test ==")
	d := doc_new(16, 16, "t")
	append(&docs, d)
	doc = d
	opts.brush_size = 1
	opts.pixel_perf = false

	// --- strokes + undo/redo ---
	red := Color{255, 0, 0, 255}
	stroke_begin(false, red, red)
	brush_stamp(3, 3)
	stroke_segment(3, 3, 8, 3, false)
	stroke_end()
	check(color_eq(cel_px(d, 0, 0, 5, 3), red), "line stroke painted")
	check(len(d.undo) == 1, "one undo entry")
	history_undo(d)
	check(cel_px(d, 0, 0, 5, 3).a == 0, "undo clears stroke")
	history_redo(d)
	check(color_eq(cel_px(d, 0, 0, 5, 3), red), "redo restores stroke")

	// empty stroke is discarded
	n := len(d.undo)
	stroke_begin(false, red, red)
	stroke_end()
	check(len(d.undo) == n - 0 + 1 - 1 || len(d.undo) == n, "empty stroke discarded")
	check(len(d.undo) == n, "empty stroke discarded (count)")

	// --- shapes ---
	stroke_begin(false, red, red)
	opts.fill_shape = true
	draw_shape(.Rect, {10, 10}, {12, 12})
	opts.fill_shape = false
	stroke_end()
	check(color_eq(cel_px(d, 0, 0, 11, 11), red), "filled rect")
	// flood fill
	mask := region_select(d.layers[0].cels[0].pix, 16, 16, 0, 0, 0, true, nil)
	cnt := 0
	for v in mask do if v != 0 do cnt += 1
	check(cnt > 200, "flood region large")
	delete(mask)

	// --- layers / frames ---
	doc_add_layer(d)
	doc_add_frame(d, true)
	check(len(d.layers) == 2 && len(d.frames) == 2, "layer+frame added")
	stroke_begin(false, Color{0, 255, 0, 255}, red)
	brush_stamp(1, 1)
	stroke_end()
	check(color_eq(cel_px(d, 1, 1, 1, 1), Color{0, 255, 0, 255}), "paint on frame 2")
	check(cel_px(d, 1, 0, 1, 1).a == 0, "frame 1 untouched (copy on write)")
	doc_dup_layer(d)
	check(len(d.layers) == 3, "dup layer")
	history_undo(d)
	check(len(d.layers) == 2, "undo dup layer")
	history_redo(d)
	doc_merge_down(d)
	check(len(d.layers) == 2, "merge down")

	// --- layer filters ---
	{
		fd := doc_new(4, 4, "f")
		append(&docs, fd)
		doc = fd
		clear(&fd.palette)
		append(&fd.palette, Color{0, 0, 0, 255}, Color{255, 255, 255, 255}, Color{200, 30, 30, 255})
		fd.layers[0].cels[0].pix[0] = Color{250, 250, 250, 255}
		fd.layers[0].cels[0].pix[1] = Color{180, 40, 20, 255}
		fd.layers[0].cels[0].pix[2] = Color{10, 5, 20, 128}
		history_push(fd)
		append(&fd.layers[0].filters, filter_make(.Palette))
		doc_touch(fd)
		doc_refresh_comp(fd)
		check(color_eq(fd.comp[0], Color{255, 255, 255, 255}), "palette filter: near-white -> white")
		check(color_eq(fd.comp[1], Color{200, 30, 30, 255}), "palette filter: reddish -> palette red")
		check(fd.comp[2].a == 128 && fd.comp[2].r == 0, "palette filter keeps alpha")
		check(fd.comp[3].a == 0, "palette filter skips transparent")
		check(fd.layers[0].cels[0].pix[0].r == 250, "filter is non-destructive")
		// palette edits re-trigger the composite
		fd.palette[1] = Color{255, 255, 0, 255}
		doc_refresh_comp(fd)
		check(color_eq(fd.comp[0], Color{255, 255, 0, 255}), "palette change refreshes palette filter")
		append(&fd.layers[0].filters, filter_make(.Invert))
		fd.layers[0].filters[0], fd.layers[0].filters[1] = fd.layers[0].filters[1], fd.layers[0].filters[0]
		doc_touch(fd)
		doc_refresh_comp(fd)
		check(color_eq(fd.comp[0], Color{0, 0, 0, 255}), "filter order matters (invert, then palette)")
		fdata := project_encode(fd)
		fd2, fok := project_decode(fdata)
		check(fok, "filter doc decodes")
		check(fok && len(fd2.layers[0].filters) == 2 && fd2.layers[0].filters[0].kind == .Invert && fd2.layers[0].filters[1].kind == .Palette, "filters round-trip")
		if fok do doc_destroy(fd2)
		history_undo(fd)
		check(len(fd.layers[0].filters) == 0, "undo removes filters")

		// merge down bakes both layers' filters and looks the same afterwards
		append(&fd.layers[0].filters, filter_make(.Invert))
		doc_add_layer(fd)
		fd.layers[1].cels[0].pix[3] = Color{200, 100, 50, 255}
		append(&fd.layers[1].filters, filter_make(.Grayscale))
		doc_touch(fd)
		doc_refresh_comp(fd)
		before := slice.clone(fd.comp, context.temp_allocator)
		check(doc_merge_down(fd), "merge filtered layers")
		check(len(fd.layers) == 1 && len(fd.layers[0].filters) == 0, "merge bakes filters")
		doc_refresh_comp(fd)
		check(slice.equal(before, fd.comp), "merge with filters keeps appearance")
		check(color_eq(fd.comp[0], Color{5, 5, 5, 255}), "merge: lower filter applied once")
		history_undo(fd)
		check(len(fd.layers) == 2 && len(fd.layers[0].filters) == 1 && fd.layers[0].cels[0].pix[0].r == 250, "undo merge restores filters")
		pop(&docs)
		doc_destroy(fd)
		doc = d
	}

	// --- image -> pixel art ---
	{
		// 8x8 source: left half red, right half blue, bottom-right quarter transparent
		src := make([]Color, 64, context.temp_allocator)
		for y in 0 ..< 8 {
			for x in 0 ..< 8 {
				c := x < 4 ? Color{250, 10, 10, 255} : Color{10, 10, 240, 255}
				if x >= 4 && y >= 4 do c = {}
				src[y * 8 + x] = c
			}
		}
		sc := make([]Color, 4, context.temp_allocator)
		pixelate_scale(src, 8, 8, sc, 2, 2)
		check(color_eq(sc[0], Color{250, 10, 10, 255}) && color_eq(sc[1], Color{10, 10, 240, 255}), "pixelate: box downscale")
		check(sc[3].a == 0, "pixelate: transparent area stays transparent")
		pal := make([dynamic]Color, context.temp_allocator)
		median_cut(sc, 2, &pal)
		check(len(pal) == 2, "median cut: requested colour count")
		out := make([]Color, 4, context.temp_allocator)
		gb := palette_preset(.Gameboy)
		for di in Dither {
			quantize(sc, out, 2, 2, gb, di)
			in_pal := true
			for c, i in out {
				if i == 3 {
					in_pal &= c.a == 0
					continue
				}
				found := false
				for pc in gb do found |= color_eq(pc, c)
				in_pal &= found
			}
			check(in_pal, fmt.tprintf("quantize (%v): output uses only palette colours", di))
		}
	}

	// --- project round trip ---
	name_set(&d.layers[0].name, "base")
	data := project_encode(d)
	d2, ok := project_decode(data)
	check(ok, "project decodes")
	if ok {
		same := d2.w == d.w && d2.h == d.h && len(d2.layers) == len(d.layers) && len(d2.frames) == len(d.frames)
		for l in 0 ..< len(d.layers) {
			for f in 0 ..< len(d.frames) {
				for i in 0 ..< d.w * d.h {
					if !color_eq(d.layers[l].cels[f].pix[i], d2.layers[l].cels[f].pix[i]) do same = false
				}
			}
		}
		check(same, "project round-trip identical")
		check(name_str(&d2.layers[0].name) == "base", "layer name preserved")
		doc_destroy(d2)
	}

	// --- transforms ---
	w0, h0 := d.w, d.h
	doc_resize(d, 20, 10, 2, 1)
	check(d.w == 20 && d.h == 10 && len(d.comp) == 200, "canvas resize")
	history_undo(d)
	check(d.w == w0 && d.h == h0, "undo canvas resize")
	history_redo(d)
	history_undo(d)
	doc_rotate(d, 1)
	doc_rotate(d, 3)
	check(color_eq(cel_px(d, 0, 0, 5, 3), red), "rotate cw+ccw identity")
	doc_flip_sprite(d, true)
	doc_flip_sprite(d, true)
	check(color_eq(cel_px(d, 0, 0, 5, 3), red), "flip twice identity")
	doc_scale(d, 32, 32)
	check(d.w == 32, "scale")
	history_undo(d)

	// --- selection ops ---
	doc_sel_set(d, mask_rect(d.w, d.h, 2, 2, 6, 6))
	edit_copy(false)
	check(clip.w == 5 && clip.h == 5, "copy selection size")
	edit_flip(true)
	doc_sel_clear(d)
	check(len(d.sel_edges) == 0 || d.sel_dirty, "selection cleared")

	// --- tool state machine ---
	td := doc_new(24, 24, "tools")
	append(&docs, td)
	doc = td
	set_fg(Color{10, 20, 30, 255})
	bg = Color{200, 100, 50, 255}
	opts.pixel_perf = true
	opts.brush_size = 1
	cur_tool = .Pencil
	begin_drag(0, {2, 2})
	update_drag({3, 3})
	update_drag({4, 3})
	update_drag({5, 4})
	end_drag()
	check(cel_px(td, 0, 0, 2, 2).a == 255 && cel_px(td, 0, 0, 5, 4).a == 255, "pencil drag draws")
	// pixel perfect: (3,3) then (4,3) forms an L with (3,3)? path 2,2 -> 3,3 -> 4,3 -> 5,4
	check(len(td.undo) == 1, "pencil drag = one undo step")
	history_undo(td)
	check(cel_px(td, 0, 0, 2, 2).a == 0, "pencil drag undone")

	cur_tool = .Line
	begin_drag(0, {0, 0})
	update_drag({7, 0})
	update_drag({7, 5})
	end_drag()
	check(cel_px(td, 0, 0, 7, 5).a == 255 && cel_px(td, 0, 0, 7, 0).a == 0, "line tool follows final point only")
	history_undo(td)

	cur_tool = .Rect
	opts.fill_shape = true
	begin_drag(1, {4, 4})
	update_drag({8, 8})
	end_drag()
	opts.fill_shape = false
	check(color_eq(cel_px(td, 0, 0, 6, 6), bg), "right button uses background colour")

	cur_tool = .Bucket
	begin_drag(0, {20, 20})
	check(color_eq(cel_px(td, 0, 0, 22, 1), Color{10, 20, 30, 255}), "bucket fills outside region")
	check(color_eq(cel_px(td, 0, 0, 6, 6), bg), "bucket respects boundary")
	history_undo(td)

	cur_tool = .Select_Rect
	begin_drag(0, {3, 3})
	update_drag({9, 9})
	end_drag()
	check(td.sel != nil && td.sel[5 * 24 + 5] != 0 && td.sel[12 * 24 + 12] == 0, "marquee selection")
	cur_tool = .Move
	begin_drag(0, {5, 5})
	update_drag({15, 5})
	end_drag()
	check(color_eq(cel_px(td, 0, 0, 16, 6), bg) && cel_px(td, 0, 0, 6, 6).a == 0, "move tool moves selected pixels")
	check(td.sel[5 * 24 + 15] != 0 && td.sel[5 * 24 + 5] == 0, "selection moved with content")
	history_undo(td)
	check(color_eq(cel_px(td, 0, 0, 6, 6), bg), "move undone")

	cur_tool = .Wand
	begin_drag(0, {6, 6})
	check(td.sel != nil && td.sel[7 * 24 + 7] != 0, "magic wand selects region")
	doc_sel_clear(td)
	cur_tool = .Eraser
	begin_drag(0, {6, 6})
	end_drag()
	check(cel_px(td, 0, 0, 6, 6).a == 0, "eraser erases")
	// tiled drawing wraps
	opts.tile = .X
	cur_tool = .Pencil
	opts.pixel_perf = false
	begin_drag(0, {-1, 10})
	end_drag()
	check(cel_px(td, 0, 0, 23, 10).a == 255, "tiled mode wraps")
	opts.tile = .Off
	// symmetry
	opts.sym_x = true
	begin_drag(0, {1, 15})
	end_drag()
	opts.sym_x = false
	check(cel_px(td, 0, 0, 22, 15).a == 255, "symmetry mirrors")
	// dither pattern
	opts.pattern = .Checker
	cur_tool = .Rect
	opts.fill_shape = true
	begin_drag(0, {0, 20})
	update_drag({3, 23})
	end_drag()
	opts.fill_shape = false
	opts.pattern = .Solid
	check(cel_px(td, 0, 0, 0, 20).a == 255 && cel_px(td, 0, 0, 1, 20).a == 0, "checker pattern")
	// pixel-perfect must not erase earlier parts of the same stroke when drawing back over them
	opts.pixel_perf = true
	opts.brush_size = 1
	cur_tool = .Pencil
	begin_drag(0, {2, 18})
	for x in 3 ..= 12 do update_drag({x, 18}) // horizontal run to the right
	for x := 11; x >= 4; x -= 1 do update_drag({x, 18}) // retrace back over it
	update_drag({4, 19}) // turn down: forms an L (5,18)-(4,18)-(4,19) with a pixel painted earlier in the stroke
	update_drag({4, 20})
	end_drag()
	all_there := true
	for x in 2 ..= 12 {
		if cel_px(td, 0, 0, x, 18).a == 0 do all_there = false
	}
	check(all_there, "pixel-perfect retrace keeps earlier pixels")
	history_undo(td)
	opts.pixel_perf = false

	// bezier curve tool
	cur_tool = .Curve
	begin_drag(0, {1, 1})
	update_drag({20, 1})
	end_drag()
	check(curve.active && curve.phase == 1, "curve: line placed, waiting for handles")
	check(cel_px(td, 0, 0, 10, 1).a == 255, "curve: initial straight line drawn")
	begin_drag(0, {7, 1}) // grabs control point 1 (nearest handle at x=7)
	update_drag({7, 12})
	end_drag()
	check(cel_px(td, 0, 0, 10, 1).a == 0 || cel_px(td, 0, 0, 12, 1).a == 0, "curve: bending moved pixels (preview redraws from original)")
	bent := 0
	for y in 2 ..< 24 {
		for x in 0 ..< 24 {
			if cel_px(td, 0, 0, x, y).a != 0 do bent += 1
		}
	}
	check(bent > 5, "curve: bent curve occupies other rows")
	check(color_eq(cel_px(td, 0, 0, 1, 1), Color{10, 20, 30, 255}) && color_eq(cel_px(td, 0, 0, 20, 1), Color{10, 20, 30, 255}), "curve: end points drawn")
	n_undo := len(td.undo)
	curve_commit()
	check(!curve.active && !stroke.active, "curve: commit closes stroke")
	history_undo(td)
	check(len(td.undo) == n_undo - 1 && cel_px(td, 0, 0, 1, 1).a == 0, "curve: one undo removes whole curve")
	// cancel restores the cel
	begin_drag(0, {2, 2})
	update_drag({15, 15})
	end_drag()
	curve_cancel()
	check(!curve.active && cel_px(td, 0, 0, 12, 12).a == 0, "curve: cancel leaves nothing behind")
	cur_tool = .Pencil

	// locked layer cannot be edited
	td.layers[0].locked = true
	n2 := len(td.undo)
	cur_tool = .Pencil
	begin_drag(0, {10, 10})
	end_drag()
	check(len(td.undo) == n2 && cel_px(td, 0, 0, 10, 10).a == 0, "locked layer rejects edits")
	td.layers[0].locked = false
	// playback
	doc_add_frame(td, false)
	set_frame(0)
	playing = true
	play_timer = 0
	playback_update(0.15)
	check(td.active_frame == 1, "playback advances frame")
	playing = false
	// tags adjust on insert/delete
	append(&td.tags, Tag{from = 1, to = 1})
	doc_add_frame(td, false)
	check(td.tags[0].from == 1, "tag stays before inserted frame")
	set_frame(0)
	doc_add_frame(td, false)
	check(td.tags[0].from == 2, "tag shifts after insert before it")
	doc = d

	// --- PNG + GIF ---
	img := make([]Color, 32 * 32)
	for i in 0 ..< len(img) {
		img[i] = Color{u8(rand.int_max(256)), u8(rand.int_max(256)), u8(rand.int_max(256)), 255}
	}
	check(save_png("selftest_tmp.png", img, 32, 32), "png save")
	back, bw, bh, lok := load_image_pixels("selftest_tmp.png")
	check(lok && bw == 32 && bh == 32, "png load")
	same := lok
	if lok {
		for i in 0 ..< len(img) {
			if !color_eq(img[i], back[i]) do same = false
		}
	}
	check(same, "png round trip")
	os.remove("selftest_tmp.png")
	{
		// Our JPEG decoder: progressive, 4:2:0 chroma, restart markers and
		// EXIF orientation 6. 8x4 quadrants in, 4x8 out, compared to libjpeg's decode.
		JPG := [?]u8 {
			255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 255, 225, 0, 34, 69, 120, 105,
			102, 0, 0, 77, 77, 0, 42, 0, 0, 0, 8, 0, 1, 1, 18, 0, 3, 0, 0, 0, 1, 0, 6, 0, 0, 0, 0, 0, 0, 255, 219, 0,
			67, 0, 2, 1, 1, 1, 1, 1, 2, 1, 1, 1, 2, 2, 2, 2, 2, 4, 3, 2, 2, 2, 2, 5, 4, 4, 3, 4, 6, 5, 6, 6, 6, 5, 6,
			6, 6, 7, 9, 8, 6, 7, 9, 7, 6, 6, 8, 11, 8, 9, 10, 10, 10, 10, 10, 6, 8, 11, 12, 11, 10, 12, 9, 10, 10, 10,
			255, 219, 0, 67, 1, 2, 2, 2, 2, 2, 2, 5, 3, 3, 5, 10, 7, 6, 7, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
			10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
			10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 255, 194, 0, 17, 8, 0, 4, 0, 8, 3, 1, 34, 0, 2, 17, 1, 3,
			17, 1, 255, 196, 0, 21, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 255, 196, 0, 21, 1, 1, 1,
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 7, 255, 221, 0, 4, 0, 1, 255, 218, 0, 12, 3, 1, 0, 2, 16, 3,
			16, 0, 0, 1, 162, 36, 232, 255, 196, 0, 23, 16, 0, 3, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 5, 7,
			255, 218, 0, 8, 1, 1, 0, 1, 5, 2, 197, 167, 39, 120, 255, 196, 0, 29, 17, 0, 2, 3, 0, 2, 3, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 1, 2, 3, 4, 17, 0, 5, 33, 49, 97, 255, 218, 0, 8, 1, 3, 1, 1, 63, 1, 171, 78, 159, 111, 0,
			183, 122, 53, 150, 86, 246, 238, 3, 49, 207, 3, 89, 180, 156, 0, 1, 240, 103, 63, 255, 196, 0, 33, 17, 0,
			1, 2, 4, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 7, 17, 33, 0, 5, 19, 34, 35, 49, 113, 255, 218, 0,
			8, 1, 2, 1, 1, 63, 1, 156, 4, 229, 211, 22, 54, 30, 19, 141, 180, 233, 209, 41, 218, 145, 86, 91, 38, 128,
			91, 187, 251, 143, 255, 196, 0, 30, 16, 0, 0, 4, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 17, 18, 19, 0,
			3, 5, 21, 34, 81, 113, 255, 218, 0, 8, 1, 1, 0, 6, 63, 2, 169, 93, 100, 186, 211, 40, 200, 64, 141, 122,
			228, 127, 255, 196, 0, 24, 16, 0, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 49, 1, 17, 193, 255, 218,
			0, 8, 1, 1, 0, 1, 63, 33, 208, 194, 75, 197, 161, 255, 218, 0, 12, 3, 1, 0, 2, 0, 3, 0, 0, 0, 16, 3, 255,
			196, 0, 23, 17, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 17, 33, 0, 255, 218, 0, 8, 1, 3, 1, 1,
			63, 16, 185, 181, 219, 115, 33, 169, 5, 128, 48, 14, 255, 196, 0, 24, 17, 1, 0, 3, 1, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 1, 0, 17, 33, 129, 255, 218, 0, 8, 1, 2, 1, 1, 63, 16, 95, 185, 36, 1, 139, 74, 163, 82,
			186, 179, 255, 196, 0, 25, 16, 1, 0, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 17, 0, 1, 33, 65, 240, 255,
			218, 0, 8, 1, 1, 0, 1, 63, 16, 234, 30, 116, 173, 168, 96, 110, 127, 255, 217,
		}
		REF := [?]u8 {
			39, 63, 223, 77, 48, 167, 192, 53, 92, 231, 39, 38, 36, 60, 222, 82, 51, 171, 189, 50, 89, 234, 40, 40, 40,
			62, 226, 79, 47, 170, 192, 49, 92, 234, 38, 39, 54, 66, 148, 78, 61, 113, 153, 79, 70, 174, 68, 29, 226,
			224, 139, 214, 231, 139, 104, 163, 57, 95, 175, 62, 240, 227, 60, 211, 243, 80, 66, 191, 37, 34, 204, 54,
			244, 228, 70, 210, 239, 85, 70, 189, 45, 35, 200, 61, 243, 224, 68, 215, 241, 90, 68, 185, 44, 39, 201, 64,
		}
		check(write_file("selftest_tmp.jpg", JPG[:]), "jpg save")
		jb, jbw, jbh, jok := load_image_pixels("selftest_tmp.jpg")
		check(jok && jbw == 4 && jbh == 8, "jpg load + EXIF rotation")
		worst := 0
		if jok {
			for p, i in jb {
				for ch in 0 ..< 3 do worst = max(worst, abs(int(p[ch]) - int(REF[i * 3 + ch])))
			}
			delete(jb)
		}
		check(jok && worst <= 3, fmt.tprintf("jpg matches libjpeg (max diff %d)", worst))
		os.remove("selftest_tmp.jpg")
	}

	// many colours -> median cut; compare decoded frame loosely
	gd := doc_new(32, 32, "gif")
	copy(gd.layers[0].cels[0].pix, img)
	append(&docs, gd)
	doc = gd
	gif := gif_encode(gd, 1, true)
	check(len(gif) > 100 && string(gif[:6]) == "GIF89a", "gif header")
	cpath := "selftest_tmp.gif"
	check(write_file(cpath, gif), "gif write")
	gp, gw, gh, gok := load_image_pixels(cpath)
	check(gok && gw == 32 && gh == 32, "gif decodes with stb_image (LZW valid)")
	if gok {
		// average error should be modest for 255 colours out of random data
		tot := 0
		for i in 0 ..< len(gp) {
			tot += abs(int(gp[i].r) - int(img[i].r)) + abs(int(gp[i].g) - int(img[i].g)) + abs(int(gp[i].b) - int(img[i].b))
		}
		fmt.printf("       mean abs channel error: %.1f\n", f32(tot) / f32(len(gp) * 3))
		check(f32(tot) / f32(len(gp) * 3) < 40, "gif quantisation error reasonable")
	}
	os.remove(cpath)
	// exact palette gif
	ed := doc_new(8, 8, "exact")
	for i in 0 ..< 64 {
		ed.layers[0].cels[0].pix[i] = Color{u8((i % 4) * 80), u8((i / 8) * 30), 100, 255}
	}
	doc = ed
	append(&docs, ed)
	gif2 := gif_encode(ed, 2, false)
	write_file(cpath, gif2)
	gp2, gw2, gh2, gok2 := load_image_pixels(cpath)
	check(gok2 && gw2 == 16 && gh2 == 16, "exact gif decodes (scaled x2)")
	if gok2 {
		okp := true
		for y in 0 ..< 16 {
			for x in 0 ..< 16 {
				a := ed.layers[0].cels[0].pix[(y / 2) * 8 + x / 2]
				if !color_eq(a, gp2[y * 16 + x]) do okp = false
			}
		}
		check(okp, "exact gif pixels identical")
	}
	os.remove(cpath)

	// QOI (stb_image has no QOI decoder; core:image/qoi reads it)
	{
		src := [4]Color{{255, 0, 0, 255}, {0, 255, 0, 128}, {0, 0, 255, 0}, {10, 20, 30, 255}}
		img := image.Image{width = 2, height = 2, channels = 4, depth = 8}
		bytes.buffer_write(&img.pixels, slice.to_bytes(src[:]))
		out: bytes.Buffer
		err := qoi.save_to_buffer(&out, &img)
		qp, qw, qh, qok := decode_image(bytes.buffer_to_bytes(&out), ".qoi")
		check(err == nil && qok && qw == 2 && qh == 2 && slice.equal(qp, src[:]), "qoi decodes")
		delete(qp)
		bytes.buffer_destroy(&out)
		bytes.buffer_destroy(&img.pixels)
	}

	selftest_tool_groups()

	// --- UI scale ---
	check(ui_scale_auto(1920, 1080, 1) == 150, "auto scale on a 1080p display")
	check(ui_scale_auto(2560, 1440, 1) == 200, "auto scale on a 1440p display")
	check(ui_scale_auto(3840, 2160, 1) == 300, "auto scale on a 4K display")
	check(ui_scale_auto(2560, 1600, 1) == 200, "auto scale on a 16:10 display goes by its width")
	check(ui_scale_auto(3440, 1440, 1) == 200, "auto scale on an ultrawide display goes by its height")
	check(ui_scale_auto(1366, 768, 1) == 100, "auto scale never goes below 100%")
	check(ui_scale_auto(15360, 8640, 1) == 400, "auto scale stops at the slider's maximum")
	check(ui_scale_auto(2560, 1440, 2.5) == 250, "auto scale follows a larger OS scale")
	check(ui_scale_parse(0) == 0, "a saved scale of 0 stays auto")
	check(ui_scale_parse(2) == 200, "a saved 2x from older settings reads as 200%")
	check(ui_scale_parse(150) == 150, "a saved percentage is kept")
	check(ui_scale_parse(137) == 125, "a saved percentage lands on a slider step")
	check(ui_scale_parse(9000) == UI_SCALE_MAX, "a saved percentage stays in range")
	check(ui_scale_fit(1632, 918) == 150, "a window limits the scale to what fits its layout")
	check(ui_scale_fit(900, 560) == 100, "the smallest window fits 100%")
	check(ui_scale_fit(300, 200) == 100, "the scale never drops below 100%, however small the window")

	fmt.printf("== %d failures ==\n", fails)
	return fails
}

// Tool groups: hotkeys cycle a group's tools, colour groups cycle the foreground colour,
// hotkeys can be reassigned, and the set-up survives the preferences file.
@(private = "file")
selftest_tool_groups :: proc() {
	press :: proc(k: KeyboardKey) {
		gfx.key_pressed = {}
		gfx.key_pressed[key_scancode(k)] = true
	}
	ui.ctrl, ui.shift, ui.alt = false, false, false
	tool_groups_default()
	check(len(tool_groups) == 4 && tool_groups[0].key == .ONE, "default tool groups")
	select_tool_in_group(.Lasso)
	tool_group_activate(0)
	check(cur_tool == .Pencil, "group hotkey picks its first tool")
	tool_group_activate(0)
	check(cur_tool == .Eraser, "pressing it again cycles to the next tool")
	tool_group_activate(1)
	check(cur_tool == .Line && current_group() == 1, "another group's hotkey switches group")
	tool_group_activate(0)
	check(cur_tool == .Eraser, "returning to a group picks the tool last used from it")
	run_cmd(.Tool_Zoom)
	check(cur_tool == .Zoom && current_group() == 3, "a tool shortcut selects the group holding the tool")

	press(.TWO)
	check(tool_groups_hotkeys() && cur_tool == .Line, "group hotkeys run from the keyboard")
	ui.ctrl = true
	press(.THREE)
	check(!tool_groups_hotkeys() && cur_tool == .Line, "Ctrl+digit is left to the zoom shortcuts")
	ui.ctrl = false

	// reassigning a hotkey takes it away from the group that had it
	group_key_wait = 3
	press(.TWO)
	check(tool_groups_key_capture() && tool_groups[3].key == .TWO && tool_groups[1].key == .KEY_NULL && group_key_wait == -1, "assign a group hotkey")
	group_key_wait = 3
	press(.BACKSPACE)
	tool_groups_key_capture()
	check(tool_groups[3].key == .KEY_NULL, "Backspace clears a group hotkey")
	gfx.key_pressed = {}

	// colour group
	cg := Tool_Group{key = .Q}
	append(&cg.colors, Color{255, 0, 0, 255}, Color{0, 255, 0, 255}, Color{0, 0, 255, 255})
	name_set(&cg.name, "Skin")
	append(&tool_groups, cg)
	ci := len(tool_groups) - 1
	tool_select_before := cur_tool
	set_fg(Color{1, 2, 3, 255})
	tool_group_activate(ci)
	check(fg == Color{255, 0, 0, 255} && cur_tool == tool_select_before, "colour group hotkey sets the foreground, not the tool")
	tool_group_activate(ci)
	check(fg == Color{0, 255, 0, 255}, "colour group hotkey cycles its colours")
	picker_set_fg(Color{9, 99, 199, 255})
	check(tool_groups[ci].colors[1] == Color{9, 99, 199, 255}, "the colour picker edits the linked group colour")
	set_fg(Color{0, 0, 0, 255})
	check(color_linked() == nil, "picking a colour elsewhere unlinks the group colour")

	// preferences round trip
	name_set(&tool_groups[0].name, group_clean_name("My: Tools;"))
	saved := tool_groups_serialize()
	tool_groups_default()
	tool_groups_parse(saved)
	check(len(tool_groups) == 5 && name_str(&tool_groups[0].name) == "My Tools" && tool_groups[0].key == .ONE, "groups survive the preferences file")
	check(len(tool_groups[1].tools) == 4 && tool_groups[1].key == .KEY_NULL && tool_groups[3].tools[2] == .Zoom, "group tools and hotkeys are restored")
	check(len(tool_groups[4].colors) == 3 && tool_groups[4].key == .Q && tool_groups[4].colors[1] == Color{9, 99, 199, 255}, "colour groups are restored")

	// switches: off -> on with its settings shown; picking a tool brings the tool's settings back;
	// clicking while on but not shown shows them; clicking while shown turns it off
	tool_groups_default()
	opts.grid, opts.onion = false, false
	tool_toggle(.Grid)
	check(opts.grid && options_switch_on && options_switch == .Grid, "clicking Grid turns it on and shows its settings")
	select_tool_in_group(.Pencil)
	check(opts.grid && !options_switch_on && cur_tool == .Pencil, "picking a tool brings its settings back")
	tool_toggle(.Grid)
	check(opts.grid && options_switch_on, "clicking Grid while it is on shows its settings")
	tool_toggle(.Grid)
	check(!opts.grid && !options_switch_on, "clicking Grid again turns it off")
	select_tool_in_group(.Onion)
	check(opts.onion && cur_tool == .Pencil, "a switch never becomes the active tool")
	switch_set(.Onion, false)
	opts.sym_x, opts.sym_y = false, true
	switch_set(.Symmetry, false)
	check(!opts.sym_x && !opts.sym_y, "Symmetry off clears both mirrors")
	switch_set(.Symmetry, true)
	check(!opts.sym_x && opts.sym_y, "Symmetry comes back as it was")
	switch_set(.Symmetry, false)
	opts.tile = .Y
	switch_set(.Tiling, false)
	switch_set(.Tiling, true)
	check(opts.tile == .Y, "Tiled Mode comes back as it was")
	switch_set(.Tiling, false)
	sg := Tool_Group{key = .G}
	append(&sg.tools, Tool.Grid)
	append(&tool_groups, sg)
	tool_group_activate(len(tool_groups) - 1)
	check(opts.grid && cur_tool == .Pencil, "a group of only switches flips its first one")
	switch_set(.Grid, false)
	ordered_remove(&tool_groups, len(tool_groups) - 1)

	// pattern groups
	pg := Tool_Group{key = .P}
	append(&pg.patterns, Pattern.Checker, Pattern.Dots)
	append(&tool_groups, pg)
	pgi := len(tool_groups) - 1
	opts.pattern = .Solid
	tool_group_activate(pgi)
	check(opts.pattern == .Checker && cur_tool == .Pencil, "pattern group hotkey picks its first pattern")
	tool_group_activate(pgi)
	check(opts.pattern == .Dots, "pattern group hotkey cycles its patterns")
	resize(&tool_groups[pgi].patterns, 1)
	tool_group_activate(pgi)
	check(opts.pattern == .Checker, "a lone pattern turns on")
	tool_group_activate(pgi)
	check(opts.pattern == .Solid, "and off again")

	// own brush settings: group 0 (Draw) keeps its own, the other groups share theirs
	select_tool_in_group(.Pencil, 0)
	opts.brush_size, opts.pattern = 3, .Solid
	group_set_own(0, true)
	opts.brush_size, opts.pattern = 7, .Dots
	select_tool_in_group(.Line, 1)
	check(opts.brush_size == 3 && opts.pattern == .Solid, "leaving a group with its own settings restores the shared ones")
	opts.brush_size = 2
	select_tool_in_group(.Eraser, 0)
	check(opts.brush_size == 7 && opts.pattern == .Dots, "returning to it loads its own settings")
	select_tool_in_group(.Line, 1)
	check(opts.brush_size == 2, "the shared settings are kept while away")

	// switches, patterns and own settings survive the preferences file
	saved = tool_groups_serialize()
	tool_groups_parse(saved)
	check(len(tool_groups) == 5 && tool_groups[3].tools[3] == .Grid && tool_groups[3].tools[4] == .Onion, "switches in groups are restored")
	check(len(tool_groups[4].patterns) == 1 && tool_groups[4].key == .P, "pattern groups are restored")
	check(tool_groups[0].own && tool_groups[0].brush.size == 7 && tool_groups[0].brush.pattern == .Dots && !tool_groups[1].own, "own brush settings are restored")
	select_tool_in_group(.Pencil, 0)
	check(opts.brush_size == 7, "and loaded with the group")
	tool_group_remove(0)
	check(opts.brush_size == 2 && active_group == -1, "removing an own-settings group brings the shared ones back")

	// workspaces
	workspace_builtin(3)
	check(len(tool_groups) == 4 && tool_groups[0].own && tool_groups[0].brush.pixel_perf && len(tool_groups[2].patterns) == 4, "Shading workspace")
	check(cur_tool == .Pencil && opts.pixel_perf, "a workspace starts with its first tool and that group's settings")
	text := strings.clone(workspace_text(), context.temp_allocator)
	workspace_builtin(0)
	check(workspace_apply_text(text) && len(tool_groups) == 4 && tool_groups[1].own && tool_groups[1].brush.size == 3 && tool_groups[2].key == .THREE, "workspace text round trip")
	check(!workspace_apply_text("hello=1\n") && len(tool_groups) == 4, "text without groups is not a workspace")
	workspace_builtin(0)

	// snap to grid
	opts.grid, opts.snap, opts.grid_w, opts.grid_h, opts.grid_ox, opts.grid_oy = true, true, 8, 8, 0, 0
	a, b := snap_cells({3, 3}, {10, 10})
	check(a == {0, 0} && b == {7, 7}, "a marquee drag snaps to whole grid cells")
	a, b = snap_cells({10, 12}, {3, 3})
	check(a == {7, 15} && b == {0, 0}, "snapping keeps the drag's direction")
	a, b = snap_cells({2, 2}, {2, 2})
	check(a == {0, 0} && b == {7, 7}, "a click selects the cell under it")
	check(snap_point({5, 2}) == {8, 0}, "line end points snap to grid crossings")
	drag.start = {0, 0}
	check(drag_delta({5, -3}) == {8, 0}, "moves go in whole cells")
	opts.grid = false
	a, b = snap_cells({3, 3}, {10, 10})
	check(a == {3, 3} && b == {10, 10} && drag_delta({5, -3}) == {5, -3}, "no snapping while the grid is hidden")
	opts.snap = false
	drag = {}

	// layers dragged to a new place in the timeline
	{
		ld := doc_new(4, 4, "layers")
		saved_doc := doc
		doc = ld
		doc_add_layer(ld)
		doc_add_layer(ld)
		for &l, i in ld.layers do name_set(&l.name, fmt.tprintf("L%d", i))
		check(doc_move_layer_to(ld, 0, 2) && name_str(&ld.layers[2].name) == "L0" && name_str(&ld.layers[0].name) == "L1" && ld.active_layer == 2, "move a layer to another place")
		history_undo(ld)
		check(name_str(&ld.layers[0].name) == "L0" && name_str(&ld.layers[2].name) == "L2", "moving a layer undoes in one step")
		doc = saved_doc
		doc_destroy(ld)
	}

	// recent colours
	clear(&recent)
	recent_push(Color{1, 1, 1, 255})
	recent_push(Color{2, 2, 2, 255})
	recent_push(Color{1, 1, 1, 255})
	check(len(recent) == 2 && recent[0] == Color{1, 1, 1, 255}, "recent colours: newest first, no repeats")
	for i in 0 ..< 40 do recent_push(Color{u8(i), 9, 9, 255})
	check(len(recent) == RECENT_MAX, "recent colours are capped")
	if stroke_begin(false, Color{77, 66, 55, 255}, bg) do stroke_end()
	check(recent[0] == Color{77, 66, 55, 255}, "painting adds the colour to the recent ones")

	tool_groups_default()

	selftest_files()
}

@(private = "file")
selftest_files :: proc() {
	dir := "selftest_files"
	os.remove_all(dir)
	os.make_directory(dir)
	defer os.remove_all(dir)
	join :: proc(dir, name: string) -> string {
		return fmt.tprintf("%s/%s", dir, name)
	}

	// --- the folder listing ---
	green := Color{0, 255, 0, 255}
	small := make([]Color, 4 * 2, context.temp_allocator)
	slice.fill(small, green)
	check(save_png(join(dir, "b.png"), small, 4, 2), "file browser: sample image written")
	save_png(join(dir, "A.PNG"), small, 4, 2)
	save_png(join(dir, ".hidden.png"), small, 4, 2)
	write_file(join(dir, "notes.txt"), transmute([]u8)string("x"))
	os.make_directory(join(dir, "sub"))
	files_set_dir(dir)
	check(len(files) == 3, "file browser lists images and folders only")
	if len(files) == 3 {
		check(files[0].is_dir && files[0].name == "sub", "file browser: folders come first")
		check(files[1].name == "A.PNG" && files[2].name == "b.png", "file browser: names sort ignoring case")
	}

	check(files_parent("C:\\art\\walk") == "C:\\art", "parent folder")
	check(files_parent("C:\\art") == "C:\\", "parent of a top folder is the drive")
	check(files_parent("C:\\") == "", "a drive has no parent")
	check(files_parent("/art") == "/" && files_parent("/") == "", "parent folders on unix paths")

	// --- thumbnails ---
	pix, w, h, iw, ih, ok := thumb_load(join(dir, "b.png"))
	check(ok && w == 4 && h == 2 && iw == 4 && ih == 2 && pix[0] == green, "small images are their own thumbnail")
	delete(pix)
	big := make([]Color, 600 * 300, context.temp_allocator)
	slice.fill(big, green)
	save_png(join(dir, "big.png"), big, 600, 300)
	pix, w, h, iw, ih, ok = thumb_load(join(dir, "big.png"))
	check(ok && w == THUMB_MAX && h == THUMB_MAX / 2 && iw == 600 && ih == 300, "large images shrink, keeping their shape")
	if ok do check(pix[0] == green, "shrinking keeps the colour")
	delete(pix)
	half := []Color{{255, 0, 0, 255}, {0, 0, 0, 0}, {255, 0, 0, 255}, {0, 0, 0, 0}}
	shrunk, sw, sh := thumb_shrink(half, 2, 2, 1)
	check(sw == 1 && sh == 1 && shrunk[0] == Color{255, 0, 0, 127}, "transparent pixels do not darken a thumbnail")
	delete(shrunk)
	pd := doc_new(8, 8, "p")
	pd.layers[0].cels[0].pix[0] = green
	write_file(join(dir, "p.pxl"), project_encode(pd))
	doc_destroy(pd)
	pix, w, h, iw, ih, ok = thumb_load(join(dir, "p.pxl"))
	check(ok && w == 8 && h == 8 && pix[0] == green, "projects get a thumbnail")
	delete(pix)
	write_file(join(dir, "bad.png"), transmute([]u8)string("not an image"))
	_, _, _, _, _, ok = thumb_load(join(dir, "bad.png"))
	check(!ok, "unreadable images report failure")

	// --- dropping onto the canvas ---
	d := doc_new(16, 16, "drop")
	append(&docs, d)
	doc = d
	layers := len(d.layers)
	undo := len(d.undo)
	import_as_layer(join(dir, "b.png"), IVec{8, 8})
	check(len(d.layers) == layers + 1 && d.active_layer == layers, "a drop adds a layer above the active one")
	check(len(d.undo) == undo + 1, "a drop can be undone")
	check(name_str(&d.layers[d.active_layer].name) == "b", "the layer is named after the file")
	check(cel_px(d, d.active_layer, 0, 6, 7) == green && cel_px(d, d.active_layer, 0, 9, 8) == green, "the image is centred on the drop point")
	check(cel_px(d, d.active_layer, 0, 5, 7).a == 0 && cel_px(d, d.active_layer, 0, 10, 8).a == 0, "nothing lands outside the image")
	import_as_layer(join(dir, "b.png"), IVec{0, 0})
	check(cel_px(d, d.active_layer, 0, 0, 0) == green && cel_px(d, d.active_layer, 0, 1, 0) == green, "a drop at the edge is cropped by the canvas")
	import_as_layer(join(dir, "b.png"), IVec{-100, -100})
	check(cel_px(d, d.active_layer, 0, 0, 0) == green, "a drop beside the sprite still leaves part of it on the canvas")
	import_as_layer(join(dir, "b.png"))
	check(cel_px(d, d.active_layer, 0, 3, 1) == green && cel_px(d, d.active_layer, 0, 4, 1).a == 0, "the menu import still uses the top left corner")
	files_clear()
	delete(files_dir)
	files_dir = ""
}
