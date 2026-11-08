package pangolin

import "core:fmt"

// ---------------------------------------------------------------------------
// Tooltip text for commands and tools. The menus, the toolbar and the panel buttons all read it from here.
// cmd_help has no #partial, so the compiler asks for text whenever a command is added.
// These strings are constants: a popup item keeps its tip across frames.
// ---------------------------------------------------------------------------

cmd_help :: proc(c: Cmd) -> string {
	switch c {
	case .None:
		return ""
	case .New:
		return "Start a new sprite in its own tab. The next window asks for its size and background."
	case .Open:
		return "Open a .pxl project, an image or a .gpl palette. Images and projects get their own tab, a palette replaces the sprite's."
	case .Save:
		return "Save the sprite as a .pxl project with its layers, frames and tags, asking for a file name the first time."
	case .Save_As:
		return "Save the sprite as a .pxl project under a new file name."
	case .Import_Image:
		return "Open an image file as a new sprite in its own tab."
	case .Import_Layer:
		return "Add an image file to this sprite as a new layer above the current one. Anything outside the canvas is cropped."
	case .Import_Sheet:
		return "Slice a sprite sheet image into frames: the next window asks for the size of one frame. It opens as a new sprite."
	case .Pixel_Art_Convert:
		return "Shrink any image to a small size and map it to a palette, with a live preview. The result opens as a new sprite."
	case .Export:
		return "Save a flattened copy for use elsewhere: a PNG of this frame, a sprite sheet, an animated GIF or a PNG sequence."
	case .Export_PNG_Quick:
		return "Save the current frame as a PNG at full size, without asking about the format."
	case .Close_Doc:
		return "Close this sprite's tab. If it has unsaved changes you are asked first."
	case .Exit:
		return "Quit Pangolin Pixels. If any sprite has unsaved changes you are asked first."
	case .Palette_Load:
		return "Replace this sprite's palette with one from a GIMP .gpl file."
	case .Palette_Save:
		return "Save this sprite's palette as a GIMP .gpl file that other programs can read."
	case .Palette_From_Sprite:
		return "Replace the palette with the colors used in this sprite, up to 256 of them."
	case .Undo:
		return "Take back the last change."
	case .Redo:
		return "Bring back the change you just undid."
	case .Cut:
		return "Copy the selected pixels of the current layer to the clipboard and clear them. With no selection, the whole frame of that layer."
	case .Copy:
		return "Copy the selected pixels of the current layer to the clipboard. With no selection, the whole frame of that layer."
	case .Paste:
		return "Paste the clipboard into the current layer, at the place it was copied from."
	case .Delete:
		return "Clear the selected pixels of the current layer to transparent. With no selection, the whole frame of that layer."
	case .Select_All:
		return "Select the whole canvas."
	case .Deselect:
		return "Clear the selection, so that tools work on the whole canvas again."
	case .Invert_Sel:
		return "Select everything that is not selected, and the other way round."
	case .Select_Opaque:
		return "Select every pixel of the current layer that is not fully transparent."
	case .Fill_Fg:
		return "Fill the selection, or the whole frame of the current layer, with the foreground color."
	case .Fill_Bg:
		return "Fill the selection, or the whole frame of the current layer, with the background color."
	case .Flip_H:
		return "Mirror the selected pixels of the current layer left to right. With no selection, the whole frame of that layer."
	case .Flip_V:
		return "Mirror the selected pixels of the current layer top to bottom. With no selection, the whole frame of that layer."
	case .Adjust:
		return "Shift the hue, saturation and brightness of the current layer in this frame, with a live preview."
	case .Invert_Colors:
		return "Turn the selected pixels of the current layer into their opposite colors. Transparency is kept."
	case .Grayscale:
		return "Take the color out of the selected pixels of the current layer. Transparency is kept."
	case .Outline:
		return "Draw a one pixel outline in the foreground color around what is on the current layer in this frame."
	case .Replace_Color:
		return "Change one color into another on the current layer in this frame. The colors start as the foreground and background."
	case .Pixel_Art_Sprite:
		return "Shrink what you see in this frame and map it to a palette, with a live preview. The result opens as a new sprite."
	case .Canvas_Size:
		return "Change the sprite's size without scaling it: the canvas grows or is cut off around the anchor you choose."
	case .Scale_Sprite:
		return "Resize the sprite and everything in it, keeping hard pixel edges."
	case .Crop_Sel:
		return "Cut the canvas down to the selection's bounds, on all layers and frames."
	case .Trim:
		return "Cut the canvas down to what is drawn, removing fully transparent rows and columns around it."
	case .Rotate_CW:
		return "Turn the whole sprite a quarter turn clockwise, on all layers and frames."
	case .Rotate_CCW:
		return "Turn the whole sprite a quarter turn counter-clockwise, on all layers and frames."
	case .Rotate_180:
		return "Turn the whole sprite upside down, on all layers and frames."
	case .Flip_Sprite_H:
		return "Mirror the whole sprite left to right, on all layers and frames."
	case .Flip_Sprite_V:
		return "Mirror the whole sprite top to bottom, on all layers and frames."
	case .Layer_New:
		return "Add an empty layer above the current one."
	case .Layer_Dup:
		return "Copy the current layer, with its filters, to a new layer above it."
	case .Layer_Del:
		return "Remove the current layer in all frames. A sprite always keeps one layer."
	case .Layer_Up:
		return "Move the current layer one step towards the top, so it covers more."
	case .Layer_Down:
		return "Move the current layer one step towards the bottom, so more covers it."
	case .Layer_Merge:
		return "Combine the current layer with the one below it, in all frames. Its opacity, blend mode and filters are applied for good."
	case .Layer_Flatten:
		return "Combine all visible layers into one, in all frames. Their filters are applied for good."
	case .Layer_Props:
		return "Edit the current layer's name, opacity, blend mode, visibility and lock."
	case .Layer_Vis:
		return "Show or hide the current layer. A hidden layer is left out of exports too."
	case .Layer_Lock:
		return "Lock or unlock the current layer. Tools can't change a locked layer."
	case .Frame_New:
		return "Add an empty frame after the current one."
	case .Frame_Dup:
		return "Add a frame after the current one that starts as a copy of it."
	case .Frame_Del:
		return "Remove the current frame on all layers. A sprite always keeps one frame."
	case .Frame_Left:
		return "Move the current frame one step earlier in the animation."
	case .Frame_Right:
		return "Move the current frame one step later in the animation."
	case .Frame_Props:
		return "Set how long the current frame shows, or all frames at once."
	case .Frame_Reverse:
		return "Put all the frames in the opposite order, so the animation runs backwards."
	case .Frame_Next:
		return "Go to the next frame, back to the first after the last."
	case .Frame_Prev:
		return "Go to the previous frame, back to the last before the first."
	case .Frame_First:
		return "Go to the first frame of the animation."
	case .Frame_Last:
		return "Go to the last frame of the animation."
	case .Tags:
		return "Name ranges of frames, such as walk or jump, and set their playback direction. A tag can be played and exported on its own."
	case .Play:
		return "Start or stop the animation preview, using the range picked in the timeline."
	case .Zoom_In:
		return "Zoom in on the middle of the view, by one step."
	case .Zoom_Out:
		return "Zoom out from the middle of the view, by one step."
	case .Zoom_Fit:
		return "Zoom and scroll so the whole sprite fits in the window."
	case .Zoom_1:
		return "Show one sprite pixel as one screen pixel."
	case .Zoom_2:
		return "Show one sprite pixel as 2 x 2 screen pixels."
	case .Zoom_4:
		return "Show one sprite pixel as 4 x 4 screen pixels."
	case .Zoom_8:
		return "Show one sprite pixel as 8 x 8 screen pixels."
	case .Zoom_16:
		return "Show one sprite pixel as 16 x 16 screen pixels."
	case .Toggle_Grid:
		return "Show or hide the grid you set yourself, in Grid Settings, over the sprite."
	case .Toggle_Snap:
		return "Make selections, shapes and moves snap to the grid. Snapping only works while the grid is shown."
	case .Toggle_Pixel_Grid:
		return "Show thin lines between the sprite's pixels when zoomed in far enough."
	case .Toggle_Onion:
		return "Show faint copies of the neighboring frames behind this one, to help with drawing motion."
	case .Toggle_Sym_X:
		return "Mirror everything you draw across the middle of the sprite, left to right."
	case .Toggle_Sym_Y:
		return "Mirror everything you draw across the middle of the sprite, top to bottom."
	case .Cycle_Tile:
		return "Step through Off, X, Y and X+Y. Tiled mode repeats the sprite around the canvas and wraps drawing across its edges."
	case .Toggle_Checks:
		return "Show or hide the background behind transparent pixels. It is only a guide and is not part of the sprite."
	case .Toggle_Timeline:
		return "Show or hide the animation timeline under the canvas."
	case .Toggle_Files:
		return "Show or hide the file browser under the canvas: thumbnails of a folder's images, which you can drag onto the canvas."
	case .Toggle_Preview:
		return "Show or hide the Navigator: the whole sprite in small, with the part the canvas shows marked."
	case .Toggle_Canvas_Mode:
		return "Hide the side panels, tabs, timeline and status bar to give the canvas more room. A bar along the bottom keeps the tool groups."
	case .Grid_Settings:
		return "Set the grid's cell size and offset, and whether it is shown and snapped to."
	case .Canvas_Bg:
		return "Choose what shows behind transparent pixels: checkers or a solid color. It is only a guide and is not part of the sprite."
	case .Preferences:
		return "Set the canvas background and which guides are shown. These are remembered between sessions."
	case .UI_Scale:
		return "Make the whole interface larger or smaller, or let it size itself to fit your screen."
	case .Tool_Pencil ..= .Tool_Zoom:
		return TOOL_HELP[Tool(int(c) - int(Cmd.Tool_Pencil))]
	case .Swap_Colors:
		return "Swap the foreground and background colors."
	case .Default_Colors:
		return "Set the foreground color to black and the background color to white."
	case .Brush_Smaller:
		return "Make the brush one pixel smaller."
	case .Brush_Bigger:
		return "Make the brush one pixel larger."
	case .Help_Keys:
		return "List the keyboard shortcuts and the tool groups' hotkeys."
	case .About:
		return "Show what Pangolin Pixels is and what it was made with."
	case .Ws_Manage:
		return "Switch workspaces, save the current tool set-up under a name, or delete saved ones."
	case .Ws_Import:
		return "Load a .pxws workspace file, switch to it and keep a copy in your list."
	case .Ws_Export:
		return "Save the current tool set-up to a .pxws file, to back it up or use it on another computer."
	case .Ws_First ..= .Ws_Last:
		return "Switch to this saved workspace: its tool groups, their hotkeys and the brush settings."
	case .Recent_Clear:
		return "Empty the list of recently opened and saved files in the File menu. The files themselves stay where they are."
	case .Recent_First ..= .Recent_Last:
		return "Open this file again. It is one you opened or saved lately."
	}
	return ""
}

