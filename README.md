# Pangolin Pixels

*Pixel art, scale by scale.* Written in Odin with SDL3.

A pixel art editor, and the sibling of [Pangolin Paints](https://github.com/BrandonHilde/PangolinPaints): same look and feel,
built for sprites and animation.

Build with `./build.sh` on Linux/macOS or `build.bat` on Windows. [OdinUI](https://gitlab.com/patrick.pixelshuffle/odinui) is a
git submodule in `libs/odinui`: clone with `git clone --recursive`, or let the build scripts fetch it on the first build
(`git submodule update --init`). To build by hand: `odin build src -out:PangolinPixels -o:speed -collection:odinui=libs/odinui`.
Drag image/project files onto the window to open them. `PangolinPixels --selftest` runs the headless test suite
(on Windows use `PangolinPixels-console.exe`, since the GUI build has no console).

## Features
- **Tool groups**: the toolbar is made of editable groups, each with its own hotkey (1 Draw, 2 Shapes, 3 Select,
  4 View by default). Pressing a group's hotkey picks the tool last used from it; pressing it again cycles through the
  group. The group's **+** button adds
  - tools, and the **Grid**, **Symmetry**, **Tiled Mode** and **Onion Skin** switches: clicking a switch turns it on and
    shows its settings in the options bar (clicking it again turns it off; picking a tool brings the tool's settings back);
  - or colours (the foreground colour, the sprite's palette or a preset), making a colour group whose hotkey cycles the
    foreground colour; clicking one of its colours lets the colour picker edit it;
  - or dither patterns, making a pattern group whose hotkey cycles the pattern (a lone pattern toggles on and off).

  Click a group's keycap to assign a hotkey, rename or remove it, or give it **its own brush settings** (size, shape,
  pixel-perfect, fill, pattern, ink, spray density), loaded whenever one of its tools is picked; a dot marks such groups.
  Right-click an item to remove it. Groups are remembered between sessions.
- **Workspaces** (Workspaces menu): switch the whole tool set-up at once. Built in: Default, Animation, Tiles (grid,
  tiling and snapping) and Shading (a pixel-perfect line art group, a shading group with its own brush, dither
  patterns). Save your own, delete them, or export / import them as `.pxws` files.
- **Canvas mode** (Tab): hides the side panels, tabs, timeline and status bar; a bar along the bottom shows every group
  as `[key] -> current tool`.
- **Tools**: pencil (optional pixel-perfect), eraser, line, rectangle, ellipse, **bezier curve**, paint bucket, eyedropper, rectangular /
  elliptical marquee, lasso, magic wand, move, spray, hand, zoom. Left/right mouse = foreground/background colour.
- **Brush options**: size 1-64, square/round, dither patterns (checker, dots, lines, Fg/Bg dither), ink modes
  (normal / replace / lock alpha), horizontal + vertical symmetry, tiled drawing (X / Y / both).
- **Layers & animation**: unlimited layers (opacity, 9 blend modes, lock, visibility, merge, flatten), frames with
  per-frame duration, copy-on-write cels, tags (forward / reverse / ping-pong), onion skin (previous / next frame,
  opacity), playback. Drag a layer in the timeline to reorder it; right-click it for the layer menu.
- **Grid and snapping**: a custom grid (size and offset) that marquee selections and rectangle / ellipse shapes snap to
  in whole cells, line ends to grid crossings, and moves (drag or arrow keys) in whole cells while Snap to Grid is on
  (Ctrl+Shift+;). Snapping only applies while a tool is in use.
- **Navigator**: the whole sprite at an integer zoom with the visible area marked; click or drag to move the view.
- **Pen tablets**: Windows Ink (Wacom, Huion, Surface, ...) and Linux (SDL pen events) tablets drive the pointer
  directly, and the pen's eraser end erases with any drawing tool. Set `PANGOLIN_PEN_DEBUG=1` on Linux to print pen events.
- **Selections**: add / subtract / intersect (Shift / Alt), move with content (Alt = copy), cut / copy / paste, flip,
  invert, crop to selection.
- **Colour**: HSV picker, RGB sliders, hex entry, alpha, per-sprite palettes with presets (DB32, PICO-8, Sweetie 16,
  Endesga 32, Game Boy, ...), palette from sprite, GIMP `.gpl` import/export, recently painted colours.
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
- UI scaled by a whole number (auto / 1x-4x in Preferences), with text and icons drawn sharp at the screen's resolution.

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
| Ctrl+Shift+; | snap to grid |
| 1-4 (editable) | tool group hotkeys |
| Tab | canvas mode |
| Ctrl+1-5, Ctrl+0 | zoom 100%-1600%, fit |

## Customising the interface
The interface is laid out and styled with CSS through [OdinUI](https://gitlab.com/patrick.pixelshuffle/odinui). The
default theme is [assets/ui/theme.css](assets/ui/theme.css). To change it, create `theme.css` next to the executable:
it is applied on top of the default theme and reloaded while the program runs, so it only needs what you change.

```css
:root     { --accent: #f6aa68; --accent-tint: rgba(246, 170, 104, 0.22); --panel: #1f2430; }
#body     { flex-direction: row-reverse; }   /* tools on the right, colour and palette on the left */
#right    { width: 300px; }
#timeline { height: 220px; }
```

The colour variables in `:root` also drive the parts the program draws itself (canvas surroundings, timeline,
dialogs, menus). Icons are SVG files in `assets/icons` (shared with Pangolin Paints), built into the executable and
drawn as a font (`font-family: icons`), so `color` and `font-size` style them like text.

## Developer flags
`--selftest` (tests), `--demo` (sample sprite), `--shot file.png` (screenshot after a few frames, `--shot-frame N` to
pick the frame), `--size WxH`, `--scale N`, `--menu N` (open a menu), `--dialog N`,
`--clicks "frame:x,y;..."` (left clicks at window pixels on those frames, `frame:x,y,r` for a right click),
`--convert image` (open the pixel-art converter).

## License
BSD 3-Clause. See [LICENSE](LICENSE).
