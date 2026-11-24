import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';
import '../widgets/files.dart';

/// Tab "Bài tập" trong chi tiết lớp.
class AssignmentsTab extends StatefulWidget {
  final Classroom classroom;
  final bool manage;
  const AssignmentsTab({super.key, required this.classroom, required this.manage});
  @override
  State<AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<AssignmentsTab> {
  late Future<List<Assignment>> _f;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _f = AppScope.of(context)
      .api
      .get('/classes/${widget.classroom.id}/assignments')
      .then((l) => [for (final j in l) Assignment.fromJson(j)]);

  Future<void> _create() async {
    final body = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _CreateDialog());
    if (body == null || !mounted) return;
    final api = AppScope.of(context).api;
    final ok = await runGuarded(context, () => api.post('/classes/${widget.classroom.id}/assignments', body), success: 'Đã giao bài');
    if (ok) setState(_load);
  }

  Future<void> _open(Assignment a) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => widget.manage ? GradingScreen(assignment: a) : AssignmentDetailScreen(assignment: a)),
    );
    if (mounted) setState(_load);
  }

  Widget _status(Assignment a, Role role) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.manage) {
      return Text('${a.submittedCount}/${a.totalStudents} đã nộp · ${a.gradedCount} đã chấm');
    }
    if (a.submissions.isEmpty) {
      final overdue = a.dueAt != null && DateTime.now().isAfter(a.dueAt!);
      return Text(overdue ? 'Chưa nộp · đã quá hạn' : 'Chưa nộp', style: TextStyle(color: overdue ? scheme.error : null));
    }
    final s = a.submissions.first;
    if (s.score != null) return Text('Điểm ${fmtScore(s.score!)}/${fmtScore(a.maxScore)}', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600));
    return Text(s.late ? 'Đã nộp (muộn) · chờ chấm' : 'Đã nộp · chờ chấm');
  }

  @override
  Widget build(BuildContext context) {
    final role = AppScope.of(context).user!.role;
    return Scaffold(
      floatingActionButton: widget.manage
          ? FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.assignment_add), label: const Text('Giao bài'))
          : null,
      body: AsyncView<List<Assignment>>(
        future: _f,
        onRetry: () => setState(_load),
        builder: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.assignment_outlined, text: 'Chưa có bài tập')
            : ListView(padding: const EdgeInsets.only(bottom: 88), children: [
                for (final a in list)
                  ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(a.title),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (a.dueAt != null) Text('Hạn nộp: ${fmtDateTime(a.dueAt!)}'),
                      _status(a, role),
                    ]),
                    isThreeLine: a.dueAt != null,
                    trailing: role == Role.parent ? null : const Icon(Icons.chevron_right),
                    onTap: role == Role.parent ? () => _showParent(a) : () => _open(a),
                  ),
              ]),
      ),
    );
  }

  void _showParent(Assignment a) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(a.title),
        content: Text(a.submissions.isEmpty
            ? 'Con bạn chưa nộp bài này.'
            : [
                for (final s in a.submissions)
                  '${s.student.fullName}: ${s.score == null ? 'đã nộp, chờ chấm' : 'điểm ${fmtScore(s.score!)}/${fmtScore(a.maxScore)}'}'
                      '${s.feedback != null ? '\nNhận xét: ${s.feedback}' : ''}',
              ].join('\n\n')),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng'))],
      ),
    );
  }
}

class _CreateDialog extends StatefulWidget {
  const _CreateDialog();
  @override
  State<_CreateDialog> createState() => _CreateDialogState();
}

class _CreateDialogState extends State<_CreateDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _max = TextEditingController(text: '10');
  DateTime? _due;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Giao bài tập'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _title, autofocus: true, decoration: const InputDecoration(labelText: 'Tiêu đề')),
            TextField(controller: _desc, minLines: 3, maxLines: 8, decoration: const InputDecoration(labelText: 'Đề bài')),
            TextField(controller: _max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Điểm tối đa')),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.event),
              label: Text(_due == null ? 'Không có hạn nộp (bấm để chọn)' : 'Hạn nộp: ${fmtDateTime(_due!)}'),
              onPressed: () async {
                final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2035), initialDate: DateTime.now().add(const Duration(days: 7)));
                if (d == null || !context.mounted) return;
                final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 23, minute: 59));
                setState(() => _due = DateTime(d.year, d.month, d.day, t?.hour ?? 23, t?.minute ?? 59));
              },
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'title': _title.text.trim(),
            'description': _desc.text.trim(),
            'maxScore': double.tryParse(_max.text.replaceAll(',', '.')) ?? 10,
            if (_due != null) 'dueAt': _due!.toUtc().toIso8601String(),
          }),
          child: const Text('Giao bài'),
        ),
      ],
    );
  }
}

/// Học sinh xem đề, nộp bài, xem điểm.
class AssignmentDetailScreen extends StatefulWidget {
  final Assignment assignment;
  const AssignmentDetailScreen({super.key, required this.assignment});
  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  late Submission? _sub = widget.assignment.submissions.firstOrNull;
  late final _answer = TextEditingController(text: _sub?.content ?? '');
  late List<FileRef> _files = _sub?.attachments ?? [];
  bool _busy = false;

