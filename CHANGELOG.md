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
