import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';

/// Trang quản trị: số liệu tổng quan, quản lý tài khoản, liên kết phụ huynh với học sinh.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Quản trị'),
            bottom: const TabBar(tabs: [
              Tab(icon: Icon(Icons.insights_outlined), text: 'Tổng quan'),
              Tab(icon: Icon(Icons.people_outline), text: 'Người dùng'),
              Tab(icon: Icon(Icons.family_restroom), text: 'Phụ huynh – học sinh'),
            ]),
          ),
          body: const TabBarView(children: [StatsTab(), UsersTab(), ParentLinksTab()]),
        ),
      );
}

// ---------------------------------------------------------------- Tổng quan

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  late Future<Map<String, dynamic>> _f;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  void _reload() {
    final f = AppScope.of(context).api.get('/admin/stats').then((j) => j as Map<String, dynamic>);
    setState(() {
      _f = f;
    });
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async => _reload(),
        child: AsyncView<Map<String, dynamic>>(
          future: _f,
          onRetry: _reload,
          builder: (s) {
            final u = s['users'] as Map<String, dynamic>;
            final cards = [
              (Icons.people, 'Tài khoản', '${u['total']}', '${u['locked']} bị khóa'),
              (Icons.school_outlined, 'Giáo viên', '${u['teacher']}', ''),
              (Icons.backpack_outlined, 'Học sinh', '${u['student']}', ''),
              (Icons.family_restroom, 'Phụ huynh', '${u['parent']}', ''),
              (Icons.class_outlined, 'Lớp học', '${s['classes']}', '${s['pendingEnrollments']} yêu cầu chờ duyệt'),
              (Icons.videocam_outlined, 'Buổi học trực tuyến', '${s['meetings']['total']}', '${s['meetings']['live']} đang diễn ra'),
              (Icons.assignment_outlined, 'Bài tập', '${s['assignments']['total']}', '${s['assignments']['submissions']} bài nộp'),
              (Icons.quiz_outlined, 'Bài kiểm tra', '${s['quizzes']['total']}', '${s['quizzes']['attempts']} lượt làm'),
              (Icons.menu_book_outlined, 'Bài giảng', '${s['lessons']}', ''),
              (Icons.folder_outlined, 'File đã tải lên', '${s['files']['count']}', fmtSize((s['files']['bytes'] as num).toInt())),
            ];
            return LayoutBuilder(builder: (c, box) {
              final cols = max(2, (box.maxWidth / 260).floor());
              return GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: box.maxWidth / cols / 120,
                children: [for (final x in cards) _StatCard(icon: x.$1, label: x.$2, value: x.$3, note: x.$4)],
              );
            });
          },
        ),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value, note;
  const _StatCard({required this.icon, required this.label, required this.value, required this.note});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: t.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: t.textTheme.labelLarge, overflow: TextOverflow.ellipsis)),
          ]),
          const Spacer(),
          Text(value, style: t.textTheme.headlineMedium),
          if (note.isNotEmpty) Text(note, style: t.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- Người dùng

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});
  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final _q = TextEditingController();
  Role? _role;
  Timer? _debounce;
  late Future<List<User>> _f;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _reload() {
    final params = {if (_role != null) 'role': _role!.name, if (_q.text.trim().isNotEmpty) 'q': _q.text.trim()};
    final qs = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final f = AppScope.of(context).api.get('/users$qs').then((l) => [for (final j in l) User.fromJson(j)]);
    setState(() {
      _f = f;
    });
  }

  Future<void> _create() async {
    final r = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _UserDialog());
    if (r == null || !mounted) return;
    final ok = await runGuarded(context, () => AppScope.of(context).api.post('/users', r), success: 'Đã tạo tài khoản ${r['email']}');
    if (ok) _reload();
  }

  Future<void> _edit(User u) async {
    final r = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _UserDialog(user: u));
    if (r == null || !mounted) return;
    final ok = await runGuarded(context, () => AppScope.of(context).api.patch('/users/${u.id}', r), success: 'Đã lưu');
    if (ok) _reload();
  }

  Future<void> _toggleLock(User u) async {
    if (u.active) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Khóa tài khoản ${u.fullName}?'),
          content: const Text('Người này sẽ bị đăng xuất và không đăng nhập được cho tới khi được mở khóa. Dữ liệu vẫn được giữ nguyên.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Khóa')),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    final ok = await runGuarded(context, () => AppScope.of(context).api.patch('/users/${u.id}', {'active': !u.active}),
        success: u.active ? 'Đã khóa ${u.fullName}' : 'Đã mở khóa ${u.fullName}');
    if (ok) _reload();
  }

  Future<void> _resetPassword(User u) async {
    final pw = TextEditingController(text: _randomPassword());
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Đặt lại mật khẩu cho ${u.fullName}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: pw, decoration: const InputDecoration(labelText: 'Mật khẩu mới (tối thiểu 8 ký tự)')),
          const SizedBox(height: 8),
          const Text('Ghi lại mật khẩu này và gửi cho người dùng.'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đặt lại')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await runGuarded(context, () => AppScope.of(context).api.post('/users/${u.id}/password', {'password': pw.text}),
        success: 'Đã đặt mật khẩu mới cho ${u.email}');
  }

  @override
  Widget build(BuildContext context) {
    final me = AppScope.of(context).user!;
    return Scaffold(
      floatingActionButton:
          FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.person_add), label: const Text('Thêm tài khoản')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _q,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm theo tên hoặc email (gõ không dấu cũng được)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _reload);
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            for (final r in [null, Role.teacher, Role.student, Role.parent, Role.admin])
              Padding(
                padding: const EdgeInsets.all(4),
                child: ChoiceChip(
                  label: Text(r == null ? 'Tất cả' : roleLabel(r)),
                  selected: _role == r,
                  onSelected: (_) {
                    _role = r;
                    _reload();
                  },
                ),
              ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: AsyncView<List<User>>(
            future: _f,
            onRetry: _reload,
            builder: (users) {
              if (users.isEmpty) return const EmptyState(icon: Icons.person_search, text: 'Không tìm thấy tài khoản nào');
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: users.length + 1,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text('${users.length} tài khoản', style: Theme.of(c).textTheme.labelMedium),
                    );
                  }
                  final u = users[i - 1];
                  final self = u.id == me.id;
                  return ListTile(
                    leading: CircleAvatar(child: Text(u.fullName.characters.first)),
                    title: Row(children: [
                      Flexible(child: Text(u.fullName + (self ? ' (bạn)' : ''), overflow: TextOverflow.ellipsis)),
                      if (!u.active) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: const Text('Đã khóa'),
                          avatar: const Icon(Icons.lock, size: 16),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Theme.of(c).colorScheme.errorContainer,
                        ),
                      ],
                    ]),
                    subtitle: Text('${u.email} · ${roleLabel(u.role)}'),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Thao tác',
                      onSelected: (a) => switch (a) {
                        'edit' => _edit(u),
                        'lock' => _toggleLock(u),
                        _ => _resetPassword(u),
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Sửa tên / vai trò'))),
                        const PopupMenuItem(value: 'pw', child: ListTile(leading: Icon(Icons.password), title: Text('Đặt lại mật khẩu'))),
                        if (!self)
                          PopupMenuItem(
                            value: 'lock',
                            child: ListTile(
                              leading: Icon(u.active ? Icons.lock_outline : Icons.lock_open),
                              title: Text(u.active ? 'Khóa tài khoản' : 'Mở khóa'),
                            ),
                          ),
                      ],
                    ),
                    onTap: () => _edit(u),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

