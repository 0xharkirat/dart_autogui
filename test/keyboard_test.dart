import 'package:autogui/autogui.dart';
import 'package:autogui/src/platform.dart';
import 'package:test/test.dart';

import 'mocks/mock_platform.dart';

void main() {
  late MockPlatformKeyboard mockKeyboard;
  late MockPlatformMouse mockMouse;

  setUp(() {
    mockKeyboard = MockPlatformKeyboard();
    mockMouse = MockPlatformMouse()..setPosition(100, 100);
    platformKeyboardInstance = mockKeyboard;
    platformMouseInstance = mockMouse;
    Keyboard.failSafeEnabled = true;
    Keyboard.pauseAfterAction = Duration.zero;
    Keyboard.failSafePadding = 0;
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

    test('press applies shift for uppercase characters', () async {
      await Keyboard.press('A');
      expect(mockKeyboard.calls, [
        'keyDown(1005)',
        'keyDown(97)',
        'keyUp(97)',
        'keyUp(1005)',
      ]);
    });

    test('press applies shift for shifted punctuation', () async {
      // '!' -> shift + base key '1' (code unit 49 stands in for the keycode).
      await Keyboard.press('!');
      expect(mockKeyboard.calls, [
        'keyDown(1005)',
        'keyDown(49)',
        'keyUp(49)',
        'keyUp(1005)',
      ]);
    });

    test('press repeats without holding the key for presses > 1', () async {
      await Keyboard.press('a', presses: 3);
      expect(mockKeyboard.calls, [
        'keyDown(97)',
        'keyUp(97)',
        'keyDown(97)',
        'keyUp(97)',
        'keyDown(97)',
        'keyUp(97)',
      ]);
    });

    test('press with non-positive presses is a no-op', () async {
      await Keyboard.press('a', presses: 0);
      expect(mockKeyboard.calls, isEmpty);
    });

    test('typeWrite calls keyDown/Up for each char', () async {
      await Keyboard.typeWrite('A');
      expect(mockKeyboard.calls, [
        'keyDown(1005)',
        'keyDown(97)',
        'keyUp(97)',
        'keyUp(1005)',
      ]);
    });

    test('typeWrite multiple chars', () async {
      await Keyboard.typeWrite('AB');
      expect(mockKeyboard.calls, [
        'keyDown(1005)',
        'keyDown(97)',
        'keyUp(97)',
        'keyUp(1005)',
        'keyDown(1005)',
        'keyDown(98)',
        'keyUp(98)',
        'keyUp(1005)',
      ]);
    });

    test('write supports mixed-case strings', () async {
      await Keyboard.write('Ab');
      expect(mockKeyboard.calls, [
        'keyDown(1005)',
        'keyDown(97)',
        'keyUp(97)',
        'keyUp(1005)',
        'keyDown(98)',
        'keyUp(98)',
      ]);
    });

    test('hotkey presses keys down in order and releases in reverse', () async {
      await Keyboard.hotkey([AutoGUIKey.control, 'c']);
      expect(mockKeyboard.calls, [
        'keyDown(1006)',
        'keyDown(99)',
        'keyUp(99)',
        'keyUp(1006)',
      ]);
    });

    test('hold keeps key pressed during callback and releases after', () async {
      final seenInside = <String>[];
      await Keyboard.hold(AutoGUIKey.shift, () async {
        seenInside.addAll(mockKeyboard.calls);
      });
      expect(seenInside, ['keyDown(1005)']);
      expect(mockKeyboard.calls, ['keyDown(1005)', 'keyUp(1005)']);
    });

    test('keyChord aliases hotkey', () async {
      await Keyboard.keyChord([AutoGUIKey.alt, 'x']);
      expect(mockKeyboard.calls, [
        'keyDown(1007)',
        'keyDown(120)',
        'keyUp(120)',
        'keyUp(1007)',
      ]);
    });

    test('press throws when fail-safe is triggered', () async {
      mockMouse.setPosition(0, 0);
      expect(() => Keyboard.press('a'), throwsA(isA<FailSafeException>()));
    });

    test(
      'fail-safe does not trigger off-primary-monitor coordinates',
      () async {
        // A display left/above the primary reports negative coordinates; one
        // right/below reports coordinates past the primary size. Neither is a
        // corner point, so keyboard actions must not abort.
        mockMouse.setPosition(-800, -100);
        await Keyboard.press('a');
        mockMouse.setPosition(3000, 1500);
        await Keyboard.press('a');
        expect(mockKeyboard.calls, [
          'keyDown(97)',
          'keyUp(97)',
          'keyDown(97)',
          'keyUp(97)',
        ]);
      },
    );

    test('fail-safe triggers at the bottom-right primary corner', () async {
      // screenSize is 1920x1080 -> corner point (1919, 1079).
      mockMouse.setPosition(1919, 1079);
      expect(() => Keyboard.press('a'), throwsA(isA<FailSafeException>()));
    });
  });

  group('Named key resolution', () {
    // The mock maps every AutoGUIKey to (1000 + index), so expected codes are
    // derived from the enum rather than hard-coded.
    String down(AutoGUIKey k) => 'keyDown(${1000 + k.index})';
    String up(AutoGUIKey k) => 'keyUp(${1000 + k.index})';

    test('press resolves a named key string', () async {
      await Keyboard.press('f1');
      expect(mockKeyboard.calls, [down(AutoGUIKey.f1), up(AutoGUIKey.f1)]);
    });

    test('press resolves navigation and editing names', () async {
      await Keyboard.press('pageup');
      await Keyboard.press('delete');
      expect(mockKeyboard.calls, [
        down(AutoGUIKey.pageUp),
        up(AutoGUIKey.pageUp),
        down(AutoGUIKey.delete),
        up(AutoGUIKey.delete),
      ]);
    });

    test('named-key lookup is case-insensitive and honors aliases', () async {
      // 'RETURN' -> enter, 'ESC' -> escape, 'pgdn' -> pageDown.
      await Keyboard.press('RETURN');
      await Keyboard.press('Esc');
      await Keyboard.press('pgdn');
      expect(mockKeyboard.calls, [
        down(AutoGUIKey.enter),
        up(AutoGUIKey.enter),
        down(AutoGUIKey.escape),
        up(AutoGUIKey.escape),
        down(AutoGUIKey.pageDown),
        up(AutoGUIKey.pageDown),
      ]);
    });

    test('hotkey accepts pyautogui-style string names', () async {
      await Keyboard.hotkey(['ctrl', 'shift', 'c']);
      expect(mockKeyboard.calls, [
        down(AutoGUIKey.control),
        down(AutoGUIKey.shift),
        'keyDown(99)',
        'keyUp(99)',
        up(AutoGUIKey.shift),
        up(AutoGUIKey.control),
      ]);
    });

    test('press throws on an unknown key name', () {
      expect(() => Keyboard.press('notakey'), throwsA(isA<UnsupportedError>()));
    });

    test('isValidKey accepts names, chars, enums and ints', () {
      expect(Keyboard.isValidKey('f1'), isTrue);
      expect(Keyboard.isValidKey('a'), isTrue);
      expect(Keyboard.isValidKey(AutoGUIKey.up), isTrue);
      expect(Keyboard.isValidKey(42), isTrue);
      expect(Keyboard.isValidKey('notakey'), isFalse);
      expect(Keyboard.isValidKey(''), isFalse);
    });

    test('keyboardKeys is sorted and holds named keys only', () {
      final keys = Keyboard.keyboardKeys;
      expect(keys, containsAll(['enter', 'f1', 'pgup', 'up', 'numlock']));
      expect(keys, isNot(contains('a')));
      final sorted = [...keys]..sort();
      expect(keys, sorted);
    });
  });

  group('ASCII key mapping helpers', () {
    test('requiresShift detects uppercase and shifted punctuation', () {
      expect(requiresShift('A'), isTrue);
      expect(requiresShift('!'), isTrue);
      expect(requiresShift(':'), isTrue);
      expect(requiresShift('a'), isFalse);
      expect(requiresShift('1'), isFalse);
      expect(requiresShift(';'), isFalse);
    });

    test('baseChar folds to the unshifted physical key', () {
      expect(baseChar('A'), 'a');
      expect(baseChar('!'), '1');
      expect(baseChar(':'), ';');
      expect(baseChar('a'), 'a');
      expect(baseChar('1'), '1');
    });

    test('controlCharKeysym maps newline/return/tab to X11 keysyms', () {
      expect(controlCharKeysym('\n'), 0xFF0D);
      expect(controlCharKeysym('\r'), 0xFF0D);
      expect(controlCharKeysym('\t'), 0xFF09);
      expect(controlCharKeysym('a'), isNull);
    });
  });
}
