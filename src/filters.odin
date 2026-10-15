package pangolin

import "core:slice"

// Non-destructive per-layer filters. A layer keeps an ordered list; they are applied
// top to bottom to the layer's cel whenever the document is composited.

Filter_Kind :: enum u8 {
	Brightness,
	Contrast,
	Hue,
	Saturation,
	Invert,
	Grayscale,
	Sepia,
	Posterize,
	Threshold,
	Palette,
}

Layer_Filter :: struct {
	kind:    Filter_Kind,
	enabled: bool,
	amount:  int,
}

Filter_Info :: struct {
	name:      string,
	has_param: bool,
	param:     string,
	lo, hi:    int,
	def:       int,
}

FILTER_INFO := [Filter_Kind]Filter_Info {
	.Brightness = {"Brightness", true, "Amount", -100, 100, 0},
	.Contrast   = {"Contrast", true, "Amount", -100, 100, 0},
	.Hue        = {"Hue Shift", true, "Degrees", -180, 180, 0},
	.Saturation = {"Saturation", true, "Amount", -100, 100, 0},
	.Invert     = {"Invert", false, "", 0, 0, 0},
	.Grayscale  = {"Grayscale", false, "", 0, 0, 0},
	.Sepia      = {"Sepia", true, "Strength", 0, 100, 100},
	.Posterize  = {"Posterize", true, "Levels", 2, 16, 4},
	.Threshold  = {"Threshold", true, "Level", 0, 255, 128},
	.Palette    = {"Palette Filter", true, "Strength", 0, 100, 100},
}

filter_make :: proc(kind: Filter_Kind) -> Layer_Filter {
	return Layer_Filter{kind = kind, enabled = true, amount = FILTER_INFO[kind].def}
}

layer_has_filters :: proc(l: ^Layer) -> bool {
	for f in l.filters {
		if f.enabled {
			return true
		}
	}
	return false
}

doc_uses_palette_filter :: proc(d: ^Doc) -> bool {
	for &l in d.layers {
		for f in l.filters {
			if f.enabled && f.kind == .Palette {
				return true
			}
		}
	}
	return false
}

palette_hash :: proc(pal: []Color) -> u64 {
	h: u64 = 14695981039346656037
	for c in pal {
		for b in ([4]u8{c.r, c.g, c.b, c.a}) {
			h = (h ~ u64(b)) * 1099511628211
		}
	}
	return h ~ u64(len(pal))
}

// Perceptual-ish colour distance ("redmean"): a cheap RGB metric that weights the channels
// by how the eye sees them, noticeably better than plain Euclidean distance.
color_dist :: proc(a, b: Color) -> int {
	rm := (int(a.r) + int(b.r)) / 2
	dr := int(a.r) - int(b.r)
	dg := int(a.g) - int(b.g)
	db := int(a.b) - int(b.b)
	return (((512 + rm) * dr * dr) >> 8) + 4 * dg * dg + (((767 - rm) * db * db) >> 8)
}

// Closest palette entry to `c` (alpha of `c` is ignored; fully transparent entries are skipped).
nearest_palette_color :: proc(c: Color, pal: []Color) -> Color {
	best := c
	best_d := max(int)
	for p in pal {
		if p.a == 0 {
			continue
		}
		d := color_dist(c, p)
		if d < best_d {
			best_d = d
			best = p
			if d == 0 {
				break
			}
		}
	}
	return Color{best.r, best.g, best.b, c.a}
}

filter_lerp :: proc(a, b: Color, t: int) -> Color {
	if t >= 100 {
		return Color{b.r, b.g, b.b, a.a}
	}
	mix :: proc(x, y: u8, t: int) -> u8 {
		return u8((int(x) * (100 - t) + int(y) * t + 50) / 100)
	}
	return Color{mix(a.r, b.r, t), mix(a.g, b.g, t), mix(a.b, b.b, t), a.a}
}

clamp_u8 :: proc(v: f32) -> u8 {
	return u8(clamp(v, 0, 255) + 0.5)
}

