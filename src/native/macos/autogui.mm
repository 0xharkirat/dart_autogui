#import <ApplicationServices/ApplicationServices.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <dispatch/dispatch.h>
#import <stdlib.h>
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

int dag_is_screen_capture_trusted() {
  if (@available(macOS 10.15, *)) {
    return CGPreflightScreenCaptureAccess() ? 1 : 0;
  }
  return 1;
}

// The legacy CGDisplayCreateImage / CGWindowListCreateImage capture APIs are
// SCREEN_CAPTURE_OBSOLETE as of the macOS 15 SDK - they no longer compile.
// ScreenCaptureKit is the only supported path. SCScreenshotManager is macOS 14+,
// so capture returns NULL (unsupported) on older systems while mouse/keyboard
// keep working.
//
// SCK is async; we block on a semaphore to keep the C ABI synchronous. The
// timeout avoids a hang if the completion handler never fires.
API_AVAILABLE(macos(14.0))
static CGImageRef _dag_sck_capture(int x, int y, int w, int h) {
  __block SCShareableContent *content = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [SCShareableContent
      getShareableContentWithCompletionHandler:^(SCShareableContent *c,
                                                 NSError *err) {
        content = c;
        dispatch_semaphore_signal(sem);
      }];
  if (dispatch_semaphore_wait(
          sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) != 0)
    return NULL;
  if (!content || content.displays.count == 0)
    return NULL;

  // Must be the *main* display: dag_get_screen_size uses CGMainDisplayID, and
  // the caller's scale and origin are derived from it. displays.firstObject is
  // not documented to be the main one, so match on displayID.
  CGDirectDisplayID mainID = CGMainDisplayID();
  SCDisplay *display = nil;
  for (SCDisplay *candidate in content.displays) {
    if (candidate.displayID == mainID) {
      display = candidate;
      break;
    }
  }
  if (!display)
    display = content.displays.firstObject;

  SCContentFilter *filter =
      [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];

  SCStreamConfiguration *cfg = [[SCStreamConfiguration alloc] init];
  cfg.showsCursor = NO;

  CGFloat scale = filter.pointPixelScale;
  if (w > 0 && h > 0) {
    cfg.sourceRect = CGRectMake(x, y, w, h);
    cfg.width = (size_t)(w * scale);
    cfg.height = (size_t)(h * scale);
  } else {
    CGRect r = filter.contentRect;
    cfg.width = (size_t)(r.size.width * scale);
    cfg.height = (size_t)(r.size.height * scale);
  }

  // CGImageRef is a CF type, so ARC will not manage it: the block retains and
  // the caller releases. If the wait times out we abandon the call, and a late
  // completion handler must not retain into an orphan. The lock makes the
  // hand-off atomic - either the block claims it before we give up, or it sees
  // `abandoned` and retains nothing. The race where it lands in between is
  // covered by releasing whatever it did set.
  __block CGImageRef out = NULL;
  __block BOOL abandoned = NO;
  NSObject *claim = [NSObject new];
  dispatch_semaphore_t shot = dispatch_semaphore_create(0);
  [SCScreenshotManager captureImageWithFilter:filter
                                configuration:cfg
                            completionHandler:^(CGImageRef img, NSError *err) {
                              @synchronized(claim) {
                                if (abandoned)
                                  return;
                                if (img)
                                  out = (CGImageRef)CFRetain(img);
                              }
                              dispatch_semaphore_signal(shot);
                            }];
  if (dispatch_semaphore_wait(
          shot, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) != 0) {
    @synchronized(claim) {
      abandoned = YES;
      if (out) {
        CGImageRelease(out);
        out = NULL;
      }
    }
    return NULL;
  }
  return out; // caller releases
}

unsigned char *dag_capture_screen(int x, int y, int w, int h, int *out_w,
                                  int *out_h) {
  if (out_w)
    *out_w = 0;
  if (out_h)
    *out_h = 0;

  CGImageRef image = NULL;
  if (@available(macOS 14.0, *)) {
    image = _dag_sck_capture(x, y, w, h);
  }
  if (!image)
    return NULL;

  size_t width = CGImageGetWidth(image);
  size_t height = CGImageGetHeight(image);
  size_t bytes = width * height * 4;
  unsigned char *buf = (unsigned char *)calloc(bytes, 1);
  if (!buf) {
    CGImageRelease(image);
    return NULL;
  }

  CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
  CGContextRef ctx = CGBitmapContextCreate(
      buf, width, height, 8, width * 4, cs,
      kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
  if (!ctx) {
    free(buf);
    CGColorSpaceRelease(cs);
    CGImageRelease(image);
    return NULL;
  }

  CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), image);
  CGContextRelease(ctx);
  CGColorSpaceRelease(cs);
  CGImageRelease(image);

  if (out_w)
    *out_w = (int)width;
  if (out_h)
    *out_h = (int)height;
  return buf;
}

void dag_free_image(unsigned char *buf) {
  if (buf)
    free(buf);
}

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
