#import <ApplicationServices/ApplicationServices.h>
#import <unistd.h> // usleep

extern "C" {

void dag_get_mouse_position(double* x, double* y) {
  CGEventRef e = CGEventCreate(NULL);
  CGPoint p = CGEventGetLocation(e);
  if (x) *x = p.x;
  if (y) *y = p.y;
  CFRelease(e);
}

void dag_move_mouse(double x, double y) {
  CGPoint p = CGPointMake(x, y);
  CGEventRef move = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, p, kCGMouseButtonLeft);
  CGEventPost(kCGHIDEventTap, move);
  CFRelease(move);
}

void dag_move_mouse_smooth(double x, double y, double duration_secs) {
  if (duration_secs <= 0) {
    dag_move_mouse(x, y);
    return;
  }

  // Get current position
  double sx = 0, sy = 0;
  dag_get_mouse_position(&sx, &sy);

  const int fps = 60;
  int steps = (int)(duration_secs * fps);
  if (steps < 1) steps = 1;

  for (int i = 1; i <= steps; ++i) {
    double t = (double)i / (double)steps;               // 0..1
    // Simple ease-in-out (cubic)
    double tt = (t < 0.5) ? 4*t*t*t : 1 - pow(-2*t + 2, 3) / 2.0;
    double nx = sx + (x - sx) * tt;
    double ny = sy + (y - sy) * tt;

    CGPoint p = CGPointMake(nx, ny);
    CGEventRef move = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, p, kCGMouseButtonLeft);
    CGEventPost(kCGHIDEventTap, move);
    CFRelease(move);

    // Sleep ~per-frame
    useconds_t wait_us = (useconds_t)((1.0 / fps) * 1000000.0);
    usleep(wait_us);
  }
}

int dag_is_accessibility_trusted() {
  // If false, user must grant Terminal (or your app) Accessibility in System Settings.
  return AXIsProcessTrusted() ? 1 : 0;
}

} // extern "C"
