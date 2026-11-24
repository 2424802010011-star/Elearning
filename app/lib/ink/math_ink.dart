import 'dart:math' as math;
import 'dart:ui';

import 'beautify.dart';

/// Nhận diện chữ viết tay và ký hiệu toán trên bảng, rồi viết lại cho gọn.
///
/// Chạy hoàn toàn trên máy (không cần mạng), dùng được trên web, máy tính và điện thoại:
/// 1. Tách nét thành các ký hiệu, nhận ra gạch phân số và dấu căn.
/// 2. Mỗi ký hiệu được so với bộ mẫu bằng thuật toán đám mây điểm $P
///    (không phụ thuộc thứ tự và chiều viết nét).
/// 3. Dàn lại: chữ cùng dòng thẳng hàng và cùng cỡ, số mũ nhỏ và nâng lên,
///    tử và mẫu canh giữa gạch phân số, dấu căn phủ vừa biểu thức bên trong.
///
/// Ký hiệu nhận được: 0–9, x y z a b c e f n, + − = ( ) < >, ∫ π Σ ∞ θ, dấu chấm,
/// cùng cấu trúc phân số, căn bậc hai và số mũ.

typedef Pts = List<Offset>;

class MathInkResult {
  /// Các nét đã viết lại (thay cho toàn bộ nét đầu vào).
  final List<Pts> strokes;
  /// Biểu thức đọc được, ví dụ "x² + 1 = 0".
  final String text;
  /// Số ký hiệu nhận ra được.
  final int recognized;
  const MathInkResult(this.strokes, this.text, this.recognized);
}

// ======================= Bộ mẫu ký hiệu =======================

enum SymKind { ordinary, op, tall, dot }

class _Glyph {
  final String label;
  final SymKind kind;
  /// Mỗi biến thể là một cách viết (danh sách nét). Biến thể đầu là dáng chuẩn để vẽ lại.
  final List<List<Pts>> variants;
  const _Glyph(this.label, this.kind, this.variants);
}

Pts _l(double x1, double y1, double x2, double y2) => [Offset(x1, y1), Offset(x2, y2)];

Pts _a(double cx, double cy, double rx, double ry, double a0, double a1, {int n = 24}) => [
      for (var i = 0; i <= n; i++)
        Offset(cx + rx * math.cos((a0 + (a1 - a0) * i / n) * math.pi / 180),
            cy + ry * math.sin((a0 + (a1 - a0) * i / n) * math.pi / 180)),
    ];

Pts _q(double x0, double y0, double cx, double cy, double x1, double y1, {int n = 16}) => [
      for (var i = 0; i <= n; i++)
        Offset(
          math.pow(1 - i / n, 2) * x0 + 2 * (1 - i / n) * (i / n) * cx + math.pow(i / n, 2) * x1,
          math.pow(1 - i / n, 2) * y0 + 2 * (1 - i / n) * (i / n) * cy + math.pow(i / n, 2) * y1,
        ),
    ];

Pts _c(List<Pts> parts) {
  final out = <Offset>[];
  for (final p in parts) {
    for (final o in p) {
      if (out.isNotEmpty && (out.last - o).distance < 1e-6) continue;
      out.add(o);
    }
  }
  return out;
}

