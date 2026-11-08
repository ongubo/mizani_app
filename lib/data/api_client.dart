import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A failed API call, with a message that is safe to show the client.
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final String? code;
  final int? statusCode;

  /// First message for each invalid field, for example `answers.first_name`.
  final Map<String, String> fieldErrors;

  bool get isNetworkError => statusCode == null;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

/// HTTP for the client API: base URL, bearer token and error mapping.
class ApiClient {
  ApiClient({Dio? dio, String? baseUrl}) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = '${baseUrl ?? defaultBaseUrl}/api/v1/client'
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 15)
      ..headers['Accept'] = 'application/json';
  }

  /// Set with `--dart-define=API_BASE_URL=https://...`. Without it, a debug
  /// build talks to `php artisan serve` on the development machine, which an
  /// Android emulator reaches through 10.0.2.2.
  static String get defaultBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured;
    }
    final isAndroid = !kIsWeb && Platform.isAndroid;
    return isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
  }

  final Dio _dio;

  String? _token;
  VoidCallback? onUnauthorized;

  set token(String? value) {
    _token = value;
    if (value == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $value';
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post<dynamic>(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> delete(String path) =>
      _send(() => _dio.delete<dynamic>(path));

  Future<dynamic> upload(
    String path,
    FormData form, {
    void Function(double progress)? onProgress,
  }) =>
      _send(
        () => _dio.post<dynamic>(
          path,
          data: form,
          options: Options(
            sendTimeout: const Duration(seconds: 120),
            receiveTimeout: const Duration(seconds: 120),
          ),
          onSendProgress: (sent, total) {
            if (total > 0) {
              onProgress?.call(sent / total);
            }
          },
        ),
      );

  Future<void> download(String path, String savePath) => _send(
        () => _dio.download(
          path,
          savePath,
          options: Options(receiveTimeout: const Duration(seconds: 120)),
        ),
      );

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final response = e.response;
    if (response == null) {
      return ApiException(
        "We can't reach Mizani right now. Check your connection and try again.",
      );
    }

    final status = response.statusCode ?? 0;
    final data = response.data;
    final body = data is Map ? data : const <dynamic, dynamic>{};

    if (status == 401 && _token != null) {
      onUnauthorized?.call();
    }

    final fieldErrors = _fieldErrors(body['errors']);
    final serverMessage = body['message'] as String?;

    final message = switch (status) {
      401 => 'Please sign in again.',
      403 || 404 => "This isn't available.",
      429 => _tooManyAttempts(response),
      422 when fieldErrors.isNotEmpty => fieldErrors.values.first,
      >= 500 => 'Something went wrong on our side. Please try again.',
      _ => serverMessage ?? 'Something went wrong. Please try again.',
    };

    return ApiException(
      message,
      code: body['code'] as String?,
      statusCode: status,
      fieldErrors: fieldErrors,
    );
  }

  Map<String, String> _fieldErrors(Object? errors) {
    if (errors is! Map) {
      return const {};
    }
    return {
      for (final entry in errors.entries)
        if (entry.value is List && (entry.value as List).isNotEmpty)
          entry.key.toString(): (entry.value as List).first.toString(),
    };
  }

  String _tooManyAttempts(Response<dynamic> response) {
    final seconds = int.tryParse(response.headers.value('retry-after') ?? '');
    if (seconds == null) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    final minutes = (seconds / 60).ceil();
    return seconds < 60
        ? 'Too many attempts. Please try again in $seconds seconds.'
        : 'Too many attempts. Please try again in $minutes '
            '${minutes == 1 ? 'minute' : 'minutes'}.';
  }
}
