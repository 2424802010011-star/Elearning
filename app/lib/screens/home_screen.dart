import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import 'admin_screen.dart';
import 'classes_screen.dart';
import 'notifications_screen.dart';
import 'timetable_screen.dart';

/// Khung chính: thanh điều hướng dưới (điện thoại) hoặc bên trái (máy tính).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  /// Các mục điều hướng; admin có thêm mục Quản trị.
  List<(IconData, IconData, String, Widget Function())> _destinations(Role role) => [
        (Icons.class_outlined, Icons.class_, 'Lớp học', () => const ClassesScreen()),
        (Icons.calendar_month_outlined, Icons.calendar_month, 'Thời khóa biểu', () => const TimetableScreen()),
        (Icons.notifications_outlined, Icons.notifications, 'Thông báo', () => const NotificationsScreen()),
        if (role == Role.admin)
          (Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, 'Quản trị', () => const AdminScreen()),
        (Icons.person_outline, Icons.person, 'Tài khoản', () => const AccountScreen()),
      ];

  /// Biểu tượng chuông có số thông báo chưa đọc.
  Widget _icon(IconData i) {
    if (i != Icons.notifications_outlined && i != Icons.notifications) return Icon(i);
    return ValueListenableBuilder<int>(
      valueListenable: AppScope.of(context).unread,
      builder: (_, n, _) => Badge(isLabelVisible: n > 0, label: Text(n > 99 ? '99+' : '$n'), child: Icon(i)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final dest = _destinations(AppScope.of(context).user!.role);
    if (_tab >= dest.length) _tab = 0;
    final body = dest[_tab].$4();
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.draw_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
            ),
            destinations: [
              for (final d in dest) NavigationRailDestination(icon: _icon(d.$1), selectedIcon: _icon(d.$2), label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final d in dest)
            NavigationDestination(
              icon: _icon(d.$1),
              selectedIcon: _icon(d.$2),
              // Thanh dưới có 5 mục thì rút gọn để chữ không xuống dòng.
              label: dest.length > 4 && d.$3 == 'Thời khóa biểu' ? 'Lịch học' : d.$3,
              tooltip: d.$3,
            ),
        ],
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(children: [
        ListTile(
          leading: CircleAvatar(child: Text(u.fullName.characters.first)),
          title: Text(u.fullName),
          subtitle: Text('${u.email}\n${roleLabel(u.role)}'),
          isThreeLine: true,
        ),
        if (u.role == Role.parent) const _ChildrenTile(),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: const Text('Máy chủ'),
          subtitle: Text(app.api.baseUrl),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Đăng xuất'),
          onTap: app.logout,
        ),
      ]),
    );
  }
}

class _ChildrenTile extends StatefulWidget {
  const _ChildrenTile();
  @override
  State<_ChildrenTile> createState() => _ChildrenTileState();
}

class _ChildrenTileState extends State<_ChildrenTile> {
  Future<List<User>>? _f;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _f ??= AppScope.of(context).api.get('/me/children').then((l) => [for (final j in l) User.fromJson(j)]);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<User>>(
        future: _f,
        builder: (c, s) => ListTile(
          leading: const Icon(Icons.family_restroom),
          title: const Text('Con của bạn'),
          subtitle: Text(s.hasData ? (s.data!.isEmpty ? 'Chưa liên kết, liên hệ nhà trường' : s.data!.map((u) => u.fullName).join(', ')) : '...'),
        ),
      );
}
