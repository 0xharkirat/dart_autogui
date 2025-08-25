import 'dart:io';
import 'dart:math';
import 'ffi/macos.dart';

enum MouseButton { left, right, middle }

abstract class PlatformMouse {
  Point<int> screenSize();
  Point<double> position();
  void moveToAbsolute(double x, double y);
  void mouseDown(MouseButton btn);
  void mouseUp(MouseButton btn);
  void click(MouseButton btn, {int clicks = 1, Duration? interval});
  void vscroll(int deltaLines);
  void hscroll(int deltaLines);
  bool isAccessibilityTrusted();
}

class _MacMouse implements PlatformMouse {
  final _b = MacOSBindings.load();

  @override
  Point<int> screenSize() => _b.screenSize();

  @override
  Point<double> position() => _b.mousePosition();

  @override
  void moveToAbsolute(double x, double y) => _b.moveTo(x, y);

  @override
  void mouseDown(MouseButton btn) => _b.mouseDown(btn.index);

  @override
  void mouseUp(MouseButton btn) => _b.mouseUp(btn.index);

  @override
  void click(MouseButton btn, {int clicks = 1, Duration? interval}) =>
      _b.click(btn.index, clicks, (interval ?? Duration.zero).inMilliseconds / 1000.0);

  @override
  void vscroll(int deltaLines) => _b.vscroll(deltaLines);

  @override
  void hscroll(int deltaLines) => _b.hscroll(deltaLines);

  @override
  bool isAccessibilityTrusted() => _b.isAccessibilityTrusted();
}

PlatformMouse get platformMouse {
  if (Platform.isMacOS) return _MacMouse();
  throw UnsupportedError('Only macOS is implemented in this step.');
}
