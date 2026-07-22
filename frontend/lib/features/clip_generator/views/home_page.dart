// lib/features/clip_generator/views/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/clip_provider.dart';
import 'loading_view.dart';
import 'result_view.dart';
import 'trending_podcasts_section.dart';
import '../models/job_response.dart';
import '../../../core/services/download_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _urlController.text = data!.text!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClipProvider>(context);

    return PopScope(
      canPop: provider.state == UIState.idle || provider.state == UIState.error,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Intercept system back button (swipe back)
          // Kembalikan ke halaman form jika sedang di preview atau loading
          provider.reset();
        }
      },
      child: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, ClipProvider provider) {
    // Dynamic state rendering
    switch (provider.state) {
      case UIState.loading:
        return const Scaffold(body: LoadingView());
      case UIState.result:
        return const Scaffold(body: ResultView());
      default:
        return Scaffold(
          body: Stack(
            children: [
              // Efek Background Gradasi Elegan
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F0F12), Color(0xFF1F1A3A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        const HeaderWidget(),
                        const SizedBox(height: 32),
                        
                        // Unified Form Card
                        Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C22), // abu-abu sangat gelap
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Input URL
                                TextFormField(
                                  controller: _urlController,
                                  keyboardType: TextInputType.url,
                                  decoration: InputDecoration(
                                    hintText: 'Masukkan link YouTube (e.g., https://...)',
                                    hintStyle: const TextStyle(color: Colors.white38),
                                    prefixIcon: const Icon(Icons.link, color: Colors.white54),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.content_paste, color: Colors.white54),
                                      onPressed: _pasteFromClipboard,
                                      tooltip: 'Paste from clipboard',
                                    ),
                                    filled: true,
                                    fillColor: Colors.black26,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Tautan URL tidak boleh kosong';
                                    }
                                    if (!value.contains('youtube.com') &&
                                        !value.contains('youtu.be')) {
                                      return 'Harap masukkan tautan YouTube yang valid';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                
                                // Segmented Control (Pilih Tipe Video)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildSegmentItem(context, provider, 'Solo (Vlog)', 'solo'),
                                      _buildSegmentItem(context, provider, 'Presentasi', 'presentation'),
                                      _buildSegmentItem(context, provider, 'Podcast', 'podcast'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                
                                // Error Banner
                                if (provider.state == UIState.error) ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.redAccent),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            provider.errorMessage ?? 'Terjadi kesalahan sistem.',
                                            style: const TextStyle(color: Colors.redAccent),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                // Generate Button
                                Container(
                                  width: double.infinity,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).primaryColor.withOpacity(0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: provider.state == UIState.submitting
                                        ? null
                                        : () {
                                            if (_formKey.currentState!.validate()) {
                                              provider.submitYoutubeUrl(
                                                _urlController.text.trim(),
                                              );
                                            }
                                          },
                                    child: provider.state == UIState.submitting
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              valueColor: AlwaysStoppedAnimation(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Dapatkan Vertical Clip ⚡',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Trending Podcasts Section
                        TrendingPodcastsSection(
                          urlController: _urlController,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Floating History Panel
              Positioned(
                bottom: MediaQuery.of(context).size.width > 800 ? 24 : 0,
                right: MediaQuery.of(context).size.width > 800 ? 24 : 0,
                left: MediaQuery.of(context).size.width > 800 ? null : 0,
                child: const _FloatingHistoryPanel(),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildSegmentItem(BuildContext context, ClipProvider provider, String label, String value) {
    final isSelected = provider.selectedLayout == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setLayout(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).primaryColor.withOpacity(0.1),
          ),
          child: Icon(
            Icons.movie_filter_rounded,
            size: isMobile ? 40 : 48,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Local AI Clipper',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: isMobile ? 32 : 48,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Ekstrak momen terbaik YouTube menjadi video 9:16 menggunakan kecerdasan buatan lokal.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 14 : 16,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _FloatingHistoryPanel extends StatefulWidget {
  const _FloatingHistoryPanel();

  @override
  State<_FloatingHistoryPanel> createState() => _FloatingHistoryPanelState();
}

class _FloatingHistoryPanelState extends State<_FloatingHistoryPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClipProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    
    return Container(
      width: isDesktop ? 360 : screenWidth,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A35),
        borderRadius: isDesktop
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isExpanded ? (isDesktop ? 400 : MediaQuery.of(context).size.height * 0.4) : 60,
        child: Column(
          children: [
            // Header (Always Visible)
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: isDesktop
                  ? BorderRadius.circular(20)
                  : const BorderRadius.vertical(top: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'Riwayat Klip Terakhir',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ),
            
            // Content (Only when expanded)
            if (_isExpanded)
              Expanded(
                child: provider.savedJobIds.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada riwayat',
                          style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: provider.savedJobIds.length,
                        itemBuilder: (context, index) {
                          final id = provider.savedJobIds[index];
                          final status = provider.jobStatuses[id];
                          return _buildJobTile(context, provider, id, status);
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobTile(BuildContext context, ClipProvider provider, String id, JobResponse? job) {
    IconData icon;
    Color color;
    String statusText;

    if (job == null) {
      icon = Icons.hourglass_empty;
      color = Colors.grey;
      statusText = 'Loading...';
    } else {
      switch (job.status) {
        case ClipStatus.completed:
          icon = Icons.check_circle;
          color = Colors.green;
          statusText = 'Selesai';
          break;
        case ClipStatus.failed:
          icon = Icons.error;
          color = Colors.red;
          statusText = 'Gagal';
          break;
        default:
          icon = Icons.sync;
          color = Colors.blue;
          statusText = 'Memproses';
      }
    }

    return Card(
      color: Colors.white.withOpacity(0.05),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          'Job ID: ${id.substring(0, 8)}...',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
        ),
        subtitle: Text(
          statusText,
          style: TextStyle(color: color, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (job?.status == ClipStatus.completed && job?.videoPaths != null && job!.videoPaths!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.download, color: Colors.blueAccent, size: 20),
                tooltip: 'Download',
                onPressed: () async {
                  final url = provider.getFullUrl(job!.videoPaths!.first);
                  await DownloadService.downloadVideo(url, 'ClipperAi_Result_History.mp4');
                },
              ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white38, size: 20),
              tooltip: 'Hapus Riwayat',
              onPressed: () => provider.removeJob(id),
            ),
          ],
        ),
        onTap: () {
          if (job?.status == ClipStatus.completed || job?.status == ClipStatus.processing) {
            provider.resumeJob(id);
          }
        },
      ),
    );
  }
}