  Future<void> _submit() async {
    final api = AppScope.of(context).api;
    setState(() => _busy = true);
    await runGuarded(context, () async {
      final j = await api.post('/assignments/${widget.assignment.id}/submit', {
        'content': _answer.text,
        'fileIds': [for (final f in _files) f.id],
      });
      setState(() => _sub = Submission.fromJson(j));
    }, success: 'Đã nộp bài');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    final graded = _sub?.score != null;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(a.title)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (a.dueAt != null) Text('Hạn nộp: ${fmtDateTime(a.dueAt!)}', style: TextStyle(color: scheme.onSurfaceVariant)),
        Text('Điểm tối đa: ${fmtScore(a.maxScore)}', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Text(a.description.isEmpty ? '(Không có mô tả)' : a.description, style: Theme.of(context).textTheme.bodyLarge),
        const Divider(height: 32),
        if (graded)
          Card(
            color: scheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.grade),
              title: Text('Điểm: ${fmtScore(_sub!.score!)}/${fmtScore(a.maxScore)}'),
              subtitle: _sub!.feedback == null ? null : Text('Nhận xét: ${_sub!.feedback}'),
            ),
          ),
        if (_sub != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Đã nộp lúc ${fmtDateTime(_sub!.submittedAt)}${_sub!.late ? ' (muộn)' : ''}'),
          ),
        TextField(
          controller: _answer,
          enabled: !graded,
          minLines: 6,
          maxLines: 20,
          decoration: const InputDecoration(labelText: 'Bài làm của bạn', border: OutlineInputBorder(), alignLabelWithHint: true),
        ),
        const SizedBox(height: 8),
        AttachmentPicker(
          initial: _files,
          enabled: !graded,
          onChanged: (f) => _files = f,
          label: 'Đính kèm ảnh chụp bài làm, file PDF, Word...',
        ),
        const SizedBox(height: 12),
        if (!graded)
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: const Icon(Icons.send),
            label: Text(_sub == null ? 'Nộp bài' : 'Nộp lại'),
          ),
      ]),
    );
  }
}

/// Giáo viên xem bài nộp và chấm điểm.
class GradingScreen extends StatefulWidget {
  final Assignment assignment;
  const GradingScreen({super.key, required this.assignment});
  @override
  State<GradingScreen> createState() => _GradingScreenState();
}

class _GradingScreenState extends State<GradingScreen> {
  late Future<List<Submission>> _f;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _f = AppScope.of(context)
      .api
      .get('/assignments/${widget.assignment.id}/submissions')
      .then((l) => [for (final j in l) Submission.fromJson(j)]);

  Future<void> _grade(Submission s) async {
    final score = TextEditingController(text: s.score == null ? '' : fmtScore(s.score!));
    final fb = TextEditingController(text: s.feedback ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Chấm bài: ${s.student.fullName}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Text(s.content.isEmpty ? '(Không có phần chữ)' : s.content),
              ),
              if (s.attachments.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: FileList(s.attachments)),
              const SizedBox(height: 12),
              TextField(
                controller: score,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Điểm (tối đa ${fmtScore(widget.assignment.maxScore)})'),
              ),
              TextField(controller: fb, maxLines: 3, decoration: const InputDecoration(labelText: 'Nhận xét')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu điểm')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final api = AppScope.of(context).api;
    final done = await runGuarded(context, () async {
      final v = double.tryParse(score.text.replaceAll(',', '.'));
      if (v == null) throw 'Điểm không hợp lệ';
      await api.patch('/assignments/${widget.assignment.id}/submissions/${s.id}', {
        'score': v,
        if (fb.text.trim().isNotEmpty) 'feedback': fb.text.trim(),
      });
    }, success: 'Đã lưu điểm');
    if (done) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return Scaffold(
      appBar: AppBar(title: Text(a.title)),
      body: AsyncView<List<Submission>>(
        future: _f,
        onRetry: () => setState(_load),
        builder: (subs) => ListView(children: [
          if (a.description.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(a.description)),
          ListTile(title: Text('Bài đã nộp (${subs.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
          if (subs.isEmpty) const EmptyState(icon: Icons.inbox_outlined, text: 'Chưa có học sinh nào nộp bài'),
          for (final s in subs)
            ListTile(
              leading: CircleAvatar(child: Text(s.student.fullName.characters.first)),
              title: Text(s.student.fullName),
              subtitle: Text(
                  '${s.content.isEmpty ? '' : s.content.split('\n').first}${s.attachments.isEmpty ? '' : '${s.content.isEmpty ? '' : ' · '}📎 ${s.attachments.length} file'}\nNộp ${fmtDateTime(s.submittedAt)}${s.late ? ' · muộn' : ''}',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: s.score == null
                  ? FilledButton.tonal(onPressed: () => _grade(s), child: const Text('Chấm'))
                  : TextButton(onPressed: () => _grade(s), child: Text('${fmtScore(s.score!)}/${fmtScore(a.maxScore)}')),
            ),
        ]),
      ),
    );
  }
}
