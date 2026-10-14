package pangolin

import "core:fmt"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

Palette_Preset :: enum {
	DB32,
	Pico8,
	Sweetie16,
	Endesga32,
	Gameboy,
	Grayscale16,
	Rainbow,
}

PALETTE_PRESET_NAMES := [Palette_Preset]string {
	.DB32        = "DawnBringer 32",
	.Pico8       = "PICO-8",
	.Sweetie16   = "Sweetie 16",
	.Endesga32   = "Endesga 32",
	.Gameboy     = "Game Boy",
	.Grayscale16 = "Grayscale 16",
	.Rainbow     = "Rainbow",
}

@(private = "file")
DB32 := [?]u32 {
	0x000000, 0x222034, 0x45283c, 0x663931, 0x8f563b, 0xdf7126, 0xd9a066, 0xeec39a,
	0xfbf236, 0x99e550, 0x6abe30, 0x37946e, 0x4b692f, 0x524b24, 0x323c39, 0x3f3f74,
	0x306082, 0x5b6ee1, 0x639bff, 0x5fcde4, 0xcbdbfc, 0xffffff, 0x9badb7, 0x847e87,
	0x696a6a, 0x595652, 0x76428a, 0xac3232, 0xd95763, 0xd77bba, 0x8f974a, 0x8a6f30,
}

@(private = "file")
PICO8 := [?]u32 {
	0x000000, 0x1d2b53, 0x7e2553, 0x008751, 0xab5236, 0x5f574f, 0xc2c3c7, 0xfff1e8,
	0xff004d, 0xffa300, 0xffec27, 0x00e436, 0x29adff, 0x83769c, 0xff77a8, 0xffccaa,
}

@(private = "file")
SWEETIE16 := [?]u32 {
	0x1a1c2c, 0x5d275d, 0xb13e53, 0xef7d57, 0xffcd75, 0xa7f070, 0x38b764, 0x257179,
	0x29366f, 0x3b5dc9, 0x41a6f6, 0x73eff7, 0xf4f4f4, 0x94b0c2, 0x566c86, 0x333c57,
}

@(private = "file")
ENDESGA32 := [?]u32 {
	0xbe4a2f, 0xd77643, 0xead4aa, 0xe4a672, 0xb86f50, 0x733e39, 0x3e2731, 0xa22633,
	0xe43b44, 0xf77622, 0xfeae34, 0xfee761, 0x63c74d, 0x3e8948, 0x265c42, 0x193c3e,
	0x124e89, 0x0099db, 0x2ce8f5, 0xffffff, 0xc0cbdc, 0x8b9bb4, 0x5a6988, 0x3a4466,
	0x262b44, 0x181425, 0xff0044, 0x68386c, 0xb55088, 0xf6757a, 0xe8b796, 0xc28569,
}

@(private = "file")
GAMEBOY := [?]u32{0x0f380f, 0x306230, 0x8bac0f, 0x9bbc0f}

hexc :: proc(v: u32) -> Color {
	return Color{u8(v >> 16), u8(v >> 8), u8(v), 255}
}

palette_preset :: proc(p: Palette_Preset) -> []Color {
	@(static) buf: [64]Color
	n := 0
	add :: proc(buf: ^[64]Color, n: ^int, c: Color) {
		if n^ < len(buf) {
			buf[n^] = c
			n^ += 1
		}
	}
	switch p {
	case .DB32:
		for v in DB32 do add(&buf, &n, hexc(v))
	case .Pico8:
		for v in PICO8 do add(&buf, &n, hexc(v))
	case .Sweetie16:
		for v in SWEETIE16 do add(&buf, &n, hexc(v))
	case .Endesga32:
		for v in ENDESGA32 do add(&buf, &n, hexc(v))
	case .Gameboy:
		for v in GAMEBOY do add(&buf, &n, hexc(v))
	case .Grayscale16:
		for i in 0 ..< 16 {
			g := u8(i * 255 / 15)
			add(&buf, &n, Color{g, g, g, 255})
		}
	case .Rainbow:
		for i in 0 ..< 12 {
			add(&buf, &n, hsv_to_rgb(f32(i) * 30, 1, 1))
		}
		for i in 0 ..< 12 {
			add(&buf, &n, hsv_to_rgb(f32(i) * 30, 0.5, 1))
		}
		for i in 0 ..< 12 {
			add(&buf, &n, hsv_to_rgb(f32(i) * 30, 1, 0.5))
		}
	}
	return buf[:n]
}

