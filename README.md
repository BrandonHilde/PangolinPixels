# Pangolin Pixels

*Pixel art, scale by scale.* Written in Odin with raylib.

A pixel art editor. Build with `build.bat` (or `odin build src -out:PangolinPixels.exe -o:speed`),
run `PangolinPixels.exe`. Drag image/project files onto the window to open them. `PangolinPixels.exe --selftest` runs the
headless test-suite (undo/redo, tools, file formats).

## Features
- **Tools**: pencil (optional pixel-perfect), eraser, line, rectangle, ellipse, **bezier curve**, paint bucket, eyedropper, rectangular /
  elliptical marquee, lasso, magic wand, move, spray, hand, zoom. Left/right mouse = foreground/background colour.
- **Brush options**: size 1-64, square/round, dither patterns (checker, dots, lines, Fg/Bg dither), ink modes
  (normal / replace / lock alpha), horizontal + vertical symmetry, tiled drawing (X / Y / both).
- **Layers & animation**: unlimited layers (opacity, 9 blend modes, lock, visibility, merge, flatten), frames with
  per-frame duration, copy-on-write cels, tags (forward / reverse / ping-pong), onion skin, playback.
- **Selections**: add / subtract / intersect (Shift / Alt), move with content (Alt = copy), cut / copy / paste, flip,
  invert, crop to selection.
- **Colour**: HSV picker, RGB sliders, hex entry, alpha, per-sprite palettes with presets (DB32, PICO-8, Sweetie 16,
  Endesga 32, Game Boy, ...), palette from sprite, GIMP `.gpl` import/export.
- **Layer filters**: non-destructive, reorderable filter stack per layer ("Add Filter" under the palette): brightness, contrast, hue,
  saturation, invert, grayscale, sepia, posterize, threshold, and a **Palette Filter** that remaps every colour to the nearest
  colour of the current palette (perceptual distance), with adjustable strength. Saved in `.pxl`, applied to export,
  and baked in when layers are merged (Merge Down, Ctrl+E) or flattened.
- **Image to pixel art** (File > Convert Image to Pixel Art..., Edit > Convert to Pixel Art... for the open sprite, or
  `PangolinPixels.exe --convert photo.jpg`): area-averages
  any image down to a target size (e.g. 64x64, aspect lock optional) and maps it onto a palette (auto median-cut with
  2-64 colours, the current palette, or any preset), with optional ordered or Floyd-Steinberg dithering and a live preview.
- **Sprite ops**: canvas size (with anchor), scale, rotate, flip, trim, outline, hue/saturation/brightness (live
  preview), invert, grayscale, replace colour.
- **Files**: native `.pxl` project, PNG / JPG (built-in decoder: progressive, CMYK, EXIF rotation, any size) / BMP / TGA / GIF / QOI import,
  import as layer, import sprite sheet; export PNG, sprite sheet, PNG sequence, animated GIF (median-cut quantiser),
  Multiple documents in tabs; unsaved-change prompts; unlimited undo (256 steps).
- **Canvas background**: checkerboard or any solid colour (View > Canvas Background, or the swatch in the options bar); remembered between sessions.
- Pixel-art UI rendered at an integer scale (auto / 1x-4x in Preferences).

## Shortcuts (F1 in the app shows the full list)
| | |
|-|-|
| B / E / L / U / O / C / G / I | pencil / eraser / line / rect / ellipse / curve / bucket / eyedropper |
| M, Shift+M / Q / W / V / S / H / Z | marquee / ellipse marquee / lasso / wand / move / spray / hand / zoom |
| X / D / [ ] | swap colours / default colours / brush size |
| Space (hold) / Alt (hold) | pan / temporary eyedropper |
| Mouse wheel / Shift+wheel / Ctrl+wheel | zoom / pan horizontally / pan vertically |
| Ctrl+Z / Ctrl+Y | undo / redo |
| Ctrl+N / O / S / Shift+S / Shift+E | new / open / save / save as / export |
| Shift+N / Alt+N | new layer / new frame |
| Enter, `,` `.` | play, previous / next frame |
| Shift+X / Shift+Y / Shift+T | mirror X / mirror Y / cycle tiling |
| Ctrl+' / Ctrl+Shift+' / Alt+O | grid / pixel grid / onion skin |
| 1-5, 0 | zoom 100%-1600%, fit |

## License
BSD 3-Clause. See [LICENSE](LICENSE).
