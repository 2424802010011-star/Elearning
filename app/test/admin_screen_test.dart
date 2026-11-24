import 'dart:convert';

import 'package:eduboard_app/api.dart';
import 'package:eduboard_app/app_state.dart';
import 'package:eduboard_app/models.dart';
import 'package:eduboard_app/screens/admin_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final calls = <String>[];
  var users = [
    {'id': 'a', 'email': 'admin@demo.vn', 'fullName': 'Quản trị', 'role': 'admin', 'active': true},
    {'id': 'h', 'email': 'hocsinh1@demo.vn', 'fullName': 'Nguyễn Văn An', 'role': 'student', 'active': true},
  ];

  Future<void> pump(WidgetTester t, Widget child) async {
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}${req.url.hasQuery ? '?${req.url.query}' : ''}${req.body.isEmpty ? '' : ' ${req.body}'}');
      if (req.method == 'PATCH' && req.url.path == '/api/users/h') {
        users = [users[0], {...users[1], ...jsonDecode(req.body) as Map<String, dynamic>}];
        return http.Response.bytes(utf8.encode(jsonEncode(users[1])), 200, headers: {'content-type': 'application/json'});
      }
      if (req.url.path == '/api/users') {
        final q = req.url.queryParameters['q'];
        final list = q == null ? users : users.where((u) => (u['email'] as String).contains(q)).toList();
        return http.Response.bytes(utf8.encode(jsonEncode(list)), 200);
      }
      return http.Response('[]', 200);
    });
    final state = AppState(api: ApiClient(baseUrl: 'http://x/api', token: 't', client: client))
      ..user = User(id: 'a', email: 'admin@demo.vn', fullName: 'Quản trị', role: Role.admin);
    await t.pumpWidget(AppScope(state: state, child: MaterialApp(home: Scaffold(body: child))));
    await t.pumpAndSettle();
  }

  testWidgets('danh sách người dùng, lọc và khóa tài khoản', (t) async {
    await pump(t, const UsersTab());
    expect(find.text('2 tài khoản'), findsOneWidget);
    expect(find.text('Quản trị (bạn)'), findsOneWidget);

    await t.tap(find.widgetWithText(ChoiceChip, 'Học sinh'));
    await t.pumpAndSettle();
    expect(calls.last, 'GET /api/users?role=student');

    await t.enterText(find.byType(TextField), 'hocsinh');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(calls.last, 'GET /api/users?role=student&q=hocsinh');

    await t.tap(find.byTooltip('Thao tác').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Khóa tài khoản'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Khóa'));
    await t.pumpAndSettle();
    expect(calls, contains('PATCH /api/users/h {"active":false}'));
    expect(find.text('Đã khóa'), findsOneWidget);
  });

  testWidgets('không có mục khóa cho chính mình', (t) async {
    await pump(t, const UsersTab());
    await t.tap(find.byTooltip('Thao tác').first);
    await t.pumpAndSettle();
    expect(find.text('Đặt lại mật khẩu'), findsOneWidget);
    expect(find.text('Khóa tài khoản'), findsNothing);
  });

  test('bỏ dấu tiếng Việt để tìm kiếm', () {
    expect(foldVi('Trần Bảo Châu'), 'tran bao chau');
    expect(foldVi('ĐẶNG Thị Ngọc'), 'dang thi ngoc');
  });
}
