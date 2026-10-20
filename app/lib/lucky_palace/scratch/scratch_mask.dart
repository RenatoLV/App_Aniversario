import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// A binary alpha/occupancy mask. Same cells drive rendering and coverage.
/// Coordinates use the manifest's 486×342 board, independent of viewport size.
class ScratchMask {
  ScratchMask() : bits = Uint8List(byteLength);
  ScratchMask._(this.bits) {
    for (var i = 0; i < columns * rows; i++) {
      if (isSet(i)) {
        if (!_eligible(i % columns, i ~/ columns)) {
          throw const FormatException('Máscara fuera del borde');
        }
        cleared++;
      }
    }
  }
  static const columns = 192, rows = 128, byteLength = columns * rows ~/ 8;
  static const width = 486.0, height = 342.0, corner = 18.0;
  final Uint8List bits;
  int cleared = 0, revision = 0;
  static final eligibleCount = [
    for (var y = 0; y < rows; y++)
      for (var x = 0; x < columns; x++)
        if (_eligible(x, y)) 1,
  ].length;
  static bool _eligible(int x, int y) {
    final px = (x + .5) * width / columns, py = (y + .5) * height / rows;
    final cx = px.clamp(corner, width - corner),
        cy = py.clamp(corner, height - corner);
    return (px - cx) * (px - cx) + (py - cy) * (py - cy) <= corner * corner;
  }

  bool isSet(int i) => (bits[i >> 3] & (1 << (i & 7))) != 0;
  double get coverage => cleared / eligibleCount;
  String encode() => base64Encode(bits);
  factory ScratchMask.decode(String value) {
    final data = base64Decode(value);
    if (data.length != byteLength) {
      throw const FormatException('Máscara de raspe incompatible');
    }
    return ScratchMask._(Uint8List.fromList(data));
  }
  ScratchMask copy() => ScratchMask.decode(encode());
  bool merge(ScratchMask other) {
    var changed = false;
    for (var i = 0; i < bits.length; i++) {
      final before = bits[i];
      bits[i] |= other.bits[i];
      changed |= before != bits[i];
    }
    if (changed) {
      cleared = 0;
      for (var i = 0; i < columns * rows; i++) {
        if (isSet(i)) {
          cleared++;
        }
      }
      revision++;
    }
    return changed;
  }

  bool segment(double ax, double ay, double bx, double by, double radius) {
    if (![ax, ay, bx, by, radius].every((v) => v.isFinite) || radius <= 0) {
      return false;
    }
    final left = (((math.min(ax, bx) - radius) / width) * columns)
        .floor()
        .clamp(0, columns - 1);
    final right = (((math.max(ax, bx) + radius) / width) * columns)
        .ceil()
        .clamp(0, columns - 1);
    final top = (((math.min(ay, by) - radius) / height) * rows).floor().clamp(
      0,
      rows - 1,
    );
    final bottom = (((math.max(ay, by) + radius) / height) * rows).ceil().clamp(
      0,
      rows - 1,
    );
    final dx = bx - ax, dy = by - ay, d2 = dx * dx + dy * dy;
    var changed = false;
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        final i = y * columns + x;
        if (isSet(i) || !_eligible(x, y)) continue;
        final px = (x + .5) * width / columns, py = (y + .5) * height / rows;
        final t = d2 == 0
            ? 0.0
            : (((px - ax) * dx + (py - ay) * dy) / d2).clamp(0.0, 1.0);
        final ex = px - ax - t * dx, ey = py - ay - t * dy;
        if (ex * ex + ey * ey <= radius * radius) {
          bits[i >> 3] |= 1 << (i & 7);
          cleared++;
          changed = true;
        }
      }
    }
    if (changed) revision++;
    return changed;
  }
}
