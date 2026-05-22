import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';
import 'favorites_screen.dart';
import 'scan_qr_screen.dart';

const _githubRepositoryUrl = 'https://github.com/silvansan/ablaut-App';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _updateService = const AppUpdateService();

  String? _versionLabel;
  AppUpdateInfo? _updateInfo;
  bool _checkingUpdate = true;

  @override
  void initState() {
    super.initState();
    _loadVersionAndUpdates();
  }

  Future<void> _loadVersionAndUpdates() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final updateInfo = await _updateService.checkForUpdate();

    if (!mounted) {
      return;
    }

    setState(() {
      _versionLabel = 'Version ${packageInfo.version} (${packageInfo.buildNumber})';
      _updateInfo = updateInfo?.updateAvailable == true ? updateInfo : null;
      _checkingUpdate = false;
    });

    final update = _updateInfo;
    if (update != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showUpdateDialog(update);
        }
      });
    }
  }

  Future<void> _openUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the update download link.')),
      );
    }
  }

  Future<void> _showUpdateDialog(AppUpdateInfo update) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A newer ablaut app is available (${update.latestVersion}). '
                'You are on ${update.currentVersion}.',
              ),
              if (update.releaseNotes != null && update.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  update.releaseNotes!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Tap Download update to fetch the latest APK, then install it when Android prompts you.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _openUpdateUrl(update.downloadUrl);
              },
              child: const Text('Download update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final updateInfo = _updateInfo;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Center(
              child: Image.asset(
                'assets/ablaut-logo.png',
                height: 90,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ablaut',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Join live translated audio from an ablaut server, then keep your favorite listener links ready.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (updateInfo != null) ...[
              const SizedBox(height: 20),
              Material(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update ${updateInfo.latestVersion} available',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Download the latest APK to get event QR channel picking and listener fixes.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _openUpdateUrl(updateInfo.downloadUrl),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download update'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            _HomeActionCard(
              icon: Icons.favorite_rounded,
              title: 'My favorites',
              subtitle: 'Open saved listener channels.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              ),
            ),
            const SizedBox(height: 14),
            _HomeActionCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan QR code',
              subtitle: 'Use the camera to join an event.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScanQrScreen()),
              ),
            ),
            const SizedBox(height: 28),
            _AppInfoFooter(
              versionLabel: _checkingUpdate
                  ? 'Checking for updates...'
                  : (_versionLabel ?? 'Version unknown'),
              onOpenRepository: () => _openRepository(context),
              onCheckUpdates: _loadVersionAndUpdates,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRepository(BuildContext context) async {
    final uri = Uri.parse(_githubRepositoryUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open GitHub repository.')),
      );
    }
  }
}

class _AppInfoFooter extends StatelessWidget {
  const _AppInfoFooter({
    required this.onOpenRepository,
    required this.onCheckUpdates,
    required this.versionLabel,
  });

  final VoidCallback onOpenRepository;
  final VoidCallback onCheckUpdates;
  final String versionLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          versionLabel,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onCheckUpdates,
          icon: const Icon(Icons.system_update_alt_rounded),
          label: const Text('Check for updates'),
        ),
        TextButton.icon(
          onPressed: onOpenRepository,
          icon: const Icon(Icons.code_rounded),
          label: const Text('GitHub repository'),
        ),
      ],
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(icon, color: colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
