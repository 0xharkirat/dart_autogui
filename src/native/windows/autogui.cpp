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
