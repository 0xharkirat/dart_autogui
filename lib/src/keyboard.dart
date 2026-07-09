import 'dart:async';
import 'platform.dart';

/// Named keyboard keys, mirroring PyAutoGUI's `KEY_NAMES`.
///
/// A key's availability is platform-specific: values missing from a platform's
/// map (for example [f21]-[f24], [insert] and [numLock] on macOS) resolve to
/// `null` and are rejected by [Keyboard.isValidKey] on that platform. New
/// values are appended rather than reordered so existing enum indices stay
/// stable.
enum AutoGUIKey {
  // Core keys.
  enter,
  space,
  tab,
  escape,
  backspace,
  shift,
  control,
  alt,
  cmd, // Command/Meta/Win
  // Modifier variants.
  shiftLeft,
  shiftRight,
  controlLeft,
  controlRight,
  altLeft,
  altRight,
  winLeft,
  winRight,
  fn,
  capsLock,
  numLock,
  scrollLock,

  // Function keys.
  f1,
  f2,
  f3,
  f4,
  f5,
  f6,
  f7,
  f8,
  f9,
  f10,
  f11,
  f12,
  f13,
  f14,
  f15,
  f16,
  f17,
  f18,
  f19,
  f20,
  f21,
  f22,
  f23,
  f24,

  // Arrows.
  up,
  down,
  left,
  right,

  // Navigation.
  home,
  end,
  pageUp,
  pageDown,

  // Editing / system.
  insert,
  delete,
  clear,
  select,
  execute,
  printScreen,
  pause,
  menu,
  help,

  // Numpad.
  num0,
  num1,
  num2,
  num3,
  num4,
  num5,
  num6,
  num7,
  num8,
  num9,
  numMultiply,
  numAdd,
  numSubtract,
  numDecimal,
  numDivide,
  numSeparator,
}

/// PyAutoGUI-compatible key names (and their aliases) mapped to [AutoGUIKey].
///
/// Single-character keys (`'a'`, `'!'`, `' '`) are intentionally absent: those
/// resolve through platform char-to-keystroke mapping so they carry the right
/// Shift modifier. Lookups are lower-cased before hitting this table.
const Map<String, AutoGUIKey> _keyNames = {
  'enter': AutoGUIKey.enter,
  'return': AutoGUIKey.enter,
  'space': AutoGUIKey.space,
  'tab': AutoGUIKey.tab,
  'esc': AutoGUIKey.escape,
  'escape': AutoGUIKey.escape,
  'backspace': AutoGUIKey.backspace,
  'shift': AutoGUIKey.shift,
  'shiftleft': AutoGUIKey.shiftLeft,
  'shiftright': AutoGUIKey.shiftRight,
  'ctrl': AutoGUIKey.control,
  'control': AutoGUIKey.control,
  'ctrlleft': AutoGUIKey.controlLeft,
  'ctrlright': AutoGUIKey.controlRight,
  'alt': AutoGUIKey.alt,
  'option': AutoGUIKey.alt,
  'altleft': AutoGUIKey.altLeft,
  'optionleft': AutoGUIKey.altLeft,
  'altright': AutoGUIKey.altRight,
  'optionright': AutoGUIKey.altRight,
  'cmd': AutoGUIKey.cmd,
  'command': AutoGUIKey.cmd,
  'win': AutoGUIKey.cmd,
  'super': AutoGUIKey.cmd,
  'winleft': AutoGUIKey.winLeft,
  'winright': AutoGUIKey.winRight,
  'fn': AutoGUIKey.fn,
  'capslock': AutoGUIKey.capsLock,
  'numlock': AutoGUIKey.numLock,
  'scrolllock': AutoGUIKey.scrollLock,
  'f1': AutoGUIKey.f1,
  'f2': AutoGUIKey.f2,
  'f3': AutoGUIKey.f3,
  'f4': AutoGUIKey.f4,
  'f5': AutoGUIKey.f5,
  'f6': AutoGUIKey.f6,
  'f7': AutoGUIKey.f7,
  'f8': AutoGUIKey.f8,
  'f9': AutoGUIKey.f9,
  'f10': AutoGUIKey.f10,
  'f11': AutoGUIKey.f11,
  'f12': AutoGUIKey.f12,
  'f13': AutoGUIKey.f13,
  'f14': AutoGUIKey.f14,
  'f15': AutoGUIKey.f15,
  'f16': AutoGUIKey.f16,
  'f17': AutoGUIKey.f17,
  'f18': AutoGUIKey.f18,
  'f19': AutoGUIKey.f19,
  'f20': AutoGUIKey.f20,
  'f21': AutoGUIKey.f21,
  'f22': AutoGUIKey.f22,
  'f23': AutoGUIKey.f23,
  'f24': AutoGUIKey.f24,
  'up': AutoGUIKey.up,
  'down': AutoGUIKey.down,
  'left': AutoGUIKey.left,
  'right': AutoGUIKey.right,
  'home': AutoGUIKey.home,
  'end': AutoGUIKey.end,
  'pageup': AutoGUIKey.pageUp,
  'pgup': AutoGUIKey.pageUp,
  'pagedown': AutoGUIKey.pageDown,
  'pgdn': AutoGUIKey.pageDown,
  'insert': AutoGUIKey.insert,
  'del': AutoGUIKey.delete,
  'delete': AutoGUIKey.delete,
  'clear': AutoGUIKey.clear,
  'select': AutoGUIKey.select,
  'execute': AutoGUIKey.execute,
  'printscreen': AutoGUIKey.printScreen,
  'prtsc': AutoGUIKey.printScreen,
  'prtscr': AutoGUIKey.printScreen,
  'prntscrn': AutoGUIKey.printScreen,
  'print': AutoGUIKey.printScreen,
  'pause': AutoGUIKey.pause,
  'apps': AutoGUIKey.menu,
  'menu': AutoGUIKey.menu,
  'help': AutoGUIKey.help,
  'num0': AutoGUIKey.num0,
  'num1': AutoGUIKey.num1,
  'num2': AutoGUIKey.num2,
  'num3': AutoGUIKey.num3,
  'num4': AutoGUIKey.num4,
  'num5': AutoGUIKey.num5,
  'num6': AutoGUIKey.num6,
  'num7': AutoGUIKey.num7,
  'num8': AutoGUIKey.num8,
  'num9': AutoGUIKey.num9,
  'multiply': AutoGUIKey.numMultiply,
  'add': AutoGUIKey.numAdd,
  'subtract': AutoGUIKey.numSubtract,
  'decimal': AutoGUIKey.numDecimal,
  'divide': AutoGUIKey.numDivide,
  'separator': AutoGUIKey.numSeparator,
};

