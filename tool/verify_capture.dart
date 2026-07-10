// Manual smoke test for native screen capture (phase 3, milestone A).
//
// Run from the package root:
//   dart run tool/verify_capture.dart
//
// macOS: the *app that owns this process* needs Screen Recording permission
// (System Settings > Privacy & Security > Screen Recording), then restart it.
// That is the terminal app if you run this from a terminal, not `dart` itself.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:autogui/autogui.dart';
import 'package:image/image.dart' as img;

/// Copies a physical-pixel block out of [src].
Capture cropPhysical(Capture src, int x, int y, int w, int h) {
  final bytes = Uint8List(w * h * 4);
  for (var row = 0; row < h; row++) {
    final from = ((y + row) * src.width + x) * 4;
    bytes.setRange(row * w * 4, (row + 1) * w * 4, src.rgba, from);
  }
  return Capture(bytes, w, h);
}

List<int> encodeRgba(Capture c) => img.encodePng(
  img.Image.fromBytes(
    width: c.width,
    height: c.height,
    bytes: c.rgba.buffer,
    numChannels: 4,
  ),
);

Capture decodeRgba(Uint8List png) {
  final image = img.decodeImage(png)!;
  final rgba = image
      .convert(numChannels: 4)
      .getBytes(order: img.ChannelOrder.rgba);
  return Capture(Uint8List.fromList(rgba), image.width, image.height);
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  stdout.writeln('screen capture permitted: ${Screen.isScreenCaptureTrusted}');

  final logical = Screen.size();
  stdout.writeln('Screen.size() (logical points): ${logical.x} x ${logical.y}');

  try {
    final full = Screen.screenshot(filename: 'capture_full.png');
    stdout.writeln(
      'full capture (physical px): ${full.width} x ${full.height}',
    );
    stdout.writeln(
      'scale: ${(full.width / logical.x).toStringAsFixed(2)}x '
      '${(full.height / logical.y).toStringAsFixed(2)}',
    );

    final expected = full.width * full.height * 4;
    stdout.writeln('rgba bytes: ${full.rgba.length} (expected $expected)');
    if (full.rgba.length != expected) {
      stdout.writeln('MISMATCH: buffer size does not match dimensions');
    }
    stdout.writeln('pixelAt(0, 0): ${full.pixelAt(0, 0)}');

    final region = Screen.screenshot(region: const Rectangle(0, 0, 10, 10));
    stdout.writeln(
      'region 10x10 logical -> ${region.width} x ${region.height} physical',
    );

    stdout.writeln(
      'wrote capture_full.png '
      '(${File('capture_full.png').lengthSync()} bytes)',
    );

    // Screen.pixel takes LOGICAL coords and must read the PHYSICAL pixel at
    // (x*scale, y*scale). Probing a flat-colored area proves nothing, so hunt
    // for points where the scaled and unscaled reads actually differ - there a
    // wrong mapping cannot silently pass.
    final scale = full.width ~/ logical.x;
    stdout.writeln('\n-- pixel() vs full capture (scale $scale) --');

    // The value of the scale x scale physical block behind a logical pixel,
    // but only when the block is uniform - so sub-pixel drift can't flap.
    (int, int, int)? uniformBlock(int lx, int ly) {
      final first = full.pixelAt(lx * scale, ly * scale);
      for (var dy = 0; dy < scale; dy++) {
        for (var dx = 0; dx < scale; dx++) {
          if (full.pixelAt(lx * scale + dx, ly * scale + dy) != first) {
            return null;
          }
        }
      }
      return first;
    }

    final probes = <Point<int>>[];
    if (scale > 1) {
      for (var y = 1; y < logical.y - 1 && probes.length < 3; y += 29) {
        for (var x = 1; x < logical.x - 1 && probes.length < 3; x += 41) {
          final scaled = uniformBlock(x, y);
          if (scaled != null && scaled != full.pixelAt(x, y)) {
            probes.add(Point(x, y));
          }
        }
      }
    }

    var mapped = true;
    if (scale == 1) {
      stdout.writeln('scale is 1: logical == physical, mapping is identity');
    } else if (probes.isEmpty) {
      stdout.writeln('WARN: screen too uniform to find a discriminating probe');
    } else {
      for (final p in probes) {
        final scaled = full.pixelAt(p.x * scale, p.y * scale);
        final unscaled = full.pixelAt(p.x, p.y);
        final got = Screen.pixel(p.x, p.y);
        final ok = got == scaled;
        if (!ok) mapped = false;
        stdout.writeln(
          '${ok ? "OK  " : "FAIL"} pixel(${p.x},${p.y})=$got  '
          'scaled=$scaled  unscaled=$unscaled',
        );
      }
    }
    if (!mapped) {
      stdout.writeln(
        'FAIL means pixel() did not read the scaled pixel. If it matched '
        '"unscaled", the logical->physical mapping is broken. If it matched '
        'neither, live screen content changed between captures - re-run.',
      );
    }

    final here = Screen.pixel(0, 0);
    stdout.writeln(
      'pixelMatchesColor(0,0, $here) = '
      '${Screen.pixelMatchesColor(0, 0, here)} (expect true)',
    );
    stdout.writeln(
      'pixelMatchesColor(0,0, (0,0,0), tolerance: 255) = '
      '${Screen.pixelMatchesColor(0, 0, (0, 0, 0), tolerance: 255)} '
      '(expect true)',
    );

    // Milestone C. The crop has to be BOTH distinctive and static.
    //  - flat  => it matches the first similar patch in scan order, proving
    //             nothing about the coordinate mapping;
    //  - moving => any later mismatch is the screen's fault, not the code's.
    // A second full capture is the control: a region whose bytes are identical
    // in both is static, so a remaining difference can only be our doing.
    stdout.writeln('\n-- locate round trip --');
    final fullB = Screen.screenshot();

    const rw = 80, rh = 60;

    /// Distinct sampled colours, and whether every sample is unchanged in fullB.
    (int, bool) score(int lx, int ly) {
      final seen = <int>{};
      for (var sy = 0; sy < rh; sy += 6) {
        for (var sx = 0; sx < rw; sx += 8) {
          final ax = (lx + sx) * scale, ay = (ly + sy) * scale;
          final a = full.pixelAt(ax, ay);
          if (a != fullB.pixelAt(ax, ay)) return (0, false);
          seen.add((a.$1 << 16) | (a.$2 << 8) | a.$3);
        }
      }
      return (seen.length, true);
    }

    var best = const Point(0, 0);
    var bestColours = -1;
    var foundStatic = false;
    for (var ly = 0; ly + rh < logical.y; ly += 60) {
      for (var lx = 0; lx + rw < logical.x; lx += 80) {
        final (colours, stable) = score(lx, ly);
        if (!stable) continue;
        foundStatic = true;
        if (colours > bestColours) {
          bestColours = colours;
          best = Point(lx, ly);
        }
      }
    }

    if (!foundStatic) {
      stdout.writeln(
        'WARN: no region held still across two captures; everything below is '
        'inconclusive. Stop animations and re-run.',
      );
    }
    stdout.writeln(
      'chose static region (${best.x},${best.y}) ${rw}x$rh '
      'with $bestColours distinct sampled colours',
    );
    if (bestColours < 8) {
      stdout.writeln(
        'WARN: that region is nearly uniform; the round trip below is weak. '
        'Open something colourful and re-run.',
      );
    }

    final want = Rectangle(best.x, best.y, rw, rh);
    final px = best.x * scale, py = best.y * scale;
    final pw = rw * scale, ph = rh * scale;

    // (1) Deterministic. Crop the needle out of the capture we already hold and
    // search that same capture. No second screen grab, so nothing can move: a
    // failure here is a real bug in PNG round-tripping, matching, or mapping.
    final needle = cropPhysical(full, px, py, pw, ph);
    File('needle.png').writeAsBytesSync(encodeRgba(needle));
    final decoded = decodeRgba(File('needle.png').readAsBytesSync());

    final lossless = _sameBytes(decoded.rgba, needle.rgba);
    stdout.writeln(
      '${lossless ? "OK  " : "FAIL"} png round trip is lossless '
      '(${needle.rgba.length} bytes)',
    );

    final inMemory = locate(decoded, full);
    final wantPhysical = Rectangle(px, py, pw, ph);
    stdout.writeln(
      '${inMemory == wantPhysical ? "OK  " : "FAIL"} locate(needle, capture) '
      '-> $inMemory  (expected $wantPhysical)',
    );
    if (inMemory != null) {
      final tl = full.toLogical(inMemory.left, inMemory.top);
      stdout.writeln(
        '${tl == best ? "OK  " : "FAIL"} toLogical -> $tl  (expected $best)',
      );
    }

    // (2) Is a region capture pixel-identical to that block of a full capture?
    // If ScreenCaptureKit resamples a scaled sourceRect, a needle cropped this
    // way could never match and locateOnScreen would be broken by construction.
    // The block is confirmed unchanged across two full captures first, so the
    // screen cannot be blamed for a difference.
    final blockB = cropPhysical(fullB, px, py, pw, ph);
    final blockStatic = _sameBytes(needle.rgba, blockB.rgba);
    stdout.writeln(
      '${blockStatic ? "OK  " : "SKIP"} block is identical across two full '
      'captures (static control)',
    );

    final regionShot = Screen.screenshot(region: want);
    final identical =
        regionShot.width == pw &&
        regionShot.height == ph &&
        _sameBytes(regionShot.rgba, needle.rgba);
    stdout.writeln(
      '${identical ? "OK  " : (blockStatic ? "FAIL" : "DIFF")} region capture '
      '== same block of full capture (${regionShot.width}x${regionShot.height})',
    );
    if (!identical && blockStatic) {
      stdout.writeln(
        '  FAIL over a provably static block: region captures are resampled, '
        'so they cannot be used as needles. locateOnScreen needs a needle '
        'cropped from a full screenshot.',
      );
      var differing = 0;
      for (var i = 0; i < needle.rgba.length; i++) {
        if (needle.rgba[i] != regionShot.rgba[i]) differing++;
      }
      stdout.writeln(
        '  $differing of ${needle.rgba.length} bytes differ; '
        'full=${needle.pixelAt(0, 0)} region=${regionShot.pixelAt(0, 0)}',
      );
    } else if (!identical) {
      stdout.writeln('  block moved between captures; inconclusive.');
    }

    // (3) Live. Takes a fresh screenshot, so a moving screen can defeat it.
    // Informational only - (1) is the assertion.
    final clock = Stopwatch()..start();
    final found = Screen.locateOnScreen('needle.png');
    clock.stop();
    stdout.writeln(
      '${found == want ? "OK  " : "live"} locateOnScreen -> $found  '
      '(expected $want)  in ${clock.elapsedMilliseconds}ms',
    );
    if (found != want) {
      stdout.writeln(
        '  A live miss is expected when the chosen region is animating (it is '
        'picked for colour variety, which often means text). Not a failure of '
        'the matcher - see (1).',
      );
    }

    stdout.writeln('\nOK');
  } on StateError catch (e) {
    stdout.writeln('CAPTURE FAILED: ${e.message}');
    exitCode = 1;
  }
}
