import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'src/locate.dart';
import 'src/platform.dart';
export 'src/keyboard.dart';
export 'src/locate.dart';
export 'src/platform.dart'
    show MouseButton, FailSafe, FailSafeException, Capture;

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

/// The center point of [box].
Point<int> center(Rectangle<int> box) =>
    Point(box.left + box.width ~/ 2, box.top + box.height ~/ 2);

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

  /// Whether the OS has granted screen-capture permission.
  ///
  /// On macOS this is the Screen Recording permission; without it
  /// [screenshot] fails. Always true on Linux and Windows.
  static bool get isScreenCaptureTrusted =>
      platformScreen.isScreenCaptureTrusted();

  /// Captures the primary display, or just [region] of it.
  ///
  /// [region] is in logical coordinates - the same space as [Mouse.position]
  /// and [size]. The returned [Capture] holds *physical* pixels, so on a HiDPI
  /// display its dimensions are the logical size times the backing scale
  /// factor. When [filename] is given, the capture is also written there as a
  /// PNG.
  ///
  /// Throws [StateError] if the capture fails - most often missing macOS
  /// Screen Recording permission, or macOS older than 14.
  static Capture screenshot({Rectangle<int>? region, String? filename}) {
    final capture = platformScreen.capture(region);
    if (filename != null) {
      final image = img.Image.fromBytes(
        width: capture.width,
        height: capture.height,
        bytes: capture.rgba.buffer,
        numChannels: 4,
      );
      File(filename).writeAsBytesSync(img.encodePng(image));
    }
    return capture;
  }

  /// The `(r, g, b)` color of the screen pixel at logical ([x], [y]) - the same
  /// coordinate space as [Mouse.position].
  ///
  /// Captures a 1x1 logical region, which on a HiDPI display is several
  /// physical pixels; the top-left one is returned.
  ///
  /// Each call performs its own screen capture, which is not cheap. To read
  /// many pixels, take one [screenshot] and use [Capture.pixelAt].
  static (int, int, int) pixel(int x, int y) =>
      screenshot(region: Rectangle(x, y, 1, 1)).pixelAt(0, 0);

  /// Whether the screen pixel at logical ([x], [y]) matches [rgb], allowing a
  /// per-channel absolute difference of up to [tolerance].
  static bool pixelMatchesColor(
    int x,
    int y,
    (int, int, int) rgb, {
    int tolerance = 0,
  }) {
    final (r, g, b) = pixel(x, y);
    final (wantR, wantG, wantB) = rgb;
    return (r - wantR).abs() <= tolerance &&
        (g - wantG).abs() <= tolerance &&
        (b - wantB).abs() <= tolerance;
  }

  /// Finds the image at [imagePath] on screen, searching [region] if given.
  ///
  /// Returns the match in *logical* coordinates - ready for [Mouse.click] - or
  /// null when it is not found. Matching is exact, so the needle must have been
  /// captured at the same scale as the screen (a PNG saved by [screenshot] on
  /// this display qualifies).
  static Rectangle<int>? locateOnScreen(
    String imagePath, {
    Rectangle<int>? region,
  }) {
    final haystack = screenshot(region: region);
    final match = locate(_decodeNeedle(imagePath), haystack);
    return match == null ? null : _toLogicalRect(match, haystack);
  }

  /// Every on-screen occurrence of the image at [imagePath], in logical
  /// coordinates.
  static List<Rectangle<int>> locateAllOnScreen(
    String imagePath, {
    Rectangle<int>? region,
  }) {
    final haystack = screenshot(region: region);
    return locateAll(
      _decodeNeedle(imagePath),
      haystack,
    ).map((m) => _toLogicalRect(m, haystack)).toList(growable: false);
  }

  /// The center of the first on-screen match, in logical coordinates, or null.
  static Point<int>? locateCenterOnScreen(
    String imagePath, {
    Rectangle<int>? region,
  }) {
    final box = locateOnScreen(imagePath, region: region);
    return box == null ? null : center(box);
  }

  static Capture _decodeNeedle(String imagePath) {
    final decoded = img.decodeImage(File(imagePath).readAsBytesSync());
    if (decoded == null) {
      throw ArgumentError.value(
        imagePath,
        'imagePath',
        'Not a decodable image',
      );
    }
    final rgba = decoded
        .convert(numChannels: 4)
        .getBytes(order: img.ChannelOrder.rgba);
    return Capture(Uint8List.fromList(rgba), decoded.width, decoded.height);
  }

  static Rectangle<int> _toLogicalRect(Rectangle<int> physical, Capture in_) {
    final topLeft = in_.toLogical(physical.left, physical.top);
    return Rectangle(
      topLeft.x,
      topLeft.y,
      (physical.width / in_.scale).round(),
      (physical.height / in_.scale).round(),
    );
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
    FailSafe.check();
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
    FailSafe.check();
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

  static void leftClick({int? x, int? y, Duration? interval}) =>
      click(x: x, y: y, button: MouseButton.left, interval: interval);

  static void middleClick({int? x, int? y, Duration? interval}) =>
      click(x: x, y: y, button: MouseButton.middle, interval: interval);

  static void mouseDown({MouseButton button = MouseButton.left}) {
    FailSafe.check();
    platformMouse.mouseDown(button);
  }

  // No FailSafe.check() on release: a corner-parked pointer must not be able to
  // strand a held button down mid-drag (mirrors Keyboard.keyUp).
  static void mouseUp({MouseButton button = MouseButton.left}) =>
      platformMouse.mouseUp(button);

  // --- scroll ---------------------------------------------------------

  /// Vertical scroll in "lines" (positive = up, negative = down)
  static void scroll(int clicks, {int? x, int? y}) {
    FailSafe.check();
    if (x != null || y != null) {
      final p = position();
      moveTo(x ?? p.x, y ?? p.y);
    }
    platformMouse.vscroll(clicks);
  }

  /// Alias for [scroll].
  static void vscroll(int clicks, {int? x, int? y}) =>
      scroll(clicks, x: x, y: y);

  /// Horizontal scroll in "lines" (positive = right, negative = left)
  static void hscroll(int clicks, {int? x, int? y}) {
    FailSafe.check();
    if (x != null || y != null) {
      final p = position();
      moveTo(x ?? p.x, y ?? p.y);
    }
    platformMouse.hscroll(clicks);
  }
}

// ponytail: mouse actions run FailSafe.check() (sync) but skip FailSafe.pause -
// wiring pauseAfterAction into the sync click/scroll/mouseDown API would make
// them Future-returning and break callers. Add if PAUSE-after-mouse is needed.
