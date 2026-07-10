# Phase 3 Plan: Screenshot & Image Location

Status: **planning only** (no implementation on this branch).
Scopes the remaining PyAutoGUI gap around screen capture and image matching, with
a lazy/minimal implementation approach.

## 1. The remaining gap

PyAutoGUI's screenshot/image surface, none of which exists in dart_autogui today:

| PyAutoGUI | Purpose | Home in this plan |
| --- | --- | --- |
| `screenshot(filename=None, region=None)` | Capture screen (or region) to an image, optionally save | `Screen.screenshot` |
| `pixel(x, y)` | RGB of one screen pixel | `Screen.pixel` |
| `pixelMatchesColor(x, y, rgb, tolerance)` | Compare a pixel to a color | `Screen.pixelMatchesColor` |
| `locateOnScreen(img, region, confidence, grayscale)` | Find a template image on screen | `Screen.locateOnScreen` |
| `locateAllOnScreen(...)` | All matches | `Screen.locateAllOnScreen` |
| `locateCenterOnScreen(...)` | Center point of first match | `Screen.locateCenterOnScreen` |
| `locate(needle, haystack)` / `locateAll` | Match between two images (no screen) | `locate` / `locateAll` |
| `center(box)` | Center of a region box | `center` |
| `ImageNotFoundException` / `useImageNotFoundException()` | Not-found behavior toggle | see §4 (return null instead) |

Adjacent, out of scope here (tracked separately): `press`/`typewrite` list input,
macOS media keys, `displayMousePosition` (its RGB readout depends on `pixel`),
`getInfo`, the 24 extra easing curves, and the `run()` DSL.

## 2. Design principle (ponytail)

The native layer does the one thing only native can do - grab screen pixels -
and nothing else. Everything above it is pure Dart over a byte buffer.

1. **One native entry point**: `dag_capture_screen(x, y, w, h, ...)` returning a
   raw **RGBA8888** buffer, plus `dag_free_image` to release it. Full-screen when
   `w`/`h <= 0`. `pixel(x,y)` is just a 1x1 capture - no separate pixel symbol.
2. **Pure Dart for pixel, color match, and template matching** - it is all
   indexing and comparing bytes. No native code for logic the CPU can do in Dart.
3. **One new dependency, `package:image`, for PNG only** - encode a capture to a
   file, decode a needle PNG for `locate`. Pixel access and matching run on raw
   bytes, not through the library. Hand-rolling a PNG codec is not lazy; adding a
   second dep (OpenCV bindings, etc.) is not either - skip it.
4. **Reuse `dart:math`**: regions are `Rectangle<int>` (has `left/top/width/height`
   and `.center`), points are `Point<int>`, colors are a `(int r, int g, int b)`
   record. No custom `Box`/`Color`/`Region` classes.
5. **Not-found returns `null`**, the Dart idiom - no exception, no global toggle.
   Skip `ImageNotFoundException` + `useImageNotFoundException` (YAGNI).

Net: ~2 native functions × 3 platforms, one dep, and the rest is testable pure
Dart. No new abstractions beyond what the capability needs.

## 3. Native work

Add to the C ABI (`src/native/*/autogui.*` + `autogui.h`), wire through
`NativeBindings` (`lib/src/ffi/bindings.dart`), CMake already builds one target so
no build changes beyond new source lines.

```c
// Capture (x,y,w,h) in the SAME coordinate space as dag_get_screen_size /
// dag_get_mouse_position. w<=0 || h<=0 means full primary display.
// Returns a malloc'd RGBA8888 buffer of out_w*out_h*4 bytes (row-major, no
// padding) and writes the real pixel dimensions to out_w/out_h. NULL on failure.
// Caller must release with dag_free_image.
unsigned char* dag_capture_screen(int x, int y, int w, int h,
                                   int* out_w, int* out_h);
void dag_free_image(unsigned char* buf);
```

Per platform (each normalizes to RGBA before returning, so Dart stays uniform):

- **macOS** (`autogui.mm`): **ScreenCaptureKit**, not the CG APIs.
  `CGDisplayCreateImage` and `CGWindowListCreateImage` are annotated
  `SCREEN_CAPTURE_OBSOLETE(..., 15.0)` in the macOS 15+ SDK - they are
  *unavailable*, a hard compile error, not a suppressible deprecation warning
  (verified against SDK 26.1). The supported path is
  `SCShareableContent` → `SCContentFilter` → `SCStreamConfiguration` →
  `SCScreenshotManager.captureImageWithFilter:configuration:completionHandler:`,
  wrapped in a `dispatch_semaphore` (with a timeout) to keep the C ABI
  synchronous. Scale factor comes from `SCContentFilter.pointPixelScale`.
  `SCScreenshotManager` is **macOS 14+**: capture is `@available`-gated and
  returns NULL on older systems, where mouse/keyboard keep working.
  Needs **Screen Recording** permission (TCC) - `dag_is_screen_capture_trusted()`
  wraps `CGPreflightScreenCaptureAccess`. Build: link `ScreenCaptureKit`,
  compile the `.mm` with `-fobjc-arc`, and set a `CMAKE_OSX_DEPLOYMENT_TARGET`
  (13.0) so the shipped dylib is portable.
- **Windows** (`autogui.cpp`): `BitBlt` screen DC → memory DC, `GetDIBits` for
  BGRA, swap to RGBA. No special permission.
- **Linux** (`autogui.c`): `XGetImage` on the root window → convert to RGBA. No
  special permission. *Upgrade path*: `XShmGetImage` for speed - not now.

FFI wrapper returns a Dart `Uint8List` (copy out of the native buffer, then
`dag_free_image`) plus width/height - so the native pointer never escapes the
binding and cannot leak.

