package pangolin

IVec :: [2]int
Vec2 :: [2]f32

// Integer rectangle in logical UI pixels.
Rect :: struct {
	x, y, w, h: i32,
}

// Small fixed-capacity string (names, text inputs). Safe to copy by value.
Name :: struct {
	b: [128]u8,
	n: int,
}

name_set :: proc(nm: ^Name, s: string) {
	n := min(len(s), len(nm.b))
	copy(nm.b[:n], s)
	nm.n = n
}

name_str :: proc(nm: ^Name) -> string {
	return string(nm.b[:nm.n])
}

make_name :: proc(s: string) -> Name {
	r: Name
	name_set(&r, s)
	return r
}

Blend :: enum u8 {
	Normal,
	Multiply,
	Screen,
	Overlay,
	Darken,
	Lighten,
	Add,
	Subtract,
	Difference,
}

BLEND_NAMES := [Blend]string {
	.Normal     = "Normal",
	.Multiply   = "Multiply",
	.Screen     = "Screen",
	.Overlay    = "Overlay",
	.Darken     = "Darken",
	.Lighten    = "Lighten",
	.Add        = "Add",
	.Subtract   = "Subtract",
	.Difference = "Difference",
}

// Reference-counted pixel buffer. Snapshots (undo history) share buffers; writers
// clone a buffer first if it is shared (copy-on-write).
Cel_Data :: struct {
	refs: int,
	pix:  []Color,
}

Layer :: struct {
	name:    Name,
	visible: bool,
	locked:  bool,
	opacity: u8,
	blend:   Blend,
	cels:    [dynamic]^Cel_Data, // one per frame
	filters: [dynamic]Layer_Filter, // applied in order when compositing
	// layer groups (groups.odin)
	uid:          int, // unique in its document (0: not given one yet)
	parent:       int, // uid of the group it is in, or 0 at the top level
	is_group:     bool, // a group: no pixels of its own; its layers are those whose parent it is, just below it
	pass_through: bool, // a group whose layers blend straight into what is below (else they are combined first)
	collapsed:    bool, // a group shown closed in the timeline
}

Frame :: struct {
	duration: int, // milliseconds
}

// Everything that undo/redo restores.
State :: struct {
	w, h:   int,
	layers: [dynamic]Layer,
	frames: [dynamic]Frame,
	tags:   [dynamic]Tag,
	sel:    []u8, // nil = no selection; otherwise w*h, non-zero = selected
}

Sel_Edge :: struct {
	x, y: i32,
	vert: bool, // false: horizontal edge on top side of pixel; true: vertical edge on left side
}

Doc :: struct {
	using s:                     State,
	undo, redo:                  [dynamic]State,
	active_layer, active_frame:  int,
	path:                        string, // empty if never saved
	title:                       Name,
	modified:                    bool,
	palette:                     [dynamic]Color,
	pal_sel:                     int,
	pal_hash:                    u64, // palette contents the composite was last built with

	// view
	zoom:                        f32,
	ox, oy:                      f32, // screen position of canvas pixel (0,0)
	view_init:                   bool,

	// caches
	comp:                        []Color, // composite of the active frame
	comp_dirty:                  bool,
	tex_dirty:                   bool,
	sel_edges:                   [dynamic]Sel_Edge,
	sel_dirty:                   bool,
	sel_last_pt:                 IVec,
	have_last_pt:                bool,
}

Tool :: enum {
	Pencil,
	Eraser,
	Line,
	Rect,
	Ellipse,
	Curve,
	Bucket,
	Picker,
	Select_Rect,
	Select_Ellipse,
	Lasso,
	Wand,
	Move,
	Spray,
	Hand,
	Zoom,
	// switches that can sit in tool groups: clicking one turns it on or off, never becomes the tool
	Grid,
	Symmetry,
	Tiling,
	Onion,
}

TOOL_NAMES := [Tool]string {
	.Pencil         = "Pencil (B)",
	.Eraser         = "Eraser (E)",
	.Line           = "Line (L)",
	.Rect           = "Rectangle (R)",
	.Ellipse        = "Ellipse (O)",
	.Curve          = "Bezier Curve (P)",
	.Bucket         = "Paint Bucket (G)",
	.Picker         = "Eyedropper (I)",
	.Select_Rect    = "Rectangular Marquee (M)",
	.Select_Ellipse = "Elliptical Marquee (Shift+M)",
	.Lasso          = "Lasso (Q)",
	.Wand           = "Magic Wand (W)",
	.Move           = "Move (V)",
	.Spray          = "Spray (S)",
	.Hand           = "Hand (H)",
	.Zoom           = "Zoom (Z)",
	.Grid           = "Grid (Ctrl+;)",
	.Symmetry       = "Mirror (Shift+X, Shift+Y)",
	.Tiling         = "Tiled Mode (Shift+T)",
	.Onion          = "Onion Skin (Alt+O)",
}

Sel_Mode :: enum {
	Replace,
	Add,
	Subtract,
	Intersect,
}

Ink :: enum {
	Normal,
	Replace,
	Lock_Alpha,
}

Pattern :: enum {
	Solid,
	Checker,
	Checker_Inv,
	Dither_FgBg,
	Dots,
	Lines_H,
	Lines_V,
	Diag,
}

PATTERN_NAMES := [Pattern]string {
	.Solid       = "Solid",
	.Checker     = "Checker",
	.Checker_Inv = "Checker (inv)",
	.Dither_FgBg = "Dither Fg/Bg",
	.Dots        = "Dots",
	.Lines_H     = "H Lines",
	.Lines_V     = "V Lines",
	.Diag        = "Diagonal",
}

Tile_Mode :: enum {
	Off,
	X,
	Y,
	Both,
}

// Tool options (global, shared between tools).
Options :: struct {
	brush_size:  int,
	brush_round: bool,
	pixel_perf:  bool,
	fill_shape:  bool,
	tolerance:   int,
	contiguous:  bool,
	sel_mode:    Sel_Mode,
	spray_dens:  int,
	sym_x:       bool,
	sym_y:       bool,
	tile:        Tile_Mode,
	ink:         Ink,
	pattern:     Pattern,
	onion:       bool,
	onion_prev:  int, // show the previous frame (0 / 1)
	onion_next:  int, // show the next frame (0 / 1)
	onion_alpha: int, // percent
	grid:        bool, // custom grid
	snap:        bool, // selections, shapes and moves snap to the custom grid while it is shown
	pixel_grid:  bool,
	grid_w:      int,
	grid_h:      int,
	grid_ox:     int,
	grid_oy:     int,
	show_checks: bool,
	sym_guides:  bool,
}
