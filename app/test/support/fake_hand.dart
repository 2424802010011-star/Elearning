import 'dart:math' as math;
import 'dart:ui';

import 'package:eduboard_app/ink/math_ink.dart';

/// Giả lập chữ viết tay: lấy dáng mẫu rồi làm méo, nghiêng, run tay, đảo chiều và thứ tự nét.
class FakeHand {
  final math.Random rnd;
  FakeHand(int seed) : rnd = math.Random(seed);

  double _u(double a, double b) => a + rnd.nextDouble() * (b - a);
  double _g() {
    // Box–Muller
    final u1 = math.max(rnd.nextDouble(), 1e-9), u2 = rnd.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  /// Viết ký hiệu [label] (biến thể [variant]) sao cho hộp chứa có chiều cao [height], góc trên trái ở [at].
  List<Pts> write(String label, {int variant = 0, Offset at = Offset.zero, double height = 60, double mess = 1}) {
    final v = glyphTemplates[label]![variant];
    final rot = _u(-6, 6) * mess * math.pi / 180;
    final shear = _u(-0.15, 0.15) * mess;
    final sx = _u(0.82, 1.18), sy = 1.0;
    Offset tf(Offset p) {
      var x = p.dx * sx + shear * (p.dy - 0.5), y = p.dy * sy;
      return Offset(x * math.cos(rot) - y * math.sin(rot), x * math.sin(rot) + y * math.cos(rot));
    }

    var strokes = <List<Offset>>[];
    for (final s in v) {
      final dense = <Offset>[];
      for (var i = 1; i < s.length; i++) {
        final a = tf(s[i - 1]), b = tf(s[i]);
        final steps = math.max(1, ((b - a).distance * 40).ceil());
        for (var k = 0; k < steps; k++) {
          dense.add(Offset.lerp(a, b, k / steps)!);
        }
      }
      dense.add(tf(s.last));
      final phase = _u(0, 6.28), amp = 0.02 * mess, freq = _u(2, 5);
      final wobbly = [
        for (var i = 0; i < dense.length; i++)
          dense[i] + Offset(amp * math.sin(freq * i / dense.length * 6.28 + phase), amp * math.cos(freq * i / dense.length * 6.28 + phase * 1.3)),
      ];
      strokes.add(rnd.nextBool() ? wobbly : wobbly.reversed.toList());
    }
    if (rnd.nextBool()) strokes = strokes.reversed.toList();
    // Đưa về đúng cỡ và vị trí.
    var minX = double.infinity, minY = double.infinity, maxY = -double.infinity;
    for (final s in strokes) {
      for (final p in s) {
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxY = math.max(maxY, p.dy);
      }
    }
    final h = math.max(maxY - minY, 1e-6);
    final k = height / (h < 0.2 ? 1 : h);
    return [
      for (final s in strokes)
        [for (final p in s) at + Offset((p.dx - minX) * k + _g() * 0.5 * mess, (p.dy - minY) * k + _g() * 0.5 * mess)],
    ];
  }
}
