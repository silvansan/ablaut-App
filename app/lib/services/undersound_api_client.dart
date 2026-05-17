import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/listener_link.dart';
import '../models/public_channel.dart';

class UnderSoundApiClient {
  const UnderSoundApiClient({http.Client? httpClient})
      : _httpClient = httpClient;

  final http.Client? _httpClient;

  Future<PublicChannelContext> loadPublicChannel(ListenerLink link) async {
    final uri = link.serverUrl.replace(
      path:
          '/api/public/listen/${Uri.encodeComponent(link.eventSlug)}/${Uri.encodeComponent(link.channelSlug)}',
    );

    final response = await _get(uri);
    final json = _decode(response);
    return PublicChannelContext.fromJson(json);
  }

  /// Obtains temporary subscribe-only LiveKit join credentials.
  Future<LiveKitTokenResponse> fetchListenerToken({
    required ListenerLink link,
    String? identity,
  }) async {
    final uri = link.serverUrl.replace(path: '/api/livekit/listener-token');
    final response = await _postJson(uri, {
      'eventSlug': link.eventSlug,
      'channelSlug': link.channelSlug,
      if (identity != null && identity.isNotEmpty) 'identity': identity,
    });
    final json = _decode(response);
    return LiveKitTokenResponse.fromJson(json);
  }

  Future<HlsPlaylistInspection> inspectHlsPlaylist(Uri playlistUrl) async {
    final response = await _get(
      playlistUrl.replace(
        queryParameters: {
          ...playlistUrl.queryParameters,
          '_undersound': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('HLS playlist returned ${response.statusCode}.');
    }
    return HlsPlaylistInspection.fromPlaylist(response.body);
  }

  Future<http.Response> _get(Uri uri) {
    final client = _httpClient;
    return client == null ? http.get(uri) : client.get(uri);
  }

  Future<http.Response> _postJson(Uri uri, Map<String, dynamic> body) {
    final client = _httpClient;
    final encoded = jsonEncode(body);
    final headers = {'Content-Type': 'application/json'};
    return client == null
        ? http.post(uri, headers: headers, body: encoded)
        : client.post(uri, headers: headers, body: encoded);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          decoded is Map<String, dynamic> ? decoded['error']?.toString() : null;
      throw ApiException(message ?? 'Server returned ${response.statusCode}.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Server response was not valid.');
    }
    return decoded;
  }
}

class HlsPlaylistInspection {
  const HlsPlaylistInspection({
    required this.ended,
    required this.lastProgramDateTime,
  });

  final bool ended;
  final DateTime? lastProgramDateTime;

  bool get stale {
    final dateTime = lastProgramDateTime;
    if (dateTime == null) {
      return false;
    }
    return DateTime.now().toUtc().difference(dateTime.toUtc()) >
        const Duration(seconds: 45);
  }

  factory HlsPlaylistInspection.fromPlaylist(String playlist) {
    DateTime? lastProgramDateTime;
    for (final line in const LineSplitter().convert(playlist)) {
      if (line.startsWith('#EXT-X-PROGRAM-DATE-TIME:')) {
        lastProgramDateTime = DateTime.tryParse(
          line.substring('#EXT-X-PROGRAM-DATE-TIME:'.length).trim(),
        );
      }
    }
    return HlsPlaylistInspection(
      ended: playlist.contains('#EXT-X-ENDLIST'),
      lastProgramDateTime: lastProgramDateTime,
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LiveKitTokenResponse {
  const LiveKitTokenResponse({required this.url, required this.token});

  final String url;
  final String token;

  factory LiveKitTokenResponse.fromJson(Map<String, dynamic> json) {
    final ws = json['url']?.toString() ??
        json['livekitUrl']?.toString() ??
        json['websocketUrl']?.toString();
    final tok = json['token']?.toString();
    if (ws == null || ws.isEmpty || tok == null || tok.isEmpty) {
      throw const ApiException('LiveKit token response was incomplete.');
    }
    return LiveKitTokenResponse(url: ws, token: tok);
  }
}
