// Manual smoke test for native screen capture (phase 3, milestone A).
//
// Run from the package root:
//   dart run tool/verify_capture.dart
//
// macOS: the *app that owns this process* needs Screen Recording permission
// (System Settings > Privacy & Security > Screen Recording), then restart it.
// That is the terminal app if you run this from a terminal, not `dart` itself.
import 'dart:io';
import 'dart:math';

import 'package:autogui/autogui.dart';

void main() {
  stdout.writeln('screen capture permitted: ${Screen.isScreenCaptureTrusted}');

  final logical = Screen.size();
  stdout.writeln('Screen.size() (logical points): ${logical.x} x ${logical.y}');

  try {
    final full = Screen.screenshot(filename: 'capture_full.png');
    stdout.writeln(
      'full capture (physical px): ${full.width} x ${full.height}',
    );
    stdout.writeln(
      'scale: ${(full.width / logical.x).toStringAsFixed(2)}x '
      '${(full.height / logical.y).toStringAsFixed(2)}',
    );

    final expected = full.width * full.height * 4;
    stdout.writeln('rgba bytes: ${full.rgba.length} (expected $expected)');
    if (full.rgba.length != expected) {
      stdout.writeln('MISMATCH: buffer size does not match dimensions');
    }
    stdout.writeln('pixelAt(0, 0): ${full.pixelAt(0, 0)}');

    final region = Screen.screenshot(region: const Rectangle(0, 0, 10, 10));
    stdout.writeln(
      'region 10x10 logical -> ${region.width} x ${region.height} physical',
    );

    stdout.writeln(
      'wrote capture_full.png '
      '(${File('capture_full.png').lengthSync()} bytes)',
    );

    // Screen.pixel takes LOGICAL coords and must read the PHYSICAL pixel at
    // (x*scale, y*scale). Probing a flat-colored area proves nothing, so hunt
    // for points where the scaled and unscaled reads actually differ - there a
    // wrong mapping cannot silently pass.
    final scale = full.width ~/ logical.x;
    stdout.writeln('\n-- pixel() vs full capture (scale $scale) --');

    // The value of the scale x scale physical block behind a logical pixel,
    // but only when the block is uniform - so sub-pixel drift can't flap.
    (int, int, int)? uniformBlock(int lx, int ly) {
      final first = full.pixelAt(lx * scale, ly * scale);
      for (var dy = 0; dy < scale; dy++) {
        for (var dx = 0; dx < scale; dx++) {
          if (full.pixelAt(lx * scale + dx, ly * scale + dy) != first) {
            return null;
          }
        }
      }
      return first;
    }

    final probes = <Point<int>>[];
    if (scale > 1) {
      for (var y = 1; y < logical.y - 1 && probes.length < 3; y += 29) {
        for (var x = 1; x < logical.x - 1 && probes.length < 3; x += 41) {
          final scaled = uniformBlock(x, y);
          if (scaled != null && scaled != full.pixelAt(x, y)) {
            probes.add(Point(x, y));
          }
        }
      }
    }

    var mapped = true;
    if (scale == 1) {
      stdout.writeln('scale is 1: logical == physical, mapping is identity');
    } else if (probes.isEmpty) {
      stdout.writeln('WARN: screen too uniform to find a discriminating probe');
    } else {
      for (final p in probes) {
        final scaled = full.pixelAt(p.x * scale, p.y * scale);
        final unscaled = full.pixelAt(p.x, p.y);
        final got = Screen.pixel(p.x, p.y);
        final ok = got == scaled;
        if (!ok) mapped = false;
        stdout.writeln(
          '${ok ? "OK  " : "FAIL"} pixel(${p.x},${p.y})=$got  '
          'scaled=$scaled  unscaled=$unscaled',
        );
      }
    }
    if (!mapped) {
      stdout.writeln(
        'FAIL means pixel() did not read the scaled pixel. If it matched '
        '"unscaled", the logical->physical mapping is broken. If it matched '
        'neither, live screen content changed between captures - re-run.',
      );
    }

    final here = Screen.pixel(0, 0);
    stdout.writeln(
      'pixelMatchesColor(0,0, $here) = '
      '${Screen.pixelMatchesColor(0, 0, here)} (expect true)',
    );
    stdout.writeln(
      'pixelMatchesColor(0,0, (0,0,0), tolerance: 255) = '
      '${Screen.pixelMatchesColor(0, 0, (0, 0, 0), tolerance: 255)} '
      '(expect true)',
    );

    stdout.writeln('\nOK');
  } on StateError catch (e) {
    stdout.writeln('CAPTURE FAILED: ${e.message}');
    exitCode = 1;
  }
}
