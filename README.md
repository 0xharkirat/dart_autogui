# autogui

`autogui` is a Dart package for cross-platform GUI automation. It enables you to programmatically control desktop mouse and keyboard actions from Dart using FFI and native platform APIs.

> [!NOTE]
> This package is under development. It is implemented purely in Dart using FFI
> bindings to C and platform-native interfaces. There are **no dependencies on
> Python or external runtimes**.

## Features

- Move and control the mouse, with optional eased/tweened motion
- Mouse clicks, drags, and scrolling
- Keyboard typing, key presses, hotkeys/chords, and key-hold
- PyAutoGUI-style named keys (`press('f1')`, `hotkey(['ctrl', 'c'])`) with shift-aware typing
- Screen capture, pixel colour reads, and on-screen image location
- Screen-corner fail-safe to abort a runaway script
- Works on Windows, macOS, and Linux

## Platform support

Mouse and keyboard automation are implemented on macOS, Linux, and Windows.

Screen capture (`Screen.screenshot`, `Screen.pixel`, `Screen.locateOnScreen`, and
friends) is **only verified on macOS**:

| Platform | Screen capture | Notes |
| --- | --- | --- |
| macOS | Implemented and tested | Requires **macOS 14+** and Screen Recording permission |
| Linux | Implemented, **not yet tested** | X11 only (`XGetImage`); no Wayland support |
| Windows | Implemented, **not yet tested** | GDI (`BitBlt`) |

> [!WARNING]
> The Linux and Windows capture backends are written and code-reviewed but have
> **never been compiled or run** by the author. Treat them as unproven, and
> please report what you find. Mouse and keyboard automation are unaffected.

> [!IMPORTANT]
> On macOS the process running your Dart program needs **Screen Recording**
> permission (System Settings → Privacy & Security → Screen Recording). That is
> the terminal or host application, not `dart` itself, and it must be restarted
> after you grant it. Without it, `Screen.screenshot` throws a `StateError`.
> Check first with `Screen.isScreenCaptureTrusted`.

## Installation

1. Add the dependency:
```yaml
dependencies:
  autogui: ^1.3.0
```

2. **Setup Native Library**:
   This package relies on a native shared library that must be built for your system.
   Run the setup script to compile it (requires `cmake` and a C++ compiler):
   
   ```bash
   dart run autogui:setup
   ```

## Key Functions

### Mouse Control
Use the `Mouse` class to control the cursor.

- **`Screen.size()`**: Returns `Point<int>(width, height)` of the primary screen.
- **`Mouse.position()`**: Returns `Point<double>(x, y)` of the current mouse position in global desktop coordinates.
- **`Screen.onScreen(x, y)`**: Checks if coordinates are within the screen bounds.

> [!NOTE]
> On multi-monitor macOS setups, `Mouse.position()` can legitimately return
> negative `x` or `y` values when the cursor is on a display positioned left of
> or above the primary display. `Screen.size()` and `Screen.onScreen()` describe
> the primary display only.

#### Movement
- **`Mouse.moveTo(x, y, {duration, easing})`**: Moves mouse to absolute coordinates.
  - Optional `duration` for smooth movement.
  - Optional `easing` function (e.g., `easeInQuad`, `easeInOutQuad`).
- **`Mouse.move(dx, dy, {duration, easing})`**: Moves mouse relative to current position.
- **`Mouse.dragTo(x, y, {button})`**: Drags mouse to target while holding a button.
- **`Mouse.drag(dx, dy, {button})`**: Drags mouse relatively.

#### Clicks & Scrolling
- **`Mouse.click({x, y, button, clicks, interval})`**: Clicks the mouse.
  - Supports `MouseButton.left`, `MouseButton.right`, `MouseButton.middle`.
  - `clicks`: 1 for single, 2 for double-click.
- **`Mouse.mouseDown({button})`**: Presses and holds a mouse button.
- **`Mouse.mouseUp({button})`**: Releases a mouse button.
- **`Mouse.scroll(clicks)`**: Scrolls vertically (positive = up, negative = down).
- **`Mouse.hscroll(clicks)`**: Scrolls horizontally (positive = right, negative = left).

### Keyboard Control
Use the `Keyboard` class to simulate key presses. A key can be an `AutoGUIKey`, a
PyAutoGUI-style name string, a single character, or a raw int keycode:
`Keyboard.press(AutoGUIKey.enter)`, `Keyboard.press('enter')`, `Keyboard.press('a')`,
`Keyboard.press(0x0D)`.

- **`Keyboard.write(message, {interval})`** / **`Keyboard.typeWrite(message, {intervalSec})`**: Types a string. Uppercase and shifted punctuation are handled (US layout).
- **`Keyboard.press(key, {presses, interval})`**: Presses and releases a key, optionally repeated.
- **`Keyboard.hotkey([...keys])`** / **`Keyboard.keyChord([...keys])`**: Presses keys together, releases in reverse, e.g. `hotkey(['ctrl', 'c'])`.
- **`Keyboard.hold(key, action)`**: Holds a key down while `action` runs, then releases it.
- **`Keyboard.keyDown(key)`** / **`Keyboard.keyUp(key)`**: Hold or release a key.
- **`Keyboard.isValidKey(key)`** / **`Keyboard.keyboardKeys`**: Check or list the key names supported on the current platform.

