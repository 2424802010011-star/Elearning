import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';

/// Tab "Kiểm tra" (trắc nghiệm) trong chi tiết lớp.
class QuizzesTab extends StatefulWidget {
  final Classroom classroom;
  final bool manage;
  const QuizzesTab({super.key, required this.classroom, required this.manage});
  @override
  State<QuizzesTab> createState() => _QuizzesTabState();
}

class _QuizzesTabState extends State<QuizzesTab> {
  late Future<List<Quiz>> _f;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _f = AppScope.of(context)
      .api
      .get('/classes/${widget.classroom.id}/quizzes')
      .then((l) => [for (final j in l) Quiz.fromJson(j)]);

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(_load);
  }

  String _info(Quiz q) => [
        '${q.questionCount} câu · ${fmtScore(q.maxScore)} điểm',
        if (q.durationMinutes != null) '${q.durationMinutes} phút',
        if (q.dueAt != null) 'hạn ${fmtDateTime(q.dueAt!)}',
      ].join(' · ');

  Widget _status(Quiz q, Role role) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.manage) {
      return Text([
        if (!q.published) 'Bản nháp, học sinh chưa thấy',
        if (q.published) '${q.submittedCount}/${q.totalStudents} đã nộp',
        if (q.averageScore != null) 'điểm TB ${fmtScore(q.averageScore!)}',
      ].join(' · '), style: TextStyle(color: q.published ? null : scheme.tertiary));
    }
    final a = role == Role.parent ? q.attempts.firstOrNull : q.attempt;
    if (a == null) {
      return Text(q.overdue ? 'Chưa làm · đã quá hạn' : 'Chưa làm', style: TextStyle(color: q.overdue ? scheme.error : null));
    }
    if (!a.submitted) return Text('Đang làm dở', style: TextStyle(color: scheme.tertiary));
    return Text('Điểm ${fmtScore(a.score ?? 0)}/${fmtScore(a.maxScore)}${a.late ? ' (nộp muộn)' : ''}',
        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600));
  }

  void _showParent(Quiz q) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(q.title),
        content: Text(q.attempts.isEmpty
            ? 'Con bạn chưa làm bài kiểm tra này.'
            : [
                for (final a in q.attempts)
                  '${a.studentName ?? 'Con'}: ${a.submitted ? 'điểm ${fmtScore(a.score ?? 0)}/${fmtScore(a.maxScore)}, nộp lúc ${fmtDateTime(a.submittedAt!)}' : 'đang làm dở'}',
              ].join('\n\n')),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = AppScope.of(context).user!.role;
    return Scaffold(
      floatingActionButton: widget.manage
          ? FloatingActionButton.extended(
              onPressed: () => _push(QuizEditorScreen(classroom: widget.classroom)),
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Soạn đề'),
            )
          : null,
      body: AsyncView<List<Quiz>>(
        future: _f,
        onRetry: () => setState(_load),
        builder: (list) => list.isEmpty
            ? EmptyState(icon: Icons.quiz_outlined, text: widget.manage ? 'Chưa có bài kiểm tra. Bấm "Soạn đề" để tạo.' : 'Chưa có bài kiểm tra')
            : ListView(padding: const EdgeInsets.only(bottom: 88), children: [
                for (final q in list)
                  ListTile(
                    leading: Icon(q.published ? Icons.quiz : Icons.edit_note),
                    title: Text(q.title),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_info(q)), _status(q, role)]),
                    isThreeLine: true,
                    trailing: role == Role.parent ? null : const Icon(Icons.chevron_right),
                    onTap: switch (role) {
                      Role.parent => () => _showParent(q),
                      _ when widget.manage => () => _push(QuizResultsScreen(quizId: q.id)),
                      _ => () => _push(QuizTakeScreen(quizId: q.id)),
                    },
                  ),
              ]),
      ),
    );
  }
}

// ======================= Giáo viên soạn đề =======================

class _QDraft {
  final text = TextEditingController();
  final points = TextEditingController(text: '1');
  final options = [TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController()];
  final correct = <int>{0};
}

class QuizEditorScreen extends StatefulWidget {
  final Classroom classroom;
  const QuizEditorScreen({super.key, required this.classroom});
  @override
  State<QuizEditorScreen> createState() => _QuizEditorScreenState();
}

