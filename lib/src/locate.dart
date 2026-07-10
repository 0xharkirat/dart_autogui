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
  // ponytail: O(W·H·w·h) worst case, cut down by an early-out on the needle's
  // first pixel. Fine for finding a button on a screen. If this ever needs to
  // be fast on 4K with big needles, add a first-row signature or step search -
  // not an OpenCV dependency.
  final firstR = n[0], firstG = n[1], firstB = n[2];

  for (var oy = 0; oy <= hh - nh; oy++) {
    for (var ox = 0; ox <= hw - nw; ox++) {
      final i = (oy * hw + ox) * 4;
      if (h[i] != firstR || h[i + 1] != firstG || h[i + 2] != firstB) continue;
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
