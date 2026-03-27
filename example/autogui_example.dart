import 'dart:io';
import 'package:autogui/autogui.dart';

Future<void> main() async {
  // Permissions tip
  if (!Mouse.isAccessibilityTrusted) {
    stderr.writeln(
      '⚠️  Accessibility missing. Enable your Terminal/IDE in:\n'
      'System Settings → Privacy & Security → Accessibility\n',
    );
  }

  // --- Print mouse position continuously (Ctrl+C to quit) -------------
  stdout.writeln('Press Ctrl+C to quit. Current position prints in place.\n');
  ProcessSignal.sigint.watch().listen((_) {
    stdout.writeln('\nBye!');
    exit(0);
  });

  // Also demonstrate the API once before loop:
  final size = Screen.size();
  stdout.writeln('Screen size: ${size.x} x ${size.y}');
  stdout.writeln('onScreen(0,0) -> ${Screen.onScreen(0, 0)}');
  stdout.writeln(
    'onScreen(${size.x},${size.y}) -> ${Screen.onScreen(size.x, size.y)} (expected false)',
  );
  await Mouse.moveTo(200, 200);
  await Mouse.move(
    0,
    80,
    duration: Duration(milliseconds: 300),
    easing: easeInOutQuad,
  );
  Mouse.doubleClick();
  Mouse.scroll(5);
  Mouse.hscroll(-4);

  // Live position printer (PyAutoGUI-style)
  // These are global desktop coordinates. On multi-monitor setups they can be
  // negative if a display sits left of or above the primary display.
  while (true) {
    final p = Mouse.position();
    final s =
        'X: ${p.x.toStringAsFixed(0).padLeft(4)}  Y: ${p.y.toStringAsFixed(0).padLeft(4)}';
    stdout.write('$s\r');
    await Future.delayed(Duration(milliseconds: 50));
  }
}
