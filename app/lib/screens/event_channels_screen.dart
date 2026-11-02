import 'package:flutter/material.dart';

import '../models/event_directory.dart';
import '../models/favorite_channel.dart';
import '../models/listener_link.dart';
import '../services/ablaut_api_client.dart';
import '../services/favorites_service.dart';
import '../services/listener_access_messages.dart';
import '../services/listener_channel_launcher.dart';
import '../services/listener_session_coordinator.dart';
import '../widgets/listener_password_dialog.dart';

class EventChannelsScreen extends StatefulWidget {
  const EventChannelsScreen({
    super.key,
    required this.link,
    this.favorite,
    this.addToFavorites = false,
    this.replaceCurrentRoute = false,
  });

  final ListenerLink link;

  /// The saved event this screen was opened from, if any (reuses its password session).
  final FavoriteChannel? favorite;

  /// Save the event to favorites once it has loaded (scanned from "Add favorite").
  final bool addToFavorites;
  final bool replaceCurrentRoute;

  @override
  State<EventChannelsScreen> createState() => _EventChannelsScreenState();
}

class _EventChannelsScreenState extends State<EventChannelsScreen> {
  final _api = const AblautApiClient();
  final _launcher = const ListenerChannelLauncher();
  final _favoritesService = const FavoritesService();

  EventDirectoryContext? _directory;
  String? _eventSessionToken;
  String? _error;
  bool _loading = true;
  bool _openingChannel = false;

  FavoriteChannel? _eventFavorite;
  Map<String, FavoriteChannel> _channelFavorites = const {};
  bool _savingFavorite = false;

  @override
  void initState() {
    super.initState();
    _eventFavorite = widget.favorite;
    _eventSessionToken = widget.favorite?.validListenerSessionToken;
    _start();
  }

  Future<void> _start() async {
    await _loadEventFavorite();
    await _loadDirectory();
  }

  Future<void> _loadEventFavorite() async {
    final saved = await _favoritesService.findByLink(widget.link);
    if (!mounted) {
      return;
    }
    setState(() {
      _eventFavorite = saved;
      _eventSessionToken ??= saved?.validListenerSessionToken;
    });
  }

