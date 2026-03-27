import 'dart:math';
import 'src/platform.dart';
export 'src/keyboard.dart';
export 'src/platform.dart' show MouseButton;

/// Easing function: t in [0,1] -> progress in [0,1]
typedef Easing = double Function(double t);

// Built-ins (similar to PyAutoGUI)
double easeLinear(double t) => t;
double easeInQuad(double t) => t * t;
double easeOutQuad(double t) => 1 - (1 - t) * (1 - t);
double easeInOutQuad(double t) =>
    t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2).toDouble() / 2;
double easeInBounce(double t) {
  // Quick approximation
  const n1 = 7.5625, d1 = 2.75;
  double b(double x) {
    if (x < 1 / d1) {
      return n1 * x * x;
    } else if (x < 2 / d1) {
      x -= 1.5 / d1;
      return n1 * x * x + 0.75;
    } else if (x < 2.5 / d1) {
      x -= 2.25 / d1;
      return n1 * x * x + 0.9375;
    } else {
      x -= 2.625 / d1;
      return n1 * x * x + 0.984375;
    }
  }

  return 1 - b(1 - t);
}

double easeInElastic(double t) {
  if (t == 0 || t == 1) return t;
  const c4 = (2 * 3.141592653589793) / 3;
  return -pow(2, 10 * t - 10).toDouble() * sin((t * 10 - 10.75) * c4);
}

class Screen {
  /// Returns the primary screen size in pixels.
  static Point<int> size() => platformMouse.screenSize();

  /// Checks whether (x,y) lies within the primary screen bounds.
  ///
  /// On multi-monitor desktops, [Mouse.position] may return negative values
  /// or values outside this range because coordinates are reported in the
  /// global desktop space, not clamped to the primary display.
  static bool onScreen(num x, num y) {
    final s = size();
    return x >= 0 && y >= 0 && x < s.x && y < s.y;
  }
}

class Mouse {
  static bool get isAccessibilityTrusted =>
      platformMouse.isAccessibilityTrusted();

  /// Returns the current pointer position in global desktop coordinates.
  ///
  /// On multi-monitor setups this can be negative or extend beyond the primary
  /// screen size reported by [Screen.size].
  static Point<double> position() => platformMouse.position();

  // --- movement -------------------------------------------------------

  /// Move to absolute (x,y). If duration>0, tween using [easing].
  static Future<void> moveTo(
    num? x,
    num? y, {
    Duration duration = Duration.zero,
    Easing easing = easeLinear,
    int steps = 60,
  }) async {
    final start = position();
    final target = Point<double>(
      x?.toDouble() ?? start.x,
      y?.toDouble() ?? start.y,
    );

    if (duration.inMilliseconds <= 0) {
      platformMouse.moveToAbsolute(target.x, target.y);
      return;
    }

    final total = duration.inMilliseconds;
    if (steps < 1) steps = 1;
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final tt = easing(t).clamp(0.0, 1.0);
      final nx = start.x + (target.x - start.x) * tt;
      final ny = start.y + (target.y - start.y) * tt;
      platformMouse.moveToAbsolute(nx, ny);
      final perStepMs = total ~/ steps;
      if (perStepMs > 0) {
        await Future.delayed(Duration(milliseconds: perStepMs));
      }
    }
  }

  /// Move relative by (dx,dy).
  static Future<void> move(
    num? dx,
    num? dy, {
    Duration duration = Duration.zero,
    Easing easing = easeLinear,
    int steps = 60,
  }) {
    final p = position();
    return moveTo(
      (dx != null) ? p.x + dx : null,
      (dy != null) ? p.y + dy : null,
      duration: duration,
      easing: easing,
      steps: steps,
    );
  }

  /// Drag to absolute (x,y) while holding [button].
  static Future<void> dragTo(
    num x,
    num y, {
    MouseButton button = MouseButton.left,
    Duration duration = Duration.zero,
    Easing easing = easeLinear,
    int steps = 60,
  }) async {
    mouseDown(button: button);
    await moveTo(x, y, duration: duration, easing: easing, steps: steps);
    mouseUp(button: button);
  }

  /// Drag by relative (dx,dy) while holding [button].
  static Future<void> drag(
    num dx,
    num dy, {
    MouseButton button = MouseButton.left,
    Duration duration = Duration.zero,
    Easing easing = easeLinear,
    int steps = 60,
  }) async {
    final p = position();
    await dragTo(
      p.x + dx,
      p.y + dy,
      button: button,
      duration: duration,
      easing: easing,
      steps: steps,
    );
  }

  // --- clicks ---------------------------------------------------------

  static void click({
    int? x,
    int? y,
    MouseButton button = MouseButton.left,
    int clicks = 1,
    Duration? interval,
  }) {
    if (x != null || y != null) {
      final p = position();
      moveTo(x ?? p.x, y ?? p.y);
    }
    platformMouse.click(button, clicks: clicks, interval: interval);
  }

  static void doubleClick({
    int? x,
    int? y,
    MouseButton button = MouseButton.left,
    Duration? interval,
  }) => click(x: x, y: y, button: button, clicks: 2, interval: interval);

  static void tripleClick({
    int? x,
    int? y,
    MouseButton button = MouseButton.left,
    Duration? interval,
  }) => click(x: x, y: y, button: button, clicks: 3, interval: interval);

  static void rightClick({int? x, int? y, Duration? interval}) => click(
    x: x,
    y: y,
    button: MouseButton.right,
    clicks: 1,
    interval: interval,
  );

  static void mouseDown({MouseButton button = MouseButton.left}) =>
      platformMouse.mouseDown(button);
  static void mouseUp({MouseButton button = MouseButton.left}) =>
      platformMouse.mouseUp(button);

  // --- scroll ---------------------------------------------------------

  /// Vertical scroll in "lines" (positive = up, negative = down)
  static void scroll(int clicks, {int? x, int? y}) {
    if (x != null || y != null) {
      final p = position();
      moveTo(x ?? p.x, y ?? p.y);
    }
    platformMouse.vscroll(clicks);
  }

  /// Horizontal scroll in "lines" (positive = right, negative = left)
  static void hscroll(int clicks, {int? x, int? y}) {
    if (x != null || y != null) {
      final p = position();
      moveTo(x ?? p.x, y ?? p.y);
    }
    platformMouse.hscroll(clicks);
  }
}
