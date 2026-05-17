class PublicEvent {
  const PublicEvent({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
  });

  final String id;
  final String slug;
  final String name;
  final String description;

  factory PublicEvent.fromJson(Map<String, dynamic> json) {
    return PublicEvent(
      id: (json['id'] ?? json['slug'] ?? '').toString(),
      slug: (json['slug'] ?? json['id'] ?? '').toString(),
      name: (json['title'] ?? json['name'] ?? 'UnderSound').toString(),
      description: (json['description'] ??
              json['publicDescription'] ??
              json['location'] ??
              '')
          .toString(),
    );
  }
}

class PublicChannel {
  const PublicChannel({
    required this.id,
    required this.name,
    required this.slug,
    required this.languageCode,
    required this.languageLabel,
    required this.webrtcEnabled,
    required this.hlsEnabled,
    required this.icecastFallbackUrl,
    required this.listenerTokenMode,
  });

  final String id;
  final String name;
  final String slug;
  final String languageCode;
  final String languageLabel;
  final bool webrtcEnabled;
  final bool hlsEnabled;
  final String icecastFallbackUrl;
  final String listenerTokenMode;

  factory PublicChannel.fromJson(Map<String, dynamic> json) {
    return PublicChannel(
      id: (json['id'] ?? json['slug'] ?? '').toString(),
      name: (json['name'] ?? json['languageLabel'] ?? 'Audio').toString(),
      slug: (json['slug'] ?? json['id'] ?? '').toString(),
      languageCode: json['languageCode']?.toString() ?? '',
      languageLabel: json['languageLabel']?.toString() ?? '',
      webrtcEnabled: json['webrtcEnabled'] != false,
      hlsEnabled: json['hlsEnabled'] == true,
      icecastFallbackUrl: json['icecastFallbackUrl']?.toString() ?? '',
      listenerTokenMode: json['listenerTokenMode']?.toString() ?? '',
    );
  }
}

class PublicLiveKitContext {
  const PublicLiveKitContext({
    required this.roomName,
    required this.tokenEndpoint,
    required this.url,
  });

  final String roomName;
  final String tokenEndpoint;
  final String url;

  factory PublicLiveKitContext.fromJson(Map<String, dynamic> json) {
    return PublicLiveKitContext(
      roomName: json['roomName']?.toString() ?? '',
      tokenEndpoint: json['tokenEndpoint']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}

class PublicChannelContext {
  const PublicChannelContext({
    required this.event,
    required this.channel,
    required this.livekit,
    required this.logoUrl,
  });

  final PublicEvent event;
  final PublicChannel channel;
  final PublicLiveKitContext livekit;
  final String logoUrl;

  factory PublicChannelContext.fromJson(Map<String, dynamic> json) {
    return PublicChannelContext(
      event: PublicEvent.fromJson(
        json['event'] as Map<String, dynamic>? ?? const {},
      ),
      channel: PublicChannel.fromJson(
        json['channel'] as Map<String, dynamic>? ?? const {},
      ),
      livekit: PublicLiveKitContext.fromJson(
        json['livekit'] as Map<String, dynamic>? ?? const {},
      ),
      logoUrl: json['logoUrl']?.toString() ?? '',
    );
  }
}

class HlsStatus {
  const HlsStatus({
    required this.active,
    required this.url,
    required this.status,
    this.reason,
  });

  final bool active;
  final Uri? url;
  final String status;
  final String? reason;

  factory HlsStatus.fromJson(Map<String, dynamic> json, Uri serverUrl) {
    final rawUrl = json['url']?.toString();
    Uri? parsedUrl;
    if (rawUrl != null && rawUrl.isNotEmpty) {
      final candidate = Uri.parse(rawUrl);
      parsedUrl =
          candidate.hasScheme ? candidate : serverUrl.resolveUri(candidate);
    }

    return HlsStatus(
      active: json['active'] == true,
      url: parsedUrl,
      status: json['status']?.toString() ?? 'stopped',
      reason: json['reason']?.toString(),
    );
  }
}
