import 'package:eduboard_app/ink/beautify.dart';
import 'package:eduboard_app/ink/whiteboard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late WhiteboardController b;
  late List<(List<String>, List<String>)> sent;

  setUp(() {
    b = WhiteboardController();
    sent = [];
    b.onPatch = (up, rm) => sent.add(([for (final s in up) s.id], rm));
  });

  void drawLine() {
    b.start(const Offset(10, 100));
    for (var x = 20.0; x <= 300; x += 10) {
      b.extend(Offset(x, 100));
    }
    b.end();
  }

  test('vẽ xong gửi nét đã nắn thẳng cho người khác', () {
    drawLine();
    expect(b.strokes.single.kind, ShapeKind.line);
    expect(sent.last.$1, [b.strokes.single.id]);
  });

  test('hoàn tác chỉ gỡ nét của mình và báo cho người khác', () {
    b.applyPatch([Stroke(id: 'ban-khac', points: const [Offset(1, 1), Offset(5, 5)], color: Colors.red, width: 2)], const []);
    drawLine();
    final mine = b.strokes.last.id;
    b.undo();
    expect(b.strokes.map((s) => s.id), ['ban-khac']);
    expect(sent.last.$2, [mine]);
  });

  test('tẩy rồi hoàn tác thì nét quay lại', () {
    drawLine();
    final id = b.strokes.single.id;
    b.setTool(BoardTool.eraser);
    b.start(const Offset(150, 101));
    expect(b.strokes, isEmpty);
    expect(sent.last.$2, [id]);
    b.undo();
    expect(b.strokes.single.id, id);
    expect(sent.last.$1, [id]);
  });

  test('chuyển nét sang JSON và ngược lại giữ nguyên dữ liệu', () {
    final s = Stroke(id: 'a', points: const [Offset(1.5, 2), Offset(3, 4)], color: const Color(0xFF1565C0), width: 4, kind: ShapeKind.circle);
    final back = Stroke.fromJson(s.toJson());
    expect(back.points, s.points);
    expect(back.color, s.color);
    expect(back.kind, ShapeKind.circle);
  });

  test('ảnh chụp bảng từ máy chủ thay toàn bộ bảng', () {
    drawLine();
    b.applySnapshot([Stroke(id: 'x', points: const [Offset(0, 0)], color: Colors.black, width: 3)]);
    expect(b.strokes.single.id, 'x');
    expect(b.canUndo, isFalse);
  });
}
