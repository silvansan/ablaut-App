import 'package:flutter_test/flutter_test.dart';
import 'package:undersound_mobile/services/listener_link_parser.dart';

void main() {
  test('parses current UnderSound listener URLs', () {
    final link = ListenerLinkParser.parse(
      'https://voice.example.com/e/default-event/English/listen?token=abc123',
    );

    expect(link.serverUrl.toString(), 'https://voice.example.com');
    expect(link.eventSlug, 'default-event');
    expect(link.channelName, 'English');
    expect(link.token, 'abc123');
  });

  test('parses custom app scheme URLs', () {
    final link = ListenerLinkParser.parse(
      'undersound://join?server=https://voice.example.com&event=default-event&channel=FR&token=abc123',
    );

    expect(link.serverUrl.toString(), 'https://voice.example.com');
    expect(link.eventSlug, 'default-event');
    expect(link.channelName, 'FR');
    expect(link.token, 'abc123');
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
