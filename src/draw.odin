package pangolin

import "core:math"
import "core:math/rand"
import "core:slice"

// ---------------------------------------------------------------------------
// Rasterisation primitives
// ---------------------------------------------------------------------------

line_points :: proc(x0, y0, x1, y1: int, plot: proc(x, y: int)) {
	dx := abs(x1 - x0)
	dy := -abs(y1 - y0)
	sx := x0 < x1 ? 1 : -1
	sy := y0 < y1 ? 1 : -1
	err := dx + dy
	x, y := x0, y0
	for {
		plot(x, y)
		if x == x1 && y == y1 {
			break
		}
		e2 := 2 * err
		if e2 >= dy {
			err += dy
			x += sx
		}
		if e2 <= dx {
			err += dx
			y += sy
		}
	}
}

rect_points :: proc(ax, ay, bx, by: int, filled: bool, plot: proc(x, y: int)) {
	x0, x1 := min(ax, bx), max(ax, bx)
	y0, y1 := min(ay, by), max(ay, by)
	if filled {
		for y in y0 ..= y1 {
			for x in x0 ..= x1 {
				plot(x, y)
			}
		}
		return
	}
	for x in x0 ..= x1 {
		plot(x, y0)
		plot(x, y1)
	}
	for y in y0 ..= y1 {
		plot(x0, y)
		plot(x1, y)
	}
}

ellipse_inside :: proc(x, y: int, cx, cy, a, b: f32) -> bool {
	dx := (f32(x) + 0.5 - cx) / a
	dy := (f32(y) + 0.5 - cy) / b
	return dx * dx + dy * dy <= 1.0
}

// Plots an ellipse inscribed in the bounding box; `plot_fill` receives interior
// pixels, `plot_edge` the one pixel wide outline.
ellipse_points :: proc(ax, ay, bx, by: int, filled: bool, plot_fill, plot_edge: proc(x, y: int)) {
	x0, x1 := min(ax, bx), max(ax, bx)
	y0, y1 := min(ay, by), max(ay, by)
	cx := f32(x0 + x1 + 1) / 2
	cy := f32(y0 + y1 + 1) / 2
	a := f32(x1 - x0 + 1) / 2
	b := f32(y1 - y0 + 1) / 2
	for y in y0 ..= y1 {
		for x in x0 ..= x1 {
			if !ellipse_inside(x, y, cx, cy, a, b) {
				continue
			}
			edge :=
				!ellipse_inside(x - 1, y, cx, cy, a, b) ||
				!ellipse_inside(x + 1, y, cx, cy, a, b) ||
				!ellipse_inside(x, y - 1, cx, cy, a, b) ||
				!ellipse_inside(x, y + 1, cx, cy, a, b)
			if edge {
				plot_edge(x, y)
			} else if filled {
				plot_fill(x, y)
			}
		}
	}
}

// ---------------------------------------------------------------------------
// Region selection (flood fill / magic wand)
// ---------------------------------------------------------------------------

color_match :: proc(a, b: Color, tol: int) -> bool {
	if a.a == 0 && b.a == 0 {
		return true
	}
	return(
		abs(int(a.r) - int(b.r)) <= tol &&
		abs(int(a.g) - int(b.g)) <= tol &&
		abs(int(a.b) - int(b.b)) <= tol &&
		abs(int(a.a) - int(b.a)) <= tol \
	)
}

// Returns a w*h mask (1 = in region). `limit` (may be nil) restricts the region.
region_select :: proc(pix: []Color, w, h, sx, sy, tol: int, contiguous: bool, limit: []u8) -> []u8 {
	mask := make([]u8, w * h)
	if sx < 0 || sy < 0 || sx >= w || sy >= h {
		return mask
	}
	target := pix[sy * w + sx]
	if !contiguous {
		for i in 0 ..< w * h {
			if color_match(pix[i], target, tol) && (limit == nil || limit[i] != 0) {
				mask[i] = 1
			}
		}
		return mask
	}
	stack := make([dynamic]int, context.temp_allocator)
	append(&stack, sy * w + sx)
	for len(stack) > 0 {
		i := pop(&stack)
		if mask[i] != 0 || !color_match(pix[i], target, tol) || (limit != nil && limit[i] == 0) {
			continue
		}
		x := i % w
		y := i / w
		// expand along the scanline
		l := x
		for l > 0 {
			j := y * w + l - 1
			if mask[j] != 0 || !color_match(pix[j], target, tol) || (limit != nil && limit[j] == 0) {
				break
			}
			l -= 1
		}
		r := x
		for r < w - 1 {
			j := y * w + r + 1
			if mask[j] != 0 || !color_match(pix[j], target, tol) || (limit != nil && limit[j] == 0) {
				break
			}
			r += 1
		}
		for xx in l ..= r {
			mask[y * w + xx] = 1
		}
		for yy in ([2]int{y - 1, y + 1}) {
			if yy < 0 || yy >= h {
				continue
			}
			for xx in l ..= r {
				j := yy * w + xx
				if mask[j] == 0 && color_match(pix[j], target, tol) && (limit == nil || limit[j] != 0) {
					append(&stack, j)
				}
			}
		}
	}
	return mask
}

