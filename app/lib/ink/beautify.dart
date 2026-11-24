import 'dart:math' as math;
import 'dart:ui';

/// Nhận diện nét vẽ tay và trả về dạng chuẩn, gọn gàng.
///
/// Phiên bản đầu dùng thuật toán hình học (không cần mạng, chạy ngay trên máy, < 5 ms):
/// - đường thẳng (tự nắn ngang/dọc khi gần ngang/dọc)
/// - hình tròn, hình elip
/// - tam giác, tứ giác (tự nắn thành hình chữ nhật khi các góc gần vuông), đa giác
/// - đồ thị dạng sin: ước lượng biên độ, chu kỳ, pha rồi vẽ lại y = A·sin(Bx + C) + D
///
/// Chữ viết tay và ký hiệu toán sẽ dùng mô hình học máy ở giai đoạn sau.
enum ShapeKind { none, line, circle, ellipse, triangle, rectangle, quadrilateral, polygon, sine }

String shapeLabel(ShapeKind k) => switch (k) {
      ShapeKind.none => 'Nét tự do',
      ShapeKind.line => 'Đường thẳng',
      ShapeKind.circle => 'Hình tròn',
      ShapeKind.ellipse => 'Hình elip',
      ShapeKind.triangle => 'Tam giác',
      ShapeKind.rectangle => 'Hình chữ nhật',
      ShapeKind.quadrilateral => 'Tứ giác',
      ShapeKind.polygon => 'Đa giác',
      ShapeKind.sine => 'Đồ thị hình sin',
    };

class Recognized {
  final ShapeKind kind;
  final List<Offset> points;
  /// Thông tin thêm, ví dụ tham số hàm sin.
  final String? detail;
  const Recognized(this.kind, this.points, [this.detail]);
}

double _dist(Offset a, Offset b) => (a - b).distance;

double _pathLength(List<Offset> p) {
  var s = 0.0;
  for (var i = 1; i < p.length; i++) {
    s += _dist(p[i - 1], p[i]);
  }
  return s;
}

double _pointLineDist(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len = ab.distance;
  if (len == 0) return _dist(p, a);
  return ((p.dx - a.dx) * ab.dy - (p.dy - a.dy) * ab.dx).abs() / len;
}

/// Ramer–Douglas–Peucker: giữ lại các điểm góc.
List<Offset> _rdp(List<Offset> pts, double eps) {
  if (pts.length < 3) return List.of(pts);
  var maxD = 0.0;
  var idx = 0;
  for (var i = 1; i < pts.length - 1; i++) {
    final d = _pointLineDist(pts[i], pts.first, pts.last);
    if (d > maxD) {
      maxD = d;
      idx = i;
    }
  }
  if (maxD <= eps) return [pts.first, pts.last];
  final left = _rdp(pts.sublist(0, idx + 1), eps);
  final right = _rdp(pts.sublist(idx), eps);
  return [...left.sublist(0, left.length - 1), ...right];
}

/// Nắn góc gần 0°/90°/180° về đúng ngang/dọc.
Offset _snapEnd(Offset a, Offset b, {double tolDeg = 7}) {
  final ang = math.atan2(b.dy - a.dy, b.dx - a.dx) * 180 / math.pi;
  final len = _dist(a, b);
  for (final target in [-180.0, -90.0, 0.0, 90.0, 180.0]) {
    if ((ang - target).abs() <= tolDeg) {
      final r = target * math.pi / 180;
      return Offset(a.dx + len * math.cos(r), a.dy + len * math.sin(r));
    }
  }
  return b;
}

Recognized beautify(List<Offset> raw) {
  final none = Recognized(ShapeKind.none, raw);
  if (raw.length < 4) return none;
  final length = _pathLength(raw);
  if (length < 20) return none;

  final first = raw.first, last = raw.last;
  final chord = _dist(first, last);

  // 1. Đường thẳng: mọi điểm gần đoạn nối hai đầu.
  if (chord > 0.85 * length) {
    var maxDev = 0.0;
    for (final p in raw) {
      maxDev = math.max(maxDev, _pointLineDist(p, first, last));
    }
    if (maxDev < math.max(4.0, 0.06 * chord)) {
      return Recognized(ShapeKind.line, [first, _snapEnd(first, last)]);
    }
  }

  final closed = chord < 0.18 * length;
  if (closed) return _closedShape(raw, length) ?? none;

  final sine = _fitSine(raw);
  if (sine != null) return sine;
  return none;
}

