import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_session/audio_session.dart';
import 'package:livekit_client/livekit_client.dart';

import '../models/listener_link.dart';
import '../models/public_channel.dart';
import 'stream_connection_service.dart';
import 'undersound_api_client.dart';

class LiveKitPlaybackSnapshot {
  const LiveKitPlaybackSnapshot({
    required this.phase,
    required this.connected,
    this.message,
    this.lastErrorDetail,
    this.livekitRoomConnected = false,
  });

  final StreamConnectionPhase phase;
  final bool connected;
  final String? message;
  final String? lastErrorDetail;
  final bool livekitRoomConnected;

  LiveKitPlaybackSnapshot copyWith({
    StreamConnectionPhase? phase,
    bool? connected,
    String? message,
    String? lastErrorDetail,
    bool clearErrorDetail = false,
    bool clearMessage = false,
    bool? livekitRoomConnected,
  }) {
    return LiveKitPlaybackSnapshot(
      phase: phase ?? this.phase,
      connected: connected ?? this.connected,
      message: clearMessage ? null : (message ?? this.message),
      lastErrorDetail:
          clearErrorDetail ? null : (lastErrorDetail ?? this.lastErrorDetail),
      livekitRoomConnected:
          livekitRoomConnected ?? this.livekitRoomConnected,
    );
  }
}

/// Lowest-latency LiveKit subscriber session for Undersound channels.
///
/// Background audio: unlike HLS routed through audio_service / just_audio,
/// LiveKit follows WebRTC's audio pipeline. Platforms may suspend or mute
/// WebRTC when backgrounded unless a foreground service manages the session,
/// unlike the [audio_service]/HLS path. Behavior here is **best-effort only**.
class LiveKitService {
  LiveKitService({UnderSoundApiClient api = const UnderSoundApiClient()})
      : _api = api;

  final UnderSoundApiClient _api;

  StreamController<LiveKitPlaybackSnapshot>? _snapshotController;

  LiveKitPlaybackSnapshot _snapshot = const LiveKitPlaybackSnapshot(
    phase: StreamConnectionPhase.idle,
    connected: false,
  );

  Room? _room;
  CancelListenFunc? _cancelListen;
  bool _intentToDisconnect = false;
  Completer<void>? _connectCompleter;

  Stream<LiveKitPlaybackSnapshot> get snapshots {
    final c = _snapshotController ??=
        StreamController<LiveKitPlaybackSnapshot>.broadcast();
    return c.stream;
  }

  LiveKitPlaybackSnapshot get snapshot => _snapshot;

  Future<void> connect({
    required ListenerLink link,
    required PublicChannelContext channelContext,
    String? roomNameOverride,
    String? participantIdentityOverride,
  }) async {
    if (_connectCompleter != null) {
      await _connectCompleter!.future;
    }

    await disconnect();

    final completer = Completer<void>();
    _connectCompleter = completer;

    try {
      _emit(
        _snapshot.copyWith(
          phase: StreamConnectionPhase.connecting,
          message: 'Connecting (WebRTC)...',
          connected: false,
          clearErrorDetail: true,
          livekitRoomConnected: false,
        ),
      );

      await _ensureAudioSession();
      final cred = await _api.fetchLiveKitToken(
        serverUrl: link.serverUrl,
        listenerToken: link.token,
        channelId: channelContext.channel.id,
        room: roomNameOverride,
        identity: participantIdentityOverride,
      );
      await _openRoom(link, channelContext, cred.url, cred.token);
    } on ApiException catch (e) {
      _emitFailed(e.message);
      rethrow;
    } catch (e, stack) {
      developer.log(
        'LiveKit connection failed.',
        name: 'UnderSound.WebRTC',
        error: e,
        stackTrace: stack,
      );
      _emitFailed(_humanizeLiveKitError(e));
      rethrow;
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      _connectCompleter = null;
    }
  }