class _QuizEditorScreenState extends State<QuizEditorScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _minutes = TextEditingController(text: '15');
  DateTime? _due;
  bool _showAnswers = true;
  final _qs = [_QDraft()];
  bool _busy = false;

  Future<void> _save({required bool publish}) async {
    final api = AppScope.of(context).api;
    setState(() => _busy = true);
    final ok = await runGuarded(context, () async {
      if (_title.text.trim().isEmpty) throw 'Hãy đặt tên bài kiểm tra';
      final questions = <Map<String, dynamic>>[];
      for (var i = 0; i < _qs.length; i++) {
        final q = _qs[i];
        final opts = <String>[];
        final correct = <int>[];
        for (var k = 0; k < q.options.length; k++) {
          final t = q.options[k].text.trim();
          if (t.isEmpty) continue;
          if (q.correct.contains(k)) correct.add(opts.length);
          opts.add(t);
        }
        if (q.text.text.trim().isEmpty) throw 'Câu ${i + 1} chưa có nội dung';
        if (opts.length < 2) throw 'Câu ${i + 1} cần ít nhất 2 lựa chọn';
        if (correct.isEmpty) throw 'Câu ${i + 1} chưa đánh dấu đáp án đúng';
        questions.add({
          'text': q.text.text.trim(),
          'options': opts,
          'correct': correct,
          'points': double.tryParse(q.points.text.replaceAll(',', '.')) ?? 1,
        });
      }
      final minutes = int.tryParse(_minutes.text.trim());
      await api.post('/classes/${widget.classroom.id}/quizzes', {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        if (minutes != null && minutes > 0) 'durationMinutes': minutes,
        if (_due != null) 'dueAt': _due!.toUtc().toIso8601String(),
        'showAnswers': _showAnswers,
        'published': publish,
        'questions': questions,
      });
    }, success: publish ? 'Đã phát hành bài kiểm tra' : 'Đã lưu bản nháp');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  Widget _questionCard(int i) {
    final q = _qs[i];
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Câu ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            SizedBox(
              width: 70,
              child: TextField(controller: q.points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Điểm', isDense: true)),
            ),
            IconButton(
              tooltip: 'Xóa câu',
              icon: const Icon(Icons.delete_outline),
              onPressed: _qs.length == 1 ? null : () => setState(() => _qs.removeAt(i)),
            ),
          ]),
          TextField(controller: q.text, minLines: 1, maxLines: 5, decoration: const InputDecoration(labelText: 'Nội dung câu hỏi')),
          const SizedBox(height: 8),
          Text('Bấm vào ô tròn để đánh dấu đáp án đúng (chọn nhiều ô nếu câu có nhiều đáp án)',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          for (var k = 0; k < q.options.length; k++)
            Row(children: [
              IconButton(
                tooltip: 'Đáp án đúng',
                icon: Icon(q.correct.contains(k) ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: q.correct.contains(k) ? Colors.green.shade700 : null),
                onPressed: () => setState(() => q.correct.contains(k) ? q.correct.remove(k) : q.correct.add(k)),
              ),
              Expanded(
                child: TextField(controller: q.options[k], decoration: InputDecoration(hintText: 'Lựa chọn ${String.fromCharCode(65 + k)}', isDense: true)),
              ),
              IconButton(
                tooltip: 'Bỏ lựa chọn này',
                icon: const Icon(Icons.close, size: 18),
                onPressed: q.options.length <= 2
                    ? null
                    : () => setState(() {
                          q.options.removeAt(k);
                          final shifted = {for (final c in q.correct) if (c != k) c > k ? c - 1 : c};
                          q.correct
                            ..clear()
                            ..addAll(shifted);
                        }),
              ),
            ]),
          if (q.options.length < 8)
            TextButton.icon(
              onPressed: () => setState(() => q.options.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('Thêm lựa chọn'),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soạn đề trắc nghiệm'), actions: [
        TextButton(onPressed: _busy ? null : () => _save(publish: false), child: const Text('Lưu nháp')),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton(onPressed: _busy ? null : () => _save(publish: true), child: const Text('Phát hành')),
        ),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Tên bài kiểm tra')),
            TextField(controller: _desc, maxLines: 3, minLines: 1, decoration: const InputDecoration(labelText: 'Hướng dẫn (không bắt buộc)')),
            Wrap(spacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Thời gian làm (phút)', helperText: 'Để trống = không giới hạn'),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.event),
                label: Text(_due == null ? 'Không có hạn chót (bấm để chọn)' : 'Hạn chót: ${fmtDateTime(_due!)}'),
                onPressed: () async {
                  final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2035), initialDate: DateTime.now().add(const Duration(days: 7)));
                  if (d == null || !context.mounted) return;
                  final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 23, minute: 59));
                  setState(() => _due = DateTime(d.year, d.month, d.day, t?.hour ?? 23, t?.minute ?? 59));
                },
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cho học sinh xem đáp án sau khi nộp'),
              value: _showAnswers,
              onChanged: (v) => setState(() => _showAnswers = v),
            ),
            const Divider(),
            for (var i = 0; i < _qs.length; i++) _questionCard(i),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => setState(() => _qs.add(_QDraft())), icon: const Icon(Icons.add), label: const Text('Thêm câu hỏi')),
            const SizedBox(height: 48),
          ]),
        ),
      ),
    );
  }
}

