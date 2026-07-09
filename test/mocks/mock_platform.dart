import 'dart:math';
import 'package:autogui/src/platform.dart';
import 'package:autogui/src/keyboard.dart'; // For AutoGUIKey

class MockPlatformMouse implements PlatformMouse {
  final List<String> calls = [];
  Point<double> _pos = Point(0, 0);

  void setPosition(double x, double y) {
    _pos = Point(x, y);
  }

  @override
  Point<int> screenSize() {
    calls.add('screenSize');
    return Point(1920, 1080);
  }

  @override
  Point<double> position() {
    calls.add('position');
    return _pos;
  }

  @override
  void moveToAbsolute(double x, double y) {
    calls.add('moveToAbsolute($x, $y)');
    _pos = Point(x, y);
  }

  @override
  void mouseDown(MouseButton btn) {
    calls.add('mouseDown(${btn.name})');
  }

  @override
  void mouseUp(MouseButton btn) {
    calls.add('mouseUp(${btn.name})');
  }

  @override
  void click(MouseButton btn, {int clicks = 1, Duration? interval}) {
    calls.add('click(${btn.name}, $clicks)');
  }

  @override
  void vscroll(int deltaLines) {
    calls.add('vscroll($deltaLines)');
  }

  @override
  void hscroll(int deltaLines) {
    calls.add('hscroll($deltaLines)');
  }

  @override
  bool isAccessibilityTrusted() {
    calls.add('isAccessibilityTrusted');
    return true;
  }
}

class MockPlatformKeyboard implements PlatformKeyboard {
  final List<String> calls = [];

  @override
  void keyDown(int keycode) {
    calls.add('keyDown($keycode)');
  }

  @override
  void keyUp(int keycode) {
    calls.add('keyUp($keycode)');
  }

  @override
  KeyStroke? charToKeyStroke(String char) {
    if (char.length != 1) return null;
    // Reuse the real shared helpers so tests exercise the actual shift/base
    // logic (uppercase *and* shifted punctuation), not a mock reimplementation.
    // The base char's code unit stands in for a platform keycode.
    return KeyStroke(
      baseChar(char).codeUnitAt(0),
      modifiers: requiresShift(char) ? const [AutoGUIKey.shift] : const [],
    );
  }

  @override
  int? mapKey(AutoGUIKey key) {
    // Mock mapping: index + 1000
    return 1000 + key.index;
  }
}