final List<_Glyph> _glyphs = [
  _Glyph('0', SymKind.ordinary, [
    [_a(.35, .5, .35, .5, -90, 270)],
    [_a(.35, .5, .35, .5, -60, 300)],
  ]),
  _Glyph('1', SymKind.ordinary, [
    [_c([_l(.05, .22, .3, 0), _l(.3, 0, .3, 1)])],
    [_l(.2, 0, .2, 1)],
    [_c([_l(.05, .22, .3, 0), _l(.3, 0, .3, 1)]), _l(.05, 1, .55, 1)],
  ]),
  _Glyph('2', SymKind.ordinary, [
    [_c([_a(.32, .3, .3, .28, 200, 400), _l(.55, .48, 0, 1), _l(0, 1, .7, 1)])],
    [_c([_a(.32, .28, .3, .26, 190, 390), _q(.6, .4, .3, .75, 0, 1), _l(0, 1, .7, 1)])],
  ]),
  _Glyph('3', SymKind.ordinary, [
    [_c([_a(.3, .25, .28, .24, 200, 450), _a(.3, .74, .32, .26, -90, 160)])],
    [_a(.3, .25, .28, .24, 200, 450), _a(.3, .74, .32, .26, -90, 160)],
  ]),
  _Glyph('4', SymKind.ordinary, [
    [_c([_l(.45, 0, 0, .68), _l(0, .68, .7, .68)]), _l(.5, .2, .5, 1)],
    [_c([_l(.05, 0, 0, .55), _l(0, .55, .65, .55)]), _l(.52, 0, .52, 1)],
    [_c([_l(.5, 1, .5, 0), _l(.5, 0, 0, .68), _l(0, .68, .7, .68)])],
  ]),
  _Glyph('5', SymKind.ordinary, [
    [_c([_l(.1, 0, .05, .45), _a(.3, .68, .32, .32, 225, 510)]), _l(.1, 0, .62, 0)],
    [_c([_l(.62, 0, .1, 0), _l(.1, 0, .05, .45), _a(.3, .68, .32, .32, 225, 510)])],
  ]),
  _Glyph('6', SymKind.ordinary, [
    [_c([_q(.58, 0, .02, .2, .04, .72), _a(.32, .72, .28, .28, 180, -180)])],
  ]),
  _Glyph('7', SymKind.ordinary, [
    [_c([_l(0, 0, .65, 0), _l(.65, 0, .2, 1)])],
    [_c([_l(0, 0, .65, 0), _l(.65, 0, .2, 1)]), _l(.15, .5, .6, .5)],
  ]),
  _Glyph('8', SymKind.ordinary, [
    [_c([_a(.32, .25, .25, .25, 90, 450), _a(.32, .75, .3, .25, -90, 270)])],
  ]),
  _Glyph('9', SymKind.ordinary, [
    [_c([_a(.3, .28, .28, .28, 0, -360), _l(.58, .28, .52, 1)])],
    [_a(.3, .28, .28, .28, 0, -360), _l(.58, .1, .52, 1)],
  ]),
  _Glyph('x', SymKind.ordinary, [
    [_l(0, 0, .8, 1), _l(.8, 0, 0, 1)],
    [_a(0, .5, .32, .5, -75, 75), _a(.7, .5, .32, .5, 105, 255)],
  ]),
  _Glyph('y', SymKind.ordinary, [
    [_l(0, 0, .38, .55), _l(.75, 0, .2, 1)],
    [_c([_l(0, 0, .38, .55), _l(.38, .55, .75, 0), _l(.75, 0, .25, 1)])],
    [_c([_q(0, 0, .05, .55, .35, .5), _l(.35, .5, .7, 0)]), _l(.7, 0, .3, 1)],
  ]),
  _Glyph('z', SymKind.ordinary, [
    [_c([_l(0, 0, .7, 0), _l(.7, 0, 0, 1), _l(0, 1, .75, 1)])],
  ]),
  _Glyph('a', SymKind.ordinary, [
    [_c([_a(.32, .55, .32, .45, 330, -30), _l(.6, .32, .64, .1), _l(.64, .1, .66, 1)])],
    [_a(.32, .55, .32, .45, 0, 360), _l(.66, .1, .68, 1)],
  ]),
  _Glyph('b', SymKind.ordinary, [
    [_c([_l(0, 0, 0, 1), _a(.28, .72, .28, .28, 180, -180)])],
    [_l(0, 0, 0, 1), _a(.28, .72, .28, .28, 180, -180)],
  ]),
  _Glyph('c', SymKind.ordinary, [
    [_a(.38, .5, .38, .5, -40, -320)],
  ]),
  _Glyph('e', SymKind.ordinary, [
    [_c([_l(.05, .5, .7, .5), _a(.38, .5, .33, .5, 0, -310)])],
  ]),
  _Glyph('f', SymKind.ordinary, [
    [_c([_q(.62, .05, .32, -.12, .3, .3), _l(.3, .3, .26, 1)]), _l(0, .42, .55, .42)],
  ]),
  _Glyph('n', SymKind.ordinary, [
    [_c([_l(0, 0, 0, 1), _l(0, 1, 0, .4), _a(.28, .4, .28, .4, 180, 360), _l(.56, .4, .56, 1)])],
  ]),
  _Glyph('+', SymKind.op, [
    [_l(.5, 0, .5, 1), _l(0, .5, 1, .5)],
  ]),
  _Glyph('-', SymKind.op, [
    [_l(0, .5, 1, .5)],
  ]),
  _Glyph('=', SymKind.op, [
    [_l(0, .3, 1, .3), _l(0, .7, 1, .7)],
  ]),
  _Glyph('<', SymKind.op, [
    [_c([_l(.65, 0, 0, .5), _l(0, .5, .65, 1)])],
  ]),
  _Glyph('>', SymKind.op, [
    [_c([_l(0, 0, .65, .5), _l(.65, .5, 0, 1)])],
  ]),
  _Glyph('∞', SymKind.op, [
    [_c([_a(.25, .25, .25, .25, 0, 360), _a(.75, .25, .25, .25, 180, -180)])],
  ]),
  _Glyph('(', SymKind.tall, [
    [_q(.35, 0, -.08, .5, .35, 1)],
  ]),
  _Glyph(')', SymKind.tall, [
    [_q(0, 0, .43, .5, 0, 1)],
  ]),
  _Glyph('∫', SymKind.tall, [
    [_c([_q(.55, .07, .46, -.04, .34, .08), _l(.34, .08, .22, .92), _q(.22, .92, .1, 1.04, 0, .93)])],
  ]),
  _Glyph('Σ', SymKind.tall, [
    [_c([_l(.8, 0, 0, 0), _l(0, 0, .45, .5), _l(.45, .5, 0, 1), _l(0, 1, .8, 1)])],
  ]),
  _Glyph('π', SymKind.ordinary, [
    [_l(0, .05, 1, 0), _l(.3, 0, .25, 1), _q(.7, 0, .68, .85, .9, 1)],
    [_c([_l(0, .05, 1, 0)]), _l(.3, 0, .3, 1), _l(.7, 0, .72, 1)],
  ]),
  _Glyph('θ', SymKind.ordinary, [
    [_a(.32, .5, .32, .5, -90, 270), _l(0, .5, .64, .5)],
  ]),
];

