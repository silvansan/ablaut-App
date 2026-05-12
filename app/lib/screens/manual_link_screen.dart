import 'package:flutter/material.dart';

import '../models/listener_link.dart';
import '../models/public_channel.dart';
import '../services/listener_link_parser.dart';
import '../services/undersound_api_client.dart';
import 'player_screen.dart';

class ManualLinkScreen extends StatefulWidget {
  const ManualLinkScreen({super.key});

  @override
  State<ManualLinkScreen> createState() => _ManualLinkScreenState();
}

class _ManualLinkScreenState extends State<ManualLinkScreen> {
  final _controller = TextEditingController();
  final _api = const UnderSoundApiClient();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final link = ListenerLinkParser.parse(_controller.text);
      final channelContext = await _api.loadPublicChannel(link);
      if (!mounted) return;
      _openPlayer(link, channelContext);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _openPlayer(ListenerLink link, PublicChannelContext channelContext) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            PlayerScreen(link: link, channelContext: channelContext),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter listener link')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Listener URL',
              hintText: 'https://your-server/e/event/EN/listen?token=...',
            ),
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _connect,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link),
            label: Text(_loading ? 'Connecting...' : 'Connect'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
