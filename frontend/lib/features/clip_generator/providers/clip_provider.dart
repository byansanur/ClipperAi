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

  List<String>? _videoUrls;
  List<String>? get videoUrls => _videoUrls;

  bool _isGeneratingMore = false;
  bool get isGeneratingMore => _isGeneratingMore;

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
    final paths = job.videoPaths ?? [];
    
    if (paths.isNotEmpty) {
      _videoUrls = paths.map((path) {
        final cleanPath = path.startsWith('/') ? path : '/$path';
        return '${_apiClient.dio.options.baseUrl}$cleanPath';
      }).toList();
      _state = UIState.result;
      
      if (job.status == ClipStatus.processing) {
        _startPolling(id);
      }
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
    _videoUrls = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        '/api/v1/clips',
        data: {
          'youtube_url': youtubeUrl,
          'layout_mode': _selectedLayout,
        },
      );

      if (response.statusCode == 202 || response.statusCode == 200) {
        _jobId = response.data['job_id'];
        _state = UIState.loading;
        
        await _saveJobId(_jobId!); // Simpan ID ke local storage
        notifyListeners();
        
        if (response.statusCode == 200) {
          // Jika status 200 (cache hit), data job mungkin sudah ada
          // Kita bisa langsung memanggil polling yang akan langsung menghentikan timer
          // dan memindahkan ke state result
          _startPolling(_jobId!);
        } else {
          // Memulai asinkron polling status normal
          _startPolling(_jobId!);
        }
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleError(e.message ?? 'Gagal menghubungi server.');
    } catch (e) {
      _handleError(e.toString());
    }
  }

  // Generate Next Clip on demand
  Future<void> generateNextClip(String jobId) async {
    _isGeneratingMore = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post('/api/v1/clips/$jobId/next');

      if (response.statusCode == 202) {
        // Start polling again because job is back to processing
        _startPolling(jobId);
      } else {
        _isGeneratingMore = false;
        notifyListeners();
      }
    } on DioException catch (e) {
      _isGeneratingMore = false;
      // We might want to show error without resetting everything
      debugPrint('Error generating next clip: ${e.response?.data}');
      notifyListeners();
    } catch (e) {
      _isGeneratingMore = false;
      debugPrint('Error generating next clip: $e');
      notifyListeners();
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

          // Hentikan timer JIKA status sudah final (completed / failed)
          if (job.status == ClipStatus.completed || job.status == ClipStatus.failed) {
            timer.cancel();
            if (_jobId == id) {
              _isGeneratingMore = false; // reset loading state
            }
          }

          if (_jobId == id) {
            // Update daftar videoUrl jika ada yang baru (progressive delivery)
            final paths = job.videoPaths ?? [];
            if (paths.isNotEmpty) {
              _videoUrls = paths.map((path) {
                final cleanPath = path.startsWith('/') ? path : '/$path';
                return '${_apiClient.dio.options.baseUrl}$cleanPath';
              }).toList();

              // Berubah ke ResultView jika belum
              if (_state != UIState.result) {
                _state = UIState.result;
              }
            }

            if (job.status == ClipStatus.failed && paths.isEmpty) {
              _handleError(job.error ?? 'Backend gagal memproses klip video.');
            }
          }
          
          notifyListeners();
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
    _videoUrls = null;
    _errorMessage = null;
    _isGeneratingMore = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
