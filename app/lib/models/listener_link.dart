class ListenerLink {
  const ListenerLink({
    required this.serverUrl,
    required this.eventSlug,
    required this.channelSlug,
    required this.originalUrl,
  });

  final Uri serverUrl;
  final String eventSlug;
  final String channelSlug;
  final Uri originalUrl;
}