/// Bộ mẫu (để kiểm thử và xem trước).
Map<String, List<List<Pts>>> get glyphTemplates => {for (final g in _glyphs) g.label: g.variants};

String get supportedSymbols => _glyphs.map((g) => g.label).join(' ');

// ======================= Thuật toán $P =======================

const _n = 32;

class _Cloud {
  final _Glyph glyph;
  final int strokes;
  final double aspect;
  final List<Offset> pts;
  _Cloud(this.glyph, this.strokes, this.aspect, this.pts);
}

/// Tỉ lệ rộng/cao (log), chặn hai đầu để nét thẳng không thành vô cực.
double _aspect(List<Pts> strokes) {
  var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
  for (final s in strokes) {
    for (final p in s) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
  }
  final w = maxX - minX, h = maxY - minY, m = math.max(math.max(w, h), 1e-9);
  return math.log(math.max(w, 0.08 * m) / math.max(h, 0.08 * m));
}

final List<_Cloud> _templates = [
  for (final g in _glyphs)
    for (final v in g.variants) _Cloud(g, v.length, _aspect(v), _normalize(v)),
];

double _len(Pts p) {
  var s = 0.0;
  for (var i = 1; i < p.length; i++) {
    s += (p[i] - p[i - 1]).distance;
  }
  return s;
}

List<Offset> _resample(List<Pts> strokes) {
  final total = strokes.fold<double>(0, (s, p) => s + _len(p));
  final all = [for (final s in strokes) ...s];
  if (total < 1e-9 || all.isEmpty) return List.filled(_n, all.isEmpty ? Offset.zero : all.first);
  final step = total / (_n - 1);
  final out = <Offset>[strokes.first.first];
  var acc = 0.0;
  for (final s in strokes) {
    if (s.isEmpty) continue;
    var prev = s.first;
    for (var i = 1; i < s.length; i++) {
      var cur = s[i];
      var d = (cur - prev).distance;
      while (acc + d >= step && d > 0) {
        final t = (step - acc) / d;
        final q = prev + (cur - prev) * t;
        out.add(q);
        prev = q;
        d = (cur - prev).distance;
        acc = 0;
      }
      acc += d;
      prev = cur;
    }
  }
  while (out.length < _n) {
    out.add(strokes.last.last);
  }
  return out.sublist(0, _n);
}

