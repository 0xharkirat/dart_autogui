import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:autogui/autogui.dart';
import 'package:autogui/src/platform.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'mocks/mock_platform.dart';

/// Builds a [Capture] from rows of `(r, g, b)` pixels (alpha forced opaque).
Capture cap(
  List<List<(int, int, int)>> rows, {
  double scale = 1.0,
  Point<int> origin = const Point(0, 0),
  int alpha = 255,
}) {
  final height = rows.length, width = rows.first.length;
  final bytes = Uint8List(width * height * 4);
  var i = 0;
  for (final row in rows) {
    for (final (r, g, b) in row) {
      bytes[i++] = r;
      bytes[i++] = g;
      bytes[i++] = b;
      bytes[i++] = alpha;
    }
  }
  return Capture(bytes, width, height, scale: scale, origin: origin);
}

const _k = (0, 0, 0); // black
const _w = (255, 255, 255); // white
const _r = (255, 0, 0); // red

void main() {
  group('locate', () {
    test('finds a needle and reports physical coordinates', () {
      final haystack = cap([
        [_k, _k, _k, _k],
        [_k, _w, _r, _k],
        [_k, _r, _w, _k],
        [_k, _k, _k, _k],
      ]);
      final needle = cap([
        [_w, _r],
        [_r, _w],
      ]);
      expect(locate(needle, haystack), const Rectangle(1, 1, 2, 2));
    });

    test('returns null when the needle is absent', () {
      final haystack = cap([
        [_k, _k],
        [_k, _k],
      ]);
      final needle = cap([
        [_w],
      ]);
      expect(locate(needle, haystack), isNull);
    });

    test('returns null when the needle is larger than the haystack', () {
      final haystack = cap([
        [_k],
      ]);
      final needle = cap([
        [_k, _k],
      ]);
      expect(locate(needle, haystack), isNull);
      expect(locateAll(needle, haystack), isEmpty);
    });

    test('locateAll finds every occurrence', () {
      final haystack = cap([
        [_r, _k, _r, _k, _r],
      ]);
      final needle = cap([
        [_r],
      ]);
      expect(locateAll(needle, haystack).toList(), [
        const Rectangle(0, 0, 1, 1),
        const Rectangle(2, 0, 1, 1),
        const Rectangle(4, 0, 1, 1),
      ]);
    });

    test('matches on RGB only, ignoring alpha', () {
      final haystack = cap([
        [_k, _r],
      ], alpha: 255);
      final needle = cap([
        [_r],
      ], alpha: 7);
      expect(locate(needle, haystack), const Rectangle(1, 0, 1, 1));
    });

    test('does not match when only some needle pixels line up', () {
      final haystack = cap([
        [_r, _k],
        [_k, _k],
      ]);
      // Starts with red (passes the first-pixel early-out) but diverges after.
      final needle = cap([
        [_r, _r],
      ]);
      expect(locate(needle, haystack), isNull);
    });
  });

  group('Capture.toLogical', () {
    test('is identity at scale 1 with no origin', () {
      final c = cap([
        [_k],
      ]);
      expect(c.toLogical(3, 5), const Point(3, 5));
    });

    test('divides by the scale and offsets by the origin', () {
      final c = cap(
        [
          [_k],
        ],
        scale: 2.0,
        origin: const Point(100, 50),
      );
      expect(c.toLogical(4, 2), const Point(102, 51));
    });
  });

  group('Screen.locateOnScreen', () {
    late MockPlatformScreen mockScreen;
    late Directory tmp;
    late String needlePath;

    setUp(() {
      mockScreen = MockPlatformScreen();
      platformScreenInstance = mockScreen;

      tmp = Directory.systemTemp.createTempSync('autogui_locate');
      // A 2x2 needle: white/red over red/white.
      final image = img.Image(width: 2, height: 2, numChannels: 4);
      void set(int x, int y, (int, int, int) c) =>
          image.setPixelRgba(x, y, c.$1, c.$2, c.$3, 255);
      set(0, 0, _w);
      set(1, 0, _r);
      set(0, 1, _r);
      set(1, 1, _w);
      needlePath = '${tmp.path}/needle.png';
      File(needlePath).writeAsBytesSync(img.encodePng(image));
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    test('returns the match in logical coordinates on a HiDPI capture', () {
      // 8x6 physical at scale 2 => 4x3 logical. Needle sits at physical (4,2).
      final haystack = cap([
        [_k, _k, _k, _k, _k, _k, _k, _k],
        [_k, _k, _k, _k, _k, _k, _k, _k],
        [_k, _k, _k, _k, _w, _r, _k, _k],
        [_k, _k, _k, _k, _r, _w, _k, _k],
        [_k, _k, _k, _k, _k, _k, _k, _k],
        [_k, _k, _k, _k, _k, _k, _k, _k],
      ], scale: 2.0);
      mockScreen.nextCapture = haystack;

      // physical (4,2,2,2) -> logical (2,1,1,1)
      expect(Screen.locateOnScreen(needlePath), const Rectangle(2, 1, 1, 1));
      expect(Screen.locateCenterOnScreen(needlePath), const Point(2, 1));
    });

    test('offsets by the capture origin when a region was searched', () {
      final haystack = cap(
        [
          [_w, _r],
          [_r, _w],
        ],
        scale: 1.0,
        origin: const Point(300, 200),
      );
      mockScreen.nextCapture = haystack;

      expect(
        Screen.locateOnScreen(
          needlePath,
          region: const Rectangle(300, 200, 2, 2),
        ),
        const Rectangle(300, 200, 2, 2),
      );
    });

    test('returns null when the needle is not on screen', () {
      mockScreen.nextCapture = cap([
        [_k, _k],
        [_k, _k],
      ]);
      expect(Screen.locateOnScreen(needlePath), isNull);
      expect(Screen.locateCenterOnScreen(needlePath), isNull);
      expect(Screen.locateAllOnScreen(needlePath), isEmpty);
    });

    test('throws on a file that is not a decodable image', () {
      final bad = '${tmp.path}/not_an_image.png';
      File(bad).writeAsStringSync('definitely not a png');
      expect(() => Screen.locateOnScreen(bad), throwsArgumentError);
    });
  });
}
