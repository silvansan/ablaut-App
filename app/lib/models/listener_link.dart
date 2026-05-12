class ListenerLink {
  const ListenerLink({
    required this.serverUrl,
    required this.eventSlug,
    required this.channelName,
    required this.token,
  });

  final Uri serverUrl;
  final String eventSlug;
  final String channelName;
  final String token;
}
