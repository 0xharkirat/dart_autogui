import 'dart:async';
import 'platform.dart';

// Very abbreviated Key mapping.
// Ideally, we'd have a full enum. For now, we support raw codes or a few named ones.

enum AutoGUIKey {
  enter,
  space,
  tab,
  escape,
  backspace,
  shift,
  control,
  alt,
  cmd, // Command/Meta/Win
}

class KeyStroke {
  const KeyStroke(this.keycode, {this.modifiers = const []});

  final int keycode;
  final List<AutoGUIKey> modifiers;
}

class FailSafeException implements Exception {
  const FailSafeException(this.message);

  final String message;

  @override
  String toString() => 'FailSafeException: $message';
}

class Keyboard {
  /// When enabled, keyboard actions abort if the pointer is in a fail-safe corner.
  static bool failSafeEnabled = true;

  /// Additional delay applied after async keyboard actions.
  static Duration pauseAfterAction = Duration.zero;

  /// Corner padding used for fail-safe detection.
  static int failSafePadding = 0;

  static bool get isFailSafeTriggered => _isFailSafeTriggered();

  /// Press a single key (down then up).
  /// [key] can be an [AutoGUIKey], an int (raw platform keycode),
  /// or a single-character [String] when the current platform can map it.
  static Future<void> press(
    dynamic key, {
    Duration? interval,
    int presses = 1,
  }) async {
    final stroke = _requireKeyStroke(key);
    // Matches PyAutoGUI: a non-positive [presses] is a no-op, each press is a
    // discrete down/up (the key is never held for [interval]), fail-safe is
    // re-checked before every press, and [interval] is a gap *after* each press.
    for (int i = 0; i < presses; i++) {
      _checkFailSafe();
      _applyKeyDown(stroke);
      _applyKeyUp(stroke);
      if (interval != null) await Future.delayed(interval);
    }
    await _pauseIfNeeded();
  }

  /// Type a string [message]. Currently only supports ASCII characters that map simply.
  /// Complex mapping (uppercase, symbols) requires generic layout awareness which is hard.
  /// This is a basic implementation.
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
      _checkFailSafe();
      _typeChar(message[i]);
      if (interval > Duration.zero) {
        await Future.delayed(interval);
      }
    }
    await _pauseIfNeeded();
  }

  static void keyDown(dynamic key) {
    _checkFailSafe();
    _applyKeyDown(_requireKeyStroke(key));
  }

  static void keyUp(dynamic key) {
    _applyKeyUp(_requireKeyStroke(key));
  }

  static Future<void> hotkey(List<dynamic> keys, {Duration? interval}) async {
    if (keys.isEmpty) return;
    _checkFailSafe();
    final strokes = keys.map(_requireKeyStroke).toList(growable: false);
    for (final stroke in strokes) {
      _applyKeyDown(stroke);
      if (interval != null) await Future.delayed(interval);
    }
    for (final stroke in strokes.reversed) {
      _applyKeyUp(stroke);
      if (interval != null) await Future.delayed(interval);
    }
    await _pauseIfNeeded();
  }

  static Future<void> keyChord(List<dynamic> keys, {Duration? interval}) =>
      hotkey(keys, interval: interval);

  static Future<T> hold<T>(dynamic key, FutureOr<T> Function() action) async {
    final stroke = _requireKeyStroke(key);
    _checkFailSafe();
    _applyKeyDown(stroke);
    try {
      return await action();
    } finally {
      _applyKeyUp(stroke);
      await _pauseIfNeeded();
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
    if (key is String && key.length == 1) {
      return platformKeyboard.charToKeyStroke(key);
    }
    if (key is AutoGUIKey) {
      final keycode = platformKeyboard.mapKey(key);
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

  static void _checkFailSafe() {
    if (!_isFailSafeTriggered()) return;
    throw const FailSafeException(
      'Pointer is in a fail-safe corner. Move it away from the screen edge or disable Keyboard.failSafeEnabled to continue.',
    );
  }

  static bool _isFailSafeTriggered() {
    if (!failSafeEnabled) return false;
    final p = platformMouse.position();
    final size = platformMouse.screenSize();
    final pad = failSafePadding.toDouble();
    final maxX = (size.x - 1).toDouble();
    final maxY = (size.y - 1).toDouble();
    // Match a corner *point* within [failSafePadding], like PyAutoGUI's
    // FAILSAFE_POINTS. Open-ended edge bands (p.x <= pad, p.x >= maxX - pad)
    // false-triggered on multi-monitor layouts, where the pointer legitimately
    // reports negative coordinates (a display left/above the primary) or
    // coordinates past the primary size (a display right/below it).
    bool near(double value, double target) => (value - target).abs() <= pad;
    final atLeftOrRight = near(p.x, 0) || near(p.x, maxX);
    final atTopOrBottom = near(p.y, 0) || near(p.y, maxY);
    return atLeftOrRight && atTopOrBottom;
  }

  static Future<void> _pauseIfNeeded() async {
    if (pauseAfterAction > Duration.zero) {
      await Future.delayed(pauseAfterAction);
    }
  }
}
