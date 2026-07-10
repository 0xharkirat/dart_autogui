#include <X11/Xlib.h>
#include <X11/keysym.h>
#include <X11/extensions/XTest.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

// Export macros
#if defined(_WIN32)
    #define EXPORT __declspec(dllexport)
#else
    #define EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

// Maps for button index to X11 button codes
// 1=Left, 2=Middle, 3=Right in simpler terms, but in X11:
// 1=Left, 2=Middle, 3=Right, 4=ScrollUp, 5=ScrollDown
// dart_autogui: 0=Left, 1=Right, 2=Middle

int _toXButton(int b) {
    switch (b) {
        case 0: return 1; // Left
        case 1: return 3; // Right
        case 2: return 2; // Middle
        default: return 1;
    }
}

EXPORT void dag_get_screen_size(double* width, double* height) {
    Display* d = XOpenDisplay(NULL);
    if (!d) return;
    int s = DefaultScreen(d);
    if (width) *width = (double)DisplayWidth(d, s);
    if (height) *height = (double)DisplayHeight(d, s);
    XCloseDisplay(d);
}

EXPORT void dag_get_mouse_position(double* x, double* y) {
    Display* d = XOpenDisplay(NULL);
    if (!d) return;
    Window root = DefaultRootWindow(d);
    Window ret_root, ret_child;
    int root_x, root_y, win_x, win_y;
    unsigned int mask;
    if (XQueryPointer(d, root, &ret_root, &ret_child, &root_x, &root_y, &win_x, &win_y, &mask)) {
        if (x) *x = (double)root_x;
        if (y) *y = (double)root_y;
    }
    XCloseDisplay(d);
}

EXPORT void dag_move_mouse(double x, double y) {
    Display* d = XOpenDisplay(NULL);
    if (!d) return;
    // x, y, delay=0
    XTestFakeMotionEvent(d, 0, (int)x, (int)y, 0);
    XFlush(d);
    XCloseDisplay(d);
}

EXPORT void dag_mouse_down(int button) {
    Display* d = XOpenDisplay(NULL);
    if (!d) return;
    XTestFakeButtonEvent(d, _toXButton(button), True, 0);
    XFlush(d);
    XCloseDisplay(d);
}

EXPORT void dag_mouse_up(int button) {
    Display* d = XOpenDisplay(NULL);
    if (!d) return;
    XTestFakeButtonEvent(d, _toXButton(button), False, 0);
    XFlush(d);
    XCloseDisplay(d);
}

EXPORT void dag_mouse_click(int button, int clicks, double interval_secs) {
    Display* d = XOpenDisplay(NULL);
    if (!d) return;
    
    int xb = _toXButton(button);
    if (clicks < 1) clicks = 1;
    
    for (int i=0; i<clicks; i++) {
        XTestFakeButtonEvent(d, xb, True, 0);
        XTestFakeButtonEvent(d, xb, False, 0);
        XFlush(d);
        if (i+1 < clicks) {
             useconds_t us = (useconds_t)(interval_secs * 1000000.0);
             if (us > 0) usleep(us);
        }
    }
    XCloseDisplay(d);
}

EXPORT void dag_scroll(int delta_lines) {
    Display* d = XOpenDisplay(NULL);
    if (!d) return;
    
    int button = (delta_lines > 0) ? 4 : 5; // 4=Up, 5=Down
    int count = (delta_lines > 0) ? delta_lines : -delta_lines;

    for (int i=0; i<count; i++) {
        XTestFakeButtonEvent(d, button, True, 0);
        XTestFakeButtonEvent(d, button, False, 0);
    }
    XFlush(d);
    XCloseDisplay(d);
}

EXPORT void dag_hscroll(int delta_lines) {
    Display* d = XOpenDisplay(NULL);
    if (!d) return;
    
    // X11 standardized 6=Left, 7=Right usually? Or 6=Left 7=Right?
    // Actually horizontal scroll varies by mapping. Common is 6 (left), 7 (right).
    int button = (delta_lines > 0) ? 7 : 6; // Right : Left
    int count = (delta_lines > 0) ? delta_lines : -delta_lines;

    for (int i=0; i<count; i++) {
        XTestFakeButtonEvent(d, button, True, 0);
        XTestFakeButtonEvent(d, button, False, 0);
    }
    XFlush(d);
    XCloseDisplay(d);
}