class KeyStroke {
  const KeyStroke(this.keycode, {this.modifiers = const []});

  final int keycode;
  final List<AutoGUIKey> modifiers;
}

class Keyboard {
  /// When enabled, actions abort if the pointer is in a fail-safe corner.
  /// Forwards to the shared [FailSafe.enabled] (honored by [Mouse] too).
  static bool get failSafeEnabled => FailSafe.enabled;
  static set failSafeEnabled(bool value) => FailSafe.enabled = value;

  /// Delay applied after async keyboard actions. Forwards to [FailSafe.pause].
  static Duration get pauseAfterAction => FailSafe.pause;
  static set pauseAfterAction(Duration value) => FailSafe.pause = value;

  /// Corner padding used for fail-safe detection. Forwards to [FailSafe.padding].
  static int get failSafePadding => FailSafe.padding;
  static set failSafePadding(int value) => FailSafe.padding = value;

  static bool get isFailSafeTriggered => FailSafe.triggered;

  /// The named keys accepted by [press], [keyDown], [hotkey], etc., mirroring
  /// PyAutoGUI's `KEY_NAMES`. Single characters (e.g. `'a'`, `'!'`) are also
  /// valid inputs but are not listed here. Availability of a named key varies
  /// by platform - check [isValidKey] for the running platform.
  static List<String> get keyboardKeys =>
      _keyNames.keys.toList(growable: false)..sort();

  /// Whether [key] resolves to something typeable on the current platform.
  ///
  /// Accepts the same inputs as [press]: an [AutoGUIKey], a raw int keycode, a
  /// single character, or a named key string. Returns false for unknown names
  /// and for named keys the current platform has no keycode for (e.g. `'f21'`
  /// on macOS).
  static bool isValidKey(dynamic key) => _getKeyStroke(key) != null;

  /// Press a single key (down then up).
  /// [key] can be an [AutoGUIKey], an int (raw platform keycode),
  /// or a single-character [String] when the current platform can map it.
  static Future<void> press(
    dynamic key, {
    Duration? interval,
    int presses = 1,
  }) async {
    // Non-positive [presses] is a no-op (PyAutoGUI parity): guard before
    // resolving so an unsupported key can't throw when nothing is pressed.
    if (presses < 1) return;
    final stroke = _requireKeyStroke(key);
    // Each press is a discrete down/up (the key is never held for [interval]),
    // fail-safe is re-checked before every press, and [interval] is a gap
    // *after* each press.
    for (int i = 0; i < presses; i++) {
      FailSafe.check();
      _applyKeyDown(stroke);
      _applyKeyUp(stroke);
      if (interval != null) await Future.delayed(interval);
    }
    await FailSafe.maybePause();
  }

