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
    stdout.writeln('full capture (physical px): ${full.width} x ${full.height}');
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

    stdout.writeln('wrote capture_full.png '
        '(${File('capture_full.png').lengthSync()} bytes)');
    stdout.writeln('OK');
  } on StateError catch (e) {
    stdout.writeln('CAPTURE FAILED: ${e.message}');
    exitCode = 1;
  }
}