List<Offset> _normalize(List<Pts> strokes) {
  final pts = _resample(strokes);
  var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
  for (final p in pts) {
    minX = math.min(minX, p.dx);
    minY = math.min(minY, p.dy);
    maxX = math.max(maxX, p.dx);
    maxY = math.max(maxY, p.dy);
  }
  final scale = math.max(math.max(maxX - minX, maxY - minY), 1e-9);
  var cx = 0.0, cy = 0.0;
  final scaled = [for (final p in pts) Offset((p.dx - minX) / scale, (p.dy - minY) / scale)];
  for (final p in scaled) {
    cx += p.dx;
    cy += p.dy;
  }
  cx /= scaled.length;
  cy /= scaled.length;
  return [for (final p in scaled) Offset(p.dx - cx, p.dy - cy)];
}

double _cloudDistance(List<Offset> a, List<Offset> b, int start) {
  final matched = List.filled(_n, false);
  var sum = 0.0;
  var i = start;
  do {
    var best = double.infinity;
    var idx = -1;
    for (var j = 0; j < _n; j++) {
      if (matched[j]) continue;
      final d = (a[i] - b[j]).distance;
      if (d < best) {
        best = d;
        idx = j;
      }
    }
    matched[idx] = true;
    final weight = 1 - ((i - start + _n) % _n) / _n;
    sum += weight * best;
    i = (i + 1) % _n;
  } while (i != start);
  return sum;
}

double _greedyMatch(List<Offset> a, List<Offset> b) {
  final step = math.sqrt(_n).floor();
  var best = double.infinity;
  for (var i = 0; i < _n; i += step) {
    best = math.min(best, math.min(_cloudDistance(a, b, i), _cloudDistance(b, a, i)));
  }
  return best;
}

/// Ngưỡng khoảng cách $P: lớn hơn thì coi như không nhận ra.
const double _maxDistance = 1.9;

/// Kết quả phân loại một nhóm nét: ký hiệu và khoảng cách (càng nhỏ càng giống).
({String label, double distance})? classifySymbol(List<Pts> strokes) {
  final r = _classify(strokes);
  return r == null ? null : (label: r.glyph.label, distance: r.distance);
}

({_Glyph glyph, double distance})? _classify(List<Pts> strokes) {
  final cloud = _normalize(strokes);
  final aspect = _aspect(strokes);
  _Glyph? best;
  var bestD = double.infinity;
  for (final t in _templates) {
    var d = _greedyMatch(cloud, t.pts);
    // Số nét khác mẫu thì phạt nhẹ (vẫn cho phép, vì mỗi người viết một kiểu).
    // Thiếu nét so với mẫu thì phạt nặng hơn thừa nét.
    if (t.strokes > strokes.length) d *= 1 + 0.3 * (t.strokes - strokes.length).clamp(0, 3);
    if (t.strokes < strokes.length) d *= 1 + 0.12 * (strokes.length - t.strokes).clamp(0, 3);
    // Dáng quá khác (ví dụ quá cao so với ∞) thì phạt.
    d *= 1 + 0.3 * math.max(0, (aspect - t.aspect).abs() - 0.45);
    if (d < bestD) {
      bestD = d;
      best = t.glyph;
    }
  }
  if (best == null || bestD > _maxDistance) return null;
  return (glyph: best, distance: bestD);
}

// ======================= Phân tích bố cục =======================

