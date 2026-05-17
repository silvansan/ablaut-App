import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/favorites_service.dart';
import '../services/listener_link_parser.dart';
import '../services/undersound_api_client.dart';
import 'manual_link_screen.dart';
import 'player_screen.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({
    super.key,
    this.addScannedChannelToFavorites = false,
  });

  final bool addScannedChannelToFavorites;

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final _api = const UnderSoundApiClient();
  final _favoritesService = const FavoritesService();
  final _imagePicker = ImagePicker();

  late final MobileScannerController _scannerController =
      MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _loading = false;
  String? _error;

  Future<void> _handleCode(String? rawValue) async {
    if (_loading || rawValue == null || rawValue.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final link = ListenerLinkParser.parse(rawValue.trim());
      final channelContext = await _api.loadPublicChannel(link);
      if (widget.addScannedChannelToFavorites) {
        await _favoritesService.addFavorite(
          name: '${channelContext.event.name} - ${channelContext.channel.name}',
          url: link.originalUrl.toString(),
        );
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            link: link,
            channelContext: channelContext,
          ),
        ),
      );
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
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _scanQrFromFile() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      final BarcodeCapture? result =
          await _scannerController.analyzeImage(image.path);

      final String? rawValue = result?.barcodes.isNotEmpty == true
          ? result!.barcodes.first.rawValue
          : null;

      if (rawValue == null || rawValue.isEmpty) {
        if (mounted) {
          setState(() => _error = 'No QR code found in this image.');
        }
        return;
      }

      await _handleCode(rawValue);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not scan image: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final String? rawValue = capture.barcodes.isNotEmpty
                  ? capture.barcodes.first.rawValue
                  : null;

              _handleCode(rawValue);
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _loading
                          ? 'Loading event...'
                          : 'Point the camera at an UnderSound listener QR code.',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => ManualLinkScreen(
                                    addConnectedChannelToFavorites:
                                        widget.addScannedChannelToFavorites,
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Paste / enter link manually'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _scanQrFromFile,
                      icon: const Icon(Icons.image_rounded),
                      label: const Text('Scan QR code from file'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
