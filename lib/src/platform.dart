import 'dart:io';
import 'dart:math';
import 'ffi/macos.dart';
import 'ffi/linux.dart';
import 'ffi/windows.dart';
import 'keyboard.dart';

enum MouseButton { left, right, middle }

abstract class PlatformMouse {
  Point<int> screenSize();
  Point<double> position();
  void moveToAbsolute(double x, double y);
  void mouseDown(MouseButton btn);
  void mouseUp(MouseButton btn);
  void click(MouseButton btn, {int clicks = 1, Duration? interval});
  void vscroll(int deltaLines);
  void hscroll(int deltaLines);
  bool isAccessibilityTrusted();
}

abstract class PlatformKeyboard {
  void keyDown(int keycode);
  void keyUp(int keycode);
  int? charToKeycode(String char);
  int? mapKey(AutoGUIKey key);
}

class _MacMouse implements PlatformMouse {
  final _b = MacOSBindings.load();

  @override
  Point<int> screenSize() => _b.screenSize();

  @override
  Point<double> position() => _b.mousePosition();

  @override
  void moveToAbsolute(double x, double y) => _b.moveTo(x, y);

  @override
  void mouseDown(MouseButton btn) => _b.mouseDown(btn.index);

  @override
  void mouseUp(MouseButton btn) => _b.mouseUp(btn.index);

  @override
  void click(MouseButton btn, {int clicks = 1, Duration? interval}) => _b.click(
    btn.index,
    clicks,
    (interval ?? Duration.zero).inMilliseconds / 1000.0,
  );

  @override
  void vscroll(int deltaLines) => _b.vscroll(deltaLines);

  @override
  void hscroll(int deltaLines) => _b.hscroll(deltaLines);

  @override
  bool isAccessibilityTrusted() => _b.isAccessibilityTrusted();
}

class _LinuxMouse implements PlatformMouse {
  final _b = LinuxBindings.load();

  @override
  Point<int> screenSize() => _b.screenSize();

  @override
  Point<double> position() => _b.mousePosition();

  @override
  void moveToAbsolute(double x, double y) => _b.moveTo(x, y);

  @override
  void mouseDown(MouseButton btn) => _b.mouseDown(btn.index);

  @override
  void mouseUp(MouseButton btn) => _b.mouseUp(btn.index);

  @override
  void click(MouseButton btn, {int clicks = 1, Duration? interval}) => _b.click(
    btn.index,
    clicks,
    (interval ?? Duration.zero).inMilliseconds / 1000.0,
  );

  @override
  void vscroll(int deltaLines) => _b.vscroll(deltaLines);

  @override
  void hscroll(int deltaLines) => _b.hscroll(deltaLines);

  @override
  bool isAccessibilityTrusted() => _b.isAccessibilityTrusted();
}

class _WindowsMouse implements PlatformMouse {
  final _b = WindowsBindings.load();

  @override
  Point<int> screenSize() => _b.screenSize();

  @override
  Point<double> position() => _b.mousePosition();

  @override
  void moveToAbsolute(double x, double y) => _b.moveTo(x, y);

  @override
  void mouseDown(MouseButton btn) => _b.mouseDown(btn.index);

  @override
  void mouseUp(MouseButton btn) => _b.mouseUp(btn.index);

  @override
  void click(MouseButton btn, {int clicks = 1, Duration? interval}) => _b.click(
    btn.index,
    clicks,
    (interval ?? Duration.zero).inMilliseconds / 1000.0,
  );

  @override
  void vscroll(int deltaLines) => _b.vscroll(deltaLines);

  @override
  void hscroll(int deltaLines) => _b.hscroll(deltaLines);

  @override
  bool isAccessibilityTrusted() => _b.isAccessibilityTrusted();
}

// --- Keyboard Implementations ---

class _MacKeyboard implements PlatformKeyboard {
  final _b = MacOSBindings.load();
  static const Map<String, int> _charMap = {
    'a': 0,
    's': 1,
    'd': 2,
    'f': 3,
    'h': 4,
    'g': 5,
    'z': 6,
    'x': 7,
    'c': 8,
    'v': 9,
    'b': 11,
    'q': 12,
    'w': 13,
    'e': 14,
    'r': 15,
    'y': 16,
    't': 17,
    '1': 18,
    '2': 19,
    '3': 20,
    '4': 21,
    '6': 22,
    '5': 23,
    '=': 24,
    '9': 25,
    '7': 26,
    '-': 27,
    '8': 28,
    '0': 29,
    ']': 30,
    'o': 31,
    'u': 32,
    '[': 33,
    'i': 34,
    'p': 35,
    '\n': 36,
    'l': 37,
    'j': 38,
    '\'': 39,
    'k': 40,
    ';': 41,
    '\\': 42,
    ',': 43,
    '/': 44,
    'n': 45,
    'm': 46,
    '.': 47,
    '\t': 48,
    ' ': 49,
    '`': 50,
  };

  @override
  void keyDown(int keycode) => _b.keyDown(keycode);

