import '../models/listener_link.dart';
import '../models/public_channel.dart';
import 'livekit_service.dart';

class LiveKitPlaybackController {
  LiveKitPlaybackController({
    LiveKitService? liveKitService,
  }) : _liveKitService = liveKitService ?? LiveKitService();

  final LiveKitService _liveKitService;

  ListenerLink? _activeLink;
  PublicChannelContext? _activeChannelContext;

  Stream<LiveKitPlaybackSnapshot> get snapshots => _liveKitService.snapshots;

  LiveKitPlaybackSnapshot get snapshot => _liveKitService.snapshot;

  ListenerLink? get activeLink => _activeLink;

  PublicChannelContext? get activeChannelContext => _activeChannelContext;

  bool get hasActiveSession =>
      _activeLink != null && _activeChannelContext != null;

  Future<void> connect({
    required ListenerLink link,
    required PublicChannelContext channelContext,
  }) async {
    _activeLink = link;
    _activeChannelContext = channelContext;
    await _liveKitService.connect(link: link, channelContext: channelContext);
  }

  Future<void> reconnectActiveSession() async {
    final link = _activeLink;
    final context = _activeChannelContext;
    if (link == null || context == null) {
      return;
    }
    await connect(link: link, channelContext: context);
  }

  Future<void> disconnect({bool keepSession = false, String? message}) async {
    await _liveKitService.disconnect(message: message);
    if (!keepSession) {
      _activeLink = null;
      _activeChannelContext = null;
    }
  }

  Future<void> pauseForRouteChange() {
    return disconnect(
      keepSession: true,
      message: 'Playback paused because audio output disconnected.',
    );
  }

  Future<void> setMuted(bool muted) => _liveKitService.setMuted(muted);

  Future<void> toggleMuted() => _liveKitService.toggleMuted();

  Future<void> dispose() => _liveKitService.dispose();
}