// ---------------------------------------------------------------------------
// Selection masks
// ---------------------------------------------------------------------------

mask_rect :: proc(w, h, ax, ay, bx, by: int) -> []u8 {
	m := make([]u8, w * h)
	x0, x1 := max(min(ax, bx), 0), min(max(ax, bx), w - 1)
	y0, y1 := max(min(ay, by), 0), min(max(ay, by), h - 1)
	for y in y0 ..= y1 {
		for x in x0 ..= x1 {
			m[y * w + x] = 1
		}
	}
	return m
}

mask_ellipse :: proc(w, h, ax, ay, bx, by: int) -> []u8 {
	m := make([]u8, w * h)
	x0, x1 := min(ax, bx), max(ax, bx)
	y0, y1 := min(ay, by), max(ay, by)
	cx := f32(x0 + x1 + 1) / 2
	cy := f32(y0 + y1 + 1) / 2
	a := f32(x1 - x0 + 1) / 2
	b := f32(y1 - y0 + 1) / 2
	for y in max(y0, 0) ..= min(y1, h - 1) {
		for x in max(x0, 0) ..= min(x1, w - 1) {
			if ellipse_inside(x, y, cx, cy, a, b) {
				m[y * w + x] = 1
			}
		}
	}
	return m
}

// Even-odd polygon fill sampled at pixel centres.
mask_polygon :: proc(w, h: int, pts: []IVec) -> []u8 {
	m := make([]u8, w * h)
	n := len(pts)
	if n < 3 {
		if n >= 1 {
			p := pts[0]
			if p.x >= 0 && p.y >= 0 && p.x < w && p.y < h {
				m[p.y * w + p.x] = 1
			}
		}
		return m
	}
	xs := make([dynamic]f32, context.temp_allocator)
	for y in 0 ..< h {
		clear(&xs)
		fy := f32(y) + 0.5
		for i in 0 ..< n {
			a := pts[i]
			b := pts[(i + 1) % n]
			ay, by := f32(a.y) + 0.5, f32(b.y) + 0.5
			if (ay <= fy && by > fy) || (by <= fy && ay > fy) {
				t := (fy - ay) / (by - ay)
				append(&xs, f32(a.x) + 0.5 + t * (f32(b.x) - f32(a.x)))
			}
		}
		slice.sort(xs[:])
		for k := 0; k + 1 < len(xs); k += 2 {
			x0 := int(math.ceil(xs[k] - 0.5))
			x1 := int(math.floor(xs[k + 1] - 0.5))
			for x in max(x0, 0) ..= min(x1, w - 1) {
				m[y * w + x] = 1
			}
		}
	}
	// make sure the outline itself is selected
	for i in 0 ..< n {
		a := pts[i]
		b := pts[(i + 1) % n]
		dx := abs(b.x - a.x)
		dy := -abs(b.y - a.y)
		sx := a.x < b.x ? 1 : -1
		sy := a.y < b.y ? 1 : -1
		err := dx + dy
		x, y := a.x, a.y
		for {
			if x >= 0 && y >= 0 && x < w && y < h {
				m[y * w + x] = 1
			}
			if x == b.x && y == b.y {
				break
			}
			e2 := 2 * err
			if e2 >= dy {
				err += dy
				x += sx
			}
			if e2 <= dx {
				err += dx
				y += sy
			}
		}
	}
	return m
}

// Combine an existing selection (base, may be nil) with a new shape mask.
sel_combine :: proc(base, shape: []u8, mode: Sel_Mode) -> []u8 {
	n := len(shape)
	out := make([]u8, n)
	switch mode {
	case .Replace:
		copy(out, shape)
	case .Add:
		for i in 0 ..< n {
			out[i] = (shape[i] != 0 || (base != nil && base[i] != 0)) ? 1 : 0
		}
	case .Subtract:
		if base != nil {
			for i in 0 ..< n {
				out[i] = (base[i] != 0 && shape[i] == 0) ? 1 : 0
			}
		}
	case .Intersect:
		if base != nil {
			for i in 0 ..< n {
				out[i] = (base[i] != 0 && shape[i] != 0) ? 1 : 0
			}
		}
	}
	return out
}

