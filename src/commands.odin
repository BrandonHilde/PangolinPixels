package pangolin

import "core:fmt"
import rl "vendor:raylib"

Cmd :: enum {
	None,
	// file
	New,
	Open,
	Save,
	Save_As,
	Import_Image,
	Import_Layer,
	Import_Sheet,
	Pixel_Art_Convert,
	Export,
	Export_PNG_Quick,
	Close_Doc,
	Exit,
	Palette_Load,
	Palette_Save,
	Palette_From_Sprite,
	// edit
	Undo,
	Redo,
	Cut,
	Copy,
	Paste,
	Delete,
	Select_All,
	Deselect,
	Invert_Sel,
	Select_Opaque,
	Fill_Fg,
	Fill_Bg,
	Flip_H,
	Flip_V,
	Adjust,
	Invert_Colors,
	Grayscale,
	Outline,
	Replace_Color,
	Pixel_Art_Sprite,
	// sprite
	Canvas_Size,
	Scale_Sprite,
	Crop_Sel,
	Trim,
	Rotate_CW,
	Rotate_CCW,
	Rotate_180,
	Flip_Sprite_H,
	Flip_Sprite_V,
	// layer
	Layer_New,
	Layer_Dup,
	Layer_Del,
	Layer_Up,
	Layer_Down,
	Layer_Merge,
	Layer_Flatten,
	Layer_Props,
	Layer_Vis,
	Layer_Lock,
	// frame
	Frame_New,
	Frame_Dup,
	Frame_Del,
	Frame_Left,
	Frame_Right,
	Frame_Props,
	Frame_Reverse,
	Frame_Next,
	Frame_Prev,
	Frame_First,
	Frame_Last,
	Tags,
	Play,
	// view
	Zoom_In,
	Zoom_Out,
	Zoom_Fit,
	Zoom_1,
	Zoom_2,
	Zoom_4,
	Zoom_8,
	Zoom_16,
	Toggle_Grid,
	Toggle_Pixel_Grid,
	Toggle_Onion,
	Toggle_Sym_X,
	Toggle_Sym_Y,
	Cycle_Tile,
	Toggle_Checks,
	Toggle_Timeline,
	Toggle_Preview,
	Grid_Settings,
	Canvas_Bg,
	Preferences,
	// tools (must stay in the same order as `Tool`)
	Tool_Pencil,
	Tool_Eraser,
	Tool_Line,
	Tool_Rect,
	Tool_Ellipse,
	Tool_Curve,
	Tool_Bucket,
	Tool_Picker,
	Tool_Select_Rect,
	Tool_Select_Ellipse,
	Tool_Lasso,
	Tool_Wand,
	Tool_Move,
	Tool_Spray,
	Tool_Hand,
	Tool_Zoom,
	Swap_Colors,
	Default_Colors,
	Brush_Smaller,
	Brush_Bigger,
	Help_Keys,
	About,
}

Shortcut :: struct {
	cmd:                Cmd,
	key:                rl.KeyboardKey,
	ctrl, shift, alt:   bool,
}

