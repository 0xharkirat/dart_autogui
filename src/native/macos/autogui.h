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

// Keyboard
void dag_key_down(int keycode);
void dag_key_up(int keycode);

#ifdef __cplusplus
}
#endif
