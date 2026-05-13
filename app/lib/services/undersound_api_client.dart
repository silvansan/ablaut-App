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
      path: '/api/public/channel',
      queryParameters: {
        'event': link.eventSlug,
        'channel': link.channelName,
        'role': 'listener',
        'token': link.token,
      },
    );

    final response = await _get(uri);
    final json = _decode(response);
    return PublicChannelContext.fromJson(json);
  }

  Future<HlsStatus> loadHlsStatus({
    required Uri serverUrl,
    required String channelId,
    required String token,
  }) async {
    final uri = serverUrl.replace(
      path: '/api/channels/${Uri.encodeComponent(channelId)}/hls',
      queryParameters: {'token': token},
    );

    final response = await _get(uri);
    final json = _decode(response);
    return HlsStatus.fromJson(json, serverUrl);
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

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['error']?.toString()
          : null;
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
