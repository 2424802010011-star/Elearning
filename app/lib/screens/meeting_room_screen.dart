import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../ink/beautify.dart';
import '../ink/whiteboard.dart';
import '../models.dart';
import '../ui.dart';

/// Phòng học: bảng trắng + quyền viết. Video/âm thanh qua LiveKit sẽ gắn vào khung phía trên.
class MeetingRoomScreen extends StatefulWidget {
  final Meeting meeting;
  final Classroom classroom;
  final Map<String, dynamic> joinInfo;
  const MeetingRoomScreen({super.key, required this.meeting, required this.classroom, required this.joinInfo});
  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  final board = WhiteboardController();
  late bool canWrite = widget.joinInfo['canWriteBoard'] == true;
  late final bool isHost = widget.joinInfo['isHost'] == true;
  Timer? _poll;

  static const _colors = [Colors.black, Color(0xFF1565C0), Color(0xFFC62828), Color(0xFF2E7D32), Color(0xFFEF6C00)];

  @override
  void initState() {
    super.initState();
    if (!isHost) {
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refreshPermission());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    board.dispose();
    super.dispose();
  }

  Future<void> _refreshPermission() async {
    try {
      final p = await AppScope.of(context).api.get('/meetings/${widget.meeting.id}/whiteboard/permissions');
      final now = p['canWrite'] == true;
      if (now != canWrite && mounted) {
        setState(() => canWrite = now);
        showMsg(context, now ? 'Giáo viên đã cho phép bạn viết lên bảng' : 'Giáo viên đã thu quyền viết bảng');
      }
    } catch (_) {
      // Mất kết nối tạm thời: thử lại ở lần sau.
    }
  }

  void _onBeautified(Stroke s) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 3),
      content: Text('AI đã nắn thành: ${shapeLabel(s.kind)}'),
      action: SnackBarAction(label: 'Giữ nét gốc', onPressed: () => board.revertToOriginal(s)),
    ));
  }

  Future<void> _end() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kết thúc buổi học?'),
        content: const Text('Mọi học sinh sẽ rời phòng và quyền viết bảng bị thu lại.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kết thúc')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final api = AppScope.of(context).api;
    final done = await runGuarded(context, () => api.post('/meetings/${widget.meeting.id}/end'));
    if (done && mounted) Navigator.pop(context);
  }

  Future<void> _permissions() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PermissionSheet(meetingId: widget.meeting.id, classId: widget.classroom.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.meeting.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (isHost) IconButton(tooltip: 'Quyền viết bảng', icon: const Icon(Icons.edit_note), onPressed: _permissions),
          if (isHost)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _end,
                icon: const Icon(Icons.call_end),
                label: const Text('Kết thúc'),
              ),
            ),
        ],
      ),
      body: Column(children: [
        Material(
          color: scheme.surfaceContainerHigh,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.videocam_outlined),
            title: Text('${widget.classroom.name} · phòng ${widget.joinInfo['roomName'].toString().substring(9, 17)}'),
            subtitle: Text(isHost
                ? 'Bạn là người dạy. Video/âm thanh kết nối tới ${widget.joinInfo['livekitUrl']}'
                : (canWrite ? 'Bạn đang được phép viết lên bảng' : 'Bạn đang xem bảng. Chờ giáo viên cho phép viết.')),
          ),
        ),
        if (canWrite) _Toolbar(board: board, colors: _colors, isHost: isHost),
        const Divider(height: 1),
        Expanded(
          child: WhiteboardCanvas(controller: board, enabled: canWrite, onBeautified: _onBeautified),
        ),
      ]),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final WhiteboardController board;
  final List<Color> colors;
  final bool isHost;
  const _Toolbar({required this.board, required this.colors, required this.isHost});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: board,
      builder: (context, _) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          IconButton(
            tooltip: 'Bút',
            isSelected: board.tool == BoardTool.pen,
            icon: const Icon(Icons.edit),
            onPressed: () => board.setTool(BoardTool.pen),
          ),
          IconButton(
            tooltip: 'Tẩy',
            isSelected: board.tool == BoardTool.eraser,
            icon: const Icon(Icons.auto_fix_normal),
            onPressed: () => board.setTool(BoardTool.eraser),
          ),
          const SizedBox(width: 8),
          for (final c in colors)
            GestureDetector(
              onTap: () => board.setColor(c),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: board.color == c ? Theme.of(context).colorScheme.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          for (final w in [2.0, 4.0, 8.0])
            IconButton(
              tooltip: 'Nét ${w.toInt()}',
              isSelected: board.width == w,
              icon: Icon(Icons.circle, size: 6 + w * 1.5),
              onPressed: () => board.setWidth(w),
            ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('AI làm đẹp nét'),
            selected: board.aiEnabled,
            onSelected: board.setAi,
          ),
          IconButton(tooltip: 'Hoàn tác', icon: const Icon(Icons.undo), onPressed: board.canUndo ? board.undo : null),
          if (isHost) IconButton(tooltip: 'Xóa bảng', icon: const Icon(Icons.delete_sweep_outlined), onPressed: board.clear),
        ]),
      ),
    );
  }
}

class _PermissionSheet extends StatefulWidget {
  final String meetingId;
  final String classId;
  const _PermissionSheet({required this.meetingId, required this.classId});
  @override
  State<_PermissionSheet> createState() => _PermissionSheetState();
}

class _PermissionSheetState extends State<_PermissionSheet> {
  List<Enrollment> _students = [];
  Set<String> _writers = {};
  bool _allowAll = false;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    await runGuarded(context, () async {
      final list = await api.get('/classes/${widget.classId}/enrollments?status=approved');
      final p = await api.get('/meetings/${widget.meetingId}/whiteboard/permissions');
      setState(() {
        _students = [for (final j in list) Enrollment.fromJson(j)];
        _writers = {for (final w in p['writers']) w as String};
        _allowAll = p['allowAll'] == true;
        _loading = false;
      });
    });
  }

  Future<void> _save({bool? allowAll}) async {
    final api = AppScope.of(context).api;
    await runGuarded(context, () async {
      final p = await api.put('/meetings/${widget.meetingId}/whiteboard/permissions', {
        'studentIds': _writers.toList(),
        'allowAll': ?allowAll,
      });
      setState(() => _allowAll = p['allowAll'] == true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: ListView(shrinkWrap: true, children: [
          const ListTile(title: Text('Ai được viết lên bảng?', style: TextStyle(fontWeight: FontWeight.bold))),
          SwitchListTile(
            title: const Text('Cả lớp'),
            value: _allowAll,
            onChanged: (v) => _save(allowAll: v),
          ),
          const Divider(),
          for (final e in _students)
            CheckboxListTile(
              title: Text(e.student.fullName),
              subtitle: Text(e.student.email),
              value: _allowAll || _writers.contains(e.student.id),
              onChanged: _allowAll
                  ? null
                  : (v) {
                      setState(() => v == true ? _writers.add(e.student.id) : _writers.remove(e.student.id));
                      _save();
                    },
            ),
          if (_students.isEmpty) const ListTile(title: Text('Lớp chưa có học sinh')),
        ]),
      ),
    );
  }
}
