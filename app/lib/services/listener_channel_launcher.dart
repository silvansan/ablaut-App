import 'package:flutter/material.dart';

import '../models/favorite_channel.dart';
import '../models/listener_link.dart';
import '../screens/event_channels_screen.dart';
import '../screens/player_screen.dart';
import 'favorites_service.dart';
import 'listener_session_coordinator.dart';
import 'ablaut_api_client.dart';

class ListenerChannelLauncher {
  const ListenerChannelLauncher({
    AblautApiClient? api,
    ListenerSessionCoordinator? coordinator,
    FavoritesService? favoritesService,
  })  : _api = api ?? const AblautApiClient(),
        _coordinator = coordinator ?? const ListenerSessionCoordinator(),
        _favoritesService = favoritesService ?? const FavoritesService();

  final AblautApiClient _api;
  final ListenerSessionCoordinator _coordinator;
  final FavoritesService _favoritesService;

  Future<void> openLink({
    required BuildContext context,
    required ListenerLink link,
    FavoriteChannel? favorite,
    bool addToFavorites = false,
    bool replaceCurrentRoute = false,
  }) async {
    if (link.isEventDirectory) {
      final screen = EventChannelsScreen(
        link: link,
        replaceCurrentRoute: replaceCurrentRoute,
      );
      final route = MaterialPageRoute(builder: (_) => screen);
      if (replaceCurrentRoute) {
        await Navigator.of(context).pushReplacement(route);
      } else {
        await Navigator.of(context).push(route);
      }
      return;
    }

    await openChannel(
      context: context,
      link: link,
      favorite: favorite,
      addToFavorites: addToFavorites,
      replaceCurrentRoute: replaceCurrentRoute,
    );
  }

  Future<void> openChannel({
    required BuildContext context,
    required ListenerLink link,
    FavoriteChannel? favorite,
    bool addToFavorites = false,
    bool replaceCurrentRoute = false,
    String? eventListenerSessionToken,
  }) async {
    if (link.isEventDirectory) {
      await openLink(
        context: context,
        link: link,
        favorite: favorite,
        addToFavorites: addToFavorites,
        replaceCurrentRoute: replaceCurrentRoute,
      );
      return;
    }

    final channelContext = await _api.loadPublicChannel(link);
    if (!context.mounted) {
      return;
    }
    _coordinator.ensureChannelAccessible(channelContext);

    String? listenerSessionToken;
    if (channelContext.access.listenerPasswordRequired &&
        eventListenerSessionToken == null) {
      listenerSessionToken = await _coordinator.resolveSessionToken(
        context: context,
        link: link,
        channelContext: channelContext,
        favorite: favorite,
        persistForFavorite: true,
      );
    }

    if (addToFavorites) {
      await _favoritesService.addFavorite(
        name: '${channelContext.event.name} - ${channelContext.channel.name}',
        url: link.originalUrl.toString(),
        listenerPasswordRequired:
            channelContext.access.listenerPasswordRequired,
        listenerSessionToken: listenerSessionToken,
        sessionExpiresInSeconds: null,
      );
    }

    if (!context.mounted) {
      return;
    }

    final player = PlayerScreen(
      link: link,
      channelContext: channelContext,
      listenerSessionToken: listenerSessionToken,
      eventListenerSessionToken: eventListenerSessionToken,
    );
    final route = MaterialPageRoute(builder: (_) => player);
    if (replaceCurrentRoute) {
      await Navigator.of(context).pushReplacement(route);
    } else {
      await Navigator.of(context).push(route);
    }
  }
}
