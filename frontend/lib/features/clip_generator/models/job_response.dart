// lib/features/clip_generator/models/job_response.dart

enum ClipStatus { processing, completed, failed, unknown }

class JobResponse {
  final String id;
  final ClipStatus status;
  final List<String>? videoPaths;
  final String? error;

  JobResponse({
    required this.id,
    required this.status,
    this.videoPaths,
    this.error,
  });

  factory JobResponse.fromJson(Map<String, dynamic> json) {
    ClipStatus mappedStatus;
    switch (json['status']) {
      case 'processing':
        mappedStatus = ClipStatus.processing;
        break;
      case 'completed':
        mappedStatus = ClipStatus.completed;
        break;
      case 'failed':
        mappedStatus = ClipStatus.failed;
        break;
      default:
        mappedStatus = ClipStatus.unknown;
    }

    List<String>? parsedVideoPaths;
    if (json['video_paths'] != null) {
      parsedVideoPaths = List<String>.from(json['video_paths']);
    }

    return JobResponse(
      id: json['id'] ?? '',
      status: mappedStatus,
      videoPaths: parsedVideoPaths,
      error: json['error'],
    );
  }
}
