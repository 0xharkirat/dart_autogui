import 'dart:io';
import 'package:dart_autogui/dart_autogui.dart';

Future<void> main() async {
  // 1) Check permissions
  if (!Mouse.isAccessibilityTrusted) {
    stderr.writeln(
      '⚠️  Accessibility permission missing.\n'
      'Give your Terminal (or app) access: System Settings → Privacy & Security → Accessibility.'
    );
    // You can continue, but events may do nothing.
  }

  // 2) Read current position
  final p = Mouse.position();
  print('Current mouse at: $p');

  // 3) Move instantly
  await Mouse.moveTo(200, 200);
  sleep(Duration(milliseconds: 300));

  // 4) Smooth glide
  await Mouse.moveTo(1000, 600, duration: Duration(milliseconds: 900));
  print('Done.');
}
