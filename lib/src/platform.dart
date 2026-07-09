import 'dart:io';
import 'dart:math';
import 'ffi/bindings.dart';
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
  KeyStroke? charToKeyStroke(String char);
  int? mapKey(AutoGUIKey key);
}

const Map<String, String> _shiftedBaseChars = {
  '!': '1',
  '@': '2',
  '#': '3',
  r'$': '4',
  '%': '5',
  '^': '6',
  '&': '7',
  '*': '8',
  '(': '9',
  ')': '0',
  '_': '-',
  '+': '=',
  '{': '[',
  '}': ']',
  '|': '\\',
  ':': ';',
  '"': '\'',
  '<': ',',
  '>': '.',
  '?': '/',
  '~': '`',
};

/// Whether typing [char] on a US layout requires holding Shift.
///
/// Package-internal (not re-exported from `autogui.dart`); exposed without a
/// leading underscore so the platform keyboards, the test mock, and unit tests
/// all share the exact same logic instead of re-deriving it.
bool requiresShift(String char) {
  if (_shiftedBaseChars.containsKey(char)) return true;
  final lower = char.toLowerCase();
  return char != lower &&
      lower.codeUnitAt(0) >= 97 &&
      lower.codeUnitAt(0) <= 122;
}

/// Folds [char] to the physical key that produces it, dropping Shift.
///
/// e.g. `'A' -> 'a'`, `'!' -> '1'`, `':' -> ';'`. See [requiresShift].
String baseChar(String char) {
  if (_shiftedBaseChars.containsKey(char)) return _shiftedBaseChars[char]!;
  return char.toLowerCase();
}

/// Maps the ASCII control characters that appear in typed text to their X11
/// keysyms. Newline/carriage-return both resolve to Return so that
/// `write("line1\nline2")` types correctly on Linux instead of feeding the raw
/// code unit (10/13) to `keysymToKeycode`, which has no such keysym.
int? controlCharKeysym(String char) {
  switch (char) {
    case '\n':
    case '\r':
      return 0xFF0D; // XK_Return
    case '\t':
      return 0xFF09; // XK_Tab
  }
  return null;
}

class _NativeMouse implements PlatformMouse {
  _NativeMouse(this._b);

  final NativeBindings _b;

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
  _MacKeyboard(this._b);

  final NativeBindings _b;

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
    '\r': 36,
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
  KeyStroke? charToKeyStroke(String char) {
    if (char.length != 1) return null;
    final base = baseChar(char);
    final keycode = _charMap[base];
    if (keycode == null) return null;
    return KeyStroke(
      keycode,
      modifiers: requiresShift(char) ? const [AutoGUIKey.shift] : const [],
    );
  }