#### Supported Keys (`AutoGUIKey`)
Around 90 named keys, mapped per platform:
- Modifiers: `shift`/`control`/`alt`/`cmd` plus `left`/`right` variants, `capsLock`, `numLock`, `fn`
- Function keys `f1`-`f24`, arrows, `home`/`end`/`pageUp`/`pageDown`, `insert`/`delete`
- Numpad `num0`-`num9` and operators
- Name aliases: `esc`, `pgup`, `command`, `option`, and more

Keys with no equivalent on a platform (for example `f21`-`f24` and `insert` on macOS) resolve to null; use `Keyboard.isValidKey` to check.

### Screen Capture & Image Location

See [Platform support](#platform-support) first - this is macOS-verified only.

- **`Screen.screenshot({region, filename})`**: Captures the primary display, or a `region` of it, and optionally writes a PNG. Returns a `Capture`.
- **`Screen.pixel(x, y)`**: The `(r, g, b)` of one screen pixel.
- **`Screen.pixelMatchesColor(x, y, rgb, {tolerance})`**: Compares a pixel to a colour, per-channel.
- **`Screen.locateOnScreen(path, {region})`**: Finds an image on screen. Returns a `Rectangle<int>`, or null.
- **`Screen.locateAllOnScreen(path, {region})`** / **`Screen.locateCenterOnScreen(path, {region})`**
- **`locate(needle, haystack)`** / **`locateAll(needle, haystack)`**: Match one `Capture` inside another.
- **`center(box)`**: The centre `Point<int>` of a rectangle.
- **`Screen.isScreenCaptureTrusted`**: Whether the OS granted capture permission.

Coordinates you pass in and get back are **logical** - the same space as
`Mouse.position` - so a match feeds straight into `Mouse.click`:

```dart
final button = Screen.locateCenterOnScreen('button.png');
if (button != null) Mouse.click(x: button.x, y: button.y);
```

> [!NOTE]
> A `Capture` holds **physical** pixels, which on a HiDPI display are the logical
> size times the backing scale factor (2x on Retina). Use `Capture.toLogical` to
> convert, or stay in logical coordinates by using the `Screen.locate*` helpers.

> [!TIP]
> Matching is **exact** on RGB - alpha is ignored, and there is no `confidence`
> option. Give it a distinctive needle: a flat one matches the first similar
> patch in scan order, and is also the slow case.

### Fail-safe

By default, mouse and keyboard actions abort with a `FailSafeException` if the pointer
is slammed into a screen corner - a manual kill switch for a runaway script. Disable
with `Keyboard.failSafeEnabled = false` (or `FailSafe.enabled = false`).

## Examples

```dart
import 'dart:io';
import 'package:autogui/autogui.dart';

Future<void> main() async {
  await Future.delayed(const Duration(seconds: 3)); // focus your target window

  // Fill a form: type, Tab between fields, submit.
  await Keyboard.write('Ada Lovelace');
  await Keyboard.press('tab');
  await Keyboard.write('ada@example.com');
  await Keyboard.press('enter');

  // Copy from one spot and paste to another (platform-correct modifier).
  final mod = Platform.isMacOS ? 'command' : 'ctrl';
  Mouse.click(x: 400, y: 300);
  await Keyboard.hotkey([mod, 'a']);
  await Keyboard.hotkey([mod, 'c']);
  Mouse.click(x: 900, y: 300);
  await Keyboard.hotkey([mod, 'v']);

  // Smooth, eased pointer move.
  await Mouse.moveTo(1200, 800,
      duration: const Duration(seconds: 1), easing: easeInOutQuad);
}
```

See [`example/`](example/) for more.

## Current Limitations

- **Screen capture is only tested on macOS.** The Linux and Windows backends are implemented but unproven - see [Platform support](#platform-support).
- Screen capture on macOS requires macOS 14 or newer, plus Screen Recording permission.
- Capture covers the primary display only; multi-monitor is not supported.
- Image matching is exact - no `confidence`/fuzzy matching and no grayscale mode.
- Linux capture is X11 only; Wayland is not supported.
- Text entry assumes a US keyboard layout; non-ASCII input is not yet supported.
- Media and volume keys are not yet available on macOS.

## Requirements
- **macOS**: Xcode Command Line Tools. Screen capture additionally needs macOS 14+ and Screen Recording permission; mouse and keyboard work on older releases.
- **Linux**: `libx11-dev`, `libxtst-dev`, `cmake`, `build-essential`. X11 session (not Wayland).
- **Windows**: Visual Studio (C++) or MinGW, `cmake`.
