#import <ApplicationServices/ApplicationServices.h>
#import <unistd.h>

static int _activeButton = -1;

static CGMouseButton _btn(int b) {
  switch (b) {
  case 1:
    return kCGMouseButtonRight;
  case 2:
    return kCGMouseButtonCenter;
  default:
    return kCGMouseButtonLeft;
  }
}
static CGEventType _downType(int b) {
  switch (b) {
  case 1:
    return kCGEventRightMouseDown;
  case 2:
    return kCGEventOtherMouseDown;
  default:
    return kCGEventLeftMouseDown;
  }
}
static CGEventType _upType(int b) {
  switch (b) {
  case 1:
    return kCGEventRightMouseUp;
  case 2:
    return kCGEventOtherMouseUp;
  default:
    return kCGEventLeftMouseUp;
  }
}
static CGEventType _moveType() {
  switch (_activeButton) {
  case 0:
    return kCGEventLeftMouseDragged;
  case 1:
    return kCGEventRightMouseDragged;
  case 2:
    return kCGEventOtherMouseDragged;
  default:
    return kCGEventMouseMoved;
  }
}

extern "C" {

void dag_get_screen_size(double *width, double *height) {
  CGDirectDisplayID did = CGMainDisplayID();
  size_t w = CGDisplayPixelsWide(did);
  size_t h = CGDisplayPixelsHigh(did);
  if (width)
    *width = (double)w;
  if (height)
    *height = (double)h;
}

void dag_get_mouse_position(double *x, double *y) {
  CGEventRef e = CGEventCreate(NULL);
  CGPoint p = CGEventGetLocation(e);
  if (x)
    *x = p.x;
  if (y)
    *y = p.y;
  CFRelease(e);
}

void dag_move_mouse(double x, double y) {
  CGPoint p = CGPointMake(x, y);
  if (_activeButton == -1) {
    CGWarpMouseCursorPosition(p);
    CGAssociateMouseAndMouseCursorPosition(true);
    return;
  }

  CGEventRef move =
      CGEventCreateMouseEvent(NULL, _moveType(), p, _btn(_activeButton));
  CGEventPost(kCGHIDEventTap, move);
  CFRelease(move);
}

void dag_mouse_down(int button) {
  double x = 0, y = 0;
  dag_get_mouse_position(&x, &y);
  CGPoint p = CGPointMake(x, y);
  CGEventRef e =
      CGEventCreateMouseEvent(NULL, _downType(button), p, _btn(button));
  CGEventPost(kCGHIDEventTap, e);
  _activeButton = button;
  CFRelease(e);
}

void dag_mouse_up(int button) {
  double x = 0, y = 0;
  dag_get_mouse_position(&x, &y);
  CGPoint p = CGPointMake(x, y);
  CGEventRef e =
      CGEventCreateMouseEvent(NULL, _upType(button), p, _btn(button));
  CGEventPost(kCGHIDEventTap, e);
  _activeButton = -1;
  CFRelease(e);
}

void dag_mouse_click(int button, int clicks, double interval_secs) {
  if (clicks < 1)
    clicks = 1;
  for (int i = 0; i < clicks; ++i) {
    dag_mouse_down(button);
    dag_mouse_up(button);
    if (i + 1 < clicks) {
      useconds_t us = (useconds_t)(interval_secs * 1000000.0);
      if (us > 0)
        usleep(us);
    }
  }
}

void dag_scroll(int delta_lines) {
  CGEventRef e = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitLine, 1,
                                               (int32_t)delta_lines);
  CGEventPost(kCGHIDEventTap, e);
  CFRelease(e);
}

void dag_hscroll(int delta_lines) {
  // wheelCount = 2 → (vertical, horizontal). Here vertical=0,
  // horizontal=delta_lines.
  CGEventRef e = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitLine, 2,
                                               0, (int32_t)delta_lines);
  CGEventPost(kCGHIDEventTap, e);
  CFRelease(e);
}

int dag_is_accessibility_trusted() { return AXIsProcessTrusted() ? 1 : 0; }

void dag_key_down(int keycode) {
  CGEventRef e = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)keycode, true);
  CGEventPost(kCGHIDEventTap, e);
  CFRelease(e);
}

void dag_key_up(int keycode) {
  CGEventRef e = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)keycode, false);
  CGEventPost(kCGHIDEventTap, e);
  CFRelease(e);
}

} // extern "C"
