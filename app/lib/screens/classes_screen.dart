import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';
import 'class_detail_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});
  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  late Future<List<Classroom>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final api = AppScope.of(context).api;
    _future = api.get('/classes').then((l) => [for (final j in l) Classroom.fromJson(j)]);
  }

  void _reload() => setState(_load);

  Future<void> _createClass() async {
    final name = TextEditingController();
    final subject = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tạo lớp mới'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Tên lớp, ví dụ Toán 10A1')),
          TextField(controller: subject, decoration: const InputDecoration(labelText: 'Môn học')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tạo')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final api = AppScope.of(context).api;
    final done = await runGuarded(context, () async {
      await api.post('/classes', {'name': name.text.trim(), if (subject.text.trim().isNotEmpty) 'subject': subject.text.trim()});
    }, success: 'Đã tạo lớp');
    if (done) _reload();
  }

  Future<void> _joinClass() async {
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Vào lớp bằng mã mời'),
        content: TextField(
          controller: code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Mã mời 6 ký tự (giáo viên cung cấp)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Gửi yêu cầu')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final api = AppScope.of(context).api;
    await runGuarded(context, () async {
      await api.post('/classes/join', {'inviteCode': code.text.trim()});
    }, success: 'Đã gửi yêu cầu, chờ giáo viên duyệt');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final role = app.user!.role;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lớp học'),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'Tải lại')],
      ),
      floatingActionButton: switch (role) {
        Role.teacher || Role.admin =>
          FloatingActionButton.extended(onPressed: _createClass, icon: const Icon(Icons.add), label: const Text('Tạo lớp')),
        Role.student =>
          FloatingActionButton.extended(onPressed: _joinClass, icon: const Icon(Icons.login), label: const Text('Vào lớp')),
        Role.parent => null,
      },
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: AsyncView<List<Classroom>>(
          future: _future,
          onRetry: _reload,
          builder: (classes) {
            if (classes.isEmpty) {
              return EmptyState(
                icon: Icons.class_outlined,
                text: switch (role) {
                  Role.student => 'Bạn chưa ở lớp nào. Bấm "Vào lớp" và nhập mã mời của giáo viên.',
                  Role.parent => 'Con bạn chưa ở lớp nào.',
                  _ => 'Chưa có lớp. Bấm "Tạo lớp" để bắt đầu.',
                },
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: classes.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (c, i) {
                final cl = classes[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(cl.name.characters.first)),
                  title: Text(cl.name),
                  subtitle: Text([if (cl.subject != null) cl.subject!, 'GV: ${cl.teacher.fullName}'].join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClassDetailScreen(classroom: cl)));
                    _reload();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