  // Carbon kVK_* virtual keycodes. Keys with no macOS equivalent (f21-f24,
  // insert, numlock, scrolllock, win, media, ...) are absent and resolve to
  // null. Numpad codes come from the kVK_ANSI_Keypad* constants.
  static const Map<AutoGUIKey, int> _keyCodes = {
    AutoGUIKey.enter: 0x24,
    AutoGUIKey.space: 0x31,
    AutoGUIKey.tab: 0x30,
    AutoGUIKey.escape: 0x35,
    AutoGUIKey.backspace: 0x33,
    AutoGUIKey.shift: 0x38,
    AutoGUIKey.control: 0x3B,
    AutoGUIKey.alt: 0x3A, // Option
    AutoGUIKey.cmd: 0x37,
    AutoGUIKey.shiftLeft: 0x38,
    AutoGUIKey.shiftRight: 0x3C,
    AutoGUIKey.controlLeft: 0x3B,
    AutoGUIKey.controlRight: 0x3E,
    AutoGUIKey.altLeft: 0x3A,
    AutoGUIKey.altRight: 0x3D,
    AutoGUIKey.fn: 0x3F,
    AutoGUIKey.capsLock: 0x39,
    AutoGUIKey.f1: 0x7A,
    AutoGUIKey.f2: 0x78,
    AutoGUIKey.f3: 0x63,
    AutoGUIKey.f4: 0x76,
    AutoGUIKey.f5: 0x60,
    AutoGUIKey.f6: 0x61,
    AutoGUIKey.f7: 0x62,
    AutoGUIKey.f8: 0x64,
    AutoGUIKey.f9: 0x65,
    AutoGUIKey.f10: 0x6D,
    AutoGUIKey.f11: 0x67,
    AutoGUIKey.f12: 0x6F,
    AutoGUIKey.f13: 0x69,
    AutoGUIKey.f14: 0x6B,
    AutoGUIKey.f15: 0x71,
    AutoGUIKey.f16: 0x6A,
    AutoGUIKey.f17: 0x40,
    AutoGUIKey.f18: 0x4F,
    AutoGUIKey.f19: 0x50,
    AutoGUIKey.f20: 0x5A,
    AutoGUIKey.up: 0x7E,
    AutoGUIKey.down: 0x7D,
    AutoGUIKey.left: 0x7B,
    AutoGUIKey.right: 0x7C,
    AutoGUIKey.home: 0x73,
    AutoGUIKey.end: 0x77,
    AutoGUIKey.pageUp: 0x74,
    AutoGUIKey.pageDown: 0x79,
    AutoGUIKey.delete: 0x75, // Forward delete
    AutoGUIKey.help: 0x72,
    AutoGUIKey.clear: 0x47, // kVK_ANSI_KeypadClear
    AutoGUIKey.num0: 0x52,
    AutoGUIKey.num1: 0x53,
    AutoGUIKey.num2: 0x54,
    AutoGUIKey.num3: 0x55,
    AutoGUIKey.num4: 0x56,
    AutoGUIKey.num5: 0x57,
    AutoGUIKey.num6: 0x58,
    AutoGUIKey.num7: 0x59,
    AutoGUIKey.num8: 0x5B,
    AutoGUIKey.num9: 0x5C,
    AutoGUIKey.numMultiply: 0x43,
    AutoGUIKey.numAdd: 0x45,
    AutoGUIKey.numSubtract: 0x4E,
    AutoGUIKey.numDecimal: 0x41,
    AutoGUIKey.numDivide: 0x4B,
  };

  @override
  int? mapKey(AutoGUIKey key) => _keyCodes[key];
}

class _LinuxKeyboard implements PlatformKeyboard {
  _LinuxKeyboard(this._b);

  final NativeBindings _b;

  @override
  void keyDown(int keycode) => _b.keyDown(keycode);

  @override
  void keyUp(int keycode) => _b.keyUp(keycode);

  @override
  KeyStroke? charToKeyStroke(String char) {
    if (char.length != 1) return null;
    final base = baseChar(char);
    // Control chars (\n, \r, \t) are not their own keysyms; map them explicitly
    // before falling back to the Latin-1 code unit for printable characters.
    final keysym = controlCharKeysym(base) ?? base.codeUnitAt(0);
    final keycode = _b.keysymToKeycode(keysym);
    if (keycode == null || keycode == 0) return null;
    return KeyStroke(
      keycode,
      modifiers: requiresShift(char) ? const [AutoGUIKey.shift] : const [],
    );
  }

