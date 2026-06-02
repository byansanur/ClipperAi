// lib/features/clip_generator/models/job_response.dart

enum ClipStatus { processing, completed, failed, unknown }

class JobResponse {
  final String id;
  final ClipStatus status;
  final String? videoPath;
  final String? error;

  JobResponse({
    required this.id,
    required this.status,
    this.videoPath,
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

    return JobResponse(
      id: json['id'] ?? '',
      status: mappedStatus,
      videoPath: json['video_path'],
      error: json['error'],
    );
  }
}