  @override
  void keyUp(int keycode) => _b.keyUp(keycode);

  @override
  int? charToKeycode(String char) {
    if (char.length != 1) return null;
    return _charMap[char.toLowerCase()];
  }

  @override
  int? mapKey(AutoGUIKey key) {
    // Mac keycodes
    switch (key) {
      case AutoGUIKey.enter:
        return 36;
      case AutoGUIKey.space:
        return 49;
      case AutoGUIKey.tab:
        return 48;
      case AutoGUIKey.escape:
        return 53;
      case AutoGUIKey.backspace:
        return 51;
      case AutoGUIKey.shift:
        return 56;
      case AutoGUIKey.control:
        return 59;
      case AutoGUIKey.alt:
        return 58; // Option
      case AutoGUIKey.cmd:
        return 55;
    }
  }
}

class _LinuxKeyboard implements PlatformKeyboard {
  final _b = LinuxBindings.load();

  @override
  void keyDown(int keycode) => _b.keyDown(keycode);

  @override
  void keyUp(int keycode) => _b.keyUp(keycode);

  @override
  int? charToKeycode(String char) {
    // On Linux we can use XKeysymToKeycode if we had the keysym.
    // ASCII chars map to keysyms usually (Latin-1).
    if (char.length != 1) return null;
    int keysym = char.codeUnitAt(0);
    return _b.keysymToKeycode(keysym);
  }

  @override
  int? mapKey(AutoGUIKey key) {
    // Keysyms standard?
    switch (key) {
      case AutoGUIKey.enter:
        return _b.keysymToKeycode(0xFF0D); // Return
      case AutoGUIKey.space:
        return _b.keysymToKeycode(0x0020);
      case AutoGUIKey.tab:
        return _b.keysymToKeycode(0xFF09);
      case AutoGUIKey.escape:
        return _b.keysymToKeycode(0xFF1B);
      case AutoGUIKey.backspace:
        return _b.keysymToKeycode(0xFF08);
      case AutoGUIKey.shift:
        return _b.keysymToKeycode(0xFFE1); // Shift_L
      case AutoGUIKey.control:
        return _b.keysymToKeycode(0xFFE3); // Control_L
      case AutoGUIKey.alt:
        return _b.keysymToKeycode(0xFFE9); // Alt_L
      case AutoGUIKey.cmd:
        return _b.keysymToKeycode(0xFFEB); // Super_L
    }
  }
}

class _WindowsKeyboard implements PlatformKeyboard {
  final _b = WindowsBindings.load();

  @override
  void keyDown(int keycode) => _b.keyDown(keycode);

  @override
  void keyUp(int keycode) => _b.keyUp(keycode);

  @override
  int? charToKeycode(String char) {
    // Windows Virtual Key codes.
    // A-Z, 0-9 match ASCII for the most part (UPPERCASE).
    if (char.length != 1) return null;
    int c = char.toUpperCase().codeUnitAt(0);
    // 0-9 and A-Z are same as ASCII
    if ((c >= 48 && c <= 57) || (c >= 65 && c <= 90)) {
      return c;
    }
    if (char == ' ') return 0x20; // VK_SPACE
    return null;
  }

  @override
  int? mapKey(AutoGUIKey key) {
    switch (key) {
      case AutoGUIKey.enter:
        return 0x0D; // VK_RETURN
      case AutoGUIKey.space:
        return 0x20; // VK_SPACE
      case AutoGUIKey.tab:
        return 0x09; // VK_TAB
      case AutoGUIKey.escape:
        return 0x1B; // VK_ESCAPE
      case AutoGUIKey.backspace:
        return 0x08; // VK_BACK
      case AutoGUIKey.shift:
        return 0x10; // VK_SHIFT
      case AutoGUIKey.control:
        return 0x11; // VK_CONTROL
      case AutoGUIKey.alt:
        return 0x12; // VK_MENU
      case AutoGUIKey.cmd:
        return 0x5B; // VK_LWIN
    }
  }
}

PlatformMouse? _platformMouse;
PlatformKeyboard? _platformKeyboard;

/// Mockable instance for testing
set platformMouseInstance(PlatformMouse? mock) => _platformMouse = mock;
set platformKeyboardInstance(PlatformKeyboard? mock) =>
    _platformKeyboard = mock;

PlatformMouse get platformMouse {
  if (_platformMouse != null) return _platformMouse!;
  if (Platform.isMacOS) return _platformMouse = _MacMouse();
  if (Platform.isLinux) return _platformMouse = _LinuxMouse();
  if (Platform.isWindows) return _platformMouse = _WindowsMouse();
  throw UnsupportedError('Platform not supported');
}

PlatformKeyboard get platformKeyboard {
  if (_platformKeyboard != null) return _platformKeyboard!;
  if (Platform.isMacOS) return _platformKeyboard = _MacKeyboard();
  if (Platform.isLinux) return _platformKeyboard = _LinuxKeyboard();
  if (Platform.isWindows) return _platformKeyboard = _WindowsKeyboard();
  throw UnsupportedError('Platform not supported');
}