// ======================= Giáo viên xem kết quả =======================

class QuizResultsScreen extends StatefulWidget {
  final String quizId;
  const QuizResultsScreen({super.key, required this.quizId});
  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  late Future<(Quiz, List<QuizAttempt>, Map<String, (int, int)>)> _f;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final api = AppScope.of(context).api;
    _f = () async {
      final quiz = Quiz.fromJson(await api.get('/quizzes/${widget.quizId}'));
      final r = await api.get('/quizzes/${widget.quizId}/results');
      final atts = [for (final a in r['attempts'] as List) QuizAttempt.fromJson(a)];
      final stats = {for (final s in r['questionStats'] as List) s['id'] as String: (s['correctCount'] as int, s['total'] as int)};
      return (quiz, atts, stats);
    }();
  }

  Future<void> _publish(Quiz q, bool v) async {
    final api = AppScope.of(context).api;
    final ok = await runGuarded(context, () => api.patch('/quizzes/${q.id}', {'published': v}),
        success: v ? 'Đã phát hành, học sinh đã thấy bài' : 'Đã ẩn bài kiểm tra');
    if (ok && mounted) setState(_load);
  }

  Future<void> _delete(Quiz q) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa bài kiểm tra?'),
        content: const Text('Bài làm và điểm của học sinh cũng bị xóa theo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final api = AppScope.of(context).api;
    final ok = await runGuarded(context, () => api.delete('/quizzes/${q.id}'), success: 'Đã xóa');
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: _f,
      builder: (context, snap) => Scaffold(
        appBar: AppBar(
          title: Text(snap.data?.$1.title ?? 'Bài kiểm tra'),
          actions: [
            if (snap.data != null) IconButton(tooltip: 'Xóa', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(snap.data!.$1)),
          ],
        ),
        body: AsyncView(
          future: _f,
          onRetry: () => setState(_load),
          builder: (data) {
            final (q, atts, stats) = data;
            final done = atts.where((a) => a.submitted).toList();
            return ListView(padding: const EdgeInsets.all(16), children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Phát hành cho học sinh'),
                subtitle: Text(q.published ? 'Học sinh đã thấy và làm được bài' : 'Bản nháp, học sinh chưa thấy'),
                value: q.published,
                onChanged: (v) => _publish(q, v),
              ),
              Text([
                '${q.questionCount} câu · ${fmtScore(q.maxScore)} điểm',
                if (q.durationMinutes != null) '${q.durationMinutes} phút',
                if (q.dueAt != null) 'hạn ${fmtDateTime(q.dueAt!)}',
              ].join(' · ')),
              if (q.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(q.description)),
              const Divider(height: 32),
              Text('Điểm của học sinh (${done.length} đã nộp)', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (atts.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Chưa có học sinh nào làm bài')),
              for (final a in atts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text((a.studentName ?? '?').characters.first)),
                  title: Text(a.studentName ?? ''),
                  subtitle: Text(a.submitted ? 'Nộp lúc ${fmtDateTime(a.submittedAt!)}${a.late ? ' · muộn' : ''}' : 'Đang làm (bắt đầu ${fmtDateTime(a.startedAt)})'),
                  trailing: a.submitted
                      ? Text('${fmtScore(a.score ?? 0)}/${fmtScore(a.maxScore)}', style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary, fontSize: 16))
                      : null,
                ),
              const Divider(height: 32),
              const Text('Đề và tỉ lệ làm đúng', style: TextStyle(fontWeight: FontWeight.bold)),
              for (var i = 0; i < q.questions.length; i++)
                _QuestionReview(
                  index: i,
                  question: q.questions[i],
                  footer: stats[q.questions[i].id] == null || stats[q.questions[i].id]!.$2 == 0
                      ? null
                      : '${stats[q.questions[i].id]!.$1}/${stats[q.questions[i].id]!.$2} học sinh làm đúng',
                ),
            ]);
          },
        ),
      ),
    );
  }
}