  // X11 keysyms, resolved to keycodes at runtime. Keys with no X11 keysym on a
  // given server (e.g. fn) are absent; a keysym that resolves to keycode 0 is
  // treated as unsupported in [mapKey].
  static const Map<AutoGUIKey, int> _keysyms = {
    AutoGUIKey.enter: 0xFF0D, // Return
    AutoGUIKey.space: 0x0020,
    AutoGUIKey.tab: 0xFF09,
    AutoGUIKey.escape: 0xFF1B,
    AutoGUIKey.backspace: 0xFF08,
    AutoGUIKey.shift: 0xFFE1, // Shift_L
    AutoGUIKey.control: 0xFFE3, // Control_L
    AutoGUIKey.alt: 0xFFE9, // Alt_L
    AutoGUIKey.cmd: 0xFFEB, // Super_L
    AutoGUIKey.shiftLeft: 0xFFE1,
    AutoGUIKey.shiftRight: 0xFFE2,
    AutoGUIKey.controlLeft: 0xFFE3,
    AutoGUIKey.controlRight: 0xFFE4,
    AutoGUIKey.altLeft: 0xFFE9,
    AutoGUIKey.altRight: 0xFFEA,
    AutoGUIKey.winLeft: 0xFFEB, // Super_L
    AutoGUIKey.winRight: 0xFFEC, // Super_R
    AutoGUIKey.capsLock: 0xFFE5,
    AutoGUIKey.numLock: 0xFF7F,
    AutoGUIKey.scrollLock: 0xFF14,
    AutoGUIKey.f1: 0xFFBE,
    AutoGUIKey.f2: 0xFFBF,
    AutoGUIKey.f3: 0xFFC0,
    AutoGUIKey.f4: 0xFFC1,
    AutoGUIKey.f5: 0xFFC2,
    AutoGUIKey.f6: 0xFFC3,
    AutoGUIKey.f7: 0xFFC4,
    AutoGUIKey.f8: 0xFFC5,
    AutoGUIKey.f9: 0xFFC6,
    AutoGUIKey.f10: 0xFFC7,
    AutoGUIKey.f11: 0xFFC8,
    AutoGUIKey.f12: 0xFFC9,
    AutoGUIKey.f13: 0xFFCA,
    AutoGUIKey.f14: 0xFFCB,
    AutoGUIKey.f15: 0xFFCC,
    AutoGUIKey.f16: 0xFFCD,
    AutoGUIKey.f17: 0xFFCE,
    AutoGUIKey.f18: 0xFFCF,
    AutoGUIKey.f19: 0xFFD0,
    AutoGUIKey.f20: 0xFFD1,
    AutoGUIKey.f21: 0xFFD2,
    AutoGUIKey.f22: 0xFFD3,
    AutoGUIKey.f23: 0xFFD4,
    AutoGUIKey.f24: 0xFFD5,
    AutoGUIKey.up: 0xFF52,
    AutoGUIKey.down: 0xFF54,
    AutoGUIKey.left: 0xFF51,
    AutoGUIKey.right: 0xFF53,
    AutoGUIKey.home: 0xFF50,
    AutoGUIKey.end: 0xFF57,
    AutoGUIKey.pageUp: 0xFF55,
    AutoGUIKey.pageDown: 0xFF56,
    AutoGUIKey.insert: 0xFF63,
    AutoGUIKey.delete: 0xFFFF,
    AutoGUIKey.clear: 0xFF0B,
    AutoGUIKey.select: 0xFF60,
    AutoGUIKey.execute: 0xFF62,
    AutoGUIKey.printScreen: 0xFF61, // Print
    AutoGUIKey.pause: 0xFF13,
    AutoGUIKey.menu: 0xFF67,
    AutoGUIKey.help: 0xFF6A,
    AutoGUIKey.num0: 0xFFB0,
    AutoGUIKey.num1: 0xFFB1,
    AutoGUIKey.num2: 0xFFB2,
    AutoGUIKey.num3: 0xFFB3,
    AutoGUIKey.num4: 0xFFB4,
    AutoGUIKey.num5: 0xFFB5,
    AutoGUIKey.num6: 0xFFB6,
    AutoGUIKey.num7: 0xFFB7,
    AutoGUIKey.num8: 0xFFB8,
    AutoGUIKey.num9: 0xFFB9,
    AutoGUIKey.numMultiply: 0xFFAA,
    AutoGUIKey.numAdd: 0xFFAB,
    AutoGUIKey.numSubtract: 0xFFAD,
    AutoGUIKey.numDecimal: 0xFFAE,
    AutoGUIKey.numDivide: 0xFFAF,
    AutoGUIKey.numSeparator: 0xFFAC,
  };

