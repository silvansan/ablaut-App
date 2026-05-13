import '../models/public_channel.dart';
import 'undersound_api_client.dart';

/// Server-side snapshot of whether HLS is available for listeners.
typedef HlsStreamSummary = ({
  Uri? playableUrl,
  String statusSummary,
});

class HlsService {
  HlsService([this.api = const UnderSoundApiClient()]);

  final UnderSoundApiClient api;

  /// Resolves whether the HLS URL is playable (active, inspected, non-stale).
  Future<Uri?> resolvePlayableUrl({
    required Uri serverUrl,
    required String channelId,
    required String token,
  }) async {
    final hls = await api.loadHlsStatus(
      serverUrl: serverUrl,
      channelId: channelId,
      token: token,
    );
    final url = hls.active ? hls.url : null;
    if (url == null) {
      return null;
    }
    final inspection = await api.inspectHlsPlaylist(url);
    if (inspection.ended || inspection.stale) {
      return null;
    }
    return url;
  }

  /// Human-facing status plus optional URL after validation (playlist inspection).
  Future<HlsStreamSummary> summarizePublicStream({
    required Uri serverUrl,
    required String channelId,
    required String token,
  }) async {
    final hls = await api.loadHlsStatus(
      serverUrl: serverUrl,
      channelId: channelId,
      token: token,
    );
    Uri? playable = hls.active ? hls.url : null;
    final baseMessage = hls.reason ?? hls.status;
    if (playable != null) {
      final inspection = await api.inspectHlsPlaylist(playable);
      if (inspection.ended || inspection.stale) {
        playable = null;
        return (
          playableUrl: null,
          statusSummary:
              'The HLS playlist has ended or is stale. Ask the speaker to restart publishing.',
        );
      }
    }
    final summary = playable != null
        ? 'Stream is live'
        : (baseMessage == 'stopped' ? 'Waiting for speaker' : baseMessage);

    return (playableUrl: playable, statusSummary: summary);
  }

  Future<HlsStatus> loadRawStatus({
    required Uri serverUrl,
    required String channelId,
    required String token,
  }) {
    return api.loadHlsStatus(
      serverUrl: serverUrl,
      channelId: channelId,
      token: token,
    );
  }
}