SHORTCUTS := [?]Shortcut {
	{.New, .N, true, false, false},
	{.Open, .O, true, false, false},
	{.Save, .S, true, false, false},
	{.Save_As, .S, true, true, false},
	{.Export, .E, true, true, false},
	{.Close_Doc, .W, true, false, false},
	{.Exit, .Q, true, false, false},
	{.Undo, .Z, true, false, false},
	{.Redo, .Y, true, false, false},
	{.Redo, .Z, true, true, false},
	{.Cut, .X, true, false, false},
	{.Copy, .C, true, false, false},
	{.Paste, .V, true, false, false},
	{.Delete, .DELETE, false, false, false},
	{.Delete, .BACKSPACE, false, false, false},
	{.Select_All, .A, true, false, false},
	{.Deselect, .D, true, false, false},
	{.Deselect, .ESCAPE, false, false, false},
	{.Invert_Sel, .I, true, false, false},
	{.Layer_New, .N, false, true, false},
	{.Layer_Merge, .E, true, false, false},
	{.Frame_New, .N, false, false, true},
	{.Play, .ENTER, false, false, false},
	{.Frame_Prev, .COMMA, false, false, false},
	{.Frame_Next, .PERIOD, false, false, false},
	{.Frame_First, .HOME, false, false, false},
	{.Frame_Last, .END, false, false, false},
	{.Zoom_In, .EQUAL, false, false, false},
	{.Zoom_In, .KP_ADD, false, false, false},
	{.Zoom_Out, .MINUS, false, false, false},
	{.Zoom_Out, .KP_SUBTRACT, false, false, false},
	{.Zoom_Fit, .ZERO, false, false, false},
	{.Zoom_1, .ONE, false, false, false},
	{.Zoom_2, .TWO, false, false, false},
	{.Zoom_4, .THREE, false, false, false},
	{.Zoom_8, .FOUR, false, false, false},
	{.Zoom_16, .FIVE, false, false, false},
	{.Toggle_Grid, .APOSTROPHE, true, false, false},
	{.Toggle_Pixel_Grid, .APOSTROPHE, true, true, false},
	{.Toggle_Onion, .O, false, false, true},
	{.Toggle_Sym_X, .X, false, true, false},
	{.Toggle_Sym_Y, .Y, false, true, false},
	{.Cycle_Tile, .T, false, true, false},
	{.Tool_Pencil, .B, false, false, false},
	{.Tool_Eraser, .E, false, false, false},
	{.Tool_Line, .L, false, false, false},
	{.Tool_Rect, .U, false, false, false},
	{.Tool_Ellipse, .O, false, false, false},
	{.Tool_Curve, .C, false, false, false},
	{.Tool_Bucket, .G, false, false, false},
	{.Tool_Picker, .I, false, false, false},
	{.Tool_Select_Rect, .M, false, false, false},
	{.Tool_Select_Ellipse, .M, false, true, false},
	{.Tool_Lasso, .Q, false, false, false},
	{.Tool_Wand, .W, false, false, false},
	{.Tool_Move, .V, false, false, false},
	{.Tool_Spray, .S, false, false, false},
	{.Tool_Hand, .H, false, false, false},
	{.Tool_Zoom, .Z, false, false, false},
	{.Swap_Colors, .X, false, false, false},
	{.Default_Colors, .D, false, false, false},
	{.Brush_Smaller, .LEFT_BRACKET, false, false, false},
	{.Brush_Bigger, .RIGHT_BRACKET, false, false, false},
	{.Help_Keys, .F1, false, false, false},
}

key_name :: proc(k: rl.KeyboardKey) -> string {
	#partial switch k {
	case .A ..= .Z:
		return fmt.tprintf("%c", rune(int(k)))
	case .ZERO ..= .NINE:
		return fmt.tprintf("%c", rune(int(k)))
	case .DELETE:
		return "Del"
	case .BACKSPACE:
		return "Backspace"
	case .ESCAPE:
		return "Esc"
	case .ENTER:
		return "Enter"
	case .COMMA:
		return ","
	case .PERIOD:
		return "."
	case .HOME:
		return "Home"
	case .END:
		return "End"
	case .EQUAL:
		return "+"
	case .KP_ADD:
		return "Num+"
	case .MINUS:
		return "-"
	case .KP_SUBTRACT:
		return "Num-"
	case .APOSTROPHE:
		return "'"
	case .LEFT_BRACKET:
		return "["
	case .RIGHT_BRACKET:
		return "]"
	case .F1:
		return "F1"
	}
	return "?"
}

shortcut_text :: proc(cmd: Cmd) -> string {
	for s in SHORTCUTS {
		if s.cmd == cmd {
			return fmt.tprintf(
				"%s%s%s%s",
				s.ctrl ? "Ctrl+" : "",
				s.shift ? "Shift+" : "",
				s.alt ? "Alt+" : "",
				key_name(s.key),
			)
		}
	}
	return ""
}

shortcuts_update :: proc() {
	if ui.focus_id != 0 || dialog.kind != .None || popup.open {
		return
	}
	// A bezier curve being edited is applied with Enter and cancelled with Escape;
	// other shortcuts are ignored until it is finished.
	if curve.active {
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) {
			curve_commit()
		} else if rl.IsKeyPressed(.ESCAPE) {
			curve_cancel()
		}
		return
	}
	// Key-hold conveniences must not trigger commands while dragging on the canvas.
	for s in SHORTCUTS {
		if !(rl.IsKeyPressed(s.key) || (s.cmd == .Frame_Prev || s.cmd == .Frame_Next || s.cmd == .Brush_Smaller || s.cmd == .Brush_Bigger || s.cmd == .Undo || s.cmd == .Redo) && rl.IsKeyPressedRepeat(s.key)) {
			continue
		}
		if s.ctrl != ui.ctrl || s.shift != ui.shift || s.alt != ui.alt {
			continue
		}
		if drag.active {
			continue
		}
		run_cmd(s.cmd)
		return
	}
	// Nudge with arrow keys using the move tool
	if cur_tool == .Move && !drag.active {
		dx, dy := 0, 0
		if key_hit(.LEFT) do dx = -1
		if key_hit(.RIGHT) do dx = 1
		if key_hit(.UP) do dy = -1
		if key_hit(.DOWN) do dy = 1
		if dx != 0 || dy != 0 {
			s := ui.shift ? 8 : 1
			edit_nudge(dx * s, dy * s)
		}
	}
}

select_tool :: proc(t: Tool) {
	if t != .Curve {
		curve_commit()
	}
	cur_tool = t
}

