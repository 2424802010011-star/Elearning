import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'beautify.dart';

/// Chiều ngang bảng tính theo "đơn vị bảng". Mọi thiết bị dùng chung hệ toạ độ này
/// nên nét vẽ hiện đúng vị trí dù màn hình to nhỏ khác nhau.
const double kBoardWidth = 1000;

class Stroke {
  final String id;
  List<Offset> points;
  final Color color;
  final double width;
  ShapeKind kind;
  /// Nét gốc trước khi AI nắn lại, để hoàn tác.
  List<Offset>? original;
  Stroke({required this.id, required this.points, required this.color, required this.width, this.kind = ShapeKind.none});

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': [for (final p in points) ...[p.dx, p.dy]],
        'color': color.toARGB32(),
        'width': width,
        'kind': kind.name,
      };

  factory Stroke.fromJson(Map<String, dynamic> j) {
    final raw = (j['points'] as List).map((n) => (n as num).toDouble()).toList();
    return Stroke(
      id: j['id'],
      points: [for (var i = 0; i + 1 < raw.length; i += 2) Offset(raw[i], raw[i + 1])],
      color: Color(j['color'] ?? 0xFF000000),
      width: (j['width'] as num?)?.toDouble() ?? 3,
      kind: ShapeKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => ShapeKind.none),
    );
  }
}

enum BoardTool { pen, eraser }

/// Thao tác của chính mình, dùng cho hoàn tác (không đụng nét của người khác).
sealed class _Action {}

class _Added extends _Action {
  final Stroke stroke;
  _Added(this.stroke);
}

class _Removed extends _Action {
  final List<Stroke> strokes;
  _Removed(this.strokes);
}

typedef PatchSender = void Function(List<Stroke> upserts, List<String> removed);

class WhiteboardController extends ChangeNotifier {
  final List<Stroke> strokes = [];
  final List<_Action> _undo = [];
  Stroke? _current;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  Color color = Colors.black;
  double width = 3;
  BoardTool tool = BoardTool.pen;
  bool aiEnabled = true;

  /// Gửi thay đổi của mình cho người khác (gắn bởi lớp đồng bộ).
  PatchSender? onPatch;
  /// Giáo viên xóa bảng.
  VoidCallback? onClear;

  final _rnd = math.Random();
  String _newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 30).toRadixString(36)}';

  void setTool(BoardTool t) {
    tool = t;
    notifyListeners();
  }

  void setColor(Color c) {
    color = c;
    tool = BoardTool.pen;
    notifyListeners();
  }

  void setWidth(double w) {
    width = w;
    notifyListeners();
  }

  void setAi(bool v) {
    aiEnabled = v;
    notifyListeners();
  }

  // ---------- thao tác của mình ----------
  void start(Offset p) {
    if (tool == BoardTool.eraser) return eraseAt(p);
    _current = Stroke(id: _newId(), points: [p], color: color, width: width);
    strokes.add(_current!);
    notifyListeners();
  }

  void extend(Offset p) {
    if (tool == BoardTool.eraser) return eraseAt(p);
    final s = _current;
    if (s == null) return;
    s.points.add(p);
    // Gửi dần khi đang vẽ (~12 lần/giây) để người khác thấy nét chạy theo tay.
    final now = DateTime.now();
    if (now.difference(_lastSent).inMilliseconds > 80) {
      _lastSent = now;
      onPatch?.call([s], const []);
    }
    notifyListeners();
  }

  /// Kết thúc nét. Trả về nét vừa được AI nắn lại (nếu có).
  Stroke? end() {
    final s = _current;
    _current = null;
    if (s == null) return null;
    _undo.add(_Added(s));
    Stroke? beautified;
    if (aiEnabled) {
      final r = beautify(s.points);
      if (r.kind != ShapeKind.none) {
        s.original = s.points;
        s.points = r.points;
        s.kind = r.kind;
        beautified = s;
      }
    }
    onPatch?.call([s], const []);
    notifyListeners();
    return beautified;
  }

  void revertToOriginal(Stroke s) {
    if (s.original == null) return;
    s.points = s.original!;
    s.original = null;
    s.kind = ShapeKind.none;
    onPatch?.call([s], const []);
    notifyListeners();
  }

  void eraseAt(Offset p, {double radius = 10}) {
    final hit = strokes.where((s) => _near(s, p, radius + s.width)).toList();
    if (hit.isEmpty) return;
    strokes.removeWhere(hit.contains);
    _undo.add(_Removed(hit));
    onPatch?.call(const [], [for (final s in hit) s.id]);
    notifyListeners();
  }

  bool _near(Stroke s, Offset p, double r) {
    if (s.points.length == 1) return (s.points.first - p).distance < r;
    for (var i = 1; i < s.points.length; i++) {
      if (_segDist(p, s.points[i - 1], s.points[i]) < r) return true;
    }
    return false;
  }

  double _segDist(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  bool get canUndo => _undo.isNotEmpty;

  void undo() {
    if (_undo.isEmpty) return;
    switch (_undo.removeLast()) {
      case _Added(:final stroke):
        strokes.removeWhere((s) => s.id == stroke.id);
        onPatch?.call(const [], [stroke.id]);
      case _Removed(strokes: final removed):
        strokes.addAll(removed);
        onPatch?.call(removed, const []);
    }
    notifyListeners();
  }

  void clear() {
    if (strokes.isEmpty) return;
    _undo.add(_Removed(List.of(strokes)));
    strokes.clear();
    onClear?.call();
    notifyListeners();
  }

  // ---------- thay đổi từ người khác ----------
  void applySnapshot(List<Stroke> all) {
    strokes
      ..clear()
      ..addAll(all);
    _undo.clear();
    notifyListeners();
  }

  void applyPatch(List<Stroke> upserts, List<String> removed) {
    for (final u in upserts) {
      final i = strokes.indexWhere((s) => s.id == u.id);
      if (i >= 0) {
        strokes[i] = u;
      } else {
        strokes.add(u);
      }
    }
    if (removed.isNotEmpty) strokes.removeWhere((s) => removed.contains(s.id));
    notifyListeners();
  }

  void applyClear() {
    strokes.clear();
    notifyListeners();
  }
}

class WhiteboardCanvas extends StatelessWidget {
  final WhiteboardController controller;
  final bool enabled;
  final void Function(Stroke beautified)? onBeautified;
  const WhiteboardCanvas({super.key, required this.controller, required this.enabled, this.onBeautified});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final scale = box.maxWidth / kBoardWidth;
      Offset toBoard(Offset local) => local / scale;
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: enabled ? (e) => controller.start(toBoard(e.localPosition)) : null,
        onPointerMove: enabled ? (e) => controller.extend(toBoard(e.localPosition)) : null,
        onPointerUp: enabled
            ? (_) {
                final s = controller.end();
                if (s != null) onBeautified?.call(s);
              }
            : null,
        child: ClipRect(
          child: CustomPaint(painter: _BoardPainter(controller, scale), size: Size.infinite),
        ),
      );
    });
  }
}

class _BoardPainter extends CustomPainter {
  final WhiteboardController c;
  final double scale;
  _BoardPainter(this.c, this.scale) : super(repaint: c);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    // Lưới chấm mờ giúp vẽ đồ thị, hình học.
    final dot = Paint()..color = const Color(0xFFDDE3EA);
    final step = 24 * scale;
    for (var x = 0.0; x < size.width; x += step) {
      for (var y = 0.0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.9, dot);
      }
    }
    canvas.save();
    canvas.scale(scale);
    for (final s in c.strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (s.points.length == 1) {
        canvas.drawCircle(s.points.first, s.width / 2, paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (final p in s.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
