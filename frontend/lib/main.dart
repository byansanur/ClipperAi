import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'core/theme.dart';
import 'features/clip_generator/providers/clip_provider.dart';
import 'features/clip_generator/views/home_page.dart';

Future<void> main() async {
  // Inisialisasi Wajib untuk MediaKit
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Memuat file konfigurasi environment (.env) secara asinkron sebelum widget dirender
  await dotenv.load(fileName: ".env");

  if (!kIsWeb) {
    await FlutterDownloader.initialize(ignoreSsl: true);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClipProvider()),
      ],
      child: const ClipperApp(),
    ),
  );
}

class ClipperApp extends StatelessWidget {
  const ClipperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local AI Clipper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomePage(),
    );
  }
}