zoom_steps := [?]f32{0.125, 0.25, 0.5, 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64}

zoom_step :: proc(z: f32, dir: int) -> f32 {
	if dir > 0 {
		for s in zoom_steps {
			if s > z + 0.001 {
				return s
			}
		}
		return zoom_steps[len(zoom_steps) - 1]
	}
	#reverse for s in zoom_steps {
		if s < z - 0.001 {
			return s
		}
	}
	return zoom_steps[0]
}

// Zoom keeping the canvas point under (sx, sy) fixed.
zoom_at :: proc(nz: f32, sx, sy: f32) {
	z := clamp(nz, 0.125, 64)
	cx := (sx - doc.ox) / doc.zoom
	cy := (sy - doc.oy) / doc.zoom
	doc.zoom = z
	doc.ox = sx - cx * z
	doc.oy = sy - cy * z
}

zoom_center :: proc(nz: f32) {
	vp := canvas_vp
	zoom_at(nz, f32(vp.x) + f32(vp.w) / 2, f32(vp.y) + f32(vp.h) / 2)
}

view_fit :: proc(d: ^Doc) {
	vp := canvas_vp
	if vp.w <= 0 || vp.h <= 0 {
		return
	}
	zx := f32(vp.w - 40) / f32(d.w)
	zy := f32(vp.h - 40) / f32(d.h)
	z := min(zx, zy)
	if z >= 1 {
		z = f32(int(z))
	}
	z = clamp(z, 0.125, 64)
	d.zoom = z
	d.ox = f32(vp.x) + (f32(vp.w) - f32(d.w) * z) / 2
	d.oy = f32(vp.y) + (f32(vp.h) - f32(d.h) * z) / 2
	d.view_init = true
}

