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

class Keyboard {
  /// Press a single key (down then up).
  /// [key] can be an [AutoGUIKey], an int (raw platform keycode),
  /// or a single-character [String] when the current platform can map it.
  static Future<void> press(dynamic key, {Duration? interval}) async {
    keyDown(key);
    if (interval != null) await Future.delayed(interval);
    keyUp(key);
  }

  /// Type a string [message]. Currently only supports ASCII characters that map simply.
  /// Complex mapping (uppercase, symbols) requires generic layout awareness which is hard.
  /// This is a basic implementation.
  static Future<void> typeWrite(
    String message, {
    double intervalSec = 0.0,
  }) async {
    for (int i = 0; i < message.length; i++) {
      final char = message[i];
      _typeChar(char);
      if (intervalSec > 0) {
        await Future.delayed(
          Duration(milliseconds: (intervalSec * 1000).toInt()),
        );
      }
    }
  }

  static void keyDown(dynamic key) {
    int? code = _getKeyCode(key);
    if (code != null) platformKeyboard.keyDown(code);
  }

  static void keyUp(dynamic key) {
    int? code = _getKeyCode(key);
    if (code != null) platformKeyboard.keyUp(code);
  }

  static void _typeChar(String char) {
    // This is extremely platform dependent and layout dependent.
    // We defer to the platform helper to try to map char to keycode.
    // Or we use a restricted set for now.
    int? code = platformKeyboard.charToKeycode(char);
    if (code != null) {
      // Need to handle shift for uppercase?
      // Basic impl: just press key.
      platformKeyboard.keyDown(code);
      platformKeyboard.keyUp(code);
    }
  }

  static int? _getKeyCode(dynamic key) {
    if (key is int) return key;
    if (key is String && key.length == 1) {
      return platformKeyboard.charToKeycode(key);
    }
    if (key is AutoGUIKey) {
      return platformKeyboard.mapKey(key);
    }
    return null;
  }
}
