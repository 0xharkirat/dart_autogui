#ifdef __cplusplus
extern "C" {
#endif

// Screen
void dag_get_screen_size(double *width, double *height);

// Mouse position & move (absolute)
void dag_get_mouse_position(double *x, double *y);
void dag_move_mouse(double x, double y);

// Buttons: 0=left, 1=right, 2=middle
void dag_mouse_down(int button);
void dag_mouse_up(int button);

// Convenience click (doesn't move)
void dag_mouse_click(int button, int clicks, double interval_secs);

// Scroll (vertical lines, positive = up, negative = down)
void dag_scroll(int delta_lines);
// Horizontal scroll (positive = right, negative = left)
void dag_hscroll(int delta_lines);

// Permissions
int dag_is_accessibility_trusted();
// Screen Recording permission (macOS). Other platforms always return 1.
int dag_is_screen_capture_trusted();

// Keyboard
void dag_key_down(int keycode);
void dag_key_up(int keycode);

// Screen capture.
// (x, y, w, h) are in the same coordinate space as dag_get_screen_size and
// dag_get_mouse_position. w <= 0 || h <= 0 captures the full primary display.
// Returns a malloc'd RGBA8888 buffer of out_w*out_h*4 bytes (row-major, no row
// padding) and writes the real pixel dimensions to out_w/out_h - these can
// exceed the requested size on HiDPI displays. Returns NULL on failure.
// The caller must release the buffer with dag_free_image.
unsigned char *dag_capture_screen(int x, int y, int w, int h, int *out_w,
                                  int *out_h);
void dag_free_image(unsigned char *buf);

#ifdef __cplusplus
}
#endif