run_cmd :: proc(cmd: Cmd) {
	if cmd != .None {
		curve_commit()
	}
	if cmd >= .Tool_Pencil && cmd <= .Tool_Zoom {
		select_tool(Tool(int(cmd) - int(Cmd.Tool_Pencil)))
		return
	}
	// Anything that edits stops playback
	#partial switch cmd {
	case .Undo, .Redo, .Cut, .Paste, .Delete, .Layer_New, .Layer_Dup, .Layer_Del, .Layer_Merge, .Layer_Flatten, .Frame_Del:
		stop_playback()
	}
	switch cmd {
	case .None:
	case .New:
		dialog_open(.New_Sprite)
	case .Open:
		file_open_dialog()
	case .Save:
		file_save(doc, false)
	case .Save_As:
		file_save(doc, true)
	case .Import_Image:
		file_import_dialog(.Image)
	case .Import_Layer:
		file_import_dialog(.Layer)
	case .Import_Sheet:
		file_import_dialog(.Sheet)
	case .Pixel_Art_Convert:
		pixelate_open_dialog()
	case .Pixel_Art_Sprite:
		pixelate_from_doc(doc)
	case .Export:
		dialog_open(.Export)
	case .Export_PNG_Quick:
		export_run(.PNG, 1, false)
	case .Close_Doc:
		request_close(doc)
	case .Exit:
		request_quit()
	case .Palette_Load:
		file_palette_load()
	case .Palette_Save:
		file_palette_save()
	case .Palette_From_Sprite:
		palette_from_sprite(doc)
		set_status("Palette extracted from sprite")

	case .Undo:
		if !history_undo(doc) {
			set_status("Nothing to undo")
		}
	case .Redo:
		if !history_redo(doc) {
			set_status("Nothing to redo")
		}
	case .Cut:
		edit_copy(true)
	case .Copy:
		edit_copy(false)
	case .Paste:
		edit_paste()
	case .Delete:
		edit_clear()
	case .Select_All:
		history_push(doc)
		doc_sel_all(doc)
	case .Deselect:
		if doc.sel != nil {
			history_push(doc)
			doc_sel_clear(doc)
		}
	case .Invert_Sel:
		history_push(doc)
		doc_sel_invert(doc)
	case .Select_Opaque:
		edit_select_opaque()
	case .Fill_Fg:
		edit_fill(fg)
	case .Fill_Bg:
		edit_fill(bg)
	case .Flip_H:
		edit_flip(true)
	case .Flip_V:
		edit_flip(false)
	case .Adjust:
		dialog_open(.Adjust)
	case .Invert_Colors:
		edit_invert_colors()
	case .Grayscale:
		edit_grayscale()
	case .Outline:
		dialog_open(.Outline)
	case .Replace_Color:
		dialog_open(.Replace_Color)

	case .Canvas_Size:
		dialog_open(.Canvas_Size)
	case .Scale_Sprite:
		dialog_open(.Scale)
	case .Crop_Sel:
		if !doc_crop_selection(doc) {
			set_status("Make a selection first")
		} else {
			doc.view_init = false
		}
	case .Trim:
		if doc_trim(doc) {
			doc.view_init = false
		} else {
			set_status("Nothing to trim")
		}
	case .Rotate_CW:
		doc_rotate(doc, 1)
		doc.view_init = false
	case .Rotate_CCW:
		doc_rotate(doc, 3)
		doc.view_init = false
	case .Rotate_180:
		doc_rotate(doc, 2)
	case .Flip_Sprite_H:
		doc_flip_sprite(doc, true)
	case .Flip_Sprite_V:
		doc_flip_sprite(doc, false)

	case .Layer_New:
		doc_add_layer(doc)
	case .Layer_Dup:
		doc_dup_layer(doc)
	case .Layer_Del:
		if !doc_delete_layer(doc) {
			set_status("Cannot delete the only layer")
		}
	case .Layer_Up:
		doc_move_layer(doc, 1)
	case .Layer_Down:
		doc_move_layer(doc, -1)
	case .Layer_Merge:
		if !doc_merge_down(doc) {
			set_status("No layer below to merge into")
		}
	case .Layer_Flatten:
		if !doc_flatten(doc) {
			set_status("Only one layer")
		}
	case .Layer_Props:
		dialog_open(.Layer_Props)
	case .Layer_Vis:
		l := &doc.layers[doc.active_layer]
		l.visible = !l.visible
		doc.comp_dirty = true
	case .Layer_Lock:
		l := &doc.layers[doc.active_layer]
		l.locked = !l.locked

	case .Frame_New:
		doc_add_frame(doc, false)
	case .Frame_Dup:
		doc_add_frame(doc, true)
	case .Frame_Del:
		if !doc_delete_frame(doc) {
			set_status("Cannot delete the only frame")
		}
	case .Frame_Left:
		doc_move_frame(doc, -1)
	case .Frame_Right:
		doc_move_frame(doc, 1)
	case .Frame_Props:
		dialog_open(.Frame_Props)
	case .Frame_Reverse:
		doc_reverse_frames(doc)
	case .Frame_Next:
		set_frame(doc.active_frame + 1 >= len(doc.frames) ? 0 : doc.active_frame + 1)
	case .Frame_Prev:
		set_frame(doc.active_frame - 1 < 0 ? len(doc.frames) - 1 : doc.active_frame - 1)
	case .Frame_First:
		set_frame(0)
	case .Frame_Last:
		set_frame(len(doc.frames) - 1)
	case .Tags:
		dialog_open(.Tags)
	case .Play:
		if playing {
			stop_playback()
		} else if len(doc.frames) > 1 {
			playing = true
			play_timer = 0
			play_dir = 1
		}

	case .Zoom_In:
		zoom_center(zoom_step(doc.zoom, 1))
	case .Zoom_Out:
		zoom_center(zoom_step(doc.zoom, -1))
	case .Zoom_Fit:
		view_fit(doc)
	case .Zoom_1:
		zoom_center(1)
	case .Zoom_2:
		zoom_center(2)
	case .Zoom_4:
		zoom_center(4)
	case .Zoom_8:
		zoom_center(8)
	case .Zoom_16:
		zoom_center(16)
	case .Toggle_Grid:
		opts.grid = !opts.grid
	case .Toggle_Pixel_Grid:
		opts.pixel_grid = !opts.pixel_grid
	case .Toggle_Onion:
		opts.onion = !opts.onion
		doc.comp_dirty = true
	case .Toggle_Sym_X:
		opts.sym_x = !opts.sym_x
	case .Toggle_Sym_Y:
		opts.sym_y = !opts.sym_y
	case .Cycle_Tile:
		opts.tile = Tile_Mode((int(opts.tile) + 1) % len(Tile_Mode))
		set_statusf("Tiled mode: %v", opts.tile)
	case .Toggle_Checks:
		opts.show_checks = !opts.show_checks
	case .Toggle_Timeline:
		show_timeline = !show_timeline
	case .Toggle_Preview:
		show_preview = !show_preview
	case .Grid_Settings:
		dialog_open(.Grid)
	case .Canvas_Bg:
		dialog_open(.Canvas_Bg)
	case .Preferences:
		dialog_open(.Prefs)

	case .Tool_Pencil ..= .Tool_Zoom:
	case .Swap_Colors:
		a, b := fg, bg
		set_fg(b)
		bg = a
	case .Default_Colors:
		set_fg(Color{0, 0, 0, 255})
		bg = Color{255, 255, 255, 255}
	case .Brush_Smaller:
		opts.brush_size = max(opts.brush_size - 1, 1)
	case .Brush_Bigger:
		opts.brush_size = min(opts.brush_size + 1, 64)
	case .Help_Keys:
		dialog_open(.Shortcuts)
	case .About:
		dialog_open(.About)
	}
}