/// Một câu hỏi kèm đáp án: xanh là đáp án đúng, đỏ là lựa chọn sai của học sinh.
class _QuestionReview extends StatelessWidget {
  final int index;
  final QuizQuestion question;
  final List<int>? chosen;
  final String? footer;
  const _QuestionReview({required this.index, required this.question, this.chosen, this.footer});

  @override
  Widget build(BuildContext context) {
    final q = question;
    final correct = q.correct;
    final right = chosen != null && correct != null && chosen!.toSet().length == correct.length && correct.every(chosen!.contains);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Câu ${index + 1}. ${q.text}', style: const TextStyle(fontWeight: FontWeight.w600))),
            if (chosen != null && correct != null) Icon(right ? Icons.check_circle : Icons.cancel, color: right ? Colors.green.shade700 : Colors.red.shade700),
          ]),
          const SizedBox(height: 6),
          for (var k = 0; k < q.options.length; k++)
            Builder(builder: (context) {
              final isCorrect = correct?.contains(k) ?? false;
              final isChosen = chosen?.contains(k) ?? false;
              final color = isCorrect ? Colors.green.shade700 : (isChosen ? Colors.red.shade700 : null);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Icon(
                    isChosen ? (q.multiple ? Icons.check_box : Icons.radio_button_checked) : (q.multiple ? Icons.check_box_outline_blank : Icons.radio_button_unchecked),
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${String.fromCharCode(65 + k)}. ${q.options[k]}',
                        style: TextStyle(color: color, fontWeight: isCorrect ? FontWeight.w600 : null)),
                  ),
                  if (isCorrect) Text('đáp án đúng', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                ]),
              );
            }),
          if (footer != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(footer!, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      ),
    );
  }
}

// ======================= Học sinh làm bài =======================

class QuizTakeScreen extends StatefulWidget {
  final String quizId;
  const QuizTakeScreen({super.key, required this.quizId});
  @override
  State<QuizTakeScreen> createState() => _QuizTakeScreenState();
}

