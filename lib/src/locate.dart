import 'dart:math';
import 'dart:typed_data';

import 'platform.dart';

/// Finds the first occurrence of [needle] inside [haystack].
///
/// Returns the match rectangle in [haystack]'s *physical* pixel coordinates, or
/// null when there is no match. Use [Capture.toLogical] to convert.
Rectangle<int>? locate(Capture needle, Capture haystack) {
  for (final match in locateAll(needle, haystack)) {
    return match;
  }
  return null;
}

/// Every occurrence of [needle] inside [haystack], in physical pixel
/// coordinates, scanned left-to-right then top-to-bottom.
///
/// Matching is exact on the RGB channels; alpha is ignored, so a needle with
/// transparency still has to match the colours underneath it. The result is
/// lazy, so [locate] stops at the first hit.
Iterable<Rectangle<int>> locateAll(Capture needle, Capture haystack) sync* {
  final nw = needle.width, nh = needle.height;
  final hw = haystack.width, hh = haystack.height;
  if (nw <= 0 || nh <= 0 || nw > hw || nh > hh) return;

  final n = needle.rgba, h = haystack.rgba;

  // Probe a few needle pixels before committing to a full compare. Testing only
  // the first pixel is not enough: a solid-fill needle on a flat background
  // passes it at every offset and the deep compare then dominates. Bottom-right
  // comes second because that is where a uniform needle tends to differ.
  //
  // Measured, 3024x1964 haystack / 160x120 needle, desktop-like content: a
  // match takes ~45 ms (it pays the full compare once), a full no-match scan
  // ~35 ms. The worst case - a uniform needle over a uniform background that
  // never matches - falls from ~141 s with a single first-pixel probe to
  // well under a second with these five.
  //
  // ponytail: still O(W·H·w·h) in the limit; a needle that agrees on every
  // probe but differs elsewhere degrades. Realistic content does not. If it
  // ever bites, add a row signature or step search, not an OpenCV dependency.
  final probes = <(int, int, int)>[]; // (needle byte index, nx, ny)
  final seen = <int>{};
  for (final (nx, ny) in [
    (0, 0),
    (nw - 1, nh - 1),
    (nw - 1, 0),
    (0, nh - 1),
    (nw ~/ 2, nh ~/ 2),
  ]) {
    final ni = (ny * nw + nx) * 4;
    if (seen.add(ni)) probes.add((ni, nx, ny));
  }

  bool probesMatch(int ox, int oy) {
    for (final (ni, nx, ny) in probes) {
      final hi = ((oy + ny) * hw + ox + nx) * 4;
      if (n[ni] != h[hi] || n[ni + 1] != h[hi + 1] || n[ni + 2] != h[hi + 2]) {
        return false;
      }
    }
    return true;
  }

  for (var oy = 0; oy <= hh - nh; oy++) {
    for (var ox = 0; ox <= hw - nw; ox++) {
      if (!probesMatch(ox, oy)) continue;
      if (_matchesAt(n, nw, nh, h, hw, ox, oy)) {
        yield Rectangle(ox, oy, nw, nh);
      }
    }
  }
}

bool _matchesAt(
  Uint8List n,
  int nw,
  int nh,
  Uint8List h,
  int hw,
  int ox,
  int oy,
) {
  for (var y = 0; y < nh; y++) {
    var ni = y * nw * 4;
    var hi = ((oy + y) * hw + ox) * 4;
    for (var x = 0; x < nw; x++) {
      if (n[ni] != h[hi] || n[ni + 1] != h[hi + 1] || n[ni + 2] != h[hi + 2]) {
        return false;
      }
      ni += 4;
      hi += 4;
    }
  }
  return true;
}