TOOL_HELP := [Tool]string {
	.Pencil         = "Drag to draw with the brush, left button in the foreground color, right button in the background color. Shift-click draws a line from the last point. Alt picks a color.",
	.Eraser         = "Drag to make pixels transparent, with the brush's size and shape. Shift-click erases a line from the last point.",
	.Line           = "Drag to draw a straight line. Shift keeps it to 45 degree steps, and the right button draws in the background color.",
	.Rect           = "Drag to draw a rectangle, outlined or filled depending on Filled. Shift makes a square, Ctrl draws from the center.",
	.Ellipse        = "Drag to draw an ellipse, outlined or filled depending on Filled. Shift makes a circle, Ctrl draws from the center.",
	.Curve          = "Drag to place a line, then drag the handles or the ends to bend it. Enter or a double-click applies the curve, Esc cancels it.",
	.Bucket         = "Click to fill with the foreground color, right-click for the background color. Tolerance and Contiguous decide which pixels are filled.",
	.Picker         = "Click a pixel to make its color the foreground color, right-click for the background. It sees the merged picture, not just the current layer.",
	.Select_Rect    = "Drag to select a rectangle. Drag inside a selection to move its outline. Shift adds to it, Alt subtracts, both together keep the overlap.",
	.Select_Ellipse = "Drag to select an ellipse. Drag inside a selection to move its outline. Shift adds to it, Alt subtracts, both together keep the overlap.",
	.Lasso          = "Drag around an area to select it freehand. Drag inside a selection to move its outline. Shift adds to it, Alt subtracts, both together keep the overlap.",
	.Wand           = "Click to select an area of similar color on the current layer. Tolerance and Contiguous decide how far it reaches. Shift adds, Alt subtracts.",
	.Move           = "Drag to move the selected pixels, or the whole layer in this frame if nothing is selected. Alt moves a copy, arrow keys nudge by one pixel and Shift+arrows by 8.",
	.Spray          = "Drag to scatter dots of color within the brush's area. Density sets how many, and the right button sprays the background color.",
	.Hand           = "Drag to scroll the view. Holding Space or dragging with the middle mouse button does this with any tool.",
	.Zoom           = "Click to zoom in, right-click to zoom out. The mouse wheel zooms with any tool.",
	.Grid           = "A switch: click to show the grid and its settings, again to hide it. It stays on while you use other tools.",
	.Symmetry       = "A switch: click to mirror what you draw and show its settings, again to stop. It stays on while you use other tools.",
	.Tiling         = "A switch: click to repeat the sprite around the canvas and show its settings, again to stop. Drawing wraps across the edges, for seamless tiles.",
	.Onion          = "A switch: click to show the neighboring frames faintly and show its settings, again to hide them. It stays on while you use other tools.",
}