class _QuizTakeScreenState extends State<QuizTakeScreen> {
  Quiz? _quiz;
  Object? _error;
  bool _busy = false;
  final Map<String, Set<int>> _answers = {};
  Timer? _ticker;
  Duration? _left;
  /// Giờ máy chủ trừ giờ máy này, để đếm ngược đúng.
  Duration _skew = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_quiz == null && _error == null) _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final q = Quiz.fromJson(await AppScope.of(context).api.get('/quizzes/${widget.quizId}'));
      // Đang làm dở (thoát ra rồi vào lại) thì tiếp tục, đồng hồ vẫn chạy tiếp.
      if (q.attempt != null && !q.attempt!.submitted) {
        await _start();
        return;
      }
      setState(() => _quiz = q);
    } catch (e) {
      setState(() => _error = e);
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    await runGuarded(context, () async {
      final q = Quiz.fromJson(await AppScope.of(context).api.post('/quizzes/${widget.quizId}/start'));
      if (q.serverTime != null) _skew = q.serverTime!.difference(DateTime.now());
      setState(() => _quiz = q);
      _tick();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    });
    if (mounted) setState(() => _busy = false);
  }

  void _tick() {
    final d = _quiz?.attempt?.deadline;
    if (d == null) return;
    final left = d.difference(DateTime.now().add(_skew));
    setState(() => _left = left.isNegative ? Duration.zero : left);
    if (left <= Duration.zero) {
      _ticker?.cancel();
      _submit(auto: true);
    }
  }

  Future<void> _submit({bool auto = false}) async {
    final q = _quiz!;
    if (_busy) return;
    if (!auto) {
      final missing = q.questions.where((x) => (_answers[x.id] ?? {}).isEmpty).length;
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Nộp bài?'),
          content: Text(missing == 0 ? 'Bạn đã trả lời đủ ${q.questions.length} câu.' : 'Bạn còn $missing câu chưa trả lời. Nộp rồi sẽ không làm lại được.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Làm tiếp')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Nộp bài')),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() => _busy = true);
    final api = AppScope.of(context).api;
    await runGuarded(context, () async {
      final r = await api.post('/quizzes/${q.id}/submit', {
        'answers': {for (final e in _answers.entries) e.key: e.value.toList()},
      });
      _ticker?.cancel();
      setState(() {
        _quiz = Quiz.fromJson(r);
        _left = null;
      });
    }, success: auto ? 'Hết giờ, bài đã được nộp tự động' : 'Đã nộp bài');
    if (mounted) setState(() => _busy = false);
  }

  String _fmt(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final q = _quiz;
    final scheme = Theme.of(context).colorScheme;
    if (q == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: _error != null ? Text(_error.toString()) : const CircularProgressIndicator()),
      );
    }
    final a = q.attempt;
    final taking = a != null && !a.submitted;
    return Scaffold(
      appBar: AppBar(
        title: Text(q.title),
        actions: [
          if (taking && _left != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: const Icon(Icons.timer_outlined, size: 18),
                label: Text(_fmt(_left!), style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                backgroundColor: _left! < const Duration(minutes: 1) ? scheme.errorContainer : null,
              ),
            ),
        ],
      ),
      bottomNavigationBar: taking
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _submit(),
                  icon: const Icon(Icons.send),
                  label: Text('Nộp bài (${_answers.values.where((s) => s.isNotEmpty).length}/${q.questions.length} câu đã làm)'),
                ),
              ),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (a == null) ..._intro(q),
            if (taking) ..._questions(q),
            if (a != null && a.submitted) ..._review(q, a),
          ]),
        ),
      ),
    );
  }

  List<Widget> _intro(Quiz q) => [
        Text(q.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (q.description.isNotEmpty) Text(q.description),
        const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.help_outline), title: Text('${q.questionCount} câu hỏi, tổng ${fmtScore(q.maxScore)} điểm')),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: Text(q.durationMinutes == null ? 'Không giới hạn thời gian' : 'Thời gian làm bài: ${q.durationMinutes} phút'),
          subtitle: q.durationMinutes == null ? null : const Text('Đồng hồ bắt đầu chạy khi bạn bấm "Bắt đầu". Hết giờ bài tự nộp.'),
        ),
        if (q.dueAt != null) ListTile(leading: const Icon(Icons.event), title: Text('Hạn chót: ${fmtDateTime(q.dueAt!)}')),
        const ListTile(leading: Icon(Icons.info_outline), title: Text('Mỗi bạn chỉ được làm một lần.')),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy || q.overdue ? null : _start,
          icon: const Icon(Icons.play_arrow),
          label: Text(q.overdue ? 'Đã quá hạn' : 'Bắt đầu làm bài'),
        ),
      ];

  List<Widget> _questions(Quiz q) => [
        for (var i = 0; i < q.questions.length; i++)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Câu ${i + 1}. ${q.questions[i].text}', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (q.questions[i].multiple)
                  Text('Chọn tất cả đáp án đúng', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.tertiary)),
                const SizedBox(height: 4),
                for (var k = 0; k < q.questions[i].options.length; k++) _option(q.questions[i], k),
              ]),
            ),
          ),
        const SizedBox(height: 24),
      ];

  Widget _option(QuizQuestion question, int k) {
    final sel = _answers[question.id] ?? {};
    final on = sel.contains(k);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        question.multiple ? (on ? Icons.check_box : Icons.check_box_outline_blank) : (on ? Icons.radio_button_checked : Icons.radio_button_unchecked),
        color: on ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text('${String.fromCharCode(65 + k)}. ${question.options[k]}'),
      onTap: () => setState(() {
        final s = _answers.putIfAbsent(question.id, () => <int>{});
        if (question.multiple) {
          on ? s.remove(k) : s.add(k);
        } else {
          s
            ..clear()
            ..add(k);
        }
      }),
    );
  }

  List<Widget> _review(Quiz q, QuizAttempt a) => [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: const Icon(Icons.grade, size: 32),
            title: Text('Điểm: ${fmtScore(a.score ?? 0)}/${fmtScore(a.maxScore)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            subtitle: Text('Nộp lúc ${fmtDateTime(a.submittedAt!)}${a.late ? ' (muộn)' : ''}'),
          ),
        ),
        const SizedBox(height: 8),
        if (!q.showAnswers) const Text('Giáo viên chưa cho xem đáp án của bài này.'),
        for (var i = 0; i < q.questions.length; i++)
          _QuestionReview(index: i, question: q.questions[i], chosen: a.answers[q.questions[i].id] ?? const []),
      ];
}
