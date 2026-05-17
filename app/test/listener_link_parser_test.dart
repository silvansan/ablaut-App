import 'package:flutter_test/flutter_test.dart';
import 'package:undersound_mobile/services/listener_link_parser.dart';

void main() {
  test('parses Studio v2 listener URLs', () {
    final link = ListenerLinkParser.parse(
      'https://voice.example.com/listen/default-event/en',
    );

    expect(link.serverUrl.toString(), 'https://voice.example.com');
    expect(link.eventSlug, 'default-event');
    expect(link.channelSlug, 'en');
    expect(link.originalUrl.toString(),
        'https://voice.example.com/listen/default-event/en');
  });

  test('parses Studio v2 compatibility listener URLs', () {
    final link = ListenerLinkParser.parse(
      'https://voice.example.com/listener/default-event/fr',
    );

    expect(link.serverUrl.toString(), 'https://voice.example.com');
    expect(link.eventSlug, 'default-event');
    expect(link.channelSlug, 'fr');
  });

  test('parses legacy UnderSound listener URLs without requiring token data',
      () {
    final link = ListenerLinkParser.parse(
      'https://voice.example.com/e/default-event/English/listen?token=abc123',
    );

    expect(link.serverUrl.toString(), 'https://voice.example.com');
    expect(link.eventSlug, 'default-event');
    expect(link.channelSlug, 'English');
  });

  test('parses custom app scheme URLs', () {
    final link = ListenerLinkParser.parse(
      'undersound://listen?server=https://voice.example.com&event=default-event&channel=FR',
    );

    expect(link.serverUrl.toString(), 'https://voice.example.com');
    expect(link.eventSlug, 'default-event');
    expect(link.channelSlug, 'FR');
  });

  test('rejects speaker URLs', () {
    expect(
      () => ListenerLinkParser.parse(
        'https://voice.example.com/e/default-event/English/speaker?token=abc123',
      ),
      throwsFormatException,
    );
  });
}