  Future<void> disconnect() async {
    _intentToDisconnect = true;
    try {
      await _shutdownRoomOnly();
      _snapshot = const LiveKitPlaybackSnapshot(
        phase: StreamConnectionPhase.idle,
        connected: false,
      );
      _broadcast();
    } catch (error, stack) {
      developer.log(
        'LiveKit teardown failed.',
        name: 'UnderSound.WebRTC',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _intentToDisconnect = false;
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _snapshotController?.close();
    _snapshotController = null;
  }

  Future<void> _openRoom(
    ListenerLink link,
    PublicChannelContext ctx,
    String url,
    String token,
  ) async {
    final room = Room();
    _room = room;
    await room.prepareConnection(url, token);

    final listener = room.createListener();
    _cancelListen = listener.listen(_handleLiveKitRoomEvent);

    await room.connect(
      url,
      token,
      connectOptions: const ConnectOptions(autoSubscribe: true),
      fastConnectOptions: FastConnectOptions(
        microphone: const TrackOption(enabled: false),
        camera: const TrackOption(enabled: false),
      ),
    );

    await _primeExisting(room);

    final hasReceiver = remoteAudioPresent(room);

    final roomLabel = '${ctx.event.name} · ${ctx.channel.name}';
    final hostSuffix = link.serverUrl.hasAuthority ? ' · ${link.serverUrl.host}' : '';

    _emit(
      LiveKitPlaybackSnapshot(
        phase: StreamConnectionPhase.connected,
        connected: true,
        message: hasReceiver
            ? 'Listening (WebRTC) — $roomLabel$hostSuffix'
            : 'Connected via WebRTC — waiting for speaker — $roomLabel$hostSuffix',
        lastErrorDetail: null,
        livekitRoomConnected: true,
      ),
    );
  }

  bool remoteAudioPresent(Room room) {
    for (final p in room.remoteParticipants.values) {
      for (final pub in p.audioTrackPublications) {
        final t = pub.track;
        if (t is RemoteAudioTrack && t.kind == TrackType.AUDIO && t.isActive) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _ensureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> _tearDownListeners() async {
    await _cancelListen?.call();
    _cancelListen = null;
  }

  Future<void> _handleLiveKitRoomEvent(LiveKitEvent event) async {
    if (_room == null || _intentToDisconnect) {
      return;
    }
    final room = _room!;

    if (event is RoomReconnectingEvent) {
      _emit(
        _snapshot.copyWith(
          phase: StreamConnectionPhase.reconnecting,
          connected: false,
          message: 'Reconnecting (WebRTC)...',
        ),
      );
      return;
    }

    if (event is RoomReconnectedEvent) {
      final listening = remoteAudioPresent(room);
      _emit(
        _snapshot.copyWith(
          phase: StreamConnectionPhase.connected,
          connected: true,
          message: listening
              ? 'Listening (WebRTC)'
              : 'Connected via WebRTC — waiting for speaker',
        ),
      );
      return;
    }

    if (event is RoomDisconnectedEvent) {
      final reasonDetail = event.reason?.toString();
      if (!_intentToDisconnect) {
        final human = reasonDetail == null || reasonDetail.isEmpty
            ? 'WebRTC disconnected unexpectedly.'
            : 'WebRTC disconnected: $reasonDetail.';
        developer.log(human, name: 'UnderSound.WebRTC');

        await _shutdownRoomOnly();
        _emitFailed(human);
      } else {
        await _shutdownRoomOnly();
      }

      return;
    }

    if (event is TrackSubscribedEvent) {
      developer.log(
        'Track subscribed: ${event.participant.identity} (${event.track.kind}).',
        name: 'UnderSound.WebRTC',
      );
      await _bootstrapAudioTrack(event.track);

      if (_snapshot.livekitRoomConnected) {
        final hasAudio =
            remoteAudioPresent(room);
        _emit(
          _snapshot.copyWith(
            phase: StreamConnectionPhase.connected,
            connected: true,
            message: hasAudio
                ? 'Listening (WebRTC)'
                : 'Connected via WebRTC — waiting for speaker',
          ),
        );
      }

      return;
    }

    if (event is TrackSubscriptionExceptionEvent) {
      final id = event.participant?.identity ?? 'unknown participant';
      final human =
          'WebRTC subscribe failed ($id): ${event.reason}.';
      developer.log(human, name: 'UnderSound.WebRTC');

      await _shutdownRoomOnly();
      _emitFailed(human);
    }
  }

  Future<void> _bootstrapAudioTrack(Track track) async {
    if (track is! RemoteAudioTrack) {
      return;
    }
    try {
      await track.start();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to start RemoteAudioTrack.',
        name: 'UnderSound.WebRTC',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _primeExisting(Room room) async {
    for (final p in room.remoteParticipants.values) {
      for (final pub in p.audioTrackPublications) {
        final t = pub.track;
        if (t is RemoteAudioTrack) {
          await _bootstrapAudioTrack(t);
        }
      }
    }
  }

  String _humanizeLiveKitError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    if (error is LiveKitException) {
      return error.message;
    }
    return error.toString();
  }

  void _emitFailed(String detail) {
    _snapshot = LiveKitPlaybackSnapshot(
      phase: StreamConnectionPhase.failed,
      connected: false,
      livekitRoomConnected: false,
      message: 'WebRTC connection failed.',
      lastErrorDetail: detail,
    );
    _broadcast();
  }

  void _broadcast() {
    _snapshotController?.add(_snapshot);
  }

  void _emit(LiveKitPlaybackSnapshot next) {
    _snapshot = next;
    _broadcast();
  }

  Future<void> _shutdownRoomOnly() async {
    await _tearDownListeners();
    final room = _room;
    if (room == null) {
      return;
    }
    try {
      await room.disconnect();
      await room.dispose();
    } catch (_) {
      //
    }
    _room = null;
  }
}