EXPORT int dag_is_accessibility_trusted() {
    // X11 usually doesn't have same "Trusted" concept as macOS Accessibility
    // Assuming true if we can open display?
    Display* d = XOpenDisplay(NULL);
    if (d) {
        XCloseDisplay(d);
        return 1;
    }
    return 0;
}

EXPORT void dag_key_down(int keycode) {
    Display* d = XOpenDisplay(NULL);
    if (!d) return;
    XTestFakeKeyEvent(d, (unsigned int)keycode, True, 0);
    XFlush(d);
    XCloseDisplay(d);
}

EXPORT void dag_key_up(int keycode) {
    Display* d = XOpenDisplay(NULL);
    if (!d) return;
    XTestFakeKeyEvent(d, (unsigned int)keycode, False, 0);
    XFlush(d);
    XCloseDisplay(d);
}

EXPORT int dag_keysym_to_keycode(int keysym) {
    Display* d = XOpenDisplay(NULL);
    if (!d) return 0;
    KeyCode code = XKeysymToKeycode(d, (KeySym)keysym);
    XCloseDisplay(d);
    return (int)code;
}

EXPORT int dag_is_screen_capture_trusted() {
    // X11 has no per-app screen capture permission.
    return 1;
}

static int _mask_shift(unsigned long mask) {
    int shift = 0;
    if (!mask) return 0;
    while (!(mask & 1UL)) { mask >>= 1; shift++; }
    return shift;
}

// Extracts one channel and widens it to 0-255. A depth-24/32 visual has an
// 8-bit mask and this is the identity; a 16-bit visual (RGB565) has 5- and
// 6-bit channels that would otherwise come out far too dark.
static unsigned char _channel(unsigned long pixel, unsigned long mask, int shift) {
    if (!mask) return 0;
    unsigned long max = mask >> shift;
    if (max == 0) return 0;
    unsigned long value = (pixel & mask) >> shift;
    if (max == 255) return (unsigned char)value;
    return (unsigned char)((value * 255UL) / max);
}

// ponytail: XGetPixel per pixel, one call per pixel. Fine for occasional
// captures; switch to XShmGetImage with direct buffer access if capture rate
// ever matters.
EXPORT unsigned char* dag_capture_screen(int x, int y, int w, int h, int* out_w, int* out_h) {
    if (out_w) *out_w = 0;
    if (out_h) *out_h = 0;

    Display* d = XOpenDisplay(NULL);
    if (!d) return NULL;
    Window root = DefaultRootWindow(d);
    int s = DefaultScreen(d);
    int sw = DisplayWidth(d, s);
    int sh = DisplayHeight(d, s);

    if (w <= 0 || h <= 0) {
        x = 0; y = 0;
        w = sw;
        h = sh;
    }

    // XGetImage raises BadMatch for any area outside the drawable, and Xlib's
    // default error handler terminates the host process. Clamp instead.
    if (x < 0) { w += x; x = 0; }
    if (y < 0) { h += y; y = 0; }
    if (x >= sw || y >= sh) { XCloseDisplay(d); return NULL; }
    if (x + w > sw) w = sw - x;
    if (y + h > sh) h = sh - y;
    if (w <= 0 || h <= 0) { XCloseDisplay(d); return NULL; }

    XImage* img = XGetImage(d, root, x, y, w, h, AllPlanes, ZPixmap);
    if (!img) { XCloseDisplay(d); return NULL; }

    unsigned char* buf = (unsigned char*)malloc((size_t)w * (size_t)h * 4);
    if (!buf) { XDestroyImage(img); XCloseDisplay(d); return NULL; }

    int rs = _mask_shift(img->red_mask);
    int gs = _mask_shift(img->green_mask);
    int bs = _mask_shift(img->blue_mask);

    for (int py = 0; py < h; py++) {
        for (int px = 0; px < w; px++) {
            unsigned long p = XGetPixel(img, px, py);
            size_t i = ((size_t)py * (size_t)w + (size_t)px) * 4;
            buf[i + 0] = _channel(p, img->red_mask, rs);
            buf[i + 1] = _channel(p, img->green_mask, gs);
            buf[i + 2] = _channel(p, img->blue_mask, bs);
            buf[i + 3] = 255;
        }
    }

    XDestroyImage(img);
    XCloseDisplay(d);
    if (out_w) *out_w = w;
    if (out_h) *out_h = h;
    return buf;
}

EXPORT void dag_free_image(unsigned char* buf) {
    if (buf) free(buf);
}
