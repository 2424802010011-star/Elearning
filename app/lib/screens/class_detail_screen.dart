import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';
import 'assignments_tab.dart';
import 'lessons_tab.dart';
import 'meeting_room_screen.dart';
import 'quizzes_tab.dart';

class ClassDetailScreen extends StatefulWidget {
  final Classroom classroom;
  const ClassDetailScreen({super.key, required this.classroom});
  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  late Classroom _c = widget.classroom;

  bool _canManage(AppState app) => app.user!.role == Role.admin || app.user!.id == _c.teacher.id;

  Future<void> _regenerate() async {
    final api = AppScope.of(context).api;
    await runGuarded(context, () async {
      final j = await api.post('/classes/${_c.id}/invite-code');
      setState(() => _c = Classroom.fromJson(j));
    }, success: 'Đã đổi mã mời, mã cũ không dùng được nữa');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final manage = _canManage(app);
    return DefaultTabController(
      length: manage ? 6 : 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_c.name),
          bottom: TabBar(isScrollable: MediaQuery.sizeOf(context).width < 600, tabAlignment: MediaQuery.sizeOf(context).width < 600 ? TabAlignment.start : null, tabs: [
            const Tab(text: 'Lịch học'),
            const Tab(text: 'Cuộc họp'),
            const Tab(text: 'Bài giảng'),
            const Tab(text: 'Bài tập'),
            const Tab(text: 'Kiểm tra'),
            if (manage) const Tab(text: 'Học sinh'),
          ]),
        ),
        body: Column(children: [
          if (manage)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text('Mã mời: ${_c.inviteCode}', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                subtitle: const Text('Gửi mã này cho học sinh để xin vào lớp'),
                trailing: Wrap(children: [
                  IconButton(
                    tooltip: 'Sao chép',
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _c.inviteCode));
                      showMsg(context, 'Đã sao chép mã mời');
                    },
                  ),
                  IconButton(tooltip: 'Đổi mã', icon: const Icon(Icons.autorenew), onPressed: _regenerate),
                ]),
              ),
            ),
          Expanded(
            child: TabBarView(children: [
              _TimetableTab(classroom: _c, manage: manage),
              _MeetingsTab(classroom: _c, manage: manage),
              LessonsTab(classroom: _c, manage: manage),
              AssignmentsTab(classroom: _c, manage: manage),
              QuizzesTab(classroom: _c, manage: manage),
              if (manage) _StudentsTab(classroom: _c),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------- Lịch học ----------------
class _TimetableTab extends StatefulWidget {
  final Classroom classroom;
  final bool manage;
  const _TimetableTab({required this.classroom, required this.manage});
  @override
  State<_TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<_TimetableTab> {
  late Future<List<TimetableEntry>> _f;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _f = AppScope.of(context)
      .api
      .get('/classes/${widget.classroom.id}/timetable')
      .then((l) => [for (final j in l) TimetableEntry.fromJson(j)]);

  Future<void> _add() async {
    final body = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _EntryDialog());
    if (body == null || !mounted) return;
    final api = AppScope.of(context).api;
    final ok = await runGuarded(context, () => api.post('/classes/${widget.classroom.id}/timetable', body), success: 'Đã thêm tiết học');
    if (ok) setState(_load);
  }

  Future<void> _delete(TimetableEntry e) async {
    final api = AppScope.of(context).api;
    final ok = await runGuarded(context, () => api.delete('/classes/${widget.classroom.id}/timetable/${e.id}'));
    if (ok) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.manage
          ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Thêm tiết'))
          : null,
      body: AsyncView<List<TimetableEntry>>(
        future: _f,
        onRetry: () => setState(_load),
        builder: (entries) => entries.isEmpty
            ? const EmptyState(icon: Icons.event_busy, text: 'Lớp chưa có lịch học')
            : ListView(children: [
                for (final e in entries)
                  ListTile(
                    leading: CircleAvatar(child: Text(e.dayOfWeek == 7 ? 'CN' : 'T${e.dayOfWeek + 1}')),
                    title: Text(e.title),
                    subtitle: Text('${dayNames[e.dayOfWeek - 1]}, ${e.startTime} - ${e.endTime}${e.location != null ? ' · ${e.location}' : ''}'),
                    trailing: widget.manage
                        ? IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Xóa', onPressed: () => _delete(e))
                        : null,
                  ),
              ]),
      ),
    );
  }
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog();
  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  int _day = 1;
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _end = const TimeOfDay(hour: 8, minute: 15);
  DateTime _from = DateTime.now();

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm tiết học hằng tuần'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _title, autofocus: true, decoration: const InputDecoration(labelText: 'Tên tiết, ví dụ Đại số')),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _day,
            decoration: const InputDecoration(labelText: 'Ngày trong tuần'),
            items: [for (var i = 1; i <= 7; i++) DropdownMenuItem(value: i, child: Text(dayNames[i - 1]))],
            onChanged: (v) => setState(() => _day = v ?? 1),
          ),
          Row(children: [
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text('Bắt đầu ${_hhmm(_start)}'),
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: _start);
                  if (t != null) setState(() => _start = t);
                },
              ),
            ),
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text('Kết thúc ${_hhmm(_end)}'),
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: _end);
                  if (t != null) setState(() => _end = t);
                },
              ),
            ),
          ]),
          TextButton.icon(
            icon: const Icon(Icons.event),
            label: Text('Áp dụng từ ngày ${_from.day}/${_from.month}/${_from.year}'),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _from,
                firstDate: DateTime(2024),
                lastDate: DateTime(2035),
              );
              if (d != null) setState(() => _from = d);
            },
          ),
          TextField(controller: _location, decoration: const InputDecoration(labelText: 'Phòng / ghi chú (không bắt buộc)')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'title': _title.text.trim(),
            'dayOfWeek': _day,
            'startTime': _hhmm(_start),
            'endTime': _hhmm(_end),
            'startDate': _ymd(_from),
            if (_location.text.trim().isNotEmpty) 'location': _location.text.trim(),
          }),
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}