Rect _boxOf(Iterable<Pts> strokes) {
  var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
  for (final s in strokes) {
    for (final p in s) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
  }
  if (minX == double.infinity) return Rect.zero;
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

sealed class _Node {
  Rect get box;
}

class _Sym extends _Node {
  final _Glyph glyph;
  final List<Pts> raw;
  @override
  final Rect box;
  _Sym(this.glyph, this.raw) : box = _boxOf(raw);
}

class _Dot extends _Node {
  final List<Pts> raw;
  @override
  final Rect box;
  _Dot(this.raw) : box = _boxOf(raw);
}

class _Raw extends _Node {
  final List<Pts> raw;
  @override
  final Rect box;
  _Raw(this.raw) : box = _boxOf(raw);
}

class _Frac extends _Node {
  final Pts bar;
  final List<_Node> num, den;
  @override
  final Rect box;
  _Frac(this.bar, this.num, this.den, List<Pts> all) : box = _boxOf(all);
}

class _Sqrt extends _Node {
  final Pts sign;
  final List<_Node> body;
  @override
  final Rect box;
  _Sqrt(this.sign, this.body, List<Pts> all) : box = _boxOf(all);
}

bool _isHorizontalBar(Pts s) {
  final b = _boxOf([s]);
  if (b.width < 20) return false;
  if (b.height > math.max(8, 0.18 * b.width)) return false;
  return (s.first - s.last).distance > 0.8 * _len(s);
}

/// Dấu căn: đi xuống, vọt lên, rồi kéo ngang sang phải thành "mái".
({Offset roofStart, double roofY})? _radical(Pts s) {
  final b = _boxOf([s]);
  if (b.width < 25 || b.height < 20) return null;
  final v = simplifyPath(s, 0.07 * math.max(b.width, b.height));
  if (v.length < 4) return null;
  final end = v.last, roofStart = v[v.length - 2], bottom = v[v.length - 3];
  final roof = end - roofStart;
  if (roof.dx < 0.35 * b.width || roof.dy.abs() > 0.3 * roof.dx) return null;
  final up = roofStart - bottom;
  if (up.dy > -0.5 * b.height || up.dy.abs() < 0.9 * up.dx.abs()) return null;
  if (bottom.dy < b.top + 0.6 * b.height) return null;
  return (roofStart: roofStart, roofY: (roofStart.dy + end.dy) / 2);
}

const double _unknownCost = 3.0;

/// Chi phí cố định cho mỗi ký hiệu: ưu tiên gom nét (ví dụ hai gạch của "=" hay ba nét của π)
/// thay vì tách thành nhiều ký hiệu nhỏ.
const double _groupCost = 0.6;

/// Hai nét có thể thuộc cùng một ký hiệu: chồng nhau theo chiều ngang và gần nhau theo chiều dọc, hoặc chạm nhau.
bool _related(Pts a, Pts b) {
  final ab = _boxOf([a]), bb = _boxOf([b]);
  final aw = math.max(ab.width, 0.25 * ab.height), bw = math.max(bb.width, 0.25 * bb.height);
  final overlap = math.min(ab.right, bb.right) - math.max(ab.left, bb.left);
  final size = math.max(math.max(ab.width, ab.height), math.max(bb.width, bb.height));
  final gapY = math.max(ab.top, bb.top) - math.min(ab.bottom, bb.bottom);
  final near = gapY < 0.6 * math.max(size, 12);
  return (overlap > 0.35 * math.min(aw, bw) && near) || _touches([a], b, 0.12 * size);
}

/// Các nét có thể gom thành một ký hiệu: nối được với nhau qua quan hệ [_related].
bool _belongTogether(List<Pts> g) {
  final reached = {0};
  var grew = true;
  while (grew) {
    grew = false;
    for (var k = 0; k < g.length; k++) {
      if (reached.contains(k)) continue;
      if (reached.any((r) => _related(g[r], g[k]))) {
        reached.add(k);
        grew = true;
      }
    }
  }
  return reached.length == g.length;
}

/// Hai nét chạm nhau (khoảng cách gần nhất nhỏ hơn [tol]).
bool _touches(List<Pts> group, Pts s, double tol) {
  final t = math.max(tol, 3.0);
  final a = [for (final g in group) for (var i = 0; i < g.length; i += math.max(1, g.length ~/ 40)) g[i]];
  final step = math.max(1, s.length ~/ 40);
  for (var i = 0; i < s.length; i += step) {
    for (final p in a) {
      if ((p - s[i]).distance < t) return true;
    }
  }
  return false;
}

List<_Node> _parse(List<Pts> strokes) {
  final pool = List<Pts>.of(strokes);
  final nodes = <_Node>[];

  // 1. Gạch phân số: có nét ở trên và ở dưới, nằm trong bề ngang của gạch. Gạch dài xét trước.
  final bars = pool.where(_isHorizontalBar).toList()
    ..sort((a, b) => _boxOf([b]).width.compareTo(_boxOf([a]).width));
  for (final bar in bars) {
    if (!pool.contains(bar)) continue;
    final bb = _boxOf([bar]);
    final y = bb.center.dy;
    final reach = math.max(60.0, 0.8 * bb.width);
    bool inSpan(Rect r) => r.center.dx >= bb.left - 0.1 * bb.width && r.center.dx <= bb.right + 0.1 * bb.width;
    final above = <Pts>[], below = <Pts>[];
    for (final s in pool) {
      if (identical(s, bar)) continue;
      final r = _boxOf([s]);
      if (!inSpan(r)) continue;
      if (r.center.dy < y && r.bottom < y + 6 && y - r.bottom < reach) above.add(s);
      if (r.center.dy > y && r.top > y - 6 && r.top - y < reach) below.add(s);
    }
    if (above.isEmpty || below.isEmpty) continue;
    pool.removeWhere((s) => identical(s, bar) || above.contains(s) || below.contains(s));
    nodes.add(_Frac(bar, _parse(above), _parse(below), [bar, ...above, ...below]));
  }

  // 2. Dấu căn có biểu thức bên dưới mái.
  for (final s in List.of(pool)) {
    if (!pool.contains(s)) continue;
    final r = _radical(s);
    if (r == null) continue;
    final sb = _boxOf([s]);
    final inside = <Pts>[];
    for (final o in pool) {
      if (identical(o, s)) continue;
      final ob = _boxOf([o]);
      if (ob.center.dx > r.roofStart.dx - 0.05 * sb.width &&
          ob.center.dx < sb.right + 0.15 * sb.width &&
          ob.center.dy > r.roofY &&
          ob.center.dy < sb.bottom + 0.2 * sb.height) {
        inside.add(o);
      }
    }
    if (inside.isEmpty) continue;
    pool.removeWhere((o) => identical(o, s) || inside.contains(o));
    nodes.add(_Sqrt(s, _parse(inside), [s, ...inside]));
  }

  // 3. Tách các nét còn lại thành ký hiệu. Xét mọi cách gom tối đa 4 nét viết liền nhau
  //    (chỉ gom khi các nét chồng hoặc chạm nhau) và chọn cách có tổng độ "lạ" nhỏ nhất.
  final m = pool.length;
  final cost = List<double>.filled(m + 1, double.infinity)..[0] = 0;
  final from = List<int>.filled(m + 1, 0);
  final picked = List<_Node?>.filled(m + 1, null);
  for (var i = 1; i <= m; i++) {
    for (var j = i - 1; j >= math.max(0, i - 4); j--) {
      final g = pool.sublist(j, i);
      if (g.length > 1 && !_belongTogether(g)) continue;
      final gb = _boxOf(g);
      _Node node;
      double c;
      if (math.max(gb.width, gb.height) < 9) {
        node = _Dot(g);
        c = 0.5;
      } else {
        final r = _classify(g);
        node = r == null ? _Raw(g) : _Sym(r.glyph, g);
        c = r?.distance ?? _unknownCost;
      }
      c += _groupCost;
      if (cost[j] + c < cost[i]) {
        cost[i] = cost[j] + c;
        from[i] = j;
        picked[i] = node;
      }
    }
  }
  final found = <_Node>[];
  for (var i = m; i > 0; i = from[i]) {
    found.add(picked[i]!);
  }
  nodes.addAll(found.reversed);
  return nodes;
}

/// Chia các nút thành từng dòng theo chiều dọc. Ký hiệu lớn lập dòng trước,
/// ký hiệu nhỏ (số mũ, dấu chấm) gắn vào dòng gần nhất.
List<List<_Node>> _rows(List<_Node> nodes) {
  final sorted = List.of(nodes)..sort((a, b) => b.box.height.compareTo(a.box.height));
  final rows = <({List<_Node> items, double top, double bottom})>[];
  for (final n in sorted) {
    final h = math.max(n.box.height, 10);
    var best = -1;
    var bestScore = -double.infinity;
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final rh = r.bottom - r.top;
      final ov = math.min(r.bottom, n.box.bottom) - math.max(r.top, n.box.top);
      final small = n.box.height < 0.8 * rh || n is _Dot;
      final ok = ov > 0.25 * h || (small && n.box.bottom > r.top - 0.45 * rh && n.box.top < r.bottom + 0.45 * rh);
      if (ok && ov > bestScore) {
        best = i;
        bestScore = ov;
      }
    }
    if (best < 0) {
      rows.add((items: [n], top: n.box.top, bottom: n.box.bottom));
    } else {
      final r = rows[best];
      r.items.add(n);
      // Chỉ ký hiệu cỡ thường mới nới rộng dòng, để số mũ không kéo dòng lên mãi.
      if (n.box.height >= 0.8 * (r.bottom - r.top)) {
        rows[best] = (items: r.items, top: math.min(r.top, n.box.top), bottom: math.max(r.bottom, n.box.bottom));
      }
    }
  }
  return [for (final r in rows) r.items];
}