// The one line the status bar shows for a tool. The longer story is in TOOL_HELP.
TOOL_HINT := [Tool]string {
	.Pencil         = "Draw with the brush. Shift-click: line from the last point",
	.Eraser         = "Erase to transparent. Shift-click: line from the last point",
	.Line           = "Drag a straight line. Shift: 45 degree steps",
	.Rect           = "Drag a rectangle. Shift: square, Ctrl: from the center",
	.Ellipse        = "Drag an ellipse. Shift: circle, Ctrl: from the center",
	.Curve          = "Drag a line, then bend it. Enter applies, Esc cancels",
	.Bucket         = "Click to fill an area of similar color",
	.Picker         = "Click to pick a color. Right-click: for the background",
	.Select_Rect    = "Drag to select. Shift adds, Alt subtracts, both keep the overlap",
	.Select_Ellipse = "Drag to select. Shift adds, Alt subtracts, both keep the overlap",
	.Lasso          = "Drag around an area to select it. Shift adds, Alt subtracts",
	.Wand           = "Click to select similar colors. Shift adds, Alt subtracts",
	.Move           = "Drag to move pixels. Alt moves a copy, arrows nudge",
	.Spray          = "Drag to scatter dots of color",
	.Hand           = "Drag to scroll the view",
	.Zoom           = "Click to zoom in, right-click to zoom out",
	.Grid           = "",
	.Symmetry       = "",
	.Tiling         = "",
	.Onion          = "",
}

