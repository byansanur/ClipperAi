// lib/features/clip_generator/views/result_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/services.dart';
import '../../../core/services/download_service.dart';
import '../models/job_response.dart';
import '../providers/clip_provider.dart';
import '../widgets/common_widgets.dart';

class ResultView extends StatefulWidget {
  const ResultView({super.key});

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClipProvider>(context);
    final urls = provider.videoUrls ?? [];
    final currentJobId = provider.jobId;
    final currentJob = currentJobId != null ? provider.jobStatuses[currentJobId] : null;
    final isProcessing = currentJob?.status == ClipStatus.processing;

    final itemCount = urls.length + 1;

    if (urls.isEmpty && !isProcessing && !provider.isGeneratingMore) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Video tidak ditemukan.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: itemCount,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              if (index == urls.length) {
                return Center(
                  child: Container(
                    width: isDesktop ? 340 : MediaQuery.of(context).size.width * 0.8,
                    height: isDesktop ? 600 : MediaQuery.of(context).size.height * 0.7,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A24),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (provider.isGeneratingMore || isProcessing) ...[
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 24),
                          const Text(
                            'Sedang memotong klip berikutnya...',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ] else ...[
                          const Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 64),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                if (currentJobId != null) {
                                  provider.generateNextClip(currentJobId);
                                }
                              },
                              child: const Text(
                                'Gunting Klip Lainnya ✂️',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              }
              return _ResultPage(
                key: ValueKey(urls[index]),
                url: urls[index],
                index: index,
                total: urls.length,
                isFocused: index == _currentIndex,
                isDesktop: isDesktop,
              );
            },
          ),
          if (isDesktop && urls.length > 1)
            Positioned(
              right: 40,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 40),
                    onPressed: _currentIndex > 0 ? _prevPage : null,
                  ),
                  const SizedBox(height: 20),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 40),
                    onPressed: _currentIndex < urls.length - 1 ? _nextPage : null,
                  ),
                ],
              ),
            ),
          if (!isDesktop && (urls.length > 1 || isProcessing))
            const Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Geser ke atas untuk melihat klip lain',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // Tombol Kembali / Back to Home
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 28),
              onPressed: () => provider.reset(),
              tooltip: 'Kembali ke Beranda',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.5),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPage extends StatefulWidget {
  final String url;
  final int index;
  final int total;
  final bool isFocused;
  final bool isDesktop;

  const _ResultPage({
    super.key,
    required this.url,
    required this.index,
    required this.total,
    required this.isFocused,
    required this.isDesktop,
  });

  @override
  State<_ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<_ResultPage> {
  late final Player player;
  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);

    player.open(Media(widget.url), play: widget.isFocused);
  }

  @override
  void didUpdateWidget(_ResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused != oldWidget.isFocused) {
      if (widget.isFocused) {
        player.play();
      } else {
        player.pause();
      }
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> _downloadVideo(String url) async {
    await DownloadService.downloadVideo(url, 'ClipperAi_Result_${widget.index}.mp4');
  }

  void _copyToClipboard(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tautan video berhasil disalin ke clipboard! 📋')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClipProvider>(context, listen: false);

    if (widget.isDesktop) {
      return _DesktopClipView(
        controller: controller,
        url: widget.url,
        index: widget.index,
        total: widget.total,
        onDownload: () => _downloadVideo(widget.url),
        onCopyLink: () => _copyToClipboard(widget.url),
        onReset: () => provider.reset(),
      );
    }

    return _MobileClipView(
      controller: controller,
      url: widget.url,
      index: widget.index,
      total: widget.total,
      onDownload: () => _downloadVideo(widget.url),
      onCopyLink: () => _copyToClipboard(widget.url),
      onReset: () => provider.reset(),
    );
  }
}

class _MobileClipView extends StatelessWidget {
  final VideoController controller;
  final String url;
  final int index;
  final int total;
  final VoidCallback onDownload;
  final VoidCallback onCopyLink;
  final VoidCallback onReset;

  const _MobileClipView({
    required this.controller,
    required this.url,
    required this.index,
    required this.total,
    required this.onDownload,
    required this.onCopyLink,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Stack(
          children: [
            Positioned.fill(
              child: Video(
                controller: controller,
                fit: BoxFit.cover,
                controls: NoVideoControls,
              ),
            ),
            const GradientOverlay(),
            TikTokTextInfo(index: index, total: total),
            TikTokActionColumn(
              onDownload: onDownload,
              onCopyLink: onCopyLink,
              onReset: onReset,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopClipView extends StatelessWidget {
  final VideoController controller;
  final String url;
  final int index;
  final int total;
  final VoidCallback onDownload;
  final VoidCallback onCopyLink;
  final VoidCallback onReset;

  const _DesktopClipView({
    required this.controller,
    required this.url,
    required this.index,
    required this.total,
    required this.onDownload,
    required this.onCopyLink,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Gunakan 85% dari tinggi layar agar ada sisa ruang (margin) di atas dan bawah
    final targetHeight = screenHeight * 0.85; 
    // Hitung lebar secara matematis untuk mengunci rasio 9:16
    final targetWidth = targetHeight * (9 / 16);

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bagian Kiri: Video Container
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 500,
              maxHeight: 950,
              maxWidth: 950 * (9 / 16),
            ),
            child: Container(
              width: targetWidth,
              height: targetHeight,
              margin: const EdgeInsets.symmetric(vertical: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Video(
                        controller: controller,
                        fit: BoxFit.cover,
                        controls: NoVideoControls,
                      ),
                    ),
                    const GradientOverlay(),
                    TikTokTextInfo(index: index, total: total),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 20),
          
          // Bagian Kanan: Action Column
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              ActionButton(
                icon: Icons.download_rounded,
                label: 'Download',
                onTap: onDownload,
              ),
              const SizedBox(height: 16),
              ActionButton(
                icon: Icons.link_rounded,
                label: 'Copy Link',
                onTap: onCopyLink,
              ),
              const SizedBox(height: 16),
              ActionButton(
                icon: Icons.add_circle_outline_rounded,
                label: 'Buat Baru',
                onTap: onReset,
              ),
              const SizedBox(height: 20), // Memberi sedikit jarak dari bawah agar sejajar dengan video
            ],
          ),
        ],
      ),
    );
  }
}
