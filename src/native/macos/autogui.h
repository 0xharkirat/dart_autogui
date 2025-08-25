#ifdef __cplusplus
extern "C" {
#endif

// Returns current mouse position (global display coords)
void dag_get_mouse_position(double* x, double* y);

// Instantly moves the mouse to (x, y)
void dag_move_mouse(double x, double y);

// Smoothly moves the mouse to (x, y) over duration_secs
void dag_move_mouse_smooth(double x, double y, double duration_secs);

// Returns 1 if Accessibility permissions are granted, else 0
int dag_is_accessibility_trusted();

#ifdef __cplusplus
}
#endif