Recognized? _closedShape(List<Offset> raw, double perimeter) {
  final pts = [...raw, raw.first];

  // Đo độ "tròn": độ lệch bán kính so với tâm.
  var cx = 0.0, cy = 0.0;
  for (final p in raw) {
    cx += p.dx;
    cy += p.dy;
  }
  final c = Offset(cx / raw.length, cy / raw.length);
  final radii = [for (final p in raw) _dist(p, c)];
  final mean = radii.reduce((a, b) => a + b) / radii.length;
  final sd = math.sqrt(radii.map((r) => (r - mean) * (r - mean)).reduce((a, b) => a + b) / radii.length);
  final roundness = sd / mean;

  // Tìm các góc bằng RDP.
  var corners = _rdp(pts, 0.045 * perimeter);
  if (corners.length > 1 && _dist(corners.first, corners.last) < 0.1 * perimeter) {
    corners = corners.sublist(0, corners.length - 1);
  }
  corners = _mergeClose(corners, 0.08 * perimeter);

  if (roundness < 0.1 && corners.length >= 5 || roundness < 0.06) {
    return Recognized(ShapeKind.circle, _ellipsePoints(c, mean, mean));
  }

  // Elip theo hình chữ nhật bao.
  var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
  for (final p in raw) {
    minX = math.min(minX, p.dx);
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  final ec = Offset((minX + maxX) / 2, (minY + maxY) / 2);
  final rx = (maxX - minX) / 2, ry = (maxY - minY) / 2;
  var err = 0.0;
  for (final p in raw) {
    final v = math.sqrt(math.pow((p.dx - ec.dx) / rx, 2) + math.pow((p.dy - ec.dy) / ry, 2));
    err += (v - 1).abs();
  }
  err /= raw.length;
  if (err < 0.08) {
    if ((rx - ry).abs() / math.max(rx, ry) < 0.12) {
      final r = (rx + ry) / 2;
      return Recognized(ShapeKind.circle, _ellipsePoints(ec, r, r));
    }
    return Recognized(ShapeKind.ellipse, _ellipsePoints(ec, rx, ry));
  }
  if (corners.length == 3) return Recognized(ShapeKind.triangle, [...corners, corners.first]);
  if (corners.length == 4) {
    if (_nearlyRectangular(corners)) {
      final xs = corners.map((p) => p.dx).toList()..sort();
      final ys = corners.map((p) => p.dy).toList()..sort();
      final l = (xs[0] + xs[1]) / 2, r = (xs[2] + xs[3]) / 2, t = (ys[0] + ys[1]) / 2, b = (ys[2] + ys[3]) / 2;
      return Recognized(ShapeKind.rectangle, [Offset(l, t), Offset(r, t), Offset(r, b), Offset(l, b), Offset(l, t)]);
    }
    return Recognized(ShapeKind.quadrilateral, [...corners, corners.first]);
  }

  if (corners.length >= 5 && corners.length <= 8) return Recognized(ShapeKind.polygon, [...corners, corners.first]);
  return null;
}

List<Offset> _mergeClose(List<Offset> pts, double minDist) {
  final out = <Offset>[];
  for (final p in pts) {
    if (out.isEmpty || _dist(out.last, p) >= minDist) out.add(p);
  }
  if (out.length > 2 && _dist(out.first, out.last) < minDist) out.removeLast();
  return out;
}

bool _nearlyRectangular(List<Offset> q) {
  for (var i = 0; i < 4; i++) {
    final a = q[(i + 3) % 4], b = q[i], c = q[(i + 1) % 4];
    final v1 = a - b, v2 = c - b;
    final cos = (v1.dx * v2.dx + v1.dy * v2.dy) / (v1.distance * v2.distance);
    if (cos.abs() > 0.26) return false; // lệch quá ~15° so với góc vuông
  }
  // Các cạnh gần song song trục thì nắn về hình chữ nhật đứng.
  for (var i = 0; i < 4; i++) {
    final d = q[(i + 1) % 4] - q[i];
    final ang = (math.atan2(d.dy, d.dx) * 180 / math.pi).abs() % 90;
    if (ang > 12 && ang < 78) return false;
  }
  return true;
}

List<Offset> _ellipsePoints(Offset c, double rx, double ry, {int n = 72}) => [
      for (var i = 0; i <= n; i++) Offset(c.dx + rx * math.cos(2 * math.pi * i / n), c.dy + ry * math.sin(2 * math.pi * i / n)),
    ];

/// Khớp y = A·sin(B·x + C) + D cho nét lượn sóng chạy theo chiều ngang.
Recognized? _fitSine(List<Offset> raw) {
  // Nét phải đi một chiều theo trục x (cho phép rung tay nhỏ).
  final dir = (raw.last.dx - raw.first.dx).sign;
  if (dir == 0) return null;
  var back = 0.0;
  for (var i = 1; i < raw.length; i++) {
    final dx = (raw[i].dx - raw[i - 1].dx) * dir;
    if (dx < 0) back += -dx;
  }
  final span = (raw.last.dx - raw.first.dx).abs();
  if (back > 0.08 * span) return null;

  // Làm mượt rồi tìm cực trị.
  final pts = _smooth(raw, 3);
  final minY = pts.map((p) => p.dy).reduce(math.min), maxY = pts.map((p) => p.dy).reduce(math.max);
  final amp = (maxY - minY) / 2;
  if (amp < 8 || amp > span) return null;
  final extrema = <int>[];
  var trend = 0;
  for (var i = 1; i < pts.length; i++) {
    final d = pts[i].dy - pts[i - 1].dy;
    if (d.abs() < 0.5) continue;
    final t = d.sign.toInt();
    if (trend != 0 && t != trend) extrema.add(i - 1);
    trend = t;
  }
  // Bỏ cực trị nhỏ do rung tay.
  final big = <int>[];
  for (final i in extrema) {
    if (big.isEmpty || (pts[i].dy - pts[big.last].dy).abs() > amp * 0.8) big.add(i);
  }
  if (big.length < 2) return null;

  final xs = big.map((i) => pts[i].dx).toList();
  var halfPeriod = 0.0;
  for (var i = 1; i < xs.length; i++) {
    halfPeriod += (xs[i] - xs[i - 1]).abs();
  }
  halfPeriod /= xs.length - 1;
  final b = math.pi / halfPeriod;
  final d = (minY + maxY) / 2;
  final x0 = pts.first.dx;

  // Tìm pha tốt nhất bằng quét lưới. (Trên màn hình trục y hướng xuống.)
  var bestC = 0.0, bestErr = double.infinity;
  for (var k = 0; k < 72; k++) {
    final c = 2 * math.pi * k / 72;
    var e = 0.0;
    for (final p in pts) {
      final y = d - amp * math.sin(b * (p.dx - x0) + c);
      e += (y - p.dy) * (y - p.dy);
    }
    if (e < bestErr) {
      bestErr = e;
      bestC = c;
    }
  }
  final rmse = math.sqrt(bestErr / pts.length);
  if (rmse > 0.3 * amp) return null;

  final from = math.min(raw.first.dx, raw.last.dx), to = math.max(raw.first.dx, raw.last.dx);
  final n = math.max(40, (span / 3).round());
  final out = [
    for (var i = 0; i <= n; i++)
      () {
        final x = from + (to - from) * i / n;
        return Offset(x, d - amp * math.sin(b * (x - x0) + bestC));
      }(),
  ];
  final period = 2 * halfPeriod;
  return Recognized(ShapeKind.sine, out, 'Biên độ ≈ ${amp.toStringAsFixed(0)} px, chu kỳ ≈ ${period.toStringAsFixed(0)} px');
}

List<Offset> _smooth(List<Offset> p, int w) => [
      for (var i = 0; i < p.length; i++)
        () {
          var sx = 0.0, sy = 0.0, n = 0;
          for (var j = math.max(0, i - w); j <= math.min(p.length - 1, i + w); j++) {
            sx += p[j].dx;
            sy += p[j].dy;
            n++;
          }
          return Offset(sx / n, sy / n);
        }(),
    ];

/// Rút gọn nét về các điểm góc (dùng chung cho bộ nhận diện ký hiệu toán).
List<Offset> simplifyPath(List<Offset> pts, double eps) => _rdp(pts, eps);
