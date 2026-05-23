import 'package:flutter_test/flutter_test.dart';
import 'package:ablaut_app/models/public_channel.dart';
import 'package:ablaut_app/models/public_listener_access.dart';

void main() {
  test('parses password-protected access metadata', () {
    final access = PublicListenerAccess.fromJson({
      'listenerTokenMode': 'password',
      'listenerPasswordRequired': true,
      'listenerPasswordConfigured': true,
      'listenerPasswordMissing': false,
      'listenerUnavailable': false,
      'verifyPasswordEndpoint': '/api/listener/verify-password',
    });

    expect(access.listenerPasswordRequired, isTrue);
    expect(access.isPrivateChannel, isFalse);
    expect(
      access.verifyPasswordUri(Uri.parse('https://studio.example.com')).path,
      '/api/listener/verify-password',
    );
  });

  test('defaults to public access when metadata is missing', () {
    final access = PublicListenerAccess.fromJson(null);
    expect(access.listenerPasswordRequired, isFalse);
    expect(access.listenerTokenMode, 'public');
  });

  test('public channel context includes access block', () {
    final context = PublicChannelContext.fromJson({
      'event': {'slug': 'evt', 'title': 'Event'},
      'channel': {'slug': 'en', 'name': 'English'},
      'livekit': {},
      'access': {
        'listenerTokenMode': 'private',
        'listenerUnavailable': true,
      },
    });

    expect(context.access.isPrivateChannel, isTrue);
  });

  test('ignores foreign absolute verify-password endpoints', () {
    final access = PublicListenerAccess.fromJson({
      'verifyPasswordEndpoint': 'https://evil.example.com/steal',
    });
    final uri = access.verifyPasswordUri(Uri.parse('https://studio.example.com'));

    expect(uri.host, 'studio.example.com');
    expect(uri.path, '/api/listener/verify-password');
  });
}
