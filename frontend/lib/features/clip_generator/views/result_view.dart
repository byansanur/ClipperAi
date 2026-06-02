// lib/features/clip_generator/views/result_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../providers/clip_provider.dart';

class ResultView extends StatefulWidget {
  const ResultView({super.key});

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  late final Player player;
  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ClipProvider>(context, listen: false);
    
    // Inisialisasi Player MediaKit
    player = Player();
    controller = VideoController(player);

    // Main video url dari state provider (Autoplay dinonaktifkan di awal sesuai web policy)
    player.open(Media(provider.videoUrl ?? ''));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> _downloadVideo(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka link unduh.')),
      );
    }
  }

  void _copyToClipboard(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tautan video berhasil disalin ke clipboard! 📋')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClipProvider>(context);

    return Container(
      color: Colors.black,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Stack(
            children: [
              // Layer 1: Video Player (Background)
              Positioned.fill(
                child: Video(
                  controller: controller,
                  fit: BoxFit.cover,
                  controls: NoVideoControls, // Menghilangkan kontrol default agar UI bersih ala TikTok
                ),
              ),

              // Layer 2: Gradient Overlay
              const _GradientOverlay(),

              // Layer 3: Text Content (Pojok Kiri Bawah)
              const _TikTokTextInfo(),

              // Layer 4: Action Buttons (Kolom Kanan Bawah)
              _TikTokActionColumn(
                onDownload: () => _downloadVideo(provider.videoUrl ?? ''),
                onCopyLink: () => _copyToClipboard(provider.videoUrl ?? ''),
                onReset: () => provider.reset(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black54,
              Colors.black87,
            ],
            stops: [0.0, 0.6, 0.85, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }
}

class _TikTokTextInfo extends StatelessWidget {
  const _TikTokTextInfo();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 80, // Memberikan ruang agar teks tidak bertabrakan dengan tombol aksi
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge "SUKSES DI-GENERATE"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'SUKSES DI-GENERATE 🎉',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Judul
          const Text(
            'Klip Video Anda Telah Siap!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),

          // Deskripsi
          Text(
            'AI berhasil memotong bagian yang paling menarik dan mengoptimalkannya menjadi format vertikal 9:16 yang ramah untuk media sosial seperti TikTok, Shorts, dan Reels.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TikTokActionColumn extends StatelessWidget {
  final VoidCallback onDownload;
  final VoidCallback onCopyLink;
  final VoidCallback onReset;

  const _TikTokActionColumn({
    required this.onDownload,
    required this.onCopyLink,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: Icons.download_rounded,
            label: 'Download',
            onTap: onDownload,
          ),
          const SizedBox(height: 24),
          _ActionButton(
            icon: Icons.link_rounded,
            label: 'Copy Link',
            onTap: onCopyLink,
          ),
          const SizedBox(height: 24),
          _ActionButton(
            icon: Icons.add_circle_outline_rounded,
            label: 'Buat Baru',
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.4),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
