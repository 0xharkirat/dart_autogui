#include <X11/Xlib.h>
#include <X11/extensions/XTest.h>
#include <unistd.h>
#include <stdio.h>

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
