import 'package:flutter/material.dart';

class GradientOverlay extends StatelessWidget {
  const GradientOverlay({super.key});

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

class TikTokTextInfo extends StatelessWidget {
  final int index;
  final int total;

  const TikTokTextInfo({super.key, required this.index, required this.total});

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
            child: Text(
              'KLIP ${index + 1} DARI $total 🎉',
              style: const TextStyle(
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

class TikTokActionColumn extends StatelessWidget {
  final VoidCallback onDownload;
  final VoidCallback onCopyLink;
  final VoidCallback onReset;

  const TikTokActionColumn({
    super.key,
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
          ActionButton(
            icon: Icons.download_rounded,
            label: 'Download',
            onTap: onDownload,
          ),
          const SizedBox(height: 24),
          ActionButton(
            icon: Icons.link_rounded,
            label: 'Copy Link',
            onTap: onCopyLink,
          ),
          const SizedBox(height: 24),
          ActionButton(
            icon: Icons.add_circle_outline_rounded,
            label: 'Buat Baru',
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
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
