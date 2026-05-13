import 'undersound_audio_service.dart';

/// Which transport backs playback on the player screen.
enum StreamTransportMode {
  webRtc,
  hls,
}

/// Connection lifecycle surfaced in the unified player UI.
enum StreamConnectionPhase {
  idle,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Maps legacy [UnderSoundPlaybackStatus] from audio_service/HLS playback to the
/// smaller UI surface requested for stream transport.
abstract final class StreamConnectionService {
  const StreamConnectionService._();

  static StreamConnectionPhase phaseForHls(
    UnderSoundPlaybackStatus playback,
  ) {
    return switch (playback) {
      UnderSoundPlaybackStatus.idle => StreamConnectionPhase.idle,
      UnderSoundPlaybackStatus.connecting =>
        StreamConnectionPhase.connecting,
      UnderSoundPlaybackStatus.buffering => StreamConnectionPhase.connecting,
      UnderSoundPlaybackStatus.playing || UnderSoundPlaybackStatus.paused =>
        StreamConnectionPhase.connected,
      UnderSoundPlaybackStatus.reconnecting =>
        StreamConnectionPhase.reconnecting,
      UnderSoundPlaybackStatus.waiting =>
        StreamConnectionPhase.connecting,
      UnderSoundPlaybackStatus.error => StreamConnectionPhase.failed,
    };
  }
}
