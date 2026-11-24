import 'dart:math' as math;

import 'package:eduboard_app/ink/beautify.dart';
import 'package:flutter_test/flutter_test.dart';

/// Thêm rung tay giả lập (cố định seed để test ổn định).
List<Offset> jitter(List<Offset> pts, double amount, [int seed = 1]) {
  final r = math.Random(seed);
  return [for (final p in pts) p + Offset((r.nextDouble() - .5) * amount, (r.nextDouble() - .5) * amount)];
}

List<Offset> segment(Offset a, Offset b, int n) => [for (var i = 0; i <= n; i++) Offset.lerp(a, b, i / n)!];

List<Offset> polyline(List<Offset> corners, {int per = 25}) {
  final out = <Offset>[];
  for (var i = 0; i < corners.length - 1; i++) {
    out.addAll(segment(corners[i], corners[i + 1], per).skip(i == 0 ? 0 : 1));
  }
  return out;
}

void main() {
  test('đường gần ngang được nắn thành đường thẳng ngang', () {
    final r = beautify(jitter(segment(const Offset(10, 100), const Offset(300, 108), 60), 3));
    expect(r.kind, ShapeKind.line);
    expect(r.points.length, 2);
    expect((r.points.last.dy - r.points.first.dy).abs(), lessThan(0.001));
  });

  test('đường xiên giữ nguyên góc', () {
    final r = beautify(jitter(segment(const Offset(0, 0), const Offset(200, 150), 60), 3));
    expect(r.kind, ShapeKind.line);
    expect(r.points.last.dy, greaterThan(100));
  });

  test('vòng tròn vẽ tay thành hình tròn', () {
    final pts = [for (var i = 0; i <= 80; i++) Offset(200 + 90 * math.cos(i / 80 * 2 * math.pi), 200 + 90 * math.sin(i / 80 * 2 * math.pi))];
    final r = beautify(jitter(pts, 8));
    expect(r.kind, ShapeKind.circle);
  });

  test('hình bầu dục thành elip', () {
    final pts = [for (var i = 0; i <= 80; i++) Offset(200 + 150 * math.cos(i / 80 * 2 * math.pi), 200 + 70 * math.sin(i / 80 * 2 * math.pi))];
    final r = beautify(jitter(pts, 6));
    expect(r.kind, ShapeKind.ellipse);
  });

  test('tam giác vẽ tay thành tam giác 3 đỉnh', () {
    final r = beautify(jitter(polyline([const Offset(100, 300), const Offset(200, 100), const Offset(320, 300), const Offset(102, 298)]), 5));
    expect(r.kind, ShapeKind.triangle);
    expect(r.points.length, 4);
  });

  test('hình vuông lệch thành hình chữ nhật thẳng', () {
    final r = beautify(jitter(
        polyline([const Offset(100, 100), const Offset(305, 104), const Offset(300, 298), const Offset(98, 302), const Offset(101, 103)]), 5));
    expect(r.kind, ShapeKind.rectangle);
    expect(r.points[0].dy, r.points[1].dy);
    expect(r.points[1].dx, r.points[2].dx);
  });

  test('tứ giác không vuông giữ dạng tứ giác', () {
    final r = beautify(jitter(
        polyline([const Offset(100, 300), const Offset(160, 120), const Offset(380, 120), const Offset(320, 300), const Offset(101, 299)]), 4));
    expect(r.kind, ShapeKind.quadrilateral);
  });

  test('đường lượn sóng thành đồ thị sin, ước lượng đúng chu kỳ', () {
    // Chu kỳ 160 px, biên độ 50 px, 2 chu kỳ.
    final pts = [for (var x = 0.0; x <= 320; x += 4) Offset(50 + x, 200 - 50 * math.sin(2 * math.pi * x / 160))];
    final r = beautify(jitter(pts, 8));
    expect(r.kind, ShapeKind.sine);
    final period = double.parse(RegExp(r'chu kỳ ≈ (\d+)').firstMatch(r.detail!)!.group(1)!);
    expect(period, closeTo(160, 8));
  });

  test('nét nguệch ngoạc giữ nguyên', () {
    final rnd = math.Random(3);
    final pts = [for (var i = 0; i < 60; i++) Offset(rnd.nextDouble() * 300, rnd.nextDouble() * 300)];
    expect(beautify(pts).kind, ShapeKind.none);
  });

  test('chấm nhỏ giữ nguyên', () {
    expect(beautify([const Offset(1, 1), const Offset(2, 2), const Offset(3, 2), const Offset(3, 3)]).kind, ShapeKind.none);
  });
}
