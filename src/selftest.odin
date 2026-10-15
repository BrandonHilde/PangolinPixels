package pangolin

import "core:fmt"
import "core:math/rand"
import "core:os"
import rl "vendor:raylib"

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
		pop(&docs)
		doc_destroy(fd)
		doc = d
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
	check(gok && gw == 32 && gh == 32, "gif decodes with raylib (LZW valid)")
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

	fmt.printf("== %d failures ==\n", fails)
	return fails
}
