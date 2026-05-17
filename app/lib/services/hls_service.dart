import '../models/public_channel.dart';
import 'undersound_api_client.dart';

/// Snapshot of whether a public fallback stream is available for listeners.
typedef HlsStreamSummary = ({
  Uri? playableUrl,
  String statusSummary,
});

class HlsService {
  HlsService([this.api = const UnderSoundApiClient()]);

  final UnderSoundApiClient api;

  /// Resolves the server-provided Icecast fallback stream, when present.
  Future<Uri?> resolvePlayableUrl({
    required Uri serverUrl,
    required PublicChannel channel,
  }) async {
    return _fallbackUrl(serverUrl: serverUrl, channel: channel);
  }

  /// Human-facing status plus optional fallback URL.
  Future<HlsStreamSummary> summarizePublicStream({
    required Uri serverUrl,
    required PublicChannel channel,
  }) async {
    final playable = _fallbackUrl(serverUrl: serverUrl, channel: channel);
    if (playable == null) {
      return (
        playableUrl: null,
        statusSummary:
            'No fallback audio stream is available for this channel.',
      );
    }

    return (
      playableUrl: playable,
      statusSummary: 'Fallback stream is available'
    );
  }

  Future<HlsStatus> loadRawStatus({
    required Uri serverUrl,
    required PublicChannel channel,
  }) {
    final playable = _fallbackUrl(serverUrl: serverUrl, channel: channel);
    return Future.value(
      HlsStatus(
        active: playable != null,
        url: playable,
        status: playable == null ? 'stopped' : 'active',
        reason: playable == null
            ? 'No fallback audio stream is available for this channel.'
            : null,
      ),
    );
  }

  Uri? _fallbackUrl({
    required Uri serverUrl,
    required PublicChannel channel,
  }) {
    final rawUrl = channel.icecastFallbackUrl;
    if (rawUrl.isEmpty) {
      return null;
    }

    final candidate = Uri.parse(rawUrl);
    return candidate.hasScheme ? candidate : serverUrl.resolveUri(candidate);
  }
}
