import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/env.dart';
import '../../../core/constants/app_constants.dart';
import '../../analytics/models/study_analytics_summary.dart';

/// Error ramah-pengguna dari proses generate AI.
class OpenRouterException implements Exception {
  const OpenRouterException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Hasil generate: teks laporan + metadata untuk disimpan.
class AiGenerationResult {
  const AiGenerationResult({
    required this.text,
    required this.promptUsed,
    required this.model,
    this.totalTokens,
  });

  final String text;
  final String promptUsed;
  final String model;
  final int? totalTokens;
}

/// Service pemanggil OpenRouter (model gratis otomatis `openrouter/free`).
class OpenRouterService {
  OpenRouterService([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConstants.openRouterBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 90),
            ));

  final Dio _dio;

  static const _systemPrompt = '''
Kamu adalah asisten evaluasi belajar yang suportif, hangat, dan berbasis data.
Tugasmu menganalisis data ringkasan belajar seorang pelajar dan memberi laporan
dalam BAHASA INDONESIA yang mudah dipahami. Gunakan format Markdown dengan
struktur WAJIB berikut (pakai heading "## "):

## Ringkasan Periode Ini
Rangkum kondisi belajar secara singkat (2-4 kalimat) berdasarkan angka.

## Insight Pola
Sebutkan pola yang terlihat dari data, misalnya topik dengan fokus rendah,
waktu paling produktif, atau kecenderungan menghentikan sesi lebih awal.
Gunakan poin-poin (-).

## Rekomendasi
Beri 3-4 rekomendasi konkret dan bisa langsung dilakukan (actionable),
disesuaikan dengan data. Gunakan poin-poin (-).

## Penutup
Satu paragraf motivasional yang positif dan personal.

Aturan: jangan mengarang data di luar yang diberikan; jika data sedikit,
akui keterbatasannya dengan sopan. Hindari bahasa menghakimi.
''';

  Future<AiGenerationResult> generateAnalysis(
    StudyAnalyticsSummary summary,
  ) async {
    final userPrompt =
        'Berikut data ringkasan belajar saya. Tolong analisis sesuai struktur '
        'yang diminta.\n\n${summary.describe()}';

    try {
      final response = await _dio.post(
        '/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer ${Env.openRouterApiKey}',
          'Content-Type': 'application/json',
          // Header opsional yang disarankan OpenRouter untuk identifikasi app.
          'HTTP-Referer': 'https://smartlearningtracker.app',
          'X-Title': AppConstants.appName,
        }),
        data: {
          'model': AppConstants.openRouterModel,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.6,
          'max_tokens': 1200,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw const OpenRouterException(
            'AI tidak mengembalikan hasil. Coba lagi sebentar.');
      }
      final content =
          (choices.first['message']?['content'] as String?)?.trim() ?? '';
      if (content.isEmpty) {
        throw const OpenRouterException(
            'AI mengembalikan jawaban kosong. Coba lagi.');
      }
      final usage = data['usage'] as Map<String, dynamic>?;
      return AiGenerationResult(
        text: content,
        promptUsed: userPrompt,
        model: AppConstants.openRouterModel,
        totalTokens: (usage?['total_tokens'] as num?)?.toInt(),
      );
    } on DioException catch (e) {
      throw OpenRouterException(_mapDioError(e));
    } on OpenRouterException {
      rethrow;
    } catch (_) {
      throw const OpenRouterException(
          'Terjadi kesalahan tak terduga saat menghubungi AI.');
    }
  }

  String _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Permintaan ke AI memakan waktu terlalu lama (timeout). '
          'Periksa koneksi lalu coba lagi.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.error is SocketException) {
      return 'Tidak ada koneksi internet. Sambungkan ke internet lalu coba lagi.';
    }
    if (e.type == DioExceptionType.badResponse) {
      final code = e.response?.statusCode;
      switch (code) {
        case 401:
          return 'API key OpenRouter tidak valid atau kedaluwarsa. '
              'Periksa konfigurasi .env.';
        case 402:
          return 'Kuota OpenRouter habis untuk model gratis saat ini. '
              'Coba lagi nanti.';
        case 429:
          return 'Terlalu banyak permintaan ke AI (rate limit). '
              'Tunggu sebentar lalu coba lagi.';
        default:
          return 'AI menolak permintaan (kode $code). Coba lagi nanti.';
      }
    }
    return 'Gagal menghubungi AI. Coba lagi nanti.';
  }
}

final openRouterServiceProvider =
    Provider<OpenRouterService>((ref) => OpenRouterService());
