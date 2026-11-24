import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';

/// Kết nối video/âm thanh của phòng học qua LiveKit.
class VideoCall extends ChangeNotifier {
  final Room room = Room(
    roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
  );
  EventsListener<RoomEvent>? _listener;
  bool connecting = false;
  bool connected = false;
  String? error;

  bool get micOn => room.localParticipant?.isMicrophoneEnabled() ?? false;
  bool get camOn => room.localParticipant?.isCameraEnabled() ?? false;
  bool get sharing => room.localParticipant?.isScreenShareEnabled() ?? false;

  /// Mọi người trong phòng, mình đứng đầu.
  List<Participant> get participants => [
        if (room.localParticipant != null) room.localParticipant!,
        ...room.remoteParticipants.values,
      ];

  Future<void> connect(String url, String token) async {
    connecting = true;
    error = null;
    notifyListeners();
    _listener = room.createListener()..listen((_) => notifyListeners());
    try {
      await room.connect(url, token).timeout(const Duration(seconds: 12));
      connected = true;
    } catch (e) {
      error = 'Chưa kết nối được máy chủ video ($url). Bảng trắng vẫn dùng bình thường.';
    }
    connecting = false;
    notifyListeners();
  }

  Future<String?> _toggle(Future<void> Function() action, String what) async {
    try {
      await action();
      notifyListeners();
      return null;
    } catch (e) {
      notifyListeners();
      return 'Không bật được $what. Kiểm tra quyền truy cập $what của trình duyệt/máy.';
    }
  }

  Future<String?> toggleMic() => _toggle(() async => room.localParticipant?.setMicrophoneEnabled(!micOn), 'micro');
  Future<String?> toggleCam() => _toggle(() async => room.localParticipant?.setCameraEnabled(!camOn), 'camera');
  Future<String?> toggleShare() => _toggle(() async => room.localParticipant?.setScreenShareEnabled(!sharing), 'chia sẻ màn hình');

  @override
  void dispose() {
    _listener?.dispose();
    unawaited(room.disconnect().then((_) => room.dispose()));
    super.dispose();
  }
}

/// Dải khung hình người tham gia (dọc khi màn hình rộng, ngang khi điện thoại).
class VideoPanel extends StatelessWidget {
  final VideoCall call;
  final Axis axis;
  const VideoPanel({super.key, required this.call, required this.axis});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: call,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        if (!call.connected) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: call.connecting
                  ? const Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Đang kết nối video...'),
                    ])
                  : Text(call.error ?? '', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ),
          );
        }
        final tiles = <Widget>[];
        for (final p in call.participants) {
          for (final pub in p.videoTrackPublications) {
            if (pub.source == TrackSource.screenShareVideo && pub.track != null && !pub.muted) {
              tiles.add(_Tile(participant: p, track: pub.track as VideoTrack, screen: true));
            }
          }
          final cam = p.videoTrackPublications.where((t) => t.source == TrackSource.camera && t.track != null && !t.muted).firstOrNull;
          tiles.add(_Tile(participant: p, track: cam?.track as VideoTrack?));
        }
        return ListView.separated(
          scrollDirection: axis,
          padding: const EdgeInsets.all(8),
          itemCount: tiles.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8, height: 8),
          itemBuilder: (_, i) => SizedBox(
            width: axis == Axis.horizontal ? 160 : null,
            height: axis == Axis.vertical ? 150 : null,
            child: tiles[i],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final Participant participant;
  final VideoTrack? track;
  final bool screen;
  const _Tile({required this.participant, this.track, this.screen = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = participant;
    final name = p.name.isNotEmpty ? p.name : p.identity;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF263238),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.isSpeaking && !screen ? Colors.greenAccent : Colors.transparent, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          if (track != null)
            VideoTrackRenderer(track!, fit: screen ? VideoViewFit.contain : VideoViewFit.cover)
          else
            Center(
              child: CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primaryContainer,
                child: Text(name.characters.first.toUpperCase(), style: const TextStyle(fontSize: 22)),
              ),
            ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Row(children: [
              if (!screen && p.isMuted) const Icon(Icons.mic_off, size: 14, color: Colors.redAccent),
              if (screen) const Icon(Icons.screen_share, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${screen ? 'Màn hình: ' : ''}$name${p is LocalParticipant ? ' (bạn)' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, shadows: [Shadow(blurRadius: 3)]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
