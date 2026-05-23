import 'package:flutter/material.dart';

import '../models/favorite_channel.dart';
import '../models/listener_link.dart';
import '../models/public_channel.dart';
import '../widgets/listener_password_dialog.dart';
import 'favorites_service.dart';
import 'listener_access_messages.dart';
import 'listener_secure_store.dart';
import 'ablaut_api_client.dart';

class ListenerAccessException implements Exception {
  const ListenerAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ListenerSessionCoordinator {
  const ListenerSessionCoordinator({
    AblautApiClient? api,
    FavoritesService? favoritesService,
    ListenerSecureStore? secureStore,
  })  : _api = api ?? const AblautApiClient(),
        _favoritesService = favoritesService ?? const FavoritesService(),
        _secureStore = secureStore ?? const ListenerSecureStore();

  final AblautApiClient _api;
  final FavoritesService _favoritesService;
  final ListenerSecureStore _secureStore;

  void ensureChannelAccessible(PublicChannelContext channelContext) {
    final access = channelContext.access;
    if (access.isPrivateChannel) {
      throw const ListenerAccessException(ListenerAccessMessages.privateChannel);
    }
    if (access.listenerPasswordMissing) {
      throw const ListenerAccessException(ListenerAccessMessages.passwordMissing);
    }
  }

  Future<String?> resolveSessionToken({
    required BuildContext context,
    required ListenerLink link,
    required PublicChannelContext channelContext,
    FavoriteChannel? favorite,
    bool persistForFavorite = true,
    bool allowInteractivePrompt = true,
  }) async {
    ensureChannelAccessible(channelContext);
    final access = channelContext.access;
    if (!access.listenerPasswordRequired) {
      return null;
    }

    final favoriteUrl = favorite?.url ?? link.originalUrl.toString();
    final savedFavorite = favorite ??
        await _favoritesService.findByUrl(favoriteUrl);

    final existingToken = savedFavorite?.validListenerSessionToken;
    if (existingToken != null) {
      return existingToken;
    }

    final storedPassword = await _secureStore.readPassword(favoriteUrl);
    if (storedPassword != null && storedPassword.isNotEmpty) {
      try {
        return await _verifyAndPersist(
          link: link,
          channelContext: channelContext,
          password: storedPassword,
          favoriteUrl: favoriteUrl,
          favorite: savedFavorite,
          persistForFavorite: persistForFavorite,
        );
      } on ApiException catch (error) {
        if (error.statusCode != 401) {
          rethrow;
        }
        await _secureStore.deletePassword(favoriteUrl);
      }
    }

    if (!allowInteractivePrompt) {
      return null;
    }

    if (!context.mounted) {
      return null;
    }

    var password = await showListenerPasswordDialog(context);
    if (!context.mounted) {
      return null;
    }
    if (password == null) {
      throw const ListenerAccessException('Listener password is required.');
    }

    var attemptPassword = password;
    while (true) {
      try {
        return await _verifyAndPersist(
          link: link,
          channelContext: channelContext,
          password: attemptPassword,
          favoriteUrl: favoriteUrl,
          favorite: savedFavorite,
          persistForFavorite: persistForFavorite,
          savePassword: true,
        );
      } on ApiException catch (error) {
        if (error.statusCode != 401 || !context.mounted) {
          rethrow;
        }
        final retryPassword = await showListenerPasswordDialog(
          context,
          errorText: ListenerAccessMessages.wrongPassword,
        );
        if (!context.mounted) {
          return null;
        }
        if (retryPassword == null) {
          throw const ListenerAccessException(
            'Listener password is required.',
          );
        }
        attemptPassword = retryPassword;
      }
    }
  }

  Future<String> changeStoredPassword({
    required BuildContext context,
    required ListenerLink link,
    required PublicChannelContext channelContext,
    required FavoriteChannel favorite,
  }) async {
    ensureChannelAccessible(channelContext);
    if (!channelContext.access.listenerPasswordRequired) {
      throw const ListenerAccessException(
        'This channel does not use a listener password.',
      );
    }

    final password = await showListenerPasswordDialog(
      context,
      title: 'Change listener password',
    );
    if (!context.mounted || password == null) {
      throw const ListenerAccessException('Listener password is required.');
    }

    try {
      return await _verifyAndPersist(
        link: link,
        channelContext: channelContext,
        password: password,
        favoriteUrl: favorite.url,
        favorite: favorite,
        persistForFavorite: true,
        savePassword: true,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        throw const ListenerAccessException(
          ListenerAccessMessages.wrongPassword,
        );
      }
      rethrow;
    }
  }

  Future<String> _verifyAndPersist({
    required ListenerLink link,
    required PublicChannelContext channelContext,
    required String password,
    required String favoriteUrl,
    FavoriteChannel? favorite,
    required bool persistForFavorite,
    bool savePassword = false,
  }) async {
    final response = await _api.verifyListenerPassword(
      link: link,
      password: password,
      access: channelContext.access,
    );
    final token = response.listenerSessionToken;
    if (!response.ok || token == null || token.isEmpty) {
      throw const ApiException('Password verification did not return a session.');
    }

    if (savePassword) {
      await _secureStore.savePassword(url: favoriteUrl, password: password);
    }

    if (persistForFavorite) {
      await _favoritesService.upsertListenerSession(
        url: favoriteUrl,
        listenerPasswordRequired: true,
        listenerSessionToken: token,
        expiresInSeconds: response.expiresIn,
        name: favorite?.name,
      );
    }

    return token;
  }
}
