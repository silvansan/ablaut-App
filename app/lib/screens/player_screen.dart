import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../models/listener_link.dart';
import '../models/public_channel.dart';
import '../services/android_power_service.dart';
import '../services/hls_service.dart';
import '../services/livekit_service.dart';
import '../services/stream_connection_service.dart';
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
  final _hlsService = HlsService();
  final _powerService = const AndroidPowerService();
  late final UnderSoundAudioHandler _audioHandler;
  late final LiveKitService _liveKit;

  StreamSubscription<UnderSoundPlaybackSnapshot>? _snapshotSubscription;
  StreamSubscription<LiveKitPlaybackSnapshot>? _webrtcSnapshots;

  StreamTransportMode _transport = StreamTransportMode.webRtc;

  bool _checkingHls = false;
  String _status = 'Ready';
  Uri? _streamUrl;

  LiveKitPlaybackSnapshot _webrtcSnap = LiveKitPlaybackSnapshot(
    phase: StreamConnectionPhase.idle,
    connected: false,
    message:
        'WebRTC is selected. Press play for lowest latency, or switch to HLS.',
  );

  bool _webrtcBusy = false;
  bool _playing = false;
  bool _batteryOptimizationIgnored = true;

  Future<void>? _transportSwitchGate;

  @override
  void initState() {
    super.initState();
    _audioHandler = UnderSoundAudioService.instance.handler;
    _liveKit = LiveKitService();

    _snapshotSubscription = _audioHandler.snapshots.listen((snapshot) {
      if (!mounted) {
        return;
      }
      if (_transport != StreamTransportMode.hls) {
        return;
      }
      setState(() {
        _status = snapshot.displayText;
        _playing = snapshot.playing;
      });
    });

    final hlsBaseline = _audioHandler.snapshot;
    _status = hlsBaseline.displayText;
    _playing = hlsBaseline.playing;

    _webrtcSnapshots = _liveKit.snapshots.listen((snapshot) {
      if (!mounted) {
        return;
      }
      setState(() => _webrtcSnap = snapshot);
    });
    _webrtcSnap = _liveKit.snapshot;

    _checkBatteryOptimization(showPrompt: true);
    _refreshHls();
  }

  @override
  void dispose() {
    _snapshotSubscription?.cancel();
    _webrtcSnapshots?.cancel();
    unawaited(_liveKit.dispose());
    super.dispose();
  }

  Future<void> _switchTransport(StreamTransportMode next) async {
    if (next == _transport) {
      return;
    }
    final previous = _transport;
    setState(() => _transport = next);

    final gate = _transportSwitchGate = _mutePreviousTransport(previous);
    try {
      await gate;
    } catch (error, stack) {
      developer.log(
        'Transport switch cleanup failed.',
        name: 'UnderSound.UI',
        error: error,
        stackTrace: stack,
      );
    } finally {
      if (identical(_transportSwitchGate, gate)) {
        _transportSwitchGate = null;
      }
    }

    if (next == StreamTransportMode.hls) {
      final snap = _audioHandler.snapshot;
      if (mounted) {
        setState(() {
          _status = snap.displayText;
          _playing = snap.playing;
        });
      }
    } else if (mounted) {
      setState(() {
        _webrtcSnap = _liveKit.snapshot;
      });
    }
  }

  Future<void> _mutePreviousTransport(StreamTransportMode previous) async {
    if (previous == StreamTransportMode.webRtc) {
      await _liveKit.disconnect();
      return;
    }
    await _audioHandler.pause();
    if (mounted) {
      setState(() => _playing = false);
    }
  }

  Future<void> _refreshHls() async {
    setState(() {
      _checkingHls = true;
      if (_transport == StreamTransportMode.hls) {
        _status = 'Checking stream...';
      }
    });

    try {
      final summary = await _hlsService.summarizePublicStream(
        serverUrl: widget.link.serverUrl,
        channelId: widget.channelContext.channel.id,
        token: widget.link.token,
      );
      developer.log(
        'HLS summary: url=${summary.playableUrl}, status=${summary.statusSummary}.',
        name: 'UnderSound.UI',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _streamUrl = summary.playableUrl;
        if (_transport == StreamTransportMode.hls) {
          _status = summary.statusSummary;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_transport == StreamTransportMode.hls) {
          _status = error.toString();
        }
      });
    } finally {
      if (mounted) {
        setState(() => _checkingHls = false);
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_transport == StreamTransportMode.webRtc) {
      await _toggleWebRtcPlayback();
      return;
    }

    if (_playing) {
      await _audioHandler.pause();
      if (mounted) {
        setState(() => _status = 'Paused');
      }
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

  Future<void> _toggleWebRtcPlayback() async {
    if (_webrtcBusy) {
      return;
    }
    if (_webrtcSnap.connected) {
      setState(() => _webrtcBusy = true);
      try {
        await _liveKit.disconnect();
      } finally {
        if (mounted) {
          setState(() => _webrtcBusy = false);
        }
      }
      return;
    }

    setState(() => _webrtcBusy = true);
    try {
      await _liveKit.connect(
        link: widget.link,
        channelContext: widget.channelContext,
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'WebRTC did not start.',
        name: 'UnderSound.UI',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() => _webrtcBusy = false);
      }
    }
  }

  Future<void> _switchToHlsAfterWebRtcFailure() async {
    await _switchTransport(StreamTransportMode.hls);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switched to HLS. Press play to start audio.'),
        ),
      );
    }
  }

  Future<void> _tryWebRtcFromHls() async {
    await _audioHandler.pause();
    await _switchTransport(StreamTransportMode.webRtc);
    await _toggleWebRtcPlayback();
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

  String get _primaryStatusLine {
    if (_transport == StreamTransportMode.webRtc) {
      return _webrtcSnap.message ??
          _webrtcSnap.lastErrorDetail ??
          'WebRTC ready.';
    }
    return _status;
  }

  bool get _playDisabled {
    if (_transport == StreamTransportMode.webRtc) {
      return _webrtcBusy ||
          _webrtcSnap.phase == StreamConnectionPhase.connecting ||
          _webrtcSnap.phase == StreamConnectionPhase.reconnecting;
    }
    return _checkingHls;
  }

  bool get _webrtcPlayIconOn {
    return _webrtcSnap.connected;
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
          const SizedBox(height: 16),
          SegmentedButton<StreamTransportMode>(
            segments: const [
              ButtonSegment<StreamTransportMode>(
                value: StreamTransportMode.webRtc,
                label: Text('WebRTC'),
                icon: Icon(Icons.bolt_rounded),
              ),
              ButtonSegment<StreamTransportMode>(
                value: StreamTransportMode.hls,
                label: Text('HLS'),
                icon: Icon(Icons.stream_rounded),
              ),
            ],
            selected: <StreamTransportMode>{_transport},
            onSelectionChanged: (modes) async {
              final next = modes.first;
              await _switchTransport(next);
            },
          ),
          const SizedBox(height: 8),
          Text(
            _transport == StreamTransportMode.webRtc
                ? 'Default: lowest latency via LiveKit.'
                : 'Higher latency but ideal for locking the screen.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
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
                  Text(_primaryStatusLine),
                  if (_transport == StreamTransportMode.webRtc &&
                      _webrtcSnap.phase == StreamConnectionPhase.failed &&
                      (_webrtcSnap.lastErrorDetail ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _webrtcSnap.lastErrorDetail!,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _webrtcBusy
                          ? null
                          : () {
                              unawaited(_switchToHlsAfterWebRtcFailure());
                            },
                      icon: const Icon(Icons.stream_rounded),
                      label: const Text('Switch to HLS'),
                    ),
                  ],
                  if (_transport == StreamTransportMode.hls) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _webrtcBusy
                          ? null
                          : () {
                              unawaited(_tryWebRtcFromHls());
                            },
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('Try WebRTC again'),
                    ),
                  ],
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
                  if (_transport == StreamTransportMode.hls)
                    StreamBuilder<UnderSoundPlaybackSnapshot>(
                      stream: _audioHandler.snapshots,
                      initialData: _audioHandler.snapshot,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playing ?? _playing;
                        final hlsPhase = StreamConnectionService.phaseForHls(
                          snapshot.data?.status ??
                              UnderSoundPlaybackStatus.idle,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'HLS • ${_phaseLabel(hlsPhase)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: _playDisabled ? null : _togglePlayback,
                              icon: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                              ),
                              label: Text(playing ? 'Pause' : 'Play'),
                            ),
                          ],
                        );
                      },
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'WebRTC • ${_phaseLabel(_webrtcSnap.phase)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _playDisabled ? null : _togglePlayback,
                          icon: Icon(
                            _webrtcPlayIconOn ? Icons.pause : Icons.play_arrow,
                          ),
                          label:
                              Text(_webrtcPlayIconOn ? 'Pause' : 'Play WebRTC'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: (_checkingHls || _webrtcBusy)
                        ? null
                        : () async {
                            if (_transport == StreamTransportMode.webRtc) {
                              await _liveKit.disconnect();
                              await _toggleWebRtcPlayback();
                              return;
                            }
                            await _refreshHls();
                          },
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

  String _phaseLabel(StreamConnectionPhase phase) {
    return switch (phase) {
      StreamConnectionPhase.idle => 'Idle',
      StreamConnectionPhase.connecting => 'Connecting',
      StreamConnectionPhase.connected => 'Connected',
      StreamConnectionPhase.reconnecting => 'Reconnecting',
      StreamConnectionPhase.failed => 'Failed',
    };
  }
}
