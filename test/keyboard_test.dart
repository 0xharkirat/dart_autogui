import 'package:autogui/autogui.dart';
import 'package:autogui/src/platform.dart';
import 'package:test/test.dart';

import 'mocks/mock_platform.dart';

void main() {
  late MockPlatformKeyboard mockKeyboard;

  setUp(() {
    mockKeyboard = MockPlatformKeyboard();
    platformKeyboardInstance = mockKeyboard;
  });

  group('Keyboard Tests', () {
    test('press calls keyDown and keyUp', () async {
      // Mock maps space to 1001 (1000 + 1)
      await Keyboard.press(AutoGUIKey.space);
      expect(mockKeyboard.calls, ['keyDown(1001)', 'keyUp(1001)']);
    });

    test('press supports single-character strings', () async {
      await Keyboard.press('a');
      expect(mockKeyboard.calls, ['keyDown(97)', 'keyUp(97)']);
    });

    test('typeWrite calls keyDown/Up for each char', () async {
      // Mock charToKeycode: 'A' -> 65
      await Keyboard.typeWrite('A');
      expect(mockKeyboard.calls, ['keyDown(65)', 'keyUp(65)']);
    });

    test('typeWrite multiple chars', () async {
      await Keyboard.typeWrite('AB');
      expect(mockKeyboard.calls, [
        'keyDown(65)',
        'keyUp(65)',
        'keyDown(66)',
        'keyUp(66)',
      ]);
    });
  });
}
