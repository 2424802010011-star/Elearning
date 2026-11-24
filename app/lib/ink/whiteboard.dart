import 'package:material_ui/material_ui.dart';

import 'beautify.dart';

class Stroke {
  List<Offset> points;
  final Color color;
  final double width;
  ShapeKind kind;
  /// Nét gốc trước khi AI nắn lại, để hoàn tác.
  List<Offset>? original;
  Stroke({required this.points, required this.color, required this.width, this.kind = ShapeKind.none});
}

enum BoardTool { pen, eraser }

/// Bảng trắng vẽ tay. [enabled] = false thì chỉ xem.
class WhiteboardController extends ChangeNotifier {
  final List<Stroke> strokes = [];
  final List<List<Stroke>> _history = [];
  Stroke? _current;
  Color color = Colors.black;
  double width = 3;
  BoardTool tool = BoardTool.pen;
  bool aiEnabled = true;

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

  void _snapshot() {
    _history.add(List.of(strokes));
    if (_history.length > 50) _history.removeAt(0);
  }

  void start(Offset p) {
    if (tool == BoardTool.eraser) {
      eraseAt(p);
      return;
    }
    _current = Stroke(points: [p], color: color, width: width);
    strokes.add(_current!);
    notifyListeners();
  }

  void extend(Offset p) {
    if (tool == BoardTool.eraser) {
      eraseAt(p);
      return;
    }
    _current?.points.add(p);
    notifyListeners();
  }

  /// Kết thúc nét. Trả về nét vừa được AI nắn lại (nếu có).
  Stroke? end() {
    final s = _current;
    _current = null;
    if (s == null) return null;
    strokes.removeLast();
    _snapshot();
    strokes.add(s);
    if (aiEnabled) {
      final r = beautify(s.points);
      if (r.kind != ShapeKind.none) {
        s.original = s.points;
        s.points = r.points;
        s.kind = r.kind;
        notifyListeners();
        return s;
      }
    }
    notifyListeners();
    return null;
  }

  void revertToOriginal(Stroke s) {
    if (s.original == null) return;
    s.points = s.original!;
    s.original = null;
    s.kind = ShapeKind.none;
    notifyListeners();
  }

  void eraseAt(Offset p, {double radius = 12}) {
    final hit = strokes.where((s) => s.points.any((q) => (q - p).distance < radius + s.width)).toList();
    if (hit.isEmpty) return;
    _snapshot();
    strokes.removeWhere(hit.contains);
    notifyListeners();
  }

  bool get canUndo => _history.isNotEmpty;
  void undo() {
    if (_history.isEmpty) return;
    strokes
      ..clear()
      ..addAll(_history.removeLast());
    notifyListeners();
  }

  void clear() {
    if (strokes.isEmpty) return;
    _snapshot();
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
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: enabled ? (e) => controller.start(e.localPosition) : null,
      onPointerMove: enabled ? (e) => controller.extend(e.localPosition) : null,
      onPointerUp: enabled
          ? (_) {
              final s = controller.end();
              if (s != null) onBeautified?.call(s);
            }
          : null,
      child: ClipRect(
        child: CustomPaint(
          painter: _BoardPainter(controller),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final WhiteboardController c;
  _BoardPainter(this.c) : super(repaint: c);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    // Lưới chấm mờ giúp vẽ đồ thị, hình học.
    final dot = Paint()..color = const Color(0xFFDDE3EA);
    for (var x = 0.0; x < size.width; x += 24) {
      for (var y = 0.0; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), 0.9, dot);
      }
    }
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
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
