// lib/features/clip_generator/providers/clip_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  String getFullUrl(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '${_apiClient.dio.options.baseUrl}$cleanPath';
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _pollingTimer;

  // Manajemen Riwayat Job Lokal
  List<String> _savedJobIds = [];
  List<String> get savedJobIds => _savedJobIds;

  final Map<String, JobResponse> _jobStatuses = {};
  Map<String, JobResponse> get jobStatuses => _jobStatuses;

  ClipProvider() {
    initStorage();
  }

  Future<void> initStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _savedJobIds = prefs.getStringList('saved_jobs') ?? [];
    notifyListeners();
    
    // Ambil status terbaru untuk setiap job yang tersimpan
    for (String id in _savedJobIds.toList()) {
      _fetchJobStatus(id);
    }
  }

  Future<void> _fetchJobStatus(String id) async {
    try {
      final response = await _apiClient.dio.get('/api/v1/clips/$id');
      if (response.statusCode == 200) {
        _jobStatuses[id] = JobResponse.fromJson(response.data);
        notifyListeners();
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        // Jika backend tidak mengenali ID (misal server restart), hapus dari storage lokal
        await removeJob(id);
      }
    }
  }

  Future<void> _saveJobId(String id) async {
    if (!_savedJobIds.contains(id)) {
      _savedJobIds.insert(0, id);
      if (_savedJobIds.length > 3) {
        _savedJobIds = _savedJobIds.sublist(0, 3); // Limit maksimal 3 job
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_jobs', _savedJobIds);
      
      // Inisialisasi awal agar UI tidak null
      _jobStatuses[id] = JobResponse(id: id, status: ClipStatus.processing);
      notifyListeners();
    }
  }

  Future<void> removeJob(String id) async {
    _savedJobIds.remove(id);
    _jobStatuses.remove(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_jobs', _savedJobIds);
    notifyListeners();
  }

  Future<void> resumeJob(String id) async {
    final job = _jobStatuses[id];
    if (job == null) return;
    
    _jobId = id;
    if (job.status == ClipStatus.completed) {
      final path = job.videoPath ?? '';
      final cleanPath = path.startsWith('/') ? path : '/$path';
      _videoUrl = '${_apiClient.dio.options.baseUrl}$cleanPath';
      _state = UIState.result;
    } else if (job.status == ClipStatus.failed) {
      _errorMessage = job.error ?? 'Backend gagal memproses klip video.';
      _state = UIState.error;
    } else {
      _state = UIState.loading;
      _startPolling(id);
    }
    notifyListeners();
  }

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
        
        await _saveJobId(_jobId!); // Simpan ID ke local storage
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

  // Polling Engine: Periksa status backend setiap 5 detik agar responsif
  void _startPolling(String id) {
    _pollingTimer?.cancel();
    // Gunakan 5 detik untuk cek berkala yang cepat pada status processing
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final response = await _apiClient.dio.get('/api/v1/clips/$id');
        
        if (response.statusCode == 200) {
          final job = JobResponse.fromJson(response.data);
          
          // Sinkronisasi status di dictionary utama agar history UI update real-time
          _jobStatuses[id] = job;
          notifyListeners();

          if (job.status == ClipStatus.completed) {
            timer.cancel();
            // Prefix output path dengan base URL backend
            final path = job.videoPath ?? '';
            final cleanPath = path.startsWith('/') ? path : '/$path';
            
            // Jika jobId yang sedang di-poll adalah halaman yg sedang dibuka (bukan proses background)
            if (_jobId == id) {
              _videoUrl = '${_apiClient.dio.options.baseUrl}$cleanPath';
              _state = UIState.result;
              notifyListeners();
            }
          } else if (job.status == ClipStatus.failed) {
            timer.cancel();
            if (_jobId == id) {
              _handleError(job.error ?? 'Backend gagal memproses klip video.');
            }
          }
        }
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 404) {
          timer.cancel();
          await removeJob(id); // Jika terhapus dari backend
          if (_jobId == id) {
            _handleError('Sesi tidak ditemukan atau server direstart.');
          }
        }
      }
    });
  }

  Future<void> cancelJob() async {
    final currentJobId = _jobId;
    if (currentJobId != null) {
      try {
        await _apiClient.dio.delete('/api/v1/clips/$currentJobId');
      } catch (e) {
        debugPrint('Failed to cancel job on backend: $e');
      }
      // Hapus dari cache local storage ketika dibatalkan
      await removeJob(currentJobId);
    }
    reset();
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