  Future<void> _loadChannelFavorites(EventDirectoryContext directory) async {
    final found = <String, FavoriteChannel>{};
    for (final channel in directory.channels) {
      final saved = await _favoritesService.findByLink(
        widget.link.withChannelSlug(channel.slug),
      );
      if (saved != null) {
        found[channel.slug] = saved;
      }
    }
    if (mounted) {
      setState(() => _channelFavorites = found);
    }
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final directory = await _api.loadEventDirectory(widget.link);
      if (!mounted) {
        return;
      }

      setState(() {
        _directory = directory;
        _loading = false;
      });

      await _loadChannelFavorites(directory);

      if (widget.addToFavorites && _eventFavorite == null) {
        await _toggleEventFavorite();
      }

      if (directory.access.listenerPasswordRequired && _eventSessionToken == null) {
        await _promptForEventPassword(directory);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _promptForEventPassword(EventDirectoryContext directory) async {
    if (directory.access.listenerPasswordMissing) {
      setState(() {
        _error = ListenerAccessMessages.passwordMissing;
      });
      return;
    }

    var password = await showListenerPasswordDialog(context);
    while (mounted && password != null) {
      try {
        final response = await _api.verifyEventDirectoryPassword(
          link: widget.link,
          password: password,
        );
        setState(() {
          _eventSessionToken = response.listenerSessionToken;
          _error = null;
        });
        await _rememberEventSession(response.listenerSessionToken, response.expiresIn);
        return;
      } on ApiException catch (error) {
        if (error.statusCode != 401 || !mounted) {
          setState(() => _error = error.message);
          return;
        }
        password = await showListenerPasswordDialog(
          context,
          errorText: ListenerAccessMessages.wrongPassword,
        );
      }
    }

    if (mounted) {
      setState(() {
        _error = 'Event listener password is required.';
      });
    }
  }

  /// A saved event keeps its password session, so reopening it does not ask again.
  Future<void> _rememberEventSession(String? token, int? expiresIn) async {
    final favorite = _eventFavorite;
    if (favorite == null || token == null || token.isEmpty) {
      return;
    }
    final updated = await _favoritesService.upsertListenerSession(
      url: favorite.url,
      listenerPasswordRequired: true,
      listenerSessionToken: token,
      expiresInSeconds: expiresIn,
    );
    if (mounted) {
      setState(() => _eventFavorite = updated);
    }
  }

  String get _eventTitle {
    final title = _directory?.eventTitle ?? '';
    return title.isEmpty ? 'ablaut event' : title;
  }

  Future<void> _toggleEventFavorite() async {
    final directory = _directory;
    if (directory == null || _savingFavorite) {
      return;
    }

    setState(() => _savingFavorite = true);
    try {
      final current = _eventFavorite;
      if (current != null) {
        await _favoritesService.deleteFavorite(current.id);
        if (mounted) {
          setState(() => _eventFavorite = null);
          _showMessage('Event removed from favorites');
        }
        return;
      }

      final saved = await _favoritesService.addFavorite(
        name: _eventTitle,
        url: widget.link.listenUrl,
        listenerPasswordRequired: directory.access.listenerPasswordRequired,
        listenerSessionToken: _eventSessionToken,
      );
      if (mounted) {
        setState(() => _eventFavorite = saved);
        _showMessage('Event saved to favorites');
      }
    } catch (error) {
      _showMessage('Could not update favorites: $error');
    } finally {
      if (mounted) {
        setState(() => _savingFavorite = false);
      }
    }
  }

  Future<void> _toggleChannelFavorite(EventDirectoryChannel channel) async {
    if (_savingFavorite) {
      return;
    }

    setState(() => _savingFavorite = true);
    try {
      final current = _channelFavorites[channel.slug];
      final next = Map<String, FavoriteChannel>.of(_channelFavorites);

      if (current != null) {
        await _favoritesService.deleteFavorite(current.id);
        next.remove(channel.slug);
        _showMessage('${channel.name} removed from favorites');
      } else {
        next[channel.slug] = await _favoritesService.addFavorite(
          name: '$_eventTitle - ${channel.name}',
          url: widget.link.withChannelSlug(channel.slug).listenUrl,
          listenerPasswordRequired: channel.listenerTokenMode == 'password',
        );
        _showMessage('${channel.name} saved to favorites');
      }

      if (mounted) {
        setState(() => _channelFavorites = next);
      }
    } catch (error) {
      _showMessage('Could not update favorites: $error');
    } finally {
      if (mounted) {
        setState(() => _savingFavorite = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openChannel(EventDirectoryChannel channel) async {
    if (_openingChannel) {
      return;
    }

    setState(() {
      _openingChannel = true;
      _error = null;
    });

    try {
      final channelLink = widget.link.withChannelSlug(channel.slug);
      await _launcher.openChannel(
        context: context,
        link: channelLink,
        favorite: _channelFavorites[channel.slug],
        eventListenerSessionToken: _eventSessionToken,
        replaceCurrentRoute: widget.replaceCurrentRoute,
      );
      // The player can add or remove the channel favorite too.
      final directory = _directory;
      if (mounted && directory != null) {
        await _loadChannelFavorites(directory);
      }
    } on ListenerAccessException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _openingChannel = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory = _directory;
    final eventSaved = _eventFavorite != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(directory?.eventTitle.isNotEmpty == true
            ? directory!.eventTitle
            : 'Choose channel'),
        actions: [
          if (directory != null)
            IconButton(
              tooltip: eventSaved ? 'Remove event from favorites' : 'Save event to favorites',
              onPressed: _savingFavorite ? null : _toggleEventFavorite,
              icon: Icon(
                eventSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Choose a channel to listen.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (directory == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('This event directory is not available.'),
                  )
                else if (directory.access.listenerPasswordRequired &&
                    _eventSessionToken == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('Enter the event listener password to continue.'),
                  )
                else if (directory.channels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('No listener channels are available right now.'),
                  )
                else ...[
                  const SizedBox(height: 16),
                  ...directory.channels.map((channel) {
                    final channelSaved = _channelFavorites.containsKey(channel.slug);
                    return Card(
                      child: ListTile(
                        leading: _openingChannel
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.headphones_rounded),
                        title: Text(channel.name),
                        subtitle: Text(
                          channel.languageLabel ??
                              channel.languageCode ??
                              'Listener channel',
                        ),
                        trailing: IconButton(
                          tooltip: channelSaved
                              ? 'Remove ${channel.name} from favorites'
                              : 'Save ${channel.name} to favorites',
                          onPressed: _savingFavorite
                              ? null
                              : () => _toggleChannelFavorite(channel),
                          icon: Icon(
                            channelSaved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                        ),
                        onTap: _openingChannel ? null : () => _openChannel(channel),
                      ),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}
