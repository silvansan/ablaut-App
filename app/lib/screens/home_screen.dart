import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'favorites_screen.dart';
import 'scan_qr_screen.dart';

const _appVersionLabel = 'Version 0.2.1';
const _githubRepositoryUrl = 'https://github.com/silvansan/UnderSound-Mobile';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Center(
              child: Image.asset(
                'assets/UnderSound-Logo.png',
                height: 90,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'UnderSound Mobile',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Join an UnderSound event, listen to live channel audio, and keep your favorite listener links ready.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
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
              onOpenRepository: () => _openRepository(context),
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
  const _AppInfoFooter({required this.onOpenRepository});

  final VoidCallback onOpenRepository;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          _appVersionLabel,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
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
