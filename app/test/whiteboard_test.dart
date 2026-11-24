import 'package:eduboard_app/ink/beautify.dart';
import 'package:eduboard_app/ink/whiteboard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fake_async/fake_async.dart';

import 'support/fake_hand.dart';

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

  group('AI chữ & toán', () {
    void write(List<List<Offset>> ink) {
      for (final st in ink) {
        b.start(st.first);
        for (final p in st.skip(1)) {
          b.extend(p);
        }
        b.end();
      }
    }

    test('đọc "x + 1", thay nét viết tay bằng nét gọn và báo cho người khác', () {
      final read = <String>[];
      b.onMathRecognized = read.add;
      b.setAiMode(AiMode.math);
      final h = FakeHand(3);
      write([
        ...h.write('x', at: const Offset(100, 100), height: 50),
        ...h.write('+', at: const Offset(170, 110), height: 30),
        ...h.write('1', at: const Offset(230, 98), height: 52),
      ]);
      final handIds = b.strokes.map((s) => s.id).toList();
      expect(handIds.length, 5);
      b.flushMath();
      expect(read, ['x + 1']);
      expect(b.strokes.map((s) => s.id).toSet().intersection(handIds.toSet()), isEmpty);
      expect(sent.last.$2.toSet(), handIds.toSet());

      // "Giữ nét gốc" trả lại đúng nét viết tay.
      b.revertLastMath();
      expect(b.strokes.map((s) => s.id).toList(), handIds);
    });

    test('tự đọc sau khi ngừng viết', () {
      fakeAsync((async) {
        final read = <String>[];
        b.onMathRecognized = read.add;
        b.setAiMode(AiMode.math);
        write(FakeHand(8).write('7', at: const Offset(50, 50), height: 60));
        async.elapse(const Duration(milliseconds: 400));
        expect(read, isEmpty);
        async.elapse(const Duration(seconds: 1));
        expect(read, ['7']);
      });
    });

    test('chế độ chữ không nắn số 0 thành hình tròn', () {
      b.setAiMode(AiMode.math);
      write(FakeHand(2).write('0', at: const Offset(50, 50), height: 60));
      expect(b.strokes.single.kind, ShapeKind.none);
    });
  });
}
