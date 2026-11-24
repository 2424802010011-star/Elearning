import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'whiteboard.dart';

/// Kết nối bảng trắng với máy chủ qua WebSocket, tự kết nối lại khi rớt mạng.
class BoardSync {
  final Uri uri;
  final WhiteboardController board;
  final void Function(bool canWrite) onCanWrite;
  final void Function() onEnded;
  final void Function(String message)? onError;
  final void Function(bool connected)? onConnection;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _retry, _ping;
  bool _closed = false;

  BoardSync({
    required String apiBaseUrl,
    required String meetingId,
    required String token,
    required this.board,
    required this.onCanWrite,
    required this.onEnded,
    this.onError,
    this.onConnection,
  }) : uri = _wsUri(apiBaseUrl, meetingId, token) {
    board.onPatch = (upserts, removed) => _send({
          'type': 'patch',
          'upserts': [for (final s in upserts) s.toJson()],
          'removed': removed,
        });
    board.onClear = () => _send({'type': 'clear'});
    _connect();
  }

  static Uri _wsUri(String api, String meetingId, String token) {
    final base = Uri.parse(api.replaceAll(RegExp(r'/api/?$'), ''));
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path}/ws/board',
      queryParameters: {'meetingId': meetingId, 'token': token},
    );
  }

  void _connect() {
    if (_closed) return;
    final ch = WebSocketChannel.connect(uri);
    _ch = ch;
    _sub = ch.stream.listen(
      _onMessage,
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
      cancelOnError: true,
    );
    ch.ready.then((_) => onConnection?.call(true)).catchError((_) {});
    _ping?.cancel();
    _ping = Timer.periodic(const Duration(seconds: 25), (_) => _send({'type': 'ping'}));
  }

  void _scheduleReconnect() {
    onConnection?.call(false);
    _ping?.cancel();
    if (_closed) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 2), _connect);
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _ch?.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  List<Stroke> _strokes(dynamic list) => [for (final j in (list as List? ?? [])) Stroke.fromJson(j as Map<String, dynamic>)];

  void _onMessage(dynamic data) {
    final m = jsonDecode(data as String) as Map<String, dynamic>;
    switch (m['type']) {
      case 'snapshot':
        board.applySnapshot(_strokes(m['strokes']));
        onCanWrite(m['canWrite'] == true);
      case 'patch':
        board.applyPatch(_strokes(m['upserts']), [for (final id in (m['removed'] as List? ?? [])) id as String]);
      case 'clear':
        board.applyClear();
      case 'permissions':
        onCanWrite(m['canWrite'] == true);
      case 'ended':
        _closed = true;
        onEnded();
      case 'error':
        onError?.call(m['message']?.toString() ?? 'Lỗi bảng trắng');
    }
  }

  void dispose() {
    _closed = true;
    _retry?.cancel();
    _ping?.cancel();
    _sub?.cancel();
    _ch?.sink.close();
    board.onPatch = null;
    board.onClear = null;
  }
}
