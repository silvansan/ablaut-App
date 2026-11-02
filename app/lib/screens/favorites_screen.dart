import 'package:flutter/material.dart';

import '../models/favorite_channel.dart';
import '../services/favorite_groups.dart';
import '../services/favorites_service.dart';
import '../services/listener_channel_launcher.dart';
import '../services/listener_link_parser.dart';
import '../services/listener_session_coordinator.dart';
import '../services/ablaut_api_client.dart';
import 'edit_favorite_screen.dart';
import 'scan_qr_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _favoritesService = const FavoritesService();
  final _launcher = const ListenerChannelLauncher();
  final _api = const AblautApiClient();
  final _sessionCoordinator = const ListenerSessionCoordinator();

  List<FavoriteChannel> _favorites = const [];
  String? _error;
  String? _openingId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final favorites = await _favoritesService.loadFavorites();
      if (mounted) {
        setState(() => _favorites = favorites);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openFavorite(FavoriteChannel favorite) async {
    setState(() {
      _openingId = favorite.id;
      _error = null;
    });
    try {
      final link = ListenerLinkParser.parse(favorite.url);
      await _launcher.openLink(
        context: context,
        link: link,
        favorite: favorite,
      );
      if (mounted) {
        await _loadFavorites();
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
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
        setState(() => _openingId = null);
      }
    }
  }

  Future<void> _changeFavoritePassword(FavoriteChannel favorite) async {
    setState(() => _error = null);
    try {
      final link = ListenerLinkParser.parse(favorite.url);
      final channelContext = await _api.loadPublicChannel(link);
      if (!context.mounted) {
        return;
      }
      await _sessionCoordinator.changeStoredPassword(
        context: context,
        link: link,
        channelContext: channelContext,
        favorite: favorite,
      );
      if (!context.mounted) {
        return;
      }
      await _loadFavorites();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listener password updated')),
      );
    } on ListenerAccessException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _addFavorite() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ScanQrScreen(
          addScannedChannelToFavorites: true,
        ),
      ),
    );
    await _loadFavorites();
  }

  Future<void> _editFavorite(FavoriteChannel favorite) async {
    final updated = await Navigator.of(context).push<FavoriteChannel>(
      MaterialPageRoute(
        builder: (_) => EditFavoriteScreen(favorite: favorite),
      ),
    );
    if (updated == null) {
      return;
    }
    await _favoritesService.updateFavorite(updated);
    await _loadFavorites();
  }

  Future<void> _confirmDelete(FavoriteChannel favorite, {String? note}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete favorite?'),
          content: Text(
            note == null
                ? 'Remove "${favorite.name}" from your favorites?'
                : 'Remove "${favorite.name}" from your favorites?\n\n$note',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }
    await _favoritesService.deleteFavorite(favorite.id);
    await _loadFavorites();
  }

  Widget _buildFavoriteCard(FavoriteEntry entry) {
    final favorite = entry.favorite;
    final isEvent = entry.isEvent;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              child: _openingId == favorite.id
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      favorite.isPasswordProtected
                          ? Icons.lock_rounded
                          : isEvent
                              ? Icons.event_rounded
                              : Icons.headphones_rounded,
                    ),
            ),
            title: Text(favorite.name),
            subtitle: Text(
              isEvent ? 'Event · choose a channel' : favorite.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: _openingId == null ? () => _openFavorite(favorite) : null,
            trailing: PopupMenuButton<_FavoriteAction>(
              onSelected: (action) {
                switch (action) {
                  case _FavoriteAction.edit:
                    _editFavorite(favorite);
                  case _FavoriteAction.changePassword:
                    _changeFavoritePassword(favorite);
                  case _FavoriteAction.delete:
                    _confirmDelete(
                      favorite,
                      note: entry.channels.isEmpty
                          ? null
                          : 'Its saved channels stay in your favorites.',
                    );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _FavoriteAction.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_rounded),
                    title: Text('Edit'),
                  ),
                ),
                if (favorite.isPasswordProtected && !isEvent)
                  const PopupMenuItem(
                    value: _FavoriteAction.changePassword,
                    child: ListTile(
                      leading: Icon(Icons.lock_reset_rounded),
                      title: Text('Change listener password'),
                    ),
                  ),
                const PopupMenuItem(
                  value: _FavoriteAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ),
          // Saved channels of this event: one tap straight into that language.
          if (entry.channels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final channel in entry.channels)
                    InputChip(
                      avatar: _openingId == channel.id
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              channel.isPasswordProtected
                                  ? Icons.lock_rounded
                                  : Icons.headphones_rounded,
                              size: 18,
                            ),
                      label: Text(channelLabel(channel, favorite)),
                      tooltip: 'Listen to ${channel.name}',
                      onPressed: _openingId == null
                          ? () => _openFavorite(channel)
                          : null,
                      deleteButtonTooltipMessage: 'Remove from favorites',
                      onDeleted: () => _confirmDelete(channel),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My favorites')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFavorite,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Add'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              Material(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_favorites.isEmpty)
              _EmptyFavorites(onAdd: _addFavorite)
            else
              for (final entry in groupFavorites(_favorites))
                _buildFavoriteCard(entry),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

enum _FavoriteAction { edit, changePassword, delete }

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 56,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('No favorites yet', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Save the events and channels you use often, then open them from here.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan QR code'),
          ),
        ],
      ),
    );
  }
}
