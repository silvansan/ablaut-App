import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/listener_link.dart';
import '../models/public_channel.dart';
import 'android_power_service.dart';
import 'hls_service.dart';
import 'undersound_api_client.dart';

enum UnderSoundPlaybackStatus {
  idle,
  connecting,
  buffering,
  playing,
  paused,
  reconnecting,
  waiting,
  error,
}

extension UnderSoundPlaybackStatusLabel on UnderSoundPlaybackStatus {
  String get label {
    return switch (this) {
      UnderSoundPlaybackStatus.idle => 'Ready',
      UnderSoundPlaybackStatus.connecting => 'Connecting',
      UnderSoundPlaybackStatus.buffering => 'Buffering',
      UnderSoundPlaybackStatus.playing => 'Playing',
      UnderSoundPlaybackStatus.paused => 'Paused',
      UnderSoundPlaybackStatus.reconnecting => 'Reconnecting',
      UnderSoundPlaybackStatus.waiting => 'Waiting for speaker',
      UnderSoundPlaybackStatus.error => 'Audio stream not available',
    };
  }
}

class UnderSoundPlaybackSnapshot {
  const UnderSoundPlaybackSnapshot({
    required this.status,
    required this.playing,
    this.message,
  });

  final UnderSoundPlaybackStatus status;
  final bool playing;
  final String? message;

  String get displayText => message ?? status.label;
}

class UnderSoundStreamRequest {
  const UnderSoundStreamRequest({
    required this.link,
    required this.channelContext,
  });

  final ListenerLink link;
  final PublicChannelContext channelContext;
}

class UnderSoundAudioService {
  UnderSoundAudioService._();

  static final UnderSoundAudioService instance = UnderSoundAudioService._();

  UnderSoundAudioHandler? _handler;

  UnderSoundAudioHandler get handler {
    final handler = _handler;
    if (handler == null) {
      throw StateError('UnderSound audio service has not been initialized.');
    }
    return handler;
  }

  Future<void> initialize() async {
    if (_handler != null) {
      return;
    }

    _handler = await AudioService.init<UnderSoundAudioHandler>(
      builder: UnderSoundAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.undersound.mobile.playback',
        androidNotificationChannelName: 'UnderSound is playing',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }
}

class UnderSoundAudioHandler extends BaseAudioHandler {
  UnderSoundAudioHandler({
    UnderSoundApiClient apiClient = const UnderSoundApiClient(),
    AndroidPowerService powerService = const AndroidPowerService(),
  }) : _hlsService = HlsService(apiClient),
       _powerService = powerService {
    _configure();
  }

  static const _retryBaseDelay = Duration(seconds: 2);
  static const _maxRetryDelay = Duration(seconds: 30);
  static const _bufferingReconnectDelay = Duration(seconds: 20);

  final HlsService _hlsService;
  final AndroidPowerService _powerService;
  final AudioPlayer _player = AudioPlayer();
  final _snapshotController =
      StreamController<UnderSoundPlaybackSnapshot>.broadcast();

  UnderSoundStreamRequest? _request;
  Uri? _currentUrl;
  bool _wantsPlayback = false;
  bool _reconnecting = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;
  Timer? _bufferingTimer;
  StreamSubscription<PlaybackEvent>? _playbackEventSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  Stream<UnderSoundPlaybackSnapshot> get snapshots =>
      _snapshotController.stream;

  UnderSoundPlaybackSnapshot get snapshot => UnderSoundPlaybackSnapshot(
    status: _status,
    playing: _player.playing,
    message: _message,
  );

  UnderSoundPlaybackStatus _status = UnderSoundPlaybackStatus.idle;
  String? _message;

  Future<void> playUnderSound(UnderSoundStreamRequest request) async {
    _request = request;
    _wantsPlayback = true;
    _retryAttempt = 0;
    developer.log(
      'Starting UnderSound playback for channel ${request.channelContext.channel.id}.',
      name: 'UnderSound.Audio',
    );
    await _powerService.requestPostNotificationsPermission();
    await _setKeepAlive(true);
    await _loadAndPlay(refreshUrl: true);
  }

  Future<HlsStatus> refreshHlsStatus(UnderSoundStreamRequest request) {
    return _loadHlsStatus(request);
  }

  @override
  Future<void> play() async {
    final request = _request;
    if (request == null) {
      return;
    }
    _wantsPlayback = true;
    await _setKeepAlive(true);
    if (_currentUrl == null) {
      await _loadAndPlay(refreshUrl: true);
      return;
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _wantsPlayback = false;
    _retryTimer?.cancel();
    _bufferingTimer?.cancel();
    await _player.pause();
    await _setKeepAlive(false);
    _setStatus(UnderSoundPlaybackStatus.paused);
  }

  @override
  Future<void> stop() async {
    _wantsPlayback = false;
    _retryTimer?.cancel();
    _bufferingTimer?.cancel();
    await _player.stop();
    await _setKeepAlive(false);
    _setStatus(UnderSoundPlaybackStatus.idle);
    return super.stop();
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    _bufferingTimer?.cancel();
    await _playbackEventSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _player.dispose();
    await _snapshotController.close();
  }

  Future<void> _configure() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _playbackEventSubscription = _player.playbackEventStream.listen(
      (event) {
        playbackState.add(_transformEvent(event));
      },
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Playback event error.',
          name: 'UnderSound.Audio',
          error: error,
          stackTrace: stackTrace,
        );
        _scheduleReconnect('Audio connection changed.');
      },
    );

