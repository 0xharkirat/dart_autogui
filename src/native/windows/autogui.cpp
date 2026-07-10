#include <cstdlib>
#include <vector>
#include <windows.h>

#define EXPORT extern "C" __declspec(dllexport)

// dart_autogui: 0=Left, 1=Right, 2=Middle

EXPORT void dag_get_screen_size(double *width, double *height) {
  if (width)
    *width = (double)GetSystemMetrics(SM_CXSCREEN);
  if (height)
    *height = (double)GetSystemMetrics(SM_CYSCREEN);
}

EXPORT void dag_get_mouse_position(double *x, double *y) {
  POINT p;
  if (GetCursorPos(&p)) {
    if (x)
      *x = (double)p.x;
    if (y)
      *y = (double)p.y;
  }
}

EXPORT void dag_move_mouse(double x, double y) {
  double sw = (double)GetSystemMetrics(SM_CXSCREEN);
  double sh = (double)GetSystemMetrics(SM_CYSCREEN);

  INPUT input = {0};
  input.type = INPUT_MOUSE;
  input.mi.dwFlags = MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_MOVE;
  // Normalized to 65535
  input.mi.dx = (LONG)((x * 65535.0) / (sw - 1));
  input.mi.dy = (LONG)((y * 65535.0) / (sh - 1));
  SendInput(1, &input, sizeof(INPUT));
}

void _sendMouse(DWORD flags) {
  INPUT input = {0};
  input.type = INPUT_MOUSE;
  input.mi.dwFlags = flags;
  SendInput(1, &input, sizeof(INPUT));
}

EXPORT void dag_mouse_down(int button) {
  switch (button) {
  case 0:
    _sendMouse(MOUSEEVENTF_LEFTDOWN);
    break;
  case 1:
    _sendMouse(MOUSEEVENTF_RIGHTDOWN);
    break;
  case 2:
    _sendMouse(MOUSEEVENTF_MIDDLEDOWN);
    break;
  }
}

EXPORT void dag_mouse_up(int button) {
  switch (button) {
  case 0:
    _sendMouse(MOUSEEVENTF_LEFTUP);
    break;
  case 1:
    _sendMouse(MOUSEEVENTF_RIGHTUP);
    break;
  case 2:
    _sendMouse(MOUSEEVENTF_MIDDLEUP);
    break;
  }
}

EXPORT void dag_mouse_click(int button, int clicks, double interval_secs) {
  if (clicks < 1)
    clicks = 1;
  for (int i = 0; i < clicks; i++) {
    dag_mouse_down(button);
    dag_mouse_up(button);
    if (i + 1 < clicks) {
      Sleep((DWORD)(interval_secs * 1000));
    }
  }
}

EXPORT void dag_scroll(int delta_lines) {
  INPUT input = {0};
  input.type = INPUT_MOUSE;
  input.mi.dwFlags = MOUSEEVENTF_WHEEL;
  input.mi.mouseData = delta_lines * WHEEL_DELTA;
  SendInput(1, &input, sizeof(INPUT));
}

EXPORT void dag_hscroll(int delta_lines) {
  INPUT input = {0};
  input.type = INPUT_MOUSE;
  input.mi.dwFlags = MOUSEEVENTF_HWHEEL;
  input.mi.mouseData = delta_lines * WHEEL_DELTA;
  SendInput(1, &input, sizeof(INPUT));
}

EXPORT int dag_is_accessibility_trusted() {
  return 1; // Windows doesn't block mouse input typically unless UAC
}

void _sendKey(WORD keycode, DWORD flags) {
  INPUT input = {0};
  input.type = INPUT_KEYBOARD;
  input.ki.wVk = keycode;
  input.ki.dwFlags = flags;
  SendInput(1, &input, sizeof(INPUT));
}

EXPORT void dag_key_down(int keycode) { _sendKey((WORD)keycode, 0); }

EXPORT void dag_key_up(int keycode) { _sendKey((WORD)keycode, KEYEVENTF_KEYUP); }

EXPORT int dag_is_screen_capture_trusted() {
  return 1; // Windows has no per-app screen capture permission.
}

EXPORT unsigned char *dag_capture_screen(int x, int y, int w, int h, int *out_w,
                                         int *out_h) {
  if (out_w)
    *out_w = 0;
  if (out_h)
    *out_h = 0;

  if (w <= 0 || h <= 0) {
    x = 0;
    y = 0;
    w = GetSystemMetrics(SM_CXSCREEN);
    h = GetSystemMetrics(SM_CYSCREEN);
  }
  if (w <= 0 || h <= 0)
    return NULL;

  HDC screen = GetDC(NULL);
  if (!screen)
    return NULL;
  HDC mem = CreateCompatibleDC(screen);
  HBITMAP bmp = CreateCompatibleBitmap(screen, w, h);
  if (!mem || !bmp) {
    if (bmp)
      DeleteObject(bmp);
    if (mem)
      DeleteDC(mem);
    ReleaseDC(NULL, screen);
    return NULL;
  }

  HGDIOBJ old = SelectObject(mem, bmp);
  // A failed BitBlt leaves the bitmap untouched, and GetDIBits would happily
  // hand back that black/garbage buffer as if it were a capture.
  if (!BitBlt(mem, 0, 0, w, h, screen, x, y, SRCCOPY)) {
    SelectObject(mem, old);
    DeleteObject(bmp);
    DeleteDC(mem);
    ReleaseDC(NULL, screen);
    return NULL;
  }

  BITMAPINFO bi = {};
  bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bi.bmiHeader.biWidth = w;
  bi.bmiHeader.biHeight = -h; // negative = top-down rows
  bi.bmiHeader.biPlanes = 1;
  bi.bmiHeader.biBitCount = 32;
  bi.bmiHeader.biCompression = BI_RGB;

  size_t bytes = (size_t)w * (size_t)h * 4;
  unsigned char *buf = (unsigned char *)malloc(bytes);
  int ok = 0;
  if (buf)
    ok = GetDIBits(mem, bmp, 0, h, buf, &bi, DIB_RGB_COLORS) != 0;

  SelectObject(mem, old);
  DeleteObject(bmp);
  DeleteDC(mem);
  ReleaseDC(NULL, screen);

  if (!buf || !ok) {
    if (buf)
      free(buf);
    return NULL;
  }

  // GetDIBits yields BGRA with an undefined alpha under BI_RGB; swap to RGBA
  // and force the alpha opaque.
  for (size_t i = 0; i < bytes; i += 4) {
    unsigned char b = buf[i];
    buf[i] = buf[i + 2];
    buf[i + 2] = b;
    buf[i + 3] = 255;
  }

  if (out_w)
    *out_w = w;
  if (out_h)
    *out_h = h;
  return buf;
}

EXPORT void dag_free_image(unsigned char *buf) {
  if (buf)
    free(buf);
}