// ======================= Dàn trang và vẽ lại =======================

class _Out {
  final List<Pts> strokes;
  Rect box;
  final String text;
  final bool superscript;
  _Out(this.strokes, this.box, this.text, {this.superscript = false});

  void shift(Offset d) {
    for (var i = 0; i < strokes.length; i++) {
      strokes[i] = [for (final p in strokes[i]) p + d];
    }
    box = box.shift(d);
  }
}

double _median(List<double> v) {
  final s = List.of(v)..sort();
  return s.isEmpty ? 0 : s[s.length ~/ 2];
}

Rect _glyphBox(_Glyph g) => _boxOf(g.variants.first);

/// Đặt dáng chuẩn của ký hiệu vào vị trí: canh giữa theo [cx], đáy tại [bottom] hoặc tâm tại [cy].
_Out _place(_Glyph g, {required double cx, double? bottom, double? cy, double? height, double? width}) {
  final gb = _glyphBox(g);
  double s;
  if (width != null || gb.height < 1e-6) {
    s = (width ?? height!) / math.max(gb.width, 1e-6);
  } else {
    s = height! / gb.height;
  }
  final w = gb.width * s, h = gb.height * s;
  final x0 = cx - w / 2;
  final y0 = bottom != null ? bottom - h : (cy ?? 0) - h / 2;
  final strokes = [
    for (final st in g.variants.first) [for (final p in st) Offset(x0 + (p.dx - gb.left) * s, y0 + (p.dy - gb.top) * s)],
  ];
  return _Out(strokes, Rect.fromLTWH(x0, y0, w, h), g.label);
}

