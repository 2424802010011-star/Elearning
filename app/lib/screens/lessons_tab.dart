import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';
import '../widgets/files.dart';

/// Tab "Bài giảng": tài liệu, slide, video giáo viên đăng cho lớp.
class LessonsTab extends StatefulWidget {
  final Classroom classroom;
  final bool manage;
  const LessonsTab({super.key, required this.classroom, required this.manage});
  @override
  State<LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<LessonsTab> {
  late Future<List<Lesson>> _f;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _f = AppScope.of(context)
      .api
      .get('/classes/${widget.classroom.id}/lessons')
      .then((l) => [for (final j in l) Lesson.fromJson(j)]);

  Future<void> _create() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _LessonDialog(classroom: widget.classroom));
    if (ok == true && mounted) setState(_load);
  }

  Future<void> _delete(Lesson l) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa bài giảng?'),
        content: Text('"${l.title}" và ${l.attachments.length} file đính kèm sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final api = AppScope.of(context).api;
    if (await runGuarded(context, () => api.delete('/lessons/${l.id}'), success: 'Đã xóa')) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.manage
          ? FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.upload_file), label: const Text('Đăng bài giảng'))
          : null,
      body: AsyncView<List<Lesson>>(
        future: _f,
        onRetry: () => setState(_load),
        builder: (list) => list.isEmpty
            ? EmptyState(icon: Icons.menu_book_outlined, text: widget.manage ? 'Chưa có bài giảng. Bấm "Đăng bài giảng" để tải tài liệu, slide, video lên.' : 'Chưa có bài giảng')
            : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 88), children: [
                for (final l in list)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.menu_book_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(l.title, style: Theme.of(context).textTheme.titleMedium),
                              Text('Đăng lúc ${fmtDateTime(l.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
                            ]),
                          ),
                          if (widget.manage) IconButton(tooltip: 'Xóa', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(l)),
                        ]),
                        if (l.content.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.content)),
                        if (l.attachments.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: FileList(l.attachments)),
                      ]),
                    ),
                  ),
              ]),
      ),
    );
  }
}

class _LessonDialog extends StatefulWidget {
  final Classroom classroom;
  const _LessonDialog({required this.classroom});
  @override
  State<_LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends State<_LessonDialog> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  List<FileRef> _files = [];
  bool _busy = false;

  Future<void> _save() async {
    final api = AppScope.of(context).api;
    setState(() => _busy = true);
    final ok = await runGuarded(context, () async {
      if (_title.text.trim().isEmpty) throw 'Hãy đặt tên bài giảng';
      await api.post('/classes/${widget.classroom.id}/lessons', {
        'title': _title.text.trim(),
        'content': _content.text.trim(),
        'fileIds': [for (final f in _files) f.id],
      });
    }, success: 'Đã đăng bài giảng');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đăng bài giảng'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _title, autofocus: true, decoration: const InputDecoration(labelText: 'Tên bài giảng')),
            TextField(controller: _content, minLines: 2, maxLines: 8, decoration: const InputDecoration(labelText: 'Nội dung, hướng dẫn')),
            const SizedBox(height: 12),
            AttachmentPicker(onChanged: (f) => _files = f, label: 'Đính kèm tài liệu, slide, video (tối đa 50 MB mỗi file)'),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Đăng')),
      ],
    );
  }
}
