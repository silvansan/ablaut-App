import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ablaut_app/models/event_directory.dart';
import 'package:ablaut_app/models/public_channel.dart';
import 'package:ablaut_app/services/hls_service.dart';

void main() {
  test('parses shared public listener channel fixture', () async {
    final fixture = await _readFixture('public_listen_channel.fixture.json');
    final context = PublicChannelContext.fromJson(fixture);

    expect(context.event.slug, 'contract-event');
    expect(context.channel.slug, 'en');
    expect(context.channel.hlsEnabled, isTrue);
    expect(context.channel.hlsUrl, isNotNull);
    expect(context.channel.hlsUrl!.toString(), contains('/hls/contract-event/en/'));
    expect(context.livekit.tokenEndpoint, '/api/livekit/listener-token');
    expect(context.access.verifyPasswordEndpoint, '/api/listener/verify-password');
  });

  test('prefers studio hlsUrl over icecast fallback', () async {
    final fixture = await _readFixture('public_listen_channel.fixture.json');
    final context = PublicChannelContext.fromJson(fixture);
    final serverUrl = Uri.parse('https://voice.example.com');
    final service = HlsService();

    final playable = await service.resolvePlayableUrl(
      serverUrl: serverUrl,
      channel: context.channel,
    );

    expect(playable, isNotNull);
    expect(playable.toString(), contains('/hls/contract-event/en/live.m3u8'));
  });

  test('parses event directory fixture fields used by the app', () async {
    final fixture = await _readFixture('public_listen_event_directory.fixture.json');
    final directory = EventDirectoryContext.fromJson(fixture);

    expect(directory.eventSlug, 'contract-event');
    expect(directory.channels, isNotEmpty);
    expect(directory.access.verifyPasswordEndpoint, '/api/listener/verify-password');
  });
}

Future<Map<String, dynamic>> _readFixture(String name) async {
  final file = File('test/fixtures/$name');
  final raw = await file.readAsString();
  return jsonDecode(raw) as Map<String, dynamic>;
}
