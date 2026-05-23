import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/event_directory.dart';
import '../models/listener_link.dart';
import '../models/listener_verify_password_response.dart';
import '../models/public_channel.dart';
import '../models/public_listener_access.dart';
import 'listener_access_messages.dart';

class AblautApiClient {
  const AblautApiClient({
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient;

  final http.Client? _httpClient;
  final Duration requestTimeout;

  Future<PublicChannelContext> loadPublicChannel(ListenerLink link) async {
    final channelSlug = link.channelSlug;
    if (channelSlug == null || channelSlug.isEmpty) {
      throw const ApiException('A channel slug is required for this link.');
    }

    final uri = link.serverUrl.replace(
      path:
          '/api/public/listen/${Uri.encodeComponent(link.eventSlug)}/${Uri.encodeComponent(channelSlug)}',
    );

    final response = await _get(uri);
    final json = _decode(response);
    return PublicChannelContext.fromJson(json);
  }

  Future<EventDirectoryContext> loadEventDirectory(ListenerLink link) async {
    final uri = link.serverUrl.replace(
      path: '/api/public/listen/${Uri.encodeComponent(link.eventSlug)}',
    );

    final response = await _get(uri);
    final json = _decode(response);
    return EventDirectoryContext.fromJson(json);
  }

  Future<ListenerVerifyPasswordResponse> verifyEventDirectoryPassword({
    required ListenerLink link,
    required String password,
  }) async {
    final uri = link.serverUrl.replace(path: '/api/listener/verify-password');
    final response = await _postJson(
      uri,
      {
        'directory': true,
        'eventSlug': link.eventSlug,
        'password': password,
      },
    );
    if (response.statusCode == 401) {
      throw const ApiException(
        ListenerAccessMessages.wrongPassword,
        statusCode: 401,
      );
    }
    final json = _decode(response);
    return ListenerVerifyPasswordResponse.fromJson(json);
  }

  Future<ListenerVerifyPasswordResponse> verifyListenerPassword({
    required ListenerLink link,
    required String password,
    PublicListenerAccess? access,
  }) async {
    final channelSlug = link.channelSlug;
    if (channelSlug == null || channelSlug.isEmpty) {
      throw const ApiException('A channel slug is required to verify this password.');
    }

    final accessMeta = access ?? PublicListenerAccess.publicDefault();
    final uri = accessMeta.verifyPasswordUri(link.serverUrl);
    final response = await _postJson(
      uri,
      {
        'eventSlug': link.eventSlug,
        'channelSlug': channelSlug,
        'password': password,
      },
    );
    if (response.statusCode == 401) {
      throw const ApiException(
        ListenerAccessMessages.wrongPassword,
        statusCode: 401,
      );
    }
    final json = _decode(response);
    return ListenerVerifyPasswordResponse.fromJson(json);
  }

  /// Obtains temporary subscribe-only LiveKit join credentials.
  Future<LiveKitTokenResponse> fetchListenerToken({
    required ListenerLink link,
    String? identity,
    String? listenerSessionToken,
    String? eventListenerSessionToken,
  }) async {
    final channelSlug = link.channelSlug;
    if (channelSlug == null || channelSlug.isEmpty) {
      throw const ApiException('A channel slug is required for playback.');
    }

    final uri = link.serverUrl.replace(path: '/api/livekit/listener-token');
    final headers = <String, String>{};
    if (listenerSessionToken != null && listenerSessionToken.isNotEmpty) {
      headers['X-Ablaut-Listener-Session'] = listenerSessionToken;
    }
    final response = await _postJson(
      uri,
      {
        'eventSlug': link.eventSlug,
        'channelSlug': channelSlug,
        if (identity != null && identity.isNotEmpty) 'identity': identity,
        if (listenerSessionToken != null && listenerSessionToken.isNotEmpty)
          'listenerSessionToken': listenerSessionToken,
        if (eventListenerSessionToken != null &&
            eventListenerSessionToken.isNotEmpty)
          'eventListenerSessionToken': eventListenerSessionToken,
      },
      headers: headers,
    );
    if (response.statusCode == 403) {
      throw const ApiException(
        ListenerAccessMessages.sessionExpired,
        statusCode: 403,
      );
    }
    final json = _decode(response);
    return LiveKitTokenResponse.fromJson(json);
  }

  Future<HlsPlaylistInspection> inspectHlsPlaylist(Uri playlistUrl) async {
    final response = await _get(
      playlistUrl.replace(
        queryParameters: {
          ...playlistUrl.queryParameters,
          '_cacheBust': DateTime.now().millisecondsSinceEpoch.toString(),
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
    final request = client == null ? http.get(uri) : client.get(uri);
    return request.timeout(
      requestTimeout,
      onTimeout: () {
        throw const ApiException('The server took too long to respond.');
      },
    );
  }

  Future<http.Response> _postJson(
    Uri uri,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) {
    final client = _httpClient;
    final encoded = jsonEncode(body);
    final requestHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    final request = client == null
        ? http.post(uri, headers: requestHeaders, body: encoded)
        : client.post(uri, headers: requestHeaders, body: encoded);
    return request.timeout(
      requestTimeout,
      onTimeout: () {
        throw const ApiException('The server took too long to respond.');
      },
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          decoded is Map<String, dynamic> ? decoded['error']?.toString() : null;
      throw ApiException(
        message ?? 'Server returned ${response.statusCode}.',
        statusCode: response.statusCode,
      );
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
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

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
