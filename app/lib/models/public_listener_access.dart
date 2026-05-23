class PublicListenerAccess {
  const PublicListenerAccess({
    required this.listenerTokenMode,
    required this.listenerPasswordRequired,
    required this.listenerPasswordConfigured,
    required this.listenerPasswordMissing,
    required this.listenerUnavailable,
    required this.verifyPasswordEndpoint,
  });

  final String listenerTokenMode;
  final bool listenerPasswordRequired;
  final bool listenerPasswordConfigured;
  final bool listenerPasswordMissing;
  final bool listenerUnavailable;
  final String verifyPasswordEndpoint;

  factory PublicListenerAccess.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return PublicListenerAccess.publicDefault();
    }
    return PublicListenerAccess(
      listenerTokenMode: json['listenerTokenMode']?.toString() ?? 'public',
      listenerPasswordRequired: json['listenerPasswordRequired'] == true,
      listenerPasswordConfigured: json['listenerPasswordConfigured'] == true,
      listenerPasswordMissing: json['listenerPasswordMissing'] == true,
      listenerUnavailable: json['listenerUnavailable'] == true,
      verifyPasswordEndpoint:
          json['verifyPasswordEndpoint']?.toString() ??
              '/api/listener/verify-password',
    );
  }

  factory PublicListenerAccess.publicDefault() {
    return const PublicListenerAccess(
      listenerTokenMode: 'public',
      listenerPasswordRequired: false,
      listenerPasswordConfigured: false,
      listenerPasswordMissing: false,
      listenerUnavailable: false,
      verifyPasswordEndpoint: '/api/listener/verify-password',
    );
  }

  bool get isPrivateChannel =>
      listenerUnavailable || listenerTokenMode == 'private';

  Uri verifyPasswordUri(Uri serverOrigin) {
    final endpoint = verifyPasswordEndpoint.trim();
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      final absolute = Uri.parse(endpoint);
      if (absolute.host != serverOrigin.host ||
          absolute.scheme != serverOrigin.scheme ||
          (absolute.hasPort ? absolute.port : null) !=
              (serverOrigin.hasPort ? serverOrigin.port : null)) {
        return serverOrigin.replace(path: '/api/listener/verify-password');
      }
      return absolute;
    }
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return serverOrigin.replace(path: path);
  }
}
