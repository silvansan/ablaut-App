import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/listener_link.dart';
import '../models/public_channel.dart';
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
  final _player = AudioPlayer();
  bool _loading = false;
  String _status = 'Ready';
  Uri? _streamUrl;

  @override
  void initState() {
    super.initState();
    _configureAudio();
    _refreshHls();
  }

  Future<void> _configureAudio() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  @override
  void dispose() {
    _player.dispose();
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
      setState(() {
        _streamUrl = hls.active ? hls.url : null;
        _status = hls.active ? 'Stream is live' : 'Waiting for speaker';
      });
    } catch (error) {
      setState(() => _status = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_player.playing) {
      await _player.pause();
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
      await _player.setUrl(url.toString());
      await _player.play();
      setState(() => _status = 'Playing');
    } catch (_) {
      setState(() => _status = 'Audio stream not available. Try reconnecting.');
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
                  const SizedBox(height: 18),
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? _player.playing;
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