  @override
  int? mapKey(AutoGUIKey key) {
    final keysym = _keysyms[key];
    if (keysym == null) return null;
    final keycode = _b.keysymToKeycode(keysym);
    if (keycode == null || keycode == 0) return null;
    return keycode;
  }
}

class _WindowsKeyboard implements PlatformKeyboard {
  _WindowsKeyboard(this._b);

  final NativeBindings _b;

  @override
  void keyDown(int keycode) => _b.keyDown(keycode);

  @override
  void keyUp(int keycode) => _b.keyUp(keycode);

  @override
  KeyStroke? charToKeyStroke(String char) {
    if (char.length != 1) return null;
    final base = baseChar(char);
    final upper = base.toUpperCase();
    final code = upper.codeUnitAt(0);

    if (base == ' ') {
      return const KeyStroke(0x20);
    }
    if (base == '\n' || base == '\r') {
      return const KeyStroke(0x0D);
    }
    if (base == '\t') {
      return const KeyStroke(0x09);
    }

    if ((code >= 48 && code <= 57) || (code >= 65 && code <= 90)) {
      return KeyStroke(
        code,
        modifiers: requiresShift(char) ? const [AutoGUIKey.shift] : const [],
      );
    }

    const windowsPunctuation = {
      ';': 0xBA,
      '=': 0xBB,
      ',': 0xBC,
      '-': 0xBD,
      '.': 0xBE,
      '/': 0xBF,
      '`': 0xC0,
      '[': 0xDB,
      '\\': 0xDC,
      ']': 0xDD,
      '\'': 0xDE,
    };
    final punct = windowsPunctuation[base];
    if (punct == null) return null;
    return KeyStroke(
      punct,
      modifiers: requiresShift(char) ? const [AutoGUIKey.shift] : const [],
    );
  }

