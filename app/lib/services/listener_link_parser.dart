import '../models/listener_link.dart';

class ListenerLinkParser {
  static ListenerLink parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Enter an UnderSound listener link.');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      throw const FormatException('Enter a complete link, including https://.');
    }

    if (uri.scheme == 'undersound') {
      return _parseCustomScheme(uri);
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const FormatException('Unsupported link type.');
    }

    final segments = uri.pathSegments;
    final firstSegment = segments.isEmpty ? '' : segments[0].toLowerCase();
    if (segments.length >= 3 &&
        (firstSegment == 'listen' || firstSegment == 'listener')) {
      return ListenerLink(
        serverUrl: _origin(uri),
        eventSlug: segments[1],
        channelSlug: segments[2],
        originalUrl: uri,
      );
    }

    final eventIndex = segments.indexOf('e');
    if (eventIndex == -1 || segments.length <= eventIndex + 3) {
      throw const FormatException(
        'This does not look like an UnderSound listener link.',
      );
    }

    final page = segments[eventIndex + 3].toLowerCase();
    if (page != 'listen') {
      throw const FormatException(
        'Use a listener link, not a speaker or admin link.',
      );
    }

    return ListenerLink(
      serverUrl: _origin(uri),
      eventSlug: segments[eventIndex + 1],
      channelSlug: segments[eventIndex + 2],
      originalUrl: uri,
    );
  }

  static ListenerLink _parseCustomScheme(Uri uri) {
    final server = uri.queryParameters['server'] ?? '';
    final event = uri.queryParameters['event'] ?? '';
    final channel = uri.queryParameters['channel'] ?? '';
    final serverUri = Uri.tryParse(server);

    if (serverUri == null || !serverUri.hasScheme || serverUri.host.isEmpty) {
      throw const FormatException('The app link is missing a valid server.');
    }
    if (event.isEmpty || channel.isEmpty) {
      throw const FormatException(
        'The app link is missing event or channel data.',
      );
    }

    return ListenerLink(
      serverUrl: _origin(serverUri),
      eventSlug: event,
      channelSlug: channel,
      originalUrl: uri,
    );
  }

  static Uri _origin(Uri uri) {
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    );
  }
}
