import 'dart:math';
import 'dart:typed_data';

import 'package:autogui/autogui.dart';
import 'package:autogui/src/platform.dart';
import 'package:test/test.dart';

import 'mocks/mock_platform.dart';

void main() {
  group('Capture', () {
    test('pixelAt reads RGB out of the RGBA buffer', () {
      // 2x1 image: red pixel then green pixel.
      final bytes = Uint8List.fromList([255, 0, 0, 255, 0, 255, 0, 255]);
      final capture = Capture(bytes, 2, 1);
      expect(capture.pixelAt(0, 0), (255, 0, 0));
      expect(capture.pixelAt(1, 0), (0, 255, 0));
    });

    test('pixelAt indexes rows correctly', () {
      // 2x2, distinct blue channel per pixel so row math is observable.
      final bytes = Uint8List.fromList([
        0, 0, 1, 255, 0, 0, 2, 255, // row 0
        0, 0, 3, 255, 0, 0, 4, 255, // row 1
      ]);
      final capture = Capture(bytes, 2, 2);
      expect(capture.pixelAt(0, 1), (0, 0, 3));
      expect(capture.pixelAt(1, 1), (0, 0, 4));
    });

    test('pixelAt rejects out-of-bounds coordinates', () {
      final capture = Capture(Uint8List(4), 1, 1);
      expect(() => capture.pixelAt(1, 0), throwsRangeError);
      expect(() => capture.pixelAt(0, -1), throwsRangeError);
    });
  });

  group('Screen capture', () {
    late MockPlatformScreen mockScreen;

    setUp(() {
      mockScreen = MockPlatformScreen();
      platformScreenInstance = mockScreen;
    });

    test('screenshot passes the region through in logical coordinates', () {
      Screen.screenshot(region: const Rectangle(10, 20, 30, 40));
      expect(mockScreen.calls, contains('capture(10,20,30,40)'));
    });

    test('screenshot with no region captures the full display', () {
      Screen.screenshot();
      expect(mockScreen.calls, contains('capture(full)'));
    });

    test('screenshot returns the platform capture unchanged', () {
      mockScreen.nextCapture = Capture(
        Uint8List.fromList([9, 8, 7, 255]),
        1,
        1,
      );
      final shot = Screen.screenshot();
      expect(shot.width, 1);
      expect(shot.height, 1);
      expect(shot.pixelAt(0, 0), (9, 8, 7));
    });

    test('isScreenCaptureTrusted delegates to the platform', () {
      mockScreen.trusted = false;
      expect(Screen.isScreenCaptureTrusted, isFalse);
      mockScreen.trusted = true;
      expect(Screen.isScreenCaptureTrusted, isTrue);
    });
  });
}
