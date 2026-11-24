import 'package:eduboard_app/ink/math_ink.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_hand.dart';

void main() {
  test('nhận đúng từng ký hiệu viết tay giả lập', () {
    final hand = FakeHand(7);
    var ok = 0, total = 0;
    final errors = <String, int>{};
    for (final e in glyphTemplates.entries) {
      for (var v = 0; v < e.value.length; v++) {
        for (var rep = 0; rep < 12; rep++) {
          final ink = hand.write(e.key, variant: v, height: e.key == "-" ? 40 : 50 + rep * 5.0, mess: 1.5);
          final r = classifySymbol(ink);
          total++;
          if (r?.label == e.key) {
            ok++;
          } else {
            final k = '${e.key}v$v→${r?.label ?? '∅'}';
            errors[k] = (errors[k] ?? 0) + 1;
          }
        }
      }
    }
    // ignore: avoid_print
    print('Độ chính xác: $ok/$total = ${(100 * ok / total).toStringAsFixed(1)}%  lỗi: $errors');
    expect(ok / total, greaterThan(0.9));
  });

  test('mỗi ký hiệu viết riêng đọc đúng qua cả quy trình (gom nét, bố cục)', () {
    var ok = 0, total = 0;
    final bad = <String>[];
    for (final lbl in glyphTemplates.keys) {
      for (var seed = 0; seed < 10; seed++) {
        final t = recognizeMath(FakeHand(seed).write(lbl, at: const Offset(100, 100), height: 45)).text;
        total++;
        if (t == lbl || (lbl == '-' && t == '−')) {
          ok++;
        } else {
          bad.add('$lbl→$t');
        }
      }
    }
    // ignore: avoid_print
    print('Cả quy trình: $ok/$total. Sai: $bad');
    expect(ok / total, greaterThan(0.93));
  });

  test('đủ nhanh: 25 nét trong chưa tới 1 giây', () {
    final h = FakeHand(11);
    final ink = <List<Offset>>[];
    var x = 0.0;
    for (final l in ['y', '=', '3', 'x', '2', '+', '5', 'x', '-', '7', '<', 'π']) {
      ink.addAll(h.write(l, at: Offset(x, 100), height: 40));
      x += 55;
    }
    final sw = Stopwatch()..start();
    recognizeMath(ink);
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });

  List<Offset> dense(List<Offset> pts) {
    final out = <Offset>[];
    for (var i = 1; i < pts.length; i++) {
      for (var k = 0; k < 10; k++) {
        out.add(Offset.lerp(pts[i - 1], pts[i], k / 10)!);
      }
    }
    return out..add(pts.last);
  }

  group('biểu thức', () {
    for (final seed in [1, 2, 3]) {
      test('x² + 1 = 0 (lần $seed)', () {
        final h = FakeHand(seed);
        final ink = [
          ...h.write('x', at: const Offset(100, 100), height: 60),
          ...h.write('2', at: const Offset(160, 75), height: 30),
          ...h.write('+', at: const Offset(215, 112), height: 36),
          ...h.write('1', at: const Offset(280, 98), height: 62),
          ...h.write('=', at: const Offset(330, 118), height: 24),
          ...h.write('0', at: const Offset(410, 102), height: 58),
        ];
        final r = recognizeMath(ink);
        expect(r.text, 'x² + 1 = 0');
        expect(r.recognized, 6);
      });
    }

    test('phân số 1/2 được canh giữa gạch', () {
      final h = FakeHand(4);
      final ink = [
        ...h.write('1', at: const Offset(30, 0), height: 50),
        dense([const Offset(0, 62), const Offset(70, 64)]),
        ...h.write('2', at: const Offset(10, 75), height: 50),
      ];
      final r = recognizeMath(ink);
      expect(r.text, '1/2');
      // Gạch phân số được vẽ lại thẳng tuyệt đối.
      final bar = r.strokes.firstWhere((s) => s.length == 2 && s.first.dy == s.last.dy);
      final mid = (bar.first.dx + bar.last.dx) / 2;
      final others = r.strokes.where((s) => !identical(s, bar)).expand((s) => s).toList();
      final minX = others.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
      final maxX = others.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      expect(((minX + maxX) / 2 - mid).abs(), lessThan(6));
    });

    test('y = (x+1)/2 trong một dòng', () {
      final h = FakeHand(5);
      final ink = [
        ...h.write('y', at: const Offset(0, 40), height: 50),
        ...h.write('=', at: const Offset(70, 58), height: 20),
        ...h.write('x', at: const Offset(150, 0), height: 40),
        ...h.write('+', at: const Offset(200, 8), height: 28),
        ...h.write('1', at: const Offset(245, 0), height: 42),
        dense([const Offset(140, 55), const Offset(275, 56)]),
        ...h.write('2', at: const Offset(190, 66), height: 42),
      ];
      expect(recognizeMath(ink).text, 'y = (x + 1)/2');
    });

    test('căn bậc hai', () {
      final h = FakeHand(6);
      final ink = [
        dense([const Offset(0, 50), const Offset(10, 44), const Offset(24, 80), const Offset(40, 0), const Offset(150, 2)]),
        ...h.write('x', at: const Offset(55, 25), height: 45),
        ...h.write('2', at: const Offset(105, 10), height: 22),
      ];
      expect(recognizeMath(ink).text, '√(x²)');
    });

    test('nét lạ không nhận ra thì giữ nguyên', () {
      final scribble = dense([const Offset(0, 0), const Offset(80, 10), const Offset(5, 30), const Offset(90, 45), const Offset(0, 70), const Offset(85, 60)]);
      final r = recognizeMath([scribble]);
      expect(r.recognized, 0);
    });
  });
}
