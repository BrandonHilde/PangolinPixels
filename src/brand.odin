package pangolin

import "core:math"

APP_NAME :: "Pangolin Pixels"
APP_TAGLINE :: "Pixel art, scale by scale."

LOGO_SIZE :: 16

// Pixel-art pangolin facing left. Characters map to colours in `logo_color`.
LOGO_ART := [LOGO_SIZE]string {
	"................",
	"................",
	"......oooooo....",
	"....ooddbbddoo..",
	"...oddbbddbbddo.",
	"..oddbbddbbddbbo",
	"..obbddbbddbbddo",
	".oobddbbddbbddbo",
	"ossoobbddbbddbo.",
	"osswoddbbddbbo..",
	".osssllooooooo..",
	"..ooollo.ol.ol..",
	"....ol.o.ol.ol..",
	"....oo.o.oo.oo..",
	"................",
	"................",
}

logo_color :: proc(ch: u8) -> (c: Color, ok: bool) {
	switch ch {
	case 'o':
		return Color{46, 32, 24, 255}, true
	case 'd':
		return Color{139, 94, 60, 255}, true
	case 'b':
		return Color{192, 140, 86, 255}, true
	case 'l':
		return Color{224, 185, 136, 255}, true
	case 's':
		return Color{240, 217, 181, 255}, true
	case 'w':
		return Color{255, 255, 255, 255}, true
	}
	return {}, false
}

logo_tex: Texture

logo_pixels :: proc(allocator := context.temp_allocator) -> []Color {
	pix := make([]Color, LOGO_SIZE * LOGO_SIZE, allocator)
	for row, y in LOGO_ART {
		for x in 0 ..< len(row) {
			if c, ok := logo_color(row[x]); ok {
				pix[y * LOGO_SIZE + x] = c
			}
		}
	}
	return pix
}

// Window icon and the texture the menu bar and About dialog draw.
brand_init :: proc() {
	pix := logo_pixels()
	logo_tex = tex_from_pixels(pix, LOGO_SIZE, LOGO_SIZE, .Point)
	// the window icon, scaled up with whole pixels
	BIG :: LOGO_SIZE * 4
	big := make([]Color, BIG * BIG, context.temp_allocator)
	for y in 0 ..< BIG {
		for x in 0 ..< BIG {
			big[y * BIG + x] = pix[(y / 4) * LOGO_SIZE + x / 4]
		}
	}
	gfx_set_icon(big, BIG, BIG)
}

// Draws the logo at an integer scale.
logo_draw :: proc(x, y, scale: i32) {
	// a whole number of screen pixels per logo pixel keeps the art even at any UI scale; centred on
	// where the exact size would have gone
	exact := f32(LOGO_SIZE * scale)
	size := LOGO_SIZE * max(math.round(f32(scale) * gfx.scale), 1) / gfx.scale
	off := (exact - size) / 2
	draw_tex(logo_tex, {0, 0, LOGO_SIZE, LOGO_SIZE}, {snap(f32(x) + off), snap(f32(y) + off), size, size})
}
