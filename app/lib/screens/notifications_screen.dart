import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';
import 'class_detail_screen.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? classId;
  final String? tab;
  final DateTime createdAt;
  DateTime? readAt;
  AppNotification.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        type = j['type'],
        title = j['title'],
        body = j['body'] ?? '',
        classId = j['classId'],
        tab = j['tab'],
        createdAt = DateTime.parse(j['createdAt']).toLocal(),
        readAt = j['readAt'] == null ? null : DateTime.parse(j['readAt']).toLocal();
}

IconData _iconFor(String type) => switch (type) {
      'assignment_new' => Icons.assignment_outlined,
      'submission_new' => Icons.assignment_turned_in_outlined,
      'graded' || 'quiz_result' => Icons.grade_outlined,
      'quiz_new' => Icons.quiz_outlined,
      'lesson_new' => Icons.menu_book_outlined,
      'meeting_live' => Icons.videocam_outlined,
      'class_soon' => Icons.alarm,
      'enroll_request' => Icons.person_add_alt,
      'enroll_approved' => Icons.how_to_reg_outlined,
      'enroll_rejected' => Icons.person_off_outlined,
      _ => Icons.notifications_outlined,
    };

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'vừa xong';
  if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
  if (d.inHours < 24) return '${d.inHours} giờ trước';
  if (d.inDays < 7) return '${d.inDays} ngày trước';
  return fmtDateTime(t);
}

/// Danh sách thông báo: bài tập mới, điểm, bài kiểm tra, lớp đang học trực tuyến...
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _f;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final app = AppScope.of(context);
    _f = app.api.get('/notifications?limit=100').then((r) {
      app.unread.value = (r['unreadCount'] as num).toInt();
      return [for (final j in r['items'] as List) AppNotification.fromJson(j)];
    });
  }

  Future<void> _open(AppNotification n) async {
    final app = AppScope.of(context);
    if (n.readAt == null) {
      setState(() => n.readAt = DateTime.now());
      app.unread.value = (app.unread.value - 1).clamp(0, 1 << 30);
      app.api.post('/notifications/${n.id}/read').ignore();
    }
    if (n.classId == null) return;
    await runGuarded(context, () async {
      final c = Classroom.fromJson(await app.api.get('/classes/${n.classId}'));
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ClassDetailScreen(classroom: c, initialTab: n.tab)));
    });
  }

  Future<void> _readAll() async {
    final app = AppScope.of(context);
    if (await runGuarded(context, () => app.api.post('/notifications/read-all'))) {
      app.unread.value = 0;
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo'), actions: [
        IconButton(tooltip: 'Tải lại', icon: const Icon(Icons.refresh), onPressed: () => setState(_load)),
        TextButton.icon(onPressed: _readAll, icon: const Icon(Icons.done_all), label: const Text('Đã đọc hết')),
      ]),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _f;
        },
        child: AsyncView<List<AppNotification>>(
          future: _f,
          onRetry: () => setState(_load),
          builder: (list) => list.isEmpty
              ? ListView(children: const [EmptyState(icon: Icons.notifications_none, text: 'Chưa có thông báo nào')])
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = list[i];
                    final unread = n.readAt == null;
                    return ListTile(
                      tileColor: unread ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
                      leading: CircleAvatar(child: Icon(_iconFor(n.type))),
                      title: Text(n.title, style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text('${n.body.isEmpty ? '' : '${n.body}\n'}${timeAgo(n.createdAt)}'),
                      isThreeLine: n.body.isNotEmpty,
                      trailing: unread ? Icon(Icons.circle, size: 10, color: scheme.primary) : null,
                      onTap: () => _open(n),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
