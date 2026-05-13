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
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? 'UnderSound',
      description: (json['publicDescription'] ?? json['location'] ?? '')
          .toString(),
    );
  }
}

class PublicChannel {
  const PublicChannel({required this.id, required this.name});

  final String id;
  final String name;

  factory PublicChannel.fromJson(Map<String, dynamic> json) {
    return PublicChannel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Audio',
    );
  }
}

class PublicChannelContext {
  const PublicChannelContext({
    required this.event,
    required this.channel,
    required this.logoUrl,
  });

  final PublicEvent event;
  final PublicChannel channel;
  final String logoUrl;

  factory PublicChannelContext.fromJson(Map<String, dynamic> json) {
    return PublicChannelContext(
      event: PublicEvent.fromJson(
        json['event'] as Map<String, dynamic>? ?? const {},
      ),
      channel: PublicChannel.fromJson(
        json['channel'] as Map<String, dynamic>? ?? const {},
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
      parsedUrl = candidate.hasScheme
          ? candidate
          : serverUrl.resolveUri(candidate);
    }

    return HlsStatus(
      active: json['active'] == true,
      url: parsedUrl,
      status: json['status']?.toString() ?? 'stopped',
      reason: json['reason']?.toString(),
    );
  }
}
