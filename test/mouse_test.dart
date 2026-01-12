import 'package:autogui/autogui.dart';
import 'package:autogui/src/platform.dart';
import 'package:test/test.dart';

import 'mocks/mock_platform.dart';

void main() {
  late MockPlatformMouse mockMouse;

  setUp(() {
    mockMouse = MockPlatformMouse();
    platformMouseInstance = mockMouse;
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

    test('scroll calls platform vscroll', () {
      Mouse.scroll(3);
      expect(mockMouse.calls, contains('vscroll(3)'));
    });
  });
}
