import 'package:flutter_test/flutter_test.dart';
import 'package:ablaut_app/models/favorite_channel.dart';
import 'package:ablaut_app/services/favorite_groups.dart';

FavoriteChannel _favorite(String id, String name, String url) {
  final now = DateTime(2026, 1, 1);
  return FavoriteChannel(id: id, name: name, url: url, createdAt: now, updatedAt: now);
}

void main() {
  final event = _favorite('e', 'Sunday Service', 'https://voice.example.com/listen/sunday');
  final english = _favorite(
    'en',
    'Sunday Service - English',
    'https://voice.example.com/listen/sunday/en',
  );
  final legacyRomanian = _favorite(
    'ro',
    'Sunday Service - Romana',
    'https://voice.example.com/e/sunday/ro/listen',
  );
  final otherEvent = _favorite(
    'x',
    'Youth Night - English',
    'https://voice.example.com/listen/youth/en',
  );
  final otherServer = _favorite(
    'y',
    'Elsewhere - English',
    'https://other.example.com/listen/sunday/en',
  );

  test('channels of a saved event are grouped under it, in list order', () {
    final entries = groupFavorites([english, otherEvent, event, legacyRomanian, otherServer]);

    expect(entries.map((entry) => entry.favorite.id), ['x', 'e', 'y']);
    final eventEntry = entries[1];
    expect(eventEntry.isEvent, isTrue);
    expect(eventEntry.channels.map((channel) => channel.id), ['en', 'ro']);
  });

  test('without a saved event, channel favorites stay separate rows', () {
    final entries = groupFavorites([english, legacyRomanian]);

    expect(entries.map((entry) => entry.favorite.id), ['en', 'ro']);
    expect(entries.every((entry) => entry.channels.isEmpty), isTrue);
  });

  test('speaker favorites are never grouped under an event', () {
    final speaker = _favorite(
      's',
      'Sunday Service - English speaker',
      'https://voice.example.com/speak/sunday/en',
    );

    final entries = groupFavorites([event, speaker]);

    expect(entries.map((entry) => entry.favorite.id), ['e', 's']);
    expect(entries.first.channels, isEmpty);
  });

  test('channel label drops the event name prefix', () {
    expect(channelLabel(english, event), 'English');
    expect(channelLabel(otherEvent, event), 'Youth Night - English');
  });
}
