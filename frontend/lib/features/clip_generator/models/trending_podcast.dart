// lib/features/clip_generator/models/trending_podcast.dart

class TrendingPodcast {
  final String id;
  final String title;
  final String channelName;
  final String youtubeUrl;
  final String thumbnailUrl;
  final String duration;
  final String layoutMode;
  final String category;

  const TrendingPodcast({
    required this.id,
    required this.title,
    required this.channelName,
    required this.youtubeUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.layoutMode,
    required this.category,
  });

  factory TrendingPodcast.fromJson(Map<String, dynamic> json) {
    return TrendingPodcast(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      channelName: json['channel_name'] ?? '',
      youtubeUrl: json['youtube_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      duration: json['duration'] ?? '',
      layoutMode: json['layout_mode'] ?? 'podcast',
      category: json['category'] ?? 'General',
    );
  }
}
