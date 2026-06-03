// lib/core/api_client.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  final Dio dio;

  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: _getBaseUrl(),
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );

  static String _getBaseUrl() {
    String url = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080';
    // Emulator Android tidak mengerti 'localhost'. Ia menggunakan '10.0.2.2' untuk merujuk ke localhost komputer host.
    if (!kIsWeb && Platform.isAndroid && (url.contains('localhost') || url.contains('127.0.0.1'))) {
      return url.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
    }
    return url;
  }
}
