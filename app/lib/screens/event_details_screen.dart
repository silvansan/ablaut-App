import 'package:flutter/material.dart';

class EventDetailsScreen extends StatelessWidget {
  final Uri serverUrl;
  final String? eventId;
  final String? channelId;
  final String? token;

  const EventDetailsScreen({
    super.key,
    required this.serverUrl,
    this.eventId,
    this.channelId,
    this.token,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Server URL:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(serverUrl.toString(), style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Text('Event ID:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              eventId ?? 'Not provided',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text('Channel ID:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              channelId ?? 'Not provided',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text('Token:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(token ?? 'Not provided', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Back to scanner'),
            ),
          ],
        ),
      ),
    );
  }
}
