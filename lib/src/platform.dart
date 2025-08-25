import 'dart:io';
import 'dart:math';
import 'ffi/macos.dart';

abstract class PlatformMouse {
  Point<double> position();
  void moveTo(num x, num y);
  void moveToSmooth(num x, num y, Duration duration);
  bool isAccessibilityTrusted();
}

class _MacMouse implements PlatformMouse {
  final _b = MacOSBindings.load();
  @override
  Point<double> position() => _b.mousePosition();

  @override
  void moveTo(num x, num y) => _b.moveTo(x.toDouble(), y.toDouble());

  @override
  void moveToSmooth(num x, num y, Duration duration) =>
      _b.moveToSmooth(x.toDouble(), y.toDouble(), duration);

  @override
  bool isAccessibilityTrusted() => _b.isAccessibilityTrusted();
}

PlatformMouse get platformMouse {
  if (Platform.isMacOS) return _MacMouse();
  throw UnsupportedError('Only macOS is implemented in this step.');
}