PATTERN_HELP := [Pattern]string {
	.Solid       = "Paint every pixel the brush touches.",
	.Checker     = "Paint every other pixel, like the dark squares of a chessboard. The pixels in between are left alone.",
	.Checker_Inv = "Paint the pixels the Checker pattern leaves alone, like the light squares of a chessboard.",
	.Dither_FgBg = "A chessboard of the foreground and background colors.",
	.Dots        = "Paint one pixel in four, as a grid of dots.",
	.Lines_H     = "Paint every other row, as horizontal lines.",
	.Lines_V     = "Paint every other column, as vertical lines.",
	.Diag        = "Paint one diagonal in four, as thin slanted lines.",
}

FILTER_HELP := [Filter_Kind]string {
	.Brightness = "Make the whole layer lighter or darker.",
	.Contrast   = "Push the layer's colors apart or draw them closer together.",
	.Hue        = "Turn all the layer's colors around the color wheel, by this many degrees.",
	.Saturation = "Make the layer's colors more vivid, or fade them towards gray.",
	.Invert     = "Turn every color on the layer into its opposite.",
	.Grayscale  = "Take the color out of the layer.",
	.Sepia      = "Give the layer the brown tint of an old photograph.",
	.Posterize  = "Limit each color channel to a few levels, for flat bands of color.",
	.Threshold  = "Turn every pixel black or white, by whether it is brighter than this level.",
	.Palette    = "Change every color on the layer to the nearest color in the current palette.",
}