  // Win32 virtual-key codes (VK_*). fn has no VK code and is absent.
  static const Map<AutoGUIKey, int> _keyCodes = {
    AutoGUIKey.enter: 0x0D, // VK_RETURN
    AutoGUIKey.space: 0x20, // VK_SPACE
    AutoGUIKey.tab: 0x09, // VK_TAB
    AutoGUIKey.escape: 0x1B, // VK_ESCAPE
    AutoGUIKey.backspace: 0x08, // VK_BACK
    AutoGUIKey.shift: 0x10, // VK_SHIFT
    AutoGUIKey.control: 0x11, // VK_CONTROL
    AutoGUIKey.alt: 0x12, // VK_MENU
    AutoGUIKey.cmd: 0x5B, // VK_LWIN
    AutoGUIKey.shiftLeft: 0xA0, // VK_LSHIFT
    AutoGUIKey.shiftRight: 0xA1, // VK_RSHIFT
    AutoGUIKey.controlLeft: 0xA2, // VK_LCONTROL
    AutoGUIKey.controlRight: 0xA3, // VK_RCONTROL
    AutoGUIKey.altLeft: 0xA4, // VK_LMENU
    AutoGUIKey.altRight: 0xA5, // VK_RMENU
    AutoGUIKey.winLeft: 0x5B, // VK_LWIN
    AutoGUIKey.winRight: 0x5C, // VK_RWIN
    AutoGUIKey.capsLock: 0x14, // VK_CAPITAL
    AutoGUIKey.numLock: 0x90, // VK_NUMLOCK
    AutoGUIKey.scrollLock: 0x91, // VK_SCROLL
    AutoGUIKey.f1: 0x70,
    AutoGUIKey.f2: 0x71,
    AutoGUIKey.f3: 0x72,
    AutoGUIKey.f4: 0x73,
    AutoGUIKey.f5: 0x74,
    AutoGUIKey.f6: 0x75,
    AutoGUIKey.f7: 0x76,
    AutoGUIKey.f8: 0x77,
    AutoGUIKey.f9: 0x78,
    AutoGUIKey.f10: 0x79,
    AutoGUIKey.f11: 0x7A,
    AutoGUIKey.f12: 0x7B,
    AutoGUIKey.f13: 0x7C,
    AutoGUIKey.f14: 0x7D,
    AutoGUIKey.f15: 0x7E,
    AutoGUIKey.f16: 0x7F,
    AutoGUIKey.f17: 0x80,
    AutoGUIKey.f18: 0x81,
    AutoGUIKey.f19: 0x82,
    AutoGUIKey.f20: 0x83,
    AutoGUIKey.f21: 0x84,
    AutoGUIKey.f22: 0x85,
    AutoGUIKey.f23: 0x86,
    AutoGUIKey.f24: 0x87,
    AutoGUIKey.up: 0x26, // VK_UP
    AutoGUIKey.down: 0x28, // VK_DOWN
    AutoGUIKey.left: 0x25, // VK_LEFT
    AutoGUIKey.right: 0x27, // VK_RIGHT
    AutoGUIKey.home: 0x24, // VK_HOME
    AutoGUIKey.end: 0x23, // VK_END
    AutoGUIKey.pageUp: 0x21, // VK_PRIOR
    AutoGUIKey.pageDown: 0x22, // VK_NEXT
    AutoGUIKey.insert: 0x2D, // VK_INSERT
    AutoGUIKey.delete: 0x2E, // VK_DELETE
    AutoGUIKey.clear: 0x0C, // VK_CLEAR
    AutoGUIKey.select: 0x29, // VK_SELECT
    AutoGUIKey.execute: 0x2B, // VK_EXECUTE
    AutoGUIKey.printScreen: 0x2C, // VK_SNAPSHOT
    AutoGUIKey.pause: 0x13, // VK_PAUSE
    AutoGUIKey.menu: 0x5D, // VK_APPS
    AutoGUIKey.help: 0x2F, // VK_HELP
    AutoGUIKey.num0: 0x60,
    AutoGUIKey.num1: 0x61,
    AutoGUIKey.num2: 0x62,
    AutoGUIKey.num3: 0x63,
    AutoGUIKey.num4: 0x64,
    AutoGUIKey.num5: 0x65,
    AutoGUIKey.num6: 0x66,
    AutoGUIKey.num7: 0x67,
    AutoGUIKey.num8: 0x68,
    AutoGUIKey.num9: 0x69,
    AutoGUIKey.numMultiply: 0x6A, // VK_MULTIPLY
    AutoGUIKey.numAdd: 0x6B, // VK_ADD
    AutoGUIKey.numSubtract: 0x6D, // VK_SUBTRACT
    AutoGUIKey.numDecimal: 0x6E, // VK_DECIMAL
    AutoGUIKey.numDivide: 0x6F, // VK_DIVIDE
    AutoGUIKey.numSeparator: 0x6C, // VK_SEPARATOR
  };

  @override
  int? mapKey(AutoGUIKey key) => _keyCodes[key];
}

PlatformMouse? _platformMouse;
PlatformKeyboard? _platformKeyboard;

/// Mockable instance for testing
set platformMouseInstance(PlatformMouse? mock) => _platformMouse = mock;
set platformKeyboardInstance(PlatformKeyboard? mock) =>
    _platformKeyboard = mock;

PlatformMouse get platformMouse =>
    _platformMouse ??= _NativeMouse(NativeBindings.load());

PlatformKeyboard get platformKeyboard {
  if (_platformKeyboard != null) return _platformKeyboard!;
  final b = NativeBindings.load();
  if (Platform.isMacOS) return _platformKeyboard = _MacKeyboard(b);
  if (Platform.isLinux) return _platformKeyboard = _LinuxKeyboard(b);
  if (Platform.isWindows) return _platformKeyboard = _WindowsKeyboard(b);
  throw UnsupportedError('Platform not supported');
}
