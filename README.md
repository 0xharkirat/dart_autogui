# autogui

`autogui` is a Dart package for cross-platform GUI automation. It enables you to programmatically control desktop mouse and keyboard actions from Dart using FFI and native platform APIs.

**Note:** This package is under development. It is implemented purely in Dart using FFI bindings to C and platform-native interfaces. There are **no dependencies on Python or external runtimes**.

## Features

- Move and control the mouse
- Perform mouse clicks and drags
- Send basic keyboard input
- Works on Windows, macOS, and Linux

## Installation

1. Add the dependency:
```yaml
dependencies:
  autogui: ^1.0.0
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
- **`Mouse.position()`**: Returns `Point<double>(x, y)` of the current mouse position.
- **`Screen.onScreen(x, y)`**: Checks if coordinates are within the screen bounds.

#### Movement
- **`Mouse.moveTo(x, y, {duration, easing})`**: Moves mouse to absolute coordinates.
  - Optional `duration` for smooth movement.
  - Optional `easing` function (e.g., `easeInQuad`, `easeOutElastic`).
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
Use the `Keyboard` class to simulate key presses.

- **`Keyboard.typeWrite(message, {intervalSec})`**: Types a string of characters.
  - `intervalSec`: Delay between each key press.
- **`Keyboard.press(key)`**: Presses and releases a single key.
  - usage: `Keyboard.press(AutoGUIKey.enter)` or `Keyboard.press(0x0D)` for a raw platform keycode.
- **`Keyboard.keyDown(key)`**: Holds a key down.
- **`Keyboard.keyUp(key)`**: Releases a key.

#### Supported Keys (`AutoGUIKey`)
- `enter`, `space`, `tab`, `escape`, `backspace`
- `shift`, `control`, `alt`, `cmd` (Meta/Super/Win)

> **Note**: Character mapping (e.g. `typeWrite`) is currently basic and relies on standard US layout assumptions for some platforms.

## Current Limitations

- Mouse automation is the most complete part of the package.
- Keyboard automation is available on macOS, Linux, and Windows, but text entry is still basic and layout-sensitive.
- There is no screenshot or image-matching API in the current package.

## Requirements
- **macOS**: Xcode Command Line Tools.
- **Linux**: `libx11-dev`, `libxtst-dev`, `cmake`, `build-essential`.
- **Windows**: Visual Studio (C++) or MinGW, `cmake`.