const _viFrom = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _viTo = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Bỏ dấu tiếng Việt và chuyển chữ thường, để tìm kiếm không cần gõ dấu.
String foldVi(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = _viFrom.indexOf(ch);
    b.write(i < 0 ? ch : _viTo[i]);
  }
  return b.toString();
}

String _randomPassword() {
  const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
  final r = Random.secure();
  return List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Hộp thoại thêm tài khoản (user == null) hoặc sửa tên / vai trò.
class _UserDialog extends StatefulWidget {
  final User? user;
  const _UserDialog({this.user});
  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  late final _name = TextEditingController(text: widget.user?.fullName);
  final _email = TextEditingController();
  final _pw = TextEditingController(text: _randomPassword());
  late Role _role = widget.user?.role ?? Role.student;

  @override
  Widget build(BuildContext context) {
    final editing = widget.user != null;
    final self = editing && widget.user!.id == AppScope.of(context).user!.id;
    return AlertDialog(
      title: Text(editing ? 'Sửa tài khoản' : 'Thêm tài khoản'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: 'Họ và tên')),
          if (editing)
            ListTile(contentPadding: EdgeInsets.zero, title: const Text('Email'), subtitle: Text(widget.user!.email))
          else ...[
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _pw, decoration: const InputDecoration(labelText: 'Mật khẩu ban đầu (tối thiểu 8 ký tự)')),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<Role>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Vai trò', border: OutlineInputBorder()),
            items: [for (final r in Role.values) DropdownMenuItem(value: r, child: Text(roleLabel(r)))],
            onChanged: self ? null : (r) => setState(() => _role = r!),
          ),
          if (editing && _role != widget.user!.role && (widget.user!.role == Role.parent || widget.user!.role == Role.student))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Đổi vai trò sẽ gỡ các liên kết phụ huynh – học sinh của tài khoản này.'),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'fullName': _name.text.trim(),
            if (!editing) 'email': _email.text.trim(),
            if (!editing) 'password': _pw.text,
            if (!self) 'role': _role.name,
          }),
          child: Text(editing ? 'Lưu' : 'Tạo'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Phụ huynh – học sinh

class _Link {
  final String id;
  final User parent, student;
  _Link.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        parent = User.fromJson(j['parent']),
        student = User.fromJson(j['student']);
}

class ParentLinksTab extends StatefulWidget {
  const ParentLinksTab({super.key});
  @override
  State<ParentLinksTab> createState() => _ParentLinksTabState();
}

class _ParentLinksTabState extends State<ParentLinksTab> {
  late Future<List<_Link>> _f;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  void _reload() {
    final f = AppScope.of(context).api.get('/parent-links').then((l) => [for (final j in l) _Link.fromJson(j)]);
    setState(() {
      _f = f;
    });
  }

  Future<void> _add() async {
    final api = AppScope.of(context).api;
    List<User> parents, students;
    try {
      final r = await Future.wait([api.get('/users?role=parent'), api.get('/users?role=student')]);
      parents = [for (final j in r[0]) User.fromJson(j)];
      students = [for (final j in r[1]) User.fromJson(j)];
    } catch (e) {
      if (mounted) showMsg(context, e, error: true);
      return;
    }
    if (!mounted) return;
    final pick = await showDialog<(String, String)>(context: context, builder: (_) => _LinkDialog(parents: parents, students: students));
    if (pick == null || !mounted) return;
    final ok = await runGuarded(context, () => api.post('/parent-links', {'parentId': pick.$1, 'studentId': pick.$2}), success: 'Đã liên kết');
    if (ok) _reload();
  }

  Future<void> _remove(_Link l) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Gỡ liên kết?'),
        content: Text('${l.parent.fullName} sẽ không còn xem được lớp học, bài tập và điểm của ${l.student.fullName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Gỡ')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final ok = await runGuarded(context, () => AppScope.of(context).api.delete('/parent-links/${l.id}'), success: 'Đã gỡ liên kết');
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton:
            FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.link), label: const Text('Liên kết phụ huynh')),
        body: AsyncView<List<_Link>>(
          future: _f,
          onRetry: _reload,
          builder: (links) {
            if (links.isEmpty) {
              return const EmptyState(
                icon: Icons.family_restroom,
                text: 'Chưa có liên kết nào. Liên kết phụ huynh với học sinh để phụ huynh xem được lớp, bài tập và điểm của con.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: links.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (c, i) {
                final l = links[i];
                return ListTile(
                  leading: const Icon(Icons.family_restroom),
                  title: Text('${l.parent.fullName}  →  ${l.student.fullName}'),
                  subtitle: Text('${l.parent.email} · con: ${l.student.email}'),
                  trailing: IconButton(tooltip: 'Gỡ liên kết', icon: const Icon(Icons.link_off), onPressed: () => _remove(l)),
                );
              },
            );
          },
        ),
      );
}