## 4. Dart API surface

All on `Screen` (screen-related) + two free functions for image-to-image work.
Everything returns `null` / empty when nothing is found.

```dart
class Capture {                    // thin: raw pixels + dimensions
  final Uint8List rgba;            // w*h*4
  final int width, height;
  (int, int, int) pixelAt(int x, int y);
}

class Screen {
  static Capture screenshot({Rectangle<int>? region, String? filename});
  static (int, int, int) pixel(int x, int y);          // 1x1 capture
  static bool pixelMatchesColor(int x, int y, (int,int,int) rgb, {int tolerance = 0});

  static Rectangle<int>? locateOnScreen(String imagePath, {Rectangle<int>? region});
  static List<Rectangle<int>> locateAllOnScreen(String imagePath, {Rectangle<int>? region});
  static Point<int>? locateCenterOnScreen(String imagePath, {Rectangle<int>? region});
}

// image-vs-image (needle/haystack as decoded pixels)
Rectangle<int>? locate(Capture needle, Capture haystack);
Iterable<Rectangle<int>> locateAll(Capture needle, Capture haystack);
Point<int> center(Rectangle<int> box) => box.center... ;   // dart:math
```

- `screenshot(filename:)` writes a PNG via `package:image` `encodePng`.
- `locate*` decode the needle PNG via `package:image` `decodePng`, capture the
  screen (or region), then run the matcher on raw bytes.
- Colors as `(int r, int g, int b)` records; `tolerance` is per-channel abs diff.

## 5. Matching approach

Naive exact template scan, pure Dart:

```
for each (ox, oy) in haystack where needle fits:
  if every needle pixel == haystack pixel at (ox+.., oy+..): record match
first-pixel early-out per offset keeps the common case cheap
```

`// ponytail: O(W·H·w·h) worst case exact-match scan. Fine for finding a button
on a screen; if it ever needs sub-100ms on full 4K + large needles, add a
first-row signature / step search or FFT, not OpenCV.`

Deliberately **not** in v1: `confidence` (fuzzy match / OpenCV), `grayscale`
speedup. Add `confidence` later only if exact match proves too brittle; it is the
one place a heavier dep might later be justified, and only then.

## 6. Milestones (each its own topic branch → cross-review → merge)

- **A - Capture** *(implemented)*: native `dag_capture_screen`/`dag_free_image` on all 3 OSes,
  FFI wiring, `Screen.screenshot()` + PNG file save, macOS permission check +
  README note, `package:image` dep. Resolves the coordinate-space question (§7).
- **B - Pixel** *(implemented)*: `Screen.pixel`, `pixelMatchesColor`, `center`.
  Pure Dart over A; `pixel` captures a 1x1 logical region so it needs no scale
  math.
- **C - Locate** *(implemented)*: `locateOnScreen`/`locateAllOnScreen`/
  `locateCenterOnScreen` + `locate`/`locateAll`, naive exact matcher in
  `lib/src/locate.dart`. Matching runs in physical pixels; results convert back
  to logical via `Capture.toLogical` (which is why `Capture` gained `scale` and
  `origin`). Alpha is ignored - RGB must match exactly.
- **D - Defer**: `confidence`/`grayscale`, `XShm`/ScreenCaptureKit perf,
  multi-monitor virtual desktop, `displayMousePosition` RGB.

A is the only hard (native) milestone; B and C are pure-Dart follow-ons and
fully unit-testable against synthetic `Capture` buffers (no real screen needed).

## 7. Risks & open questions

1. **Retina / DPI scaling - RESOLVED.** Measured on a HiDPI Mac:
   `Screen.size()` = 1512×982 logical points, a full capture returns 3024×1964
   physical pixels (scale 2.00), and a 10×10 logical region returns 20×20
   physical. So the ABI contract holds: **input rects are logical points, output
   buffers are physical pixels**, regions included. `Screen.pixel(x, y)`
   therefore needs no scale math - it captures a 1×1 *logical* region and reads
   its top-left physical pixel. Only `locate*` (Milestone C) needs the scale, to
   convert a physical match rect back to logical coordinates for `Mouse.click`.
2. **macOS Screen Recording permission.** `Screen.isScreenCaptureTrusted`
   correctly reports `false` and `screenshot()` throws a clear `StateError` when
   ungranted. TCC attributes the grant to the *responsible app* (the terminal or
   host application), not to `dart`; grant it in System Settings → Privacy &
   Security → Screen Recording and restart that app. Consider adding
   `dag_request_screen_capture_access()` (`CGRequestScreenCaptureAccess`) so the
   OS prompt can be triggered from Dart.
3. **Linux/Windows capture is unverified** - written and compile-reviewed, but
   built and smoke-tested on macOS only. Needs a real run on each OS.
4. **Native buffer ownership** - the FFI wrapper copies then calls
   `dag_free_image` in a `finally` (done); a smoke test should still capture in
   a loop and watch RSS.
5. **`package:image` on large buffers** - decode/encode is fine; keep the
   *matcher* on raw bytes (not `img.getPixel` per pixel, which is slow).
6. **Multi-monitor** - v1 captures the primary display only, consistent with
   today's primary-only `Screen.size()`. Virtual-desktop capture is Milestone D.

## 8. Definition of done (per milestone)

- native symbol exists on all three backends and is exported/loaded through
  `NativeBindings` (respect the ABI-name invariant in AGENTS.md);
- pure-Dart logic has unit tests over synthetic `Capture` buffers;
- one documented manual smoke test per OS (capture a known region, check a pixel);
- README + CHANGELOG updated in the same branch;
- coordinate space is documented and verified on a HiDPI display.
