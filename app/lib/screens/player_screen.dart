import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../models/listener_link.dart';
import '../models/public_channel.dart';
import '../services/android_power_service.dart';
import '../services/undersound_audio_service.dart';
import '../services/undersound_api_client.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.link,
    required this.channelContext,
  });

  final ListenerLink link;
  final PublicChannelContext channelContext;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _api = const UnderSoundApiClient();
  final _powerService = const AndroidPowerService();
  late final UnderSoundAudioHandler _audioHandler;
  StreamSubscription<UnderSoundPlaybackSnapshot>? _snapshotSubscription;
  bool _loading = false;
  String _status = 'Ready';
  Uri? _streamUrl;
  bool _playing = false;
  bool _batteryOptimizationIgnored = true;

  @override
  void initState() {
    super.initState();
    _audioHandler = UnderSoundAudioService.instance.handler;
    _snapshotSubscription = _audioHandler.snapshots.listen((snapshot) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = snapshot.displayText;
        _playing = snapshot.playing;
      });
    });
    final snapshot = _audioHandler.snapshot;
    _status = snapshot.displayText;
    _playing = snapshot.playing;
    _checkBatteryOptimization(showPrompt: true);
    _refreshHls();
  }

  @override
  void dispose() {
    _snapshotSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshHls() async {
    setState(() {
      _loading = true;
      _status = 'Checking stream...';
    });

    try {
      final hls = await _api.loadHlsStatus(
        serverUrl: widget.link.serverUrl,
        channelId: widget.channelContext.channel.id,
        token: widget.link.token,
      );
      developer.log(
        'HLS status: active=${hls.active}, status=${hls.status}, url=${hls.url}.',
        name: 'UnderSound.UI',
      );
      final url = hls.active ? hls.url : null;
      String status = hls.reason ?? hls.status;
      Uri? streamUrl = url;
      if (url != null) {
        final inspection = await _api.inspectHlsPlaylist(url);
        if (inspection.ended || inspection.stale) {
          streamUrl = null;
          status =
              'The HLS playlist has ended. Ask the speaker to restart publishing.';
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _streamUrl = streamUrl;
        _status = streamUrl != null
            ? 'Stream is live'
            : (status == 'stopped' ? 'Waiting for speaker' : status);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _status = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      await _audioHandler.pause();
      setState(() => _status = 'Paused');
      return;
    }

    if (_streamUrl == null) {
      await _refreshHls();
    }

    final url = _streamUrl;
    if (url == null) {
      setState(
        () => _status =
            'HLS is not running yet. Ask the speaker to start publishing.',
      );
      return;
    }

    try {
      setState(() => _status = 'Connecting...');
      await _audioHandler.playUnderSound(
        UnderSoundStreamRequest(
          link: widget.link,
          channelContext: widget.channelContext,
        ),
      );
      if (mounted) {
        setState(() => _status = 'Playing');
      }
    } catch (error, stackTrace) {
      developer.log(
        'Unable to start playback from player screen.',
        name: 'UnderSound.UI',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(
          () => _status = 'Audio stream not available. Try reconnecting.',
        );
      }
    }
  }

  Future<void> _checkBatteryOptimization({required bool showPrompt}) async {
    final ignored = await _powerService.isBatteryOptimizationIgnored();
    if (!mounted) {
      return;
    }
    setState(() => _batteryOptimizationIgnored = ignored);
    if (!ignored && showPrompt) {
      await _showBatteryOptimizationDialog();
    }
  }

  Future<void> _showBatteryOptimizationDialog() async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Keep audio playing'),
          content: const Text(
            'To keep audio playing while your screen is off, please allow UnderSound to ignore battery optimizations.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _powerService.requestIgnoreBatteryOptimizations();
                if (mounted) {
                  await _checkBatteryOptimization(showPrompt: false);
                }
              },
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openBatterySettings() async {
    await _powerService.openBatterySettings();
    if (mounted) {
      await _checkBatteryOptimization(showPrompt: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.channelContext.event;
    final channel = widget.channelContext.channel;

    return Scaffold(
      appBar: AppBar(title: const Text('Listen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(event.name, style: Theme.of(context).textTheme.headlineSmall),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(event.description),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    channel.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(_status),
                  if (!_batteryOptimizationIgnored) ...[
                    const SizedBox(height: 12),
                    Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Battery optimization is still enabled. Audio may stop when the screen turns off.',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _showBatteryOptimizationDialog,
                                  icon: const Icon(Icons.battery_saver),
                                  label: const Text('Allow optimization bypass'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _openBatterySettings,
                                  icon: const Icon(Icons.settings),
                                  label: const Text('Open Battery Settings'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  StreamBuilder<UnderSoundPlaybackSnapshot>(
                    stream: _audioHandler.snapshots,
                    initialData: _audioHandler.snapshot,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? _playing;
                      return FilledButton.icon(
                        onPressed: _loading ? null : _togglePlayback,
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        label: Text(playing ? 'Pause' : 'Play'),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _refreshHls,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reconnect'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.link.serverUrl.toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