palette_set_preset :: proc(d: ^Doc, p: Palette_Preset) {
	clear(&d.palette)
	for c in palette_preset(p) {
		append(&d.palette, c)
	}
	d.pal_sel = 0
	d.modified = true
}

// Replace the palette with the unique colours used by the sprite (max 256).
palette_from_sprite :: proc(d: ^Doc) {
	seen := make(map[u32]bool, allocator = context.temp_allocator)
	pal := make([dynamic]Color, context.temp_allocator)
	for &l in d.layers {
		for c in l.cels {
			for p in c.pix {
				if p.a == 0 {
					continue
				}
				key := color_u32(Color{p.r, p.g, p.b, 255})
				if key in seen {
					continue
				}
				seen[key] = true
				if len(pal) < 256 {
					append(&pal, Color{p.r, p.g, p.b, 255})
				}
			}
		}
	}
	if len(pal) == 0 {
		return
	}
	clear(&d.palette)
	for c in pal {
		append(&d.palette, c)
	}
	d.pal_sel = 0
	d.modified = true
}

palette_save_gpl :: proc(d: ^Doc, path: string) -> bool {
	sb := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&sb, "GIMP Palette\nName: %s\nColumns: 8\n#\n", name_str(&d.title))
	for c, i in d.palette {
		fmt.sbprintf(&sb, "%3d %3d %3d\tIndex %d\n", c.r, c.g, c.b, i)
	}
	return write_file(path, transmute([]u8)strings.to_string(sb))
}

palette_load_gpl :: proc(d: ^Doc, path: string) -> bool {
	data, ok := read_file(path)
	if !ok {
		return false
	}
	defer delete(data)
	text := string(data)
	pal := make([dynamic]Color, context.temp_allocator)
	for line in strings.split_lines_iterator(&text) {
		l := strings.trim_space(line)
		if len(l) == 0 || l[0] == '#' || strings.has_prefix(l, "GIMP") || strings.has_prefix(l, "Name") || strings.has_prefix(l, "Columns") {
			continue
		}
		fields := strings.fields(l, context.temp_allocator)
		if len(fields) < 3 {
			continue
		}
		r, rok := strconv.parse_int(fields[0])
		g, gok := strconv.parse_int(fields[1])
		b, bok := strconv.parse_int(fields[2])
		if rok && gok && bok {
			append(&pal, Color{u8(clamp(r, 0, 255)), u8(clamp(g, 0, 255)), u8(clamp(b, 0, 255)), 255})
		}
	}
	if len(pal) == 0 {
		return false
	}
	clear(&d.palette)
	for c in pal {
		append(&d.palette, c)
	}
	d.pal_sel = 0
	d.modified = true
	return true
}

// File helpers built on raylib so we do not depend on core:os API churn.
read_file :: proc(path: string) -> (data: []u8, ok: bool) {
	cpath := strings.clone_to_cstring(path, context.temp_allocator)
	size: i32
	raw := rl.LoadFileData(cpath, &size)
	if raw == nil || size < 0 {
		return nil, false
	}
	data = make([]u8, int(size))
	copy(data, raw[:size])
	rl.UnloadFileData(raw)
	return data, true
}

write_file :: proc(path: string, data: []u8) -> bool {
	cpath := strings.clone_to_cstring(path, context.temp_allocator)
	return rl.SaveFileData(cpath, raw_data(data), i32(len(data)))
}
