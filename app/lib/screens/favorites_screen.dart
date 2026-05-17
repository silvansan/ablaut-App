import 'package:flutter/material.dart';

import '../models/favorite_channel.dart';
import '../services/favorites_service.dart';
import '../services/listener_link_parser.dart';
import '../services/undersound_api_client.dart';
import 'edit_favorite_screen.dart';
import 'player_screen.dart';
import 'scan_qr_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _favoritesService = const FavoritesService();
  final _api = const UnderSoundApiClient();

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
      final channelContext = await _api.loadPublicChannel(link);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PlayerScreen(link: link, channelContext: channelContext),
        ),
      );
      if (mounted) {
        await _loadFavorites();
      }
    } on FormatException catch (error) {
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

  Future<void> _confirmDelete(FavoriteChannel favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete favorite?'),
          content: Text('Remove "${favorite.name}" from your favorites?'),
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
              for (final favorite in _favorites) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
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
                          : const Icon(Icons.headphones_rounded),
                    ),
                    title: Text(favorite.name),
                    subtitle: Text(
                      favorite.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: _openingId == null
                        ? () => _openFavorite(favorite)
                        : null,
                    trailing: PopupMenuButton<_FavoriteAction>(
                      onSelected: (action) {
                        switch (action) {
                          case _FavoriteAction.edit:
                            _editFavorite(favorite);
                          case _FavoriteAction.delete:
                            _confirmDelete(favorite);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _FavoriteAction.edit,
                          child: ListTile(
                            leading: Icon(Icons.edit_rounded),
                            title: Text('Edit'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _FavoriteAction.delete,
                          child: ListTile(
                            leading: Icon(Icons.delete_outline_rounded),
                            title: Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

enum _FavoriteAction { edit, delete }

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
            'Save listener links you use often, then open them from here.',
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