const _spaced = {'+', '-', '=', '<', '>'};
const _sup = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾', 'n': 'ⁿ', 'x': 'ˣ', 'y': 'ʸ',
};

String _wrap(String t) => t.length <= 1 ? t : '($t)';

class _Counter {
  int n = 0;
}

_Out _layoutRow(List<_Node> nodes, _Counter count) {
  final items = List.of(nodes)..sort((a, b) => a.box.center.dx.compareTo(b.box.center.dx));
  final ordinary = [for (final n in items) if (n is _Sym && n.glyph.kind == SymKind.ordinary) n];
  double? h, base;
  if (ordinary.isNotEmpty) {
    // Ký hiệu nhỏ hẳn (số mũ) không được tính vào cỡ chữ của dòng.
    final big = _median([for (final n in ordinary) n.box.height]);
    final main = [for (final n in ordinary) if (n.box.height > 0.7 * big) n];
    h = math.max(_median([for (final n in main) n.box.height]), 12);
    base = _median([for (final n in main) n.box.bottom]);
  }
  final outs = <_Out>[];
  _Node? prev;
  for (final n in items) {
    final r = n.box;
    _Out o;
    switch (n) {
      case _Sym(:final glyph):
        count.n++;
        if (h == null || base == null) {
          o = _place(glyph, cx: r.center.dx, cy: r.center.dy, height: math.max(r.height, 1), width: glyph.kind == SymKind.op && _glyphBox(glyph).width > 1.3 * _glyphBox(glyph).height ? r.width : null);
          break;
        }
        final axis = base - h / 2;
        switch (glyph.kind) {
          case SymKind.ordinary:
            final isSup = prev != null && r.bottom < base - 0.4 * h && r.height < 0.85 * h;
            if (isSup) {
              o = _place(glyph, cx: r.center.dx, bottom: base - 0.42 * h, height: 0.6 * h);
              o = _Out(o.strokes, o.box, o.text, superscript: true);
            } else {
              o = _place(glyph, cx: r.center.dx, bottom: base, height: h * (glyph.label == '∞' ? 0.5 : 1));
            }
          case SymKind.op:
            final gb = _glyphBox(glyph);
            if (gb.width > 1.3 * gb.height || gb.height < 1e-6) {
              o = _place(glyph, cx: r.center.dx, cy: axis, width: r.width.clamp(0.5 * h, 1.4 * h));
            } else {
              o = _place(glyph, cx: r.center.dx, cy: axis, height: r.height.clamp(0.5 * h, 0.9 * h));
            }
          case SymKind.tall:
            o = _place(glyph, cx: r.center.dx, cy: axis, height: math.max(r.height, 1.15 * h));
          case SymKind.dot:
            o = _Out([[r.center]], Rect.fromCenter(center: r.center, width: 1, height: 1), '.');
        }
      case _Dot(:final raw):
        final c = Offset(r.center.dx, base ?? r.center.dy);
        o = _Out([[c]], Rect.fromCenter(center: c, width: 2, height: 2), raw.isEmpty ? '' : '.');
      case _Raw(:final raw):
        o = _Out([for (final s in raw) List.of(s)], r, '?');
      case _Frac(:final bar, :final num, :final den):
        count.n++;
        final top = _layoutRow(num, count), bottom = _layoutRow(den, count);
        final unit = h ?? math.max(math.max(top.box.height, bottom.box.height), 12);
        final barY = h != null && base != null ? base - h / 2 : _boxOf([bar]).center.dy;
        final cx = _boxOf([bar]).center.dx;
        final gap = 0.2 * unit;
        top.shift(Offset(cx - top.box.center.dx, barY - gap - top.box.bottom));
        bottom.shift(Offset(cx - bottom.box.center.dx, barY + gap - bottom.box.top));
        final half = math.max(top.box.width, bottom.box.width) / 2 + 0.2 * unit;
        final line = [Offset(cx - half, barY), Offset(cx + half, barY)];
        o = _Out([line, ...top.strokes, ...bottom.strokes], top.box.expandToInclude(bottom.box).expandToInclude(Rect.fromPoints(line.first, line.last)),
            '${_wrap(top.text)}/${_wrap(bottom.text)}');
      case _Sqrt(:final body):
        count.n++;
        final inner = _layoutRow(body, count);
        final b = inner.box;
        final ih = math.max(b.height, 12);
        final left = b.left - 0.55 * ih;
        final roofY = b.top - 0.18 * ih;
        final sign = [
          Offset(left, b.bottom - 0.4 * ih),
          Offset(left + 0.14 * ih, b.bottom - 0.5 * ih),
          Offset(left + 0.32 * ih, b.bottom + 0.1 * ih),
          Offset(b.left - 0.1 * ih, roofY),
          Offset(b.right + 0.12 * ih, roofY),
        ];
        o = _Out([sign, ...inner.strokes], b.expandToInclude(_boxOf([sign])), '√${_wrap(inner.text)}');
    }
    outs.add(o);
    prev = n;
  }

  // Dời ngang nếu sau khi chỉnh cỡ các ký hiệu bị đè lên nhau.
  final gap = 0.12 * (h ?? 12);
  for (var i = 1; i < outs.length; i++) {
    final need = outs[i - 1].box.right + (outs[i].superscript ? 0.03 * (h ?? 12) : gap) - outs[i].box.left;
    if (need > 0 && outs[i - 1].box.right > outs[i].box.left - gap) {
      for (var j = i; j < outs.length; j++) {
        outs[j].shift(Offset(need, 0));
      }
    }
  }

  final buf = StringBuffer();
  for (var i = 0; i < outs.length; i++) {
    final o = outs[i];
    if (o.superscript) {
      final chars = o.text.split('');
      buf.write(chars.every(_sup.containsKey) ? chars.map((c) => _sup[c]).join() : '^${_wrap(o.text)}');
    } else if (_spaced.contains(o.text)) {
      buf.write(i == 0 && o.text == '-' ? '−' : ' ${o.text == '-' ? '−' : o.text} ');
    } else {
      buf.write(o.text);
    }
  }
  final text = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  final all = [for (final o in outs) ...o.strokes];
  return _Out(all, outs.isEmpty ? Rect.zero : outs.map((o) => o.box).reduce((a, b) => a.expandToInclude(b)), text);
}

/// Nhận diện một cụm nét viết tay (theo đúng thứ tự viết) và trả về bản viết lại gọn gàng.
MathInkResult recognizeMath(List<Pts> strokes) {
  final clean = [for (final s in strokes) if (s.isNotEmpty) s];
  if (clean.isEmpty) return const MathInkResult([], '', 0);
  final nodes = _parse(clean);
  final count = _Counter();
  final rows = _rows(nodes)..sort((a, b) => _boxOf([for (final n in a) ...n.box.toPts()]).top.compareTo(_boxOf([for (final n in b) ...n.box.toPts()]).top));
  final out = <Pts>[];
  final texts = <String>[];
  for (final r in rows) {
    final o = _layoutRow(r, count);
    out.addAll(o.strokes);
    if (o.text.isNotEmpty) texts.add(o.text);
  }
  return MathInkResult(out, texts.join('; '), count.n);
}

extension on Rect {
  List<Pts> toPts() => [
        [topLeft, bottomRight],
      ];
}
