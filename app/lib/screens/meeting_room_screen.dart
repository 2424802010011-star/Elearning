import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../ink/beautify.dart';
import '../ink/board_sync.dart';
import '../ink/whiteboard.dart';
import '../meeting/video_call.dart';
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
  BoardSync? _sync;
  final call = VideoCall();
  bool _connected = false;

  static const _colors = [Colors.black, Color(0xFF1565C0), Color(0xFFC62828), Color(0xFF2E7D32), Color(0xFFEF6C00)];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sync != null) return;
    final api = AppScope.of(context).api;
    board.onMathRecognized = _onMath;
    call.connect(widget.joinInfo['livekitUrl'], widget.joinInfo['token']);
    _sync = BoardSync(
      apiBaseUrl: api.baseUrl,
      meetingId: widget.meeting.id,
      token: api.token!,
      board: board,
      onCanWrite: (now) {
        if (!mounted || now == canWrite) return;
        setState(() => canWrite = now);
        if (!isHost) showMsg(context, now ? 'Giáo viên đã cho phép bạn viết lên bảng' : 'Giáo viên đã thu quyền viết bảng');
      },
      onConnection: (c) {
        if (mounted && c != _connected) setState(() => _connected = c);
      },
      onError: (msg) {
        if (mounted) showMsg(context, msg, error: true);
      },
      onEnded: () async {
        if (!mounted) return;
        if (!isHost) {
          await showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Buổi học đã kết thúc'),
              actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Rời phòng'))],
            ),
          );
          if (mounted) Navigator.pop(context);
        }
      },
    );
  }

  @override
  void dispose() {
    _sync?.dispose();
    call.dispose();
    board.dispose();
    super.dispose();
  }

  void _onBeautified(Stroke s) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 3),
      content: Text('AI đã nắn thành: ${shapeLabel(s.kind)}'),
      action: SnackBarAction(label: 'Giữ nét gốc', onPressed: () => board.revertToOriginal(s)),
    ));
  }

  void _onMath(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      content: Text(text.contains('?') ? 'AI đọc được: $text  (dấu ? là nét chưa nhận ra)' : 'AI đọc được: $text'),
      action: SnackBarAction(label: 'Giữ nét gốc', onPressed: board.revertLastMath),
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
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.meeting.title, overflow: TextOverflow.ellipsis),
        actions: [
          _MediaButtons(call: call),
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
            leading: Icon(_connected ? Icons.wifi : Icons.wifi_off, color: _connected ? Colors.green : Colors.orange),
            title: Text('${widget.classroom.name} · phòng ${widget.joinInfo['roomName'].toString().substring(9, 17)}'),
            subtitle: Text([
              _connected ? 'Bảng đang đồng bộ trực tiếp' : 'Đang kết nối bảng...',
              isHost ? 'Bạn là người dạy' : (canWrite ? 'Bạn được phép viết' : 'Chờ giáo viên cho phép viết'),
            ].join(' · ')),
          ),
        ),
        if (canWrite) _Toolbar(board: board, colors: _colors, isHost: isHost),
        const Divider(height: 1),
        Expanded(
          child: wide
              ? Row(children: [
                  Expanded(child: WhiteboardCanvas(controller: board, enabled: canWrite, onBeautified: _onBeautified)),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 240, child: VideoPanel(call: call, axis: Axis.vertical)),
                ])
              : Column(children: [
                  SizedBox(height: 120, child: VideoPanel(call: call, axis: Axis.horizontal)),
                  const Divider(height: 1),
                  Expanded(child: WhiteboardCanvas(controller: board, enabled: canWrite, onBeautified: _onBeautified)),
                ]),
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
          SegmentedButton<AiMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: AiMode.off, label: Text('Viết tự do'), tooltip: 'Giữ nguyên nét viết tay'),
              ButtonSegment(
                value: AiMode.shapes,
                icon: Icon(Icons.auto_awesome, size: 18),
                label: Text('AI hình'),
                tooltip: 'Nắn đường thẳng, hình học, đồ thị sin',
              ),
              ButtonSegment(
                value: AiMode.math,
                icon: Icon(Icons.functions, size: 18),
                label: Text('AI chữ & toán'),
                tooltip: 'Đọc chữ số, chữ, ký hiệu toán, phân số, căn và viết lại cho gọn',
              ),
            ],
            selected: {board.aiMode},
            onSelectionChanged: (v) => board.setAiMode(v.first),
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

class _MediaButtons extends StatelessWidget {
  final VideoCall call;
  const _MediaButtons({required this.call});

  Future<void> _run(BuildContext context, Future<String?> Function() f) async {
    final err = await f();
    if (err != null && context.mounted) showMsg(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: call,
      builder: (context, _) {
        if (!call.connected) return const SizedBox.shrink();
        return Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: call.micOn ? 'Tắt micro' : 'Bật micro',
            icon: Icon(call.micOn ? Icons.mic : Icons.mic_off, color: call.micOn ? null : Colors.red),
            onPressed: () => _run(context, call.toggleMic),
          ),
          IconButton(
            tooltip: call.camOn ? 'Tắt camera' : 'Bật camera',
            icon: Icon(call.camOn ? Icons.videocam : Icons.videocam_off, color: call.camOn ? null : Colors.red),
            onPressed: () => _run(context, call.toggleCam),
          ),
          IconButton(
            tooltip: call.sharing ? 'Dừng chia sẻ màn hình' : 'Chia sẻ màn hình',
            isSelected: call.sharing,
            icon: const Icon(Icons.screen_share_outlined),
            selectedIcon: const Icon(Icons.stop_screen_share),
            onPressed: () => _run(context, call.toggleShare),
          ),
        ]);
      },
    );
  }
}
