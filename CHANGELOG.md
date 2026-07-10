## 1.3.0

Adds screen capture and on-screen image location.

> [!WARNING]
> Screen capture is **only tested on macOS**. The Linux and Windows backends are implemented and code-reviewed but have never been compiled or run. Treat them as unproven. Mouse and keyboard automation are unaffected.

> [!IMPORTANT]
> On macOS, screen capture requires **macOS 14 or newer** and Screen Recording permission for the process running your program (the terminal or host app, not `dart` itself). Without it, `Screen.screenshot` throws a `StateError`; check `Screen.isScreenCaptureTrusted` first.

- Add `Screen.screenshot({region, filename})`, which captures the primary display or a region of it and can write a PNG.
- Add `Screen.pixel(x, y)` and `Screen.pixelMatchesColor(x, y, rgb, {tolerance})`.
- Add `Screen.locateOnScreen`, `Screen.locateAllOnScreen`, and `Screen.locateCenterOnScreen`, plus the image-to-image `locate`/`locateAll` and a top-level `center(box)`. Matching is exact on RGB; alpha is ignored and there is no `confidence` option.
- Add `Capture` (raw RGBA pixels, physical dimensions, `pixelAt`, `toLogical`) and `Screen.isScreenCaptureTrusted`.
- Coordinates crossing the API are logical, the same space as `Mouse.position`, so a match feeds straight into `Mouse.click`. A `Capture` holds physical pixels, which on a HiDPI display are the logical size times the backing scale factor.
- A capture region that runs past the edge of the display is clipped to it; one entirely off-display throws `ArgumentError`.
- Capture covers the primary display only. Linux support is X11 only, with no Wayland.
- Adds a dependency on `package:image`, used only to encode and decode PNG.

## 1.2.1

- Fix `Mouse.mouseUp` so a screen-corner fail-safe can no longer strand a held button down mid-drag; releasing a button is never blocked.

## 1.2.0

- `Mouse` actions (move, click, drag, scroll) now honor the screen-corner fail-safe, matching `Keyboard`.
- Add `Mouse.leftClick`, `Mouse.middleClick`, and a `Mouse.vscroll` alias.
- Fail-safe and pause settings now live in a shared `FailSafe` class; `Keyboard.failSafeEnabled`, `pauseAfterAction`, and `failSafePadding` continue to work as before.
- Internal: unify the three per-platform FFI binding files and mouse classes into one, with no public API change.

## 1.1.0

- Expand `AutoGUIKey` to ~90 named keys (function keys F1-F24, arrows, navigation, editing, numpad, and left/right modifier variants) mapped per platform.
- Accept PyAutoGUI-style key-name strings in `press`, `keyDown`, `keyUp`, `hotkey`, and `hold` (e.g. `press('f1')`, `hotkey(['ctrl', 'c'])`), with aliases such as `esc`, `pgup`, and `command`.
- Add `Keyboard.isValidKey` and `Keyboard.keyboardKeys` for platform-aware key validation and introspection.
- Type shifted characters (uppercase and punctuation) as base key plus Shift, and map newline/carriage-return/tab correctly on every platform (fixes a crash typing `\n`/`\t` on Linux).
- Add a screen-corner fail-safe for keyboard actions that matches an exact corner point, so multi-monitor coordinates no longer abort actions by mistake.
- `press` now performs a discrete down/up per repeat, re-checks the fail-safe before each press, and treats a non-positive press count as a no-op, matching PyAutoGUI.

## 1.0.0

- Initial release with Mouse and Keyboard automation.
- Cross-platform support for macOS (CoreGraphics), Linux (X11), and Windows (Win32).
- Native binary build system using CMake (via `dart_autogui:setup`).
