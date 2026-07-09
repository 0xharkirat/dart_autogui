import 'package:autogui/autogui.dart';
import 'package:autogui/src/platform.dart';
import 'package:test/test.dart';

import 'mocks/mock_platform.dart';

void main() {
  late MockPlatformMouse mockMouse;

  setUp(() {
    mockMouse = MockPlatformMouse();
    platformMouseInstance = mockMouse;
    // Mechanics tests below use the mock's (0,0) start, which is a corner;
    // keep them decoupled from the fail-safe (exercised in its own group).
    FailSafe.enabled = false;
    FailSafe.padding = 0;
  });

  group('Mouse Tests', () {
    test('moveTo calls platform absolute move', () async {
      await Mouse.moveTo(100, 200);
      expect(mockMouse.calls, contains('moveToAbsolute(100.0, 200.0)'));
    });

    test(
      'move relative calls platform absolute move based on current pos',
      () async {
        // Mock start pos 0,0
        await Mouse.move(50, 50);
        expect(mockMouse.calls, contains('moveToAbsolute(50.0, 50.0)'));
      },
    );

    test('click calls platform click', () {
      Mouse.click(button: MouseButton.right, clicks: 2);
      expect(mockMouse.calls, contains('click(right, 2)'));
    });

    test('middleClick clicks the middle button', () {
      Mouse.middleClick();
      expect(mockMouse.calls, contains('click(middle, 1)'));
    });

    test('scroll calls platform vscroll', () {
      Mouse.scroll(3);
      expect(mockMouse.calls, contains('vscroll(3)'));
    });
  });

  group('Mouse fail-safe', () {
    test('click throws when the pointer is in a screen corner', () {
      FailSafe.enabled = true;
      mockMouse.setPosition(0, 0); // top-left corner of the 1920x1080 mock
      expect(() => Mouse.click(), throwsA(isA<FailSafeException>()));
    });

    test('click proceeds when the pointer is away from any corner', () {
      FailSafe.enabled = true;
      mockMouse.setPosition(500, 500);
      Mouse.click();
      expect(mockMouse.calls, contains('click(left, 1)'));
    });

    test('mouseUp is never blocked by the fail-safe, even in a corner', () {
      // Releasing a held button must always go through, or a corner-parked
      // pointer could strand it down mid-drag.
      FailSafe.enabled = true;
      mockMouse.setPosition(0, 0);
      Mouse.mouseUp();
      expect(mockMouse.calls, contains('mouseUp(left)'));
    });
  });
}
