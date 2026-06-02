// lib/features/clip_generator/views/loading_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import '../providers/clip_provider.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClipProvider>(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F0F12), Color(0xFF1F1A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Neon Spin Animation
              SpinKitDoubleBounce(
                color: Theme.of(context).primaryColor,
                size: 90.0,
              ),
              const SizedBox(height: 48),
              
              const Text(
                'AI Sedang Memproses Klip Anda...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Container(
                constraints: const BoxConstraints(maxWidth: 450),
                child: const Text(
                  'Server lokal sedang mendownload transcript, melakukan evaluasi heuristik, '
                  'meminta analisis model LLM Ollama, mengunduh segmen video, dan menerapkan crop 9:16 '
                  'melalui FFmpeg. Proses ini membutuhkan waktu sekitar 1-3 menit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.5),
                ),
              ),
              const SizedBox(height: 32),
              
              // Tampilkan Job ID sebagai tanda proses aktif
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Job ID: ${provider.jobId}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 40),
              
              // Tombol Batal
              TextButton.icon(
                onPressed: () => provider.cancelJob(),
                icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                label: const Text(
                  'Batalkan & Kembali',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
