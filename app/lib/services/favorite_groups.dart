import '../models/favorite_channel.dart';
import '../models/listener_link.dart';
import 'listener_link_parser.dart';

/// One row of the favorites list: a single favorite, or a saved event with the
/// favorite channels that belong to it.
class FavoriteEntry {
  const FavoriteEntry({required this.favorite, this.channels = const []});

  final FavoriteChannel favorite;

  /// Favorite channels of this event. Empty unless [favorite] is an event.
  final List<FavoriteChannel> channels;

  bool get isEvent => isEventFavorite(favorite);
}

/// Whether a favorite points at a whole event (its channel list) rather than one channel.
bool isEventFavorite(FavoriteChannel favorite) {
  final link = _tryParse(favorite.url);
  return link != null && link.isEventDirectory && !link.isSpeaker;
}

/// Server + event identity, so links written differently (legacy `/e/...` URLs,
/// trailing query strings) still match the same event.
String eventKeyOf(ListenerLink link) {
  return '${link.serverUrl}|${link.eventSlug}';
}

String? eventKeyOfUrl(String url) {
  final link = _tryParse(url);
  return link == null ? null : eventKeyOf(link);
}

/// Groups channel favorites under their saved event, keeping the list order.
/// A channel whose event is not saved stays a row of its own.
List<FavoriteEntry> groupFavorites(List<FavoriteChannel> favorites) {
  final eventsByKey = <String, FavoriteChannel>{};
  for (final favorite in favorites) {
    if (isEventFavorite(favorite)) {
      final key = eventKeyOfUrl(favorite.url);
      if (key != null) {
        eventsByKey.putIfAbsent(key, () => favorite);
      }
    }
  }

  final channelsByEvent = <String, List<FavoriteChannel>>{};
  final entries = <FavoriteEntry>[];

  for (final favorite in favorites) {
    final link = _tryParse(favorite.url);
    if (link == null || link.isEventDirectory || link.isSpeaker) {
      continue;
    }
    final key = eventKeyOf(link);
    if (eventsByKey.containsKey(key)) {
      channelsByEvent.putIfAbsent(key, () => []).add(favorite);
    }
  }

  for (final favorite in favorites) {
    final key = eventKeyOfUrl(favorite.url);
    if (isEventFavorite(favorite)) {
      if (eventsByKey[key] == favorite) {
        entries.add(
          FavoriteEntry(favorite: favorite, channels: channelsByEvent[key] ?? const []),
        );
      }
      continue;
    }

    final grouped = channelsByEvent[key]?.contains(favorite) ?? false;
    if (!grouped) {
      entries.add(FavoriteEntry(favorite: favorite));
    }
  }

  return entries;
}

/// The channel part of a saved channel name ("Sunday Service - English" -> "English").
String channelLabel(FavoriteChannel channel, FavoriteChannel event) {
  final prefix = '${event.name} - ';
  return channel.name.startsWith(prefix)
      ? channel.name.substring(prefix.length)
      : channel.name;
}

ListenerLink? _tryParse(String url) {
  try {
    return ListenerLinkParser.parse(url);
  } on FormatException {
    return null;
  }
}
