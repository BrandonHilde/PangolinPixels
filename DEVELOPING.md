# Developing Pangolin Pixels

How to build, run, test and change it. For using it, see the [README](README.md) and the [guide](GUIDE.md).

## Building and installing from source

Build with `./build.sh` on Linux/macOS or `build.bat` on Windows. [OdinUI](https://gitlab.com/patrick.pixelshuffle/odinui) and
the code shared with the other Pangolin tools are git submodules in `libs/odinui` and `libs/shared`: clone with
`git clone --recursive`, or let the build scripts fetch them on the first build (`git submodule update --init`). To build by
hand: `sh libs/shared/sync.sh`, which copies the shared code into `src` as `shared_*.odin`, then
`odin build src -out:PangolinPixels -o:speed -collection:odinui=libs/odinui`.
To update to the newest version, run `update.bat` (Windows) or `./update.sh`: it pulls the latest commits and moves the
submodules to the versions they expect (a plain `git pull` leaves the submodules where they were, and the build then
fails). `build.bat` / `./build.sh` on their own build whatever is there now.
On Linux, `./install.sh` builds the program and installs it for your account: in `~/.local/opt/pangolin/PangolinPixels`, with
its own settings, workspaces and macros (apart from this folder's build), and in the application list with its icon.
Run it again to update, or `./install.sh --uninstall` to remove it. To install a build made elsewhere (for another
account on the computer, or without Odin), put `install.sh`, the `PangolinPixels` program and `assets/icon` in one folder and
run `sh install.sh --no-build` there.
Drag image/project files onto the window to open them. `PangolinPixels --selftest` runs the headless test suite
(on Windows use `PangolinPixels-console.exe`, since the GUI build has no console).

## Developer flags
`--selftest` (tests), `--demo` (sample sprite), `--shot file.png` (screenshot after a few frames, `--shot-frame N` to
pick the frame), `--size WxH`, `--scale N` (percent, not saved), `--menu N` (open a menu), `--dialog N` (open a window),
`--clicks "frame:x,y;..."` (left clicks at window pixels on those frames, `frame:x,y,r` for a right click),
`--drag "frame:x0,y0,x1,y1;..."` (press at the first point on that frame, move over a few frames, release at the second),
`--files folder` (show that folder in the file browser),
`--hover "frame:x,y"` (the pointer rests there from that frame on, for checking tooltips with `--shot`),
`--convert image` (open the pixel-art converter).

## Releases
A tag such as `v0.9.0-beta` (matching `APP_VERSION` in `src/brand.odin`) runs `.github/workflows/release.yml`: it builds Windows, macOS and Linux bundles, runs `--selftest` inside each, and makes a draft GitHub release to try before publishing. Actions > Release > Run workflow builds the bundles without releasing. The workflow and the packaging script (`libs/shared/release/package.sh`) live in [PangolinShared](https://github.com/BrandonHilde/PangolinShared).

## License
BSD 3-Clause. See [LICENSE](LICENSE).