// ---------------- Cuộc họp ----------------
class _MeetingsTab extends StatefulWidget {
  final Classroom classroom;
  final bool manage;
  const _MeetingsTab({required this.classroom, required this.manage});
  @override
  State<_MeetingsTab> createState() => _MeetingsTabState();
}

class _MeetingsTabState extends State<_MeetingsTab> {
  late Future<List<Meeting>> _f;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _f = AppScope.of(context)
      .api
      .get('/classes/${widget.classroom.id}/meetings')
      .then((l) => [for (final j in l) Meeting.fromJson(j)]);

  Future<void> _create() async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tạo cuộc họp'),
        content: TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Chủ đề buổi học')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tạo')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final api = AppScope.of(context).api;
    final done = await runGuarded(context, () => api.post('/classes/${widget.classroom.id}/meetings', {'title': title.text.trim()}));
    if (done) setState(_load);
  }

  Future<void> _join(Meeting m) async {
    final api = AppScope.of(context).api;
    await runGuarded(context, () async {
      final info = await api.post('/meetings/${m.id}/join');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MeetingRoomScreen(meeting: m, classroom: widget.classroom, joinInfo: info)),
      );
    });
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final role = AppScope.of(context).user!.role;
    return Scaffold(
      floatingActionButton: widget.manage
          ? FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.video_call), label: const Text('Tạo cuộc họp'))
          : null,
      body: AsyncView<List<Meeting>>(
        future: _f,
        onRetry: () => setState(_load),
        builder: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.videocam_off_outlined, text: 'Chưa có cuộc họp nào')
            : ListView(children: [
                for (final m in list)
                  ListTile(
                    leading: Icon(
                      m.status == 'live' ? Icons.sensors : (m.status == 'ended' ? Icons.check_circle_outline : Icons.schedule),
                      color: m.status == 'live' ? Colors.red : null,
                    ),
                    title: Text(m.title),
                    subtitle: Text(switch (m.status) {
                      'live' => 'Đang diễn ra',
                      'ended' => 'Đã kết thúc',
                      _ => 'Chưa bắt đầu',
                    }),
                    trailing: m.status == 'ended' || role == Role.parent
                        ? null
                        : FilledButton(
                            onPressed: () => _join(m),
                            child: Text(widget.manage && m.status != 'live' ? 'Mở phòng' : 'Vào'),
                          ),
                  ),
              ]),
      ),
    );
  }
}

// ---------------- Học sinh ----------------
class _StudentsTab extends StatefulWidget {
  final Classroom classroom;
  const _StudentsTab({required this.classroom});
  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  late Future<List<Enrollment>> _f;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _f = AppScope.of(context)
      .api
      .get('/classes/${widget.classroom.id}/enrollments')
      .then((l) => [for (final j in l) Enrollment.fromJson(j)]);

  Future<void> _review(Enrollment e, String status) async {
    final api = AppScope.of(context).api;
    final ok = await runGuarded(
      context,
      () => api.patch('/classes/${widget.classroom.id}/enrollments/${e.id}', {'status': status}),
    );
    if (ok) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Enrollment>>(
      future: _f,
      onRetry: () => setState(_load),
      builder: (all) {
        final pending = all.where((e) => e.status == 'pending').toList();
        final approved = all.where((e) => e.status == 'approved').toList();
        if (all.isEmpty) return const EmptyState(icon: Icons.group_outlined, text: 'Chưa có học sinh. Gửi mã mời cho học sinh.');
        return ListView(children: [
          if (pending.isNotEmpty) ListTile(title: Text('Chờ duyệt (${pending.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
          for (final e in pending)
            ListTile(
              leading: const Icon(Icons.hourglass_top),
              title: Text(e.student.fullName),
              subtitle: Text(e.student.email),
              trailing: Wrap(spacing: 4, children: [
                IconButton.filledTonal(tooltip: 'Từ chối', icon: const Icon(Icons.close), onPressed: () => _review(e, 'rejected')),
                IconButton.filled(tooltip: 'Duyệt', icon: const Icon(Icons.check), onPressed: () => _review(e, 'approved')),
              ]),
            ),
          ListTile(title: Text('Trong lớp (${approved.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
          for (final e in approved)
            ListTile(
              leading: CircleAvatar(child: Text(e.student.fullName.characters.first)),
              title: Text(e.student.fullName),
              subtitle: Text(e.student.email),
            ),
        ]);
      },
    );
  }
}
