// lib/features/clip_generator/providers/clip_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../models/job_response.dart';

enum UIState { idle, submitting, loading, result, error }

class ClipProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  UIState _state = UIState.idle;
  UIState get state => _state;

  String _selectedLayout = 'solo';
  String get selectedLayout => _selectedLayout;

  String? _jobId;
  String? get jobId => _jobId;

  String? _videoUrl;
  String? get videoUrl => _videoUrl;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _pollingTimer;

  void setLayout(String mode) {
    _selectedLayout = mode;
    notifyListeners();
  }

  // Submit URL YouTube untuk memicu pembuatan clip
  Future<void> submitYoutubeUrl(String youtubeUrl) async {
    _state = UIState.submitting;
    _errorMessage = null;
    _jobId = null;
    _videoUrl = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        '/api/v1/clips',
        data: {
          'youtube_url': youtubeUrl,
          'layout_mode': _selectedLayout,
        },
      );

      if (response.statusCode == 202) {
        _jobId = response.data['job_id'];
        _state = UIState.loading;
        notifyListeners();
        
        // Memulai asinkron polling status
        _startPolling(_jobId!);
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleError(e.message ?? 'Gagal menghubungi server.');
    } catch (e) {
      _handleError(e.toString());
    }
  }

  // Polling Engine: Periksa status backend setiap 30 detik
  void _startPolling(String id) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final response = await _apiClient.dio.get('/api/v1/clips/$id');
        
        if (response.statusCode == 200) {
          final job = JobResponse.fromJson(response.data);
          
          if (job.status == ClipStatus.completed) {
            timer.cancel();
            // Prefix output path dengan base URL backend
            final path = job.videoPath ?? '';
            final cleanPath = path.startsWith('/') ? path : '/$path';
            _videoUrl = '${_apiClient.dio.options.baseUrl}$cleanPath';
            
            _state = UIState.result;
            notifyListeners();
          } else if (job.status == ClipStatus.failed) {
            timer.cancel();
            _handleError(job.error ?? 'Backend gagal memproses klip video.');
          }
          // Jika masih 'processing', biarkan timer terus berjalan
        }
      } catch (e) {
        // Toleransi error jaringan temporer saat polling,
        // jangan langsung batalkan timer kecuali error berturut-turut.
      }
    });
  }

  void _handleError(String message) {
    _pollingTimer?.cancel();
    _errorMessage = message;
    _state = UIState.error;
    notifyListeners();
  }

  // Reset state agar pengguna bisa memproses video baru
  void reset() {
    _pollingTimer?.cancel();
    _state = UIState.idle;
    _jobId = null;
    _videoUrl = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