WS_BUILTIN_HELP := [len(WS_BUILTIN_NAMES)]string {
	"The standard tool groups: Draw, Shapes, Select and View.",
	"For frame by frame work: drawing tools, selections and the onion skin close at hand.",
	"For tile sets: selections and moves that snap to the grid, with the grid, tiling and mirror switches.",
	"For shading: a pixel-perfect line art group, a shade group with its own round brush, and dither patterns.",
}

// The tooltip of a button that runs a command: its name and shortcut, then what it does.
cmd_tip :: proc(name: string, c: Cmd) -> Tip {
	sc := shortcut_text(c)
	return {sc == "" ? name : fmt.tprintf("%s (%s)", name, sc), cmd_help(c)}
}

// The tooltip of a tool's button: its name and key, then how to use it.
tool_tip :: proc(t: Tool) -> Tip {
	return {TOOL_NAMES[t], TOOL_HELP[t]}
}

// Where a sprite lives and whether it has unsaved changes.
doc_status :: proc(d: ^Doc) -> string {
	where_is := d.path != "" ? d.path : "Not saved to a file yet"
	return fmt.tprintf("%s.%s", where_is, d.modified ? " It has unsaved changes." : "")
}

menu_title_tip :: proc(title: string) -> Tip {
	desc := ""
	switch title {
	case "File":       desc = "Create, open, save, import, export and close sprites, and load or save palettes."
	case "Edit":       desc = "Undo, the clipboard, filling, and changes to the current layer's colors. Preferences are here too."
	case "Sprite":     desc = "Change the whole sprite: its size, rotation and flips, and take a palette from it."
	case "Layer":      desc = "Add, remove, reorder and merge layers, and set their properties."
	case "Frame":      desc = "Add, remove and reorder animation frames, set their timing and tags, and play the animation."
	case "Select":     desc = "Select all, nothing, the opposite of the selection, or what is drawn on the layer."
	case "View":       desc = "Zoom, the grid, onion skin, mirror and tiling, which panels are shown, and the UI scale."
	case "Workspaces": desc = "Switch the whole tool set-up at once, or save, import and export your own."
	case "Help":       desc = "Keyboard shortcuts and information about the program."
	}
	return {"", desc}
}

// F1 lists the shortcut table. Most commands read fine by their own name; these don't.
shortcut_label :: proc(c: Cmd) -> string {
	if c >= .Tool_Pencil && c <= .Tool_Zoom {
		name := TOOL_NAMES[Tool(int(c) - int(Cmd.Tool_Pencil))]
		for i in 0 ..< len(name) {
			if name[i] == '(' do return name[:i - 1]
		}
		return name
	}
	#partial switch c {
	case .Toggle_Sym_X:      return "Mirror Horizontal"
	case .Toggle_Sym_Y:      return "Mirror Vertical"
	case .Cycle_Tile:        return "Cycle Tiled Mode"
	case .Toggle_Grid:       return "Grid"
	case .Toggle_Snap:       return "Snap to Grid"
	case .Toggle_Pixel_Grid: return "Pixel Grid"
	case .Toggle_Onion:      return "Onion Skin"
	case .Toggle_Canvas_Mode: return "Canvas Mode"
	case .Zoom_Fit:          return "Fit to Window"
	case .Zoom_1:            return "Zoom 100%"
	case .Zoom_2:            return "Zoom 200%"
	case .Zoom_4:            return "Zoom 400%"
	case .Zoom_8:            return "Zoom 800%"
	case .Zoom_16:           return "Zoom 1600%"
	case .Close_Doc:         return "Close"
	case .Invert_Sel:        return "Invert Selection"
	case .Layer_New:         return "New Layer"
	case .Layer_Dup:         return "Duplicate Layer"
	case .Layer_Merge:       return "Merge Down"
	case .Frame_New:         return "New Frame"
	case .Frame_Prev:        return "Previous Frame"
	case .Frame_Next:        return "Next Frame"
	case .Frame_First:       return "First Frame"
	case .Frame_Last:        return "Last Frame"
	case .Help_Keys:         return "Keyboard Shortcuts"
	}
	return fmt.tprintf("%v", c)
}