    _playerStateSubscription = _player.playerStateStream.listen(
      _handlePlayerState,
    );
  }

  Future<void> _loadAndPlay({required bool refreshUrl}) async {
    final request = _request;
    if (request == null) {
      return;
    }

    try {
      _setStatus(
        _reconnecting
            ? UnderSoundPlaybackStatus.reconnecting
            : UnderSoundPlaybackStatus.connecting,
      );
      final url = refreshUrl || _currentUrl == null
          ? await _resolveStreamUrl(request)
          : _currentUrl;

      if (url == null) {
        _setStatus(
          UnderSoundPlaybackStatus.waiting,
          'HLS is not running yet. Ask the speaker to start publishing.',
        );
        _scheduleReconnect('HLS status is not active.');
        return;
      }

      _currentUrl = url;
      developer.log(
        'Resolved HLS URL: $url',
        name: 'UnderSound.Audio',
      );
      mediaItem.add(
        MediaItem(
          id: url.toString(),
          title: 'UnderSound is playing',
          album: request.channelContext.event.name,
          artist: request.channelContext.channel.name,
          extras: {'url': url.toString()},
        ),
      );

      await _player.setAudioSource(
        AudioSource.uri(
          url,
          tag: MediaItem(
            id: url.toString(),
            title: 'UnderSound is playing',
            album: request.channelContext.event.name,
            artist: request.channelContext.channel.name,
          ),
        ),
      );
      await _player.play();
      developer.log(
        'Playback started: duration=${_player.duration}, '
        'position=${_player.position}, buffered=${_player.bufferedPosition}, '
        'processing=${_player.processingState}.',
        name: 'UnderSound.Audio',
      );
      _retryAttempt = 0;
      _reconnecting = false;
      _setStatus(UnderSoundPlaybackStatus.playing);
    } catch (error, stackTrace) {
      developer.log(
        'Unable to start HLS stream.',
        name: 'UnderSound.Audio',
        error: error,
        stackTrace: stackTrace,
      );
      _scheduleReconnect('Audio stream not available. Reconnecting...');
    }
  }

  Future<Uri?> _resolveStreamUrl(UnderSoundStreamRequest request) async {
    final url = await _hlsService.resolvePlayableUrl(
      serverUrl: request.link.serverUrl,
      channelId: request.channelContext.channel.id,
      token: request.link.token,
    );
    if (url == null) {
      developer.log(
        'HLS URL could not be resolved (inactive, ended, or stale playlist).',
        name: 'UnderSound.Audio',
      );
    }
    return url;
  }

  Future<HlsStatus> _loadHlsStatus(UnderSoundStreamRequest request) {
    return _hlsService.loadRawStatus(
      serverUrl: request.link.serverUrl,
      channelId: request.channelContext.channel.id,
      token: request.link.token,
    );
  }

  void _handlePlayerState(PlayerState state) {
    developer.log(
      'Player state: playing=${state.playing}, processing=${state.processingState}, '
      'position=${_player.position}, buffered=${_player.bufferedPosition}, '
      'duration=${_player.duration}.',
      name: 'UnderSound.Audio',
    );

    if (state.processingState == ProcessingState.buffering ||
        state.processingState == ProcessingState.loading) {
      if (_wantsPlayback) {
        _setStatus(UnderSoundPlaybackStatus.buffering);
        _startBufferingWatchdog();
      }
      return;
    }

    _bufferingTimer?.cancel();

    if (state.playing && state.processingState == ProcessingState.ready) {
      _setStatus(UnderSoundPlaybackStatus.playing);
      return;
    }

    if (!state.playing && !_wantsPlayback) {
      _setStatus(UnderSoundPlaybackStatus.paused);
      return;
    }

    if (_wantsPlayback &&
        (state.processingState == ProcessingState.idle ||
            state.processingState == ProcessingState.completed)) {
      developer.log(
        'Playback reached ${state.processingState}; current URL=$_currentUrl.',
        name: 'UnderSound.Audio',
      );
      _scheduleReconnect('Playback stopped unexpectedly.');
    }
  }

  void _startBufferingWatchdog() {
    if (_bufferingTimer?.isActive ?? false) {
      return;
    }
    _bufferingTimer = Timer(_bufferingReconnectDelay, () {
      if (!_wantsPlayback) {
        return;
      }
      _scheduleReconnect('Stream is still buffering.');
    });
  }

  void _scheduleReconnect(String reason) {
    if (!_wantsPlayback) {
      return;
    }

    _retryTimer?.cancel();
    _reconnecting = true;
    _setStatus(UnderSoundPlaybackStatus.reconnecting, 'Reconnecting...');
    final delaySeconds =
        (_retryBaseDelay.inSeconds * (1 << _retryAttempt)).clamp(
          _retryBaseDelay.inSeconds,
          _maxRetryDelay.inSeconds,
        );
    _retryAttempt = (_retryAttempt + 1).clamp(0, 8);

    developer.log(
      '$reason Retrying in ${delaySeconds}s.',
      name: 'UnderSound.Audio',
    );
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      _loadAndPlay(refreshUrl: true);
    });
  }

  Future<void> _setKeepAlive(bool enabled) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (error, stackTrace) {
      developer.log(
        'Wakelock update failed.',
        name: 'UnderSound.Audio',
        error: error,
        stackTrace: stackTrace,
      );
    }
    await _powerService.setWifiLockEnabled(enabled);
  }

  void _setStatus(UnderSoundPlaybackStatus status, [String? message]) {
    _status = status;
    _message = message;
    _snapshotController.add(snapshot);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      androidCompactActionIndices: const [0],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }
}