// ---------------------------------------------------------------------------
// Stroke engine: all drawing tools write through here.
// ---------------------------------------------------------------------------

Stroke :: struct {
	active:   bool,
	layer:    int,
	frame:    int,
	orig:     []Color, // cel contents when the stroke started
	pix:      []Color, // live cel buffer
	col:      Color,
	col2:     Color,
	erase:    bool,
	changed:  bool,
	was_mod:  bool,
	pp_pts:   [dynamic]IVec, // pixel-perfect history
	hits:     []u16, // how many times each pixel was painted by this stroke
}

stroke: Stroke

// Returns false (with a status message) when the active cel cannot be edited.
can_edit :: proc() -> bool {
	l := &doc.layers[doc.active_layer]
	if !l.visible {
		set_status("The active layer is hidden")
		return false
	}
	if l.locked {
		set_status("The active layer is locked")
		return false
	}
	return true
}

stroke_begin :: proc(erase: bool, col, col2: Color) -> bool {
	if !can_edit() {
		return false
	}
	stroke.was_mod = doc.modified
	history_push(doc)
	stroke.layer = doc.active_layer
	stroke.frame = doc.active_frame
	stroke.pix = cel_write(doc, stroke.layer, stroke.frame)
	stroke.orig = slice.clone(stroke.pix)
	stroke.hits = make([]u16, len(stroke.pix))
	stroke.col = col
	stroke.col2 = col2
	stroke.erase = erase
	stroke.changed = false
	stroke.active = true
	clear(&stroke.pp_pts)
	return true
}

stroke_end :: proc() {
	if !stroke.active {
		return
	}
	stroke.active = false
	if !stroke.changed {
		history_discard(doc)
		doc.modified = stroke.was_mod
	}
	delete(stroke.orig)
	delete(stroke.hits)
	stroke.orig = nil
	stroke.hits = nil
	stroke.pix = nil
}

// Undo everything the stroke has done so far (used by shape tools while dragging).
stroke_reset :: proc() {
	copy(stroke.pix, stroke.orig)
	for &h in stroke.hits {
		h = 0
	}
	clear(&stroke.pp_pts)
	stroke.changed = false
	doc.comp_dirty = true
}

wrap_coord :: proc(v, n: int) -> int {
	return ((v % n) + n) % n
}

pattern_allows :: proc(x, y: int) -> (use_alt: bool, ok: bool) {
	switch opts.pattern {
	case .Solid:
		return false, true
	case .Checker:
		return false, (x + y) % 2 == 0
	case .Checker_Inv:
		return false, (x + y) % 2 != 0
	case .Dither_FgBg:
		return (x + y) % 2 != 0, true
	case .Dots:
		return false, x % 2 == 0 && y % 2 == 0
	case .Lines_H:
		return false, y % 2 == 0
	case .Lines_V:
		return false, x % 2 == 0
	case .Diag:
		return false, wrap_coord(x - y, 4) == 0
	}
	return false, true
}

@(private = "file")
resolve_pixel :: proc(x0, y0: int) -> (i: int, ok: bool) {
	x, y := x0, y0
	w, h := doc.w, doc.h
	if opts.tile == .X || opts.tile == .Both {
		x = wrap_coord(x, w)
	}
	if opts.tile == .Y || opts.tile == .Both {
		y = wrap_coord(y, h)
	}
	if x < 0 || y < 0 || x >= w || y >= h {
		return 0, false
	}
	i = y * w + x
	if doc.sel != nil && doc.sel[i] == 0 {
		return 0, false
	}
	return i, true
}

@(private = "file")
plot_one :: proc(x0, y0: int) {
	i, ok := resolve_pixel(x0, y0)
	if !ok {
		return
	}
	x, y := i % doc.w, i / doc.w
	alt, pok := pattern_allows(x, y)
	if !pok {
		return
	}
	col := alt ? stroke.col2 : stroke.col
	o := stroke.orig[i]
	n: Color
	if stroke.erase {
		if int(o.a) - int(stroke.col.a) <= 0 {
			n = {}
		} else {
			n = o
			n.a = u8(int(o.a) - int(stroke.col.a))
		}
	} else {
		switch opts.ink {
		case .Normal:
			n = blend_px(o, col, 1, .Normal)
		case .Replace:
			n = col
		case .Lock_Alpha:
			if o.a == 0 {
				return
			}
			n = Color{col.r, col.g, col.b, o.a}
		}
	}
	if stroke.hits[i] < 65535 {
		stroke.hits[i] += 1
	}
	if !color_eq(stroke.pix[i], n) {
		stroke.pix[i] = n
		stroke.changed = true
	}
}