class _LinkDialog extends StatefulWidget {
  final List<User> parents, students;
  const _LinkDialog({required this.parents, required this.students});
  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  String? _parent, _student;

  Widget _picker(String label, List<User> users, ValueChanged<String?> onSelected) => DropdownMenu<String>(
        label: Text(label),
        expandedInsets: EdgeInsets.zero,
        enableFilter: true,
        requestFocusOnTap: true,
        menuHeight: 300,
        // Lọc không phân biệt dấu: gõ "tran" ra "Trần".
        filterCallback: (entries, filter) {
          final f = foldVi(filter.trim());
          return f.isEmpty ? entries : entries.where((e) => foldVi(e.label).contains(f)).toList();
        },
        dropdownMenuEntries: [for (final u in users) DropdownMenuEntry(value: u.id, label: '${u.fullName} (${u.email})')],
        onSelected: (v) => setState(() => onSelected(v)),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Liên kết phụ huynh với học sinh'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.parents.isEmpty || widget.students.isEmpty)
              const Text('Cần có ít nhất một tài khoản phụ huynh và một tài khoản học sinh.')
            else ...[
              _picker('Phụ huynh', widget.parents, (v) => _parent = v),
              const SizedBox(height: 16),
              _picker('Học sinh (con)', widget.students, (v) => _student = v),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: _parent == null || _student == null ? null : () => Navigator.pop(context, (_parent!, _student!)),
            child: const Text('Liên kết'),
          ),
        ],
      );
}
