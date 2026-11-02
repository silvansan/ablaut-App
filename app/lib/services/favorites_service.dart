import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/favorite_channel.dart';
import '../models/listener_link.dart';
import 'listener_link_parser.dart';
import 'listener_secure_store.dart';

class FavoritesService {
  const FavoritesService({ListenerSecureStore? secureStore})
      : _secureStore = secureStore ?? const ListenerSecureStore();

  static const _storageKey = 'ablaut.favoriteChannels.v1';
  static const _legacyStorageKey = 'undersound.favoriteChannels.v1';

  final ListenerSecureStore _secureStore;

  Future<List<FavoriteChannel>> loadFavorites() async {
    final preferences = await SharedPreferences.getInstance();
    await _migrateLegacyFavoritesIfNeeded(preferences);
    final rawItems = preferences.getStringList(_storageKey) ?? const [];
    final favorites = <FavoriteChannel>[];

    for (final rawItem in rawItems) {
      try {
        final decoded = jsonDecode(rawItem);
        if (decoded is Map<String, dynamic>) {
          final favorite = FavoriteChannel.fromJson(decoded);
          if (favorite.id.isNotEmpty && favorite.url.isNotEmpty) {
            favorites.add(favorite);
          }
        }
      } catch (_) {
        // Ignore malformed local entries instead of blocking the list.
      }
    }

    favorites.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return favorites;
  }

  Future<FavoriteChannel?> findByUrl(String url) async {
    final normalized = _normalizeUrl(url);
    final favorites = await loadFavorites();
    for (final favorite in favorites) {
      if (_normalizeUrl(favorite.url) == normalized) {
        return favorite;
      }
    }
    return null;
  }

  Future<bool> isSavedUrl(String url) async {
    return (await findByUrl(url)) != null;
  }

  /// Finds the favorite for the same server, event, channel and role, however its
  /// URL was written (legacy `/e/...` links, query strings).
  Future<FavoriteChannel?> findByLink(ListenerLink link) async {
    for (final favorite in await loadFavorites()) {
      final ListenerLink saved;
      try {
        saved = ListenerLinkParser.parse(favorite.url);
      } on FormatException {
        continue;
      }
      if (saved.serverUrl == link.serverUrl &&
          saved.eventSlug == link.eventSlug &&
          (saved.channelSlug ?? '') == (link.channelSlug ?? '') &&
          saved.role == link.role) {
        return favorite;
      }
    }
    return null;
  }

  Future<FavoriteChannel> addFavorite({
    required String name,
    required String url,
    bool listenerPasswordRequired = false,
    String? listenerSessionToken,
    int? sessionExpiresInSeconds,
  }) async {
    final favorites = await loadFavorites();
    final normalized = _normalizeUrl(url);
    final existing = favorites.where(
      (favorite) => _normalizeUrl(favorite.url) == normalized,
    );
    if (existing.isNotEmpty) {
      final current = existing.first;
      if (listenerSessionToken != null && listenerSessionToken.isNotEmpty) {
        return upsertListenerSession(
          url: url,
          listenerPasswordRequired: listenerPasswordRequired,
          listenerSessionToken: listenerSessionToken,
          expiresInSeconds: sessionExpiresInSeconds,
          name: name,
        );
      }
      return current;
    }

    final now = DateTime.now();
    final favorite = FavoriteChannel(
      id: now.microsecondsSinceEpoch.toString(),
      name: _cleanName(name),
      url: url.trim(),
      createdAt: now,
      updatedAt: now,
      listenerPasswordRequired: listenerPasswordRequired,
      listenerSessionToken: listenerSessionToken,
      sessionExpiresAt: _expiresAtFromSeconds(sessionExpiresInSeconds),
    );
    await _saveFavorites([favorite, ...favorites]);
    return favorite;
  }

  Future<FavoriteChannel> upsertListenerSession({
    required String url,
    required bool listenerPasswordRequired,
    required String listenerSessionToken,
    int? expiresInSeconds,
    String? name,
  }) async {
    final favorites = await loadFavorites();
    final normalized = _normalizeUrl(url);
    final now = DateTime.now();
    final updatedFavorites = <FavoriteChannel>[];

    FavoriteChannel? result;
    for (final favorite in favorites) {
      if (_normalizeUrl(favorite.url) != normalized) {
        updatedFavorites.add(favorite);
        continue;
      }

      result = favorite.copyWith(
        name: name == null ? favorite.name : _cleanName(name),
        listenerPasswordRequired: listenerPasswordRequired,
        listenerSessionToken: listenerSessionToken,
        sessionExpiresAt: _expiresAtFromSeconds(expiresInSeconds),
        updatedAt: now,
      );
      updatedFavorites.add(result);
    }

    result ??= FavoriteChannel(
      id: now.microsecondsSinceEpoch.toString(),
      name: _cleanName(name ?? 'ablaut channel'),
      url: url.trim(),
      createdAt: now,
      updatedAt: now,
      listenerPasswordRequired: listenerPasswordRequired,
      listenerSessionToken: listenerSessionToken,
      sessionExpiresAt: _expiresAtFromSeconds(expiresInSeconds),
    );

    if (!updatedFavorites.any((favorite) => favorite.id == result!.id)) {
      updatedFavorites.insert(0, result);
    }

    await _saveFavorites(updatedFavorites);
    return result;
  }

  Future<void> clearListenerSession(String url) async {
    final favorites = await loadFavorites();
    final normalized = _normalizeUrl(url);
    await _saveFavorites([
      for (final favorite in favorites)
        if (_normalizeUrl(favorite.url) == normalized)
          favorite.copyWith(clearSession: true, updatedAt: DateTime.now())
        else
          favorite,
    ]);
  }

  Future<void> updateFavorite(FavoriteChannel favorite) async {
    final favorites = await loadFavorites();
    final updated = favorite.copyWith(
      name: _cleanName(favorite.name),
      url: favorite.url.trim(),
      updatedAt: DateTime.now(),
    );
    await _saveFavorites([
      for (final item in favorites) item.id == updated.id ? updated : item,
    ]);
  }

  Future<void> deleteFavorite(String id) async {
    final favorites = await loadFavorites();
    FavoriteChannel? removed;
    for (final favorite in favorites) {
      if (favorite.id == id) {
        removed = favorite;
        break;
      }
    }
    await _saveFavorites([
      for (final favorite in favorites)
        if (favorite.id != id) favorite,
    ]);
    if (removed != null) {
      await _secureStore.deletePassword(removed.url);
    }
  }

  Future<void> _migrateLegacyFavoritesIfNeeded(
    SharedPreferences preferences,
  ) async {
    if (preferences.containsKey(_storageKey)) {
      return;
    }
    final legacy = preferences.getStringList(_legacyStorageKey);
    if (legacy == null || legacy.isEmpty) {
      return;
    }
    await preferences.setStringList(_storageKey, legacy);
    await preferences.remove(_legacyStorageKey);
  }

  Future<void> _saveFavorites(List<FavoriteChannel> favorites) async {
    final preferences = await SharedPreferences.getInstance();
    final rawItems = [
      for (final favorite in favorites) jsonEncode(favorite.toJson()),
    ];
    await preferences.setStringList(_storageKey, rawItems);
  }

  DateTime? _expiresAtFromSeconds(int? expiresInSeconds) {
    if (expiresInSeconds == null || expiresInSeconds <= 0) {
      return null;
    }
    return DateTime.now().add(Duration(seconds: expiresInSeconds));
  }

  String _cleanName(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'ablaut channel' : trimmed;
  }

  String _normalizeUrl(String url) => url.trim();
}
