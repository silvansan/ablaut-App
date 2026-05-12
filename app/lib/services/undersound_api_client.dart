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

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