@(private = "file")
restore_one :: proc(x0, y0: int) {
	i, ok := resolve_pixel(x0, y0)
	if !ok {
		return
	}
	// Only revert a pixel when nothing else in this stroke painted it, otherwise
	// drawing back over earlier parts of the stroke would erase them.
	if stroke.hits[i] > 0 {
		stroke.hits[i] -= 1
	}
	if stroke.hits[i] == 0 {
		stroke.pix[i] = stroke.orig[i]
	}
}

// Plot with symmetry applied.
stroke_plot :: proc(x, y: int) {
	w, h := doc.w, doc.h
	plot_one(x, y)
	if opts.sym_x {
		plot_one(w - 1 - x, y)
	}
	if opts.sym_y {
		plot_one(x, h - 1 - y)
	}
	if opts.sym_x && opts.sym_y {
		plot_one(w - 1 - x, h - 1 - y)
	}
}

stroke_restore :: proc(x, y: int) {
	w, h := doc.w, doc.h
	restore_one(x, y)
	if opts.sym_x {
		restore_one(w - 1 - x, y)
	}
	if opts.sym_y {
		restore_one(x, h - 1 - y)
	}
	if opts.sym_x && opts.sym_y {
		restore_one(w - 1 - x, h - 1 - y)
	}
	doc.comp_dirty = true
}

// Stamp the current brush centred on (cx, cy).
brush_stamp :: proc(cx, cy: int) {
	n := opts.brush_size
	if n <= 1 {
		stroke_plot(cx, cy)
		return
	}
	lo := -((n - 1) / 2)
	hi := n / 2
	cc := f32(lo + hi) / 2
	r := f32(n) / 2
	lim := r * r - 0.5
	for dy in lo ..= hi {
		for dx in lo ..= hi {
			if opts.brush_round {
				ddx := f32(dx) - cc
				ddy := f32(dy) - cc
				if ddx * ddx + ddy * ddy > lim {
					continue
				}
			}
			stroke_plot(cx + dx, cy + dy)
		}
	}
	doc.comp_dirty = true
}

// Pencil-style segment from (x0,y0) to (x1,y1). When pixel-perfect is on the
// stroke history is used to remove "L" corners.
stroke_segment :: proc(x0, y0, x1, y1: int, first: bool) {
	if opts.pixel_perf && opts.brush_size <= 1 {
		collect :: proc(x, y: int) {
			append(&pp_collect, IVec{x, y})
		}
		pp_collect = make([dynamic]IVec, context.temp_allocator)
		line_points(x0, y0, x1, y1, collect)
		for p, idx in pp_collect {
			if idx == 0 && !first {
				continue
			}
			pp_add(p)
		}
		doc.comp_dirty = true
		return
	}
	// regular brush: draw whole segment
	line_points(x0, y0, x1, y1, brush_stamp)
	doc.comp_dirty = true
}

@(private = "file")
pp_collect: [dynamic]IVec

@(private = "file")
pp_add :: proc(p: IVec) {
	pts := &stroke.pp_pts
	if len(pts) > 0 && pts[len(pts) - 1] == p {
		return
	}
	n := len(pts)
	if n >= 2 {
		a := pts[n - 2]
		b := pts[n - 1]
		// "L" corner: a and p are diagonal neighbours, b is orthogonally adjacent to both.
		if abs(a.x - p.x) == 1 && abs(a.y - p.y) == 1 && (abs(a.x - b.x) + abs(a.y - b.y) == 1) && (abs(p.x - b.x) + abs(p.y - b.y) == 1) {
			stroke_restore(b.x, b.y)
			pop(pts)
		}
	}
	append(pts, p)
	stroke_plot(p.x, p.y)
}

// Random speckle for the spray tool.
stroke_spray :: proc(cx, cy: int) {
	r := max(opts.brush_size, 2)
	count := max(1, (r * r * opts.spray_dens) / 100)
	for _ in 0 ..< count {
		ang := rand.float32() * 2 * math.PI
		dist := math.sqrt(rand.float32()) * f32(r) / 2
		x := cx + int(math.round(math.cos(ang) * dist))
		y := cy + int(math.round(math.sin(ang) * dist))
		stroke_plot(x, y)
	}
	doc.comp_dirty = true
}

// Paint every pixel of a region mask through the stroke engine.
stroke_fill_mask :: proc(mask: []u8) {
	w := doc.w
	for i in 0 ..< len(mask) {
		if mask[i] != 0 {
			plot_one(i % w, i / w)
		}
	}
	doc.comp_dirty = true
}
