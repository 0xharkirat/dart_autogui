import 'dart:math';
import 'src/platform.dart';

class Mouse {
  static Point<double> position() => platformMouse.position();

  static Future<void> moveTo(num x, num y, {Duration? duration}) async {
    if (duration == null || duration.inMilliseconds <= 0) {
      platformMouse.moveTo(x, y);
    } else {
      platformMouse.moveToSmooth(x, y, duration);
    }
  }

  static bool get isAccessibilityTrusted => platformMouse.isAccessibilityTrusted();
}
