import '../models/public_channel.dart';
import 'ablaut_api_client.dart';

/// Snapshot of whether a public fallback stream is available for listeners.
typedef HlsStreamSummary = ({
  Uri? playableUrl,
  String statusSummary,
});

class HlsService {
  HlsService([this.api = const AblautApiClient()]);

  final AblautApiClient api;

  /// Resolves the server-provided LL-HLS egress URL or Icecast fallback stream.
  Future<Uri?> resolvePlayableUrl({
    required Uri serverUrl,
    required PublicChannel channel,
  }) async {
    return _resolvePlayableUrl(serverUrl: serverUrl, channel: channel);
  }

  /// Human-facing status plus optional fallback URL.
  Future<HlsStreamSummary> summarizePublicStream({
    required Uri serverUrl,
    required PublicChannel channel,
  }) async {
    final playable = _resolvePlayableUrl(serverUrl: serverUrl, channel: channel);
    if (playable == null) {
      return (
        playableUrl: null,
        statusSummary:
            'No fallback audio stream is available for this channel.',
      );
    }

    final usesStudioEgress = channel.hlsEnabled && channel.hlsUrl != null;
    return (
      playableUrl: playable,
      statusSummary: usesStudioEgress
          ? 'LL-HLS stream is available'
          : 'Fallback stream is available',
    );
  }

  Future<HlsStatus> loadRawStatus({
    required Uri serverUrl,
    required PublicChannel channel,
  }) {
    final playable = _resolvePlayableUrl(serverUrl: serverUrl, channel: channel);
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

  Uri? _resolvePlayableUrl({
    required Uri serverUrl,
    required PublicChannel channel,
  }) {
    if (channel.hlsEnabled) {
      final studioUrl = channel.hlsUrl;
      if (studioUrl != null) {
        return studioUrl.hasScheme
            ? studioUrl
            : serverUrl.resolveUri(studioUrl);
      }
    }

    return _fallbackUrl(serverUrl: serverUrl, channel: channel);
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