  /// Type a string [message] one character at a time. Alias for [write].
  ///
  /// Uppercase letters and shifted punctuation are typed as base key + Shift on
  /// a US layout; non-ASCII characters and other layouts are not supported.
  /// [intervalSec] adds a delay in seconds between characters.
  static Future<void> typeWrite(
    String message, {
    double intervalSec = 0.0,
  }) async {
    await write(
      message,
      interval: Duration(milliseconds: (intervalSec * 1000).toInt()),
    );
  }

  static Future<void> write(
    String message, {
    Duration interval = Duration.zero,
  }) async {
    for (int i = 0; i < message.length; i++) {
      // Re-check per character so a mid-string fail-safe corner still aborts.
      FailSafe.check();
      _typeChar(message[i]);
      if (interval > Duration.zero) {
        await Future.delayed(interval);
      }
    }
    await FailSafe.maybePause();
  }

  static void keyDown(dynamic key) {
    FailSafe.check();
    _applyKeyDown(_requireKeyStroke(key));
  }

  static void keyUp(dynamic key) {
    _applyKeyUp(_requireKeyStroke(key));
  }

  static Future<void> hotkey(List<dynamic> keys, {Duration? interval}) async {
    if (keys.isEmpty) return;
    FailSafe.check();
    final strokes = keys.map(_requireKeyStroke).toList(growable: false);
    for (final stroke in strokes) {
      _applyKeyDown(stroke);
      if (interval != null) await Future.delayed(interval);
    }
    for (final stroke in strokes.reversed) {
      _applyKeyUp(stroke);
      if (interval != null) await Future.delayed(interval);
    }
    await FailSafe.maybePause();
  }

  static Future<void> keyChord(List<dynamic> keys, {Duration? interval}) =>
      hotkey(keys, interval: interval);

  static Future<T> hold<T>(dynamic key, FutureOr<T> Function() action) async {
    final stroke = _requireKeyStroke(key);
    FailSafe.check();
    _applyKeyDown(stroke);
    try {
      return await action();
    } finally {
      _applyKeyUp(stroke);
      await FailSafe.maybePause();
    }
  }

  static void _typeChar(String char) {
    final stroke = _requireKeyStroke(char);
    _applyKeyDown(stroke);
    _applyKeyUp(stroke);
  }

  static KeyStroke _requireKeyStroke(dynamic key) {
    final stroke = _getKeyStroke(key);
    if (stroke != null) return stroke;
    throw UnsupportedError('Unsupported key input: $key');
  }

  static KeyStroke? _getKeyStroke(dynamic key) {
    if (key is int) return KeyStroke(key);
    if (key is AutoGUIKey) {
      final keycode = platformKeyboard.mapKey(key);
      if (keycode == null) return null;
      return KeyStroke(keycode);
    }
    if (key is String) {
      // A single character types through the layout (carrying Shift as needed);
      // a longer string is a named key like 'enter', 'f1', or 'pageup'.
      if (key.length == 1) return platformKeyboard.charToKeyStroke(key);
      final named = _keyNames[key.toLowerCase()];
      if (named == null) return null;
      final keycode = platformKeyboard.mapKey(named);
      if (keycode == null) return null;
      return KeyStroke(keycode);
    }
    return null;
  }

  static void _applyKeyDown(KeyStroke stroke) {
    for (final modifier in stroke.modifiers) {
      final modifierCode = platformKeyboard.mapKey(modifier);
      if (modifierCode == null) {
        throw UnsupportedError('Unsupported modifier key: $modifier');
      }
      platformKeyboard.keyDown(modifierCode);
    }
    platformKeyboard.keyDown(stroke.keycode);
  }

  static void _applyKeyUp(KeyStroke stroke) {
    platformKeyboard.keyUp(stroke.keycode);
    for (final modifier in stroke.modifiers.reversed) {
      final modifierCode = platformKeyboard.mapKey(modifier);
      if (modifierCode == null) {
        throw UnsupportedError('Unsupported modifier key: $modifier');
      }
      platformKeyboard.keyUp(modifierCode);
    }
  }
}