// Applies one filter to `pix` in place. Transparent pixels are left alone.
filter_apply :: proc(pix: []Color, f: Layer_Filter, pal: []Color) {
	switch f.kind {
	case .Brightness:
		off := f32(f.amount) * 2.55
		for &p in pix {
			if p.a != 0 {
				p.r, p.g, p.b = clamp_u8(f32(p.r) + off), clamp_u8(f32(p.g) + off), clamp_u8(f32(p.b) + off)
			}
		}
	case .Contrast:
		c := f32(f.amount) * 2.55
		k := (259 * (c + 255)) / (255 * (259 - c))
		for &p in pix {
			if p.a != 0 {
				p.r = clamp_u8(k * (f32(p.r) - 128) + 128)
				p.g = clamp_u8(k * (f32(p.g) - 128) + 128)
				p.b = clamp_u8(k * (f32(p.b) - 128) + 128)
			}
		}
	case .Hue, .Saturation:
		for &p in pix {
			if p.a == 0 {
				continue
			}
			h, s, v := rgb_to_hsv(p)
			if f.kind == .Hue {
				h += f32(f.amount)
			} else if f.amount >= 0 {
				s = s + (1 - s) * f32(f.amount) / 100
			} else {
				s = s * (1 + f32(f.amount) / 100)
			}
			p = hsv_to_rgb(h, clamp(s, 0, 1), clamp(v, 0, 1), p.a)
		}
	case .Invert:
		for &p in pix {
			if p.a != 0 {
				p.r, p.g, p.b = 255 - p.r, 255 - p.g, 255 - p.b
			}
		}
	case .Grayscale:
		for &p in pix {
			if p.a != 0 {
				g := clamp_u8(0.299 * f32(p.r) + 0.587 * f32(p.g) + 0.114 * f32(p.b))
				p.r, p.g, p.b = g, g, g
			}
		}
	case .Sepia:
		for &p in pix {
			if p.a == 0 {
				continue
			}
			r, g, b := f32(p.r), f32(p.g), f32(p.b)
			sep := Color {
				clamp_u8(0.393 * r + 0.769 * g + 0.189 * b),
				clamp_u8(0.349 * r + 0.686 * g + 0.168 * b),
				clamp_u8(0.272 * r + 0.534 * g + 0.131 * b),
				p.a,
			}
			p = filter_lerp(p, sep, f.amount)
		}
	case .Posterize:
		n := f32(max(f.amount, 2) - 1)
		for &p in pix {
			if p.a != 0 {
				q :: proc(v: u8, n: f32) -> u8 {
					return u8(f32(int(f32(v) / 255 * n + 0.5)) / n * 255 + 0.5)
				}
				p.r, p.g, p.b = q(p.r, n), q(p.g, n), q(p.b, n)
			}
		}
	case .Threshold:
		for &p in pix {
			if p.a != 0 {
				l := 0.299 * f32(p.r) + 0.587 * f32(p.g) + 0.114 * f32(p.b)
				v: u8 = l >= f32(f.amount) ? 255 : 0
				p.r, p.g, p.b = v, v, v
			}
		}
	case .Palette:
		if len(pal) == 0 {
			return
		}
		// Sprites reuse a handful of colours, so each distinct colour is only matched once.
		cache := make(map[u32]Color, 64, context.temp_allocator)
		for &p in pix {
			if p.a == 0 {
				continue
			}
			key := u32(p.r) << 16 | u32(p.g) << 8 | u32(p.b)
			m, hit := cache[key]
			if !hit {
				m = nearest_palette_color(p, pal)
				cache[key] = m
			}
			p = filter_lerp(p, m, f.amount)
		}
	}
}

// The cel of `l` at `frame` with the layer's filters applied. Returns the cel itself
// (no copy) when there is nothing to apply; otherwise a temp-allocated copy.
layer_pixels :: proc(d: ^Doc, l: ^Layer, frame: int) -> []Color {
	src := l.cels[frame].pix
	if !layer_has_filters(l) {
		return src
	}
	out := slice.clone(src, context.temp_allocator)
	for f in l.filters {
		if f.enabled {
			filter_apply(out, f, d.palette[:])
		}
	}
	return out
}
