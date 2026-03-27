import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:math';
import 'package:ffi/ffi.dart';

typedef _CGetPos =
    ffi.Void Function(ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>);
typedef _DGetPos =
    void Function(ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>);

typedef _CMove = ffi.Void Function(ffi.Double, ffi.Double);
typedef _DMove = void Function(double, double);

typedef _CDownUp = ffi.Void Function(ffi.Int32);
typedef _DDownUp = void Function(int);

typedef _CClick = ffi.Void Function(ffi.Int32, ffi.Int32, ffi.Double);
typedef _DClick = void Function(int, int, double);

typedef _CScroll = ffi.Void Function(ffi.Int32);
typedef _DScroll = void Function(int);

typedef _CSize =
    ffi.Void Function(ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>);
typedef _DSize =
    void Function(ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>);

typedef _CIsTrusted = ffi.Int32 Function();
typedef _DIsTrusted = int Function();

typedef _CKey = ffi.Void Function(ffi.Int32);
typedef _DKey = void Function(int);

class WindowsBindings {
  late final ffi.DynamicLibrary _lib;
  late final _DGetPos _getPos;
  late final _DMove _move;
  late final _DDownUp _mouseDown;
  late final _DDownUp _mouseUp;
  late final _DClick _click;
  late final _DScroll _vscroll;
  late final _DScroll _hscroll;
  late final _DSize _getScreenSize;
  late final _DIsTrusted _isTrusted;
  late final _DKey? _keyDown;
  late final _DKey? _keyUp;

  WindowsBindings._(this._lib) {
    _getPos = _lib.lookupFunction<_CGetPos, _DGetPos>('dag_get_mouse_position');
    _move = _lib.lookupFunction<_CMove, _DMove>('dag_move_mouse');
    _mouseDown = _lib.lookupFunction<_CDownUp, _DDownUp>('dag_mouse_down');
    _mouseUp = _lib.lookupFunction<_CDownUp, _DDownUp>('dag_mouse_up');
    _click = _lib.lookupFunction<_CClick, _DClick>('dag_mouse_click');
    _vscroll = _lib.lookupFunction<_CScroll, _DScroll>('dag_scroll');
    _hscroll = _lib.lookupFunction<_CScroll, _DScroll>('dag_hscroll');
    _getScreenSize = _lib.lookupFunction<_CSize, _DSize>('dag_get_screen_size');
    _isTrusted = _lib.lookupFunction<_CIsTrusted, _DIsTrusted>(
      'dag_is_accessibility_trusted',
    );
    try {
      _keyDown = _lib.lookupFunction<_CKey, _DKey>('dag_key_down');
    } catch (_) {
      _keyDown = null;
    }
    try {
      _keyUp = _lib.lookupFunction<_CKey, _DKey>('dag_key_up');
    } catch (_) {
      _keyUp = null;
    }
  }

  static WindowsBindings load() {
    if (!Platform.isWindows) {
      throw UnsupportedError('WindowsBindings can only be used on Windows');
    }
    try {
      return WindowsBindings._(
        ffi.DynamicLibrary.open('src/native/windows/dart_autogui.dll'),
      );
    } catch (_) {
      try {
        return WindowsBindings._(ffi.DynamicLibrary.open('dart_autogui.dll'));
      } catch (e) {
        throw UnsupportedError(
          'Could not load dart_autogui.dll. Run dart_autogui:setup or ensure library is in path.',
        );
      }
    }
  }

  Point<double> mousePosition() {
    final px = calloc<ffi.Double>(), py = calloc<ffi.Double>();
    try {
      _getPos(px, py);
      return Point(px.value, py.value);
    } finally {
      calloc.free(px);
      calloc.free(py);
    }
  }

  void moveTo(double x, double y) => _move(x, y);
  void mouseDown(int button) => _mouseDown(button);
  void mouseUp(int button) => _mouseUp(button);
  void click(int button, int clicks, double intervalSec) =>
      _click(button, clicks, intervalSec);
  void vscroll(int deltaLines) => _vscroll(deltaLines);
  void hscroll(int deltaLines) => _hscroll(deltaLines);

  Point<int> screenSize() {
    final pw = calloc<ffi.Double>(), ph = calloc<ffi.Double>();
    try {
      _getScreenSize(pw, ph);
      return Point(pw.value.toInt(), ph.value.toInt());
    } finally {
      calloc.free(pw);
      calloc.free(ph);
    }
  }

  bool isAccessibilityTrusted() => _isTrusted() == 1;

  void keyDown(int keycode) {
    if (_keyDown == null) {
      throw UnsupportedError(
        'Keyboard input is not currently available on Windows.',
      );
    }
    _keyDown(keycode);
  }

  void keyUp(int keycode) {
    if (_keyUp == null) {
      throw UnsupportedError(
        'Keyboard input is not currently available on Windows.',
      );
    }
    _keyUp(keycode);
  }
}
