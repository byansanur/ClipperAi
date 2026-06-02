// lib/core/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  final Dio dio;

  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );
}
