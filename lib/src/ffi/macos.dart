import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:math';
import 'package:ffi/ffi.dart';

typedef _CGetPos = ffi.Void Function(ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>);
typedef _DGetPos = void Function(ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>);

typedef _CMove = ffi.Void Function(ffi.Double, ffi.Double);
typedef _DMove = void Function(double, double);

typedef _CMoveSmooth = ffi.Void Function(ffi.Double, ffi.Double, ffi.Double);
typedef _DMoveSmooth = void Function(double, double, double);

typedef _CIsTrusted = ffi.Int32 Function();
typedef _DIsTrusted = int Function();

class MacOSBindings {
  late final ffi.DynamicLibrary _lib;
  late final _DGetPos _getPos;
  late final _DMove _move;
  late final _DMoveSmooth _moveSmooth;
  late final _DIsTrusted _isTrusted;

  MacOSBindings._(this._lib) {
    _getPos = _lib.lookupFunction<_CGetPos, _DGetPos>('dag_get_mouse_position');
    _move = _lib.lookupFunction<_CMove, _DMove>('dag_move_mouse');
    _moveSmooth = _lib.lookupFunction<_CMoveSmooth, _DMoveSmooth>('dag_move_mouse_smooth');
    _isTrusted = _lib.lookupFunction<_CIsTrusted, _DIsTrusted>('dag_is_accessibility_trusted');
  }

  static MacOSBindings load() {
    if (!Platform.isMacOS) {
      throw UnsupportedError('MacOSBindings can only be used on macOS');
    }
    // Adjust the path if you move the dylib (we’ll package properly later).
    final lib = ffi.DynamicLibrary.open('src/native/macos/libdart_autogui.dylib');
    return MacOSBindings._(lib);
  }

  Point<double> mousePosition() {
    final px = calloc<ffi.Double>();
    final py = calloc<ffi.Double>();
    try {
      _getPos(px, py);
      return Point(px.value, py.value);
    } finally {
      calloc.free(px);
      calloc.free(py);
    }
  }

  void moveTo(double x, double y) => _move(x, y);
  void moveToSmooth(double x, double y, Duration duration) =>
      _moveSmooth(x, y, duration.inMilliseconds / 1000.0);

  bool isAccessibilityTrusted() => _isTrusted() == 1;
}
