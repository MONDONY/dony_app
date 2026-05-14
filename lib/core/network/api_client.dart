import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  ApiClient({required String baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(_AuthInterceptor());

    if (kDebugMode) {
      // Log only method/path/status. Bodies and headers contain Firebase
      // ID tokens, Stripe client secrets, FCM tokens and KYC data — never
      // dump them to logcat / Xcode console.
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('[HTTP] → ${options.method} ${options.uri.path}');
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint(
              '[HTTP] ← ${response.statusCode} ${response.requestOptions.uri.path}',
            );
            handler.next(response);
          },
          onError: (err, handler) {
            debugPrint(
              '[HTTP] ✗ ${err.response?.statusCode ?? 'no-response'} '
              '${err.requestOptions.uri.path}',
            );
            handler.next(err);
          },
        ),
      );
    }
  }

  late final Dio _dio;

  Dio get dio => _dio;
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for public endpoints (e.g. health check before Firebase is ready)
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final isCritical = options.path.contains('/payments') ||
            options.path.contains('/kyc') ||
            options.path.contains('/tracking/events') ||
            options.path.contains('/bids/checkout');
        final token = await user.getIdToken(isCritical);
        options.headers['Authorization'] = 'Bearer $token';
      }
    } on FirebaseException catch (e) {
      if (e.code == 'no-app') {
        // Firebase genuinely not initialized yet — proceed unauthenticated.
        handler.next(options);
        return;
      }
      // Any other Firebase error should NOT silently proceed.
      handler.reject(
        DioException(
          requestOptions: options,
          error: 'Authentication failed: ${e.message}',
          type: DioExceptionType.unknown,
        ),
      );
      return;
    } catch (e) {
      // Unexpected error — reject instead of silently proceeding.
      handler.reject(
        DioException(
          requestOptions: options,
          error: 'Unexpected auth error',
          type: DioExceptionType.unknown,
        ),
      );
      return;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;
    final detail = data is Map ? data['detail'] as String? : null;
    // Back-end RFC 7807 ProblemDetail uses `code` (set via problem.setProperty("code", ...)).
    // We keep `errorCode` as a legacy fallback for any older endpoint.
    final apiCode = data is Map
        ? (data['code'] as String?) ?? (data['errorCode'] as String?)
        : null;

    final AppException appException;
    if (statusCode == 401) {
      appException = UnauthorizedException(detail ?? 'Session expirée', apiCode);
    } else if (statusCode == 403) {
      appException = ForbiddenException(detail ?? 'Accès refusé', apiCode);
    } else if (statusCode == 404) {
      appException = NotFoundException(
        message: detail ?? 'Ressource introuvable',
        apiCode: apiCode,
      );
    } else if (statusCode == 409) {
      appException = ConflictException(detail ?? 'Conflit', code: apiCode);
    } else if (statusCode == 422) {
      appException = ValidationException(detail ?? 'Données invalides', code: apiCode);
    } else if (statusCode == 429) {
      appException = RateLimitException(detail ?? 'Trop de tentatives');
    } else if (statusCode != null && statusCode >= 500) {
      appException = ServerException(detail ?? 'Erreur serveur', apiCode);
    } else {
      appException = NetworkException(
        detail ?? err.message ?? 'Erreur réseau',
        code: apiCode ?? statusCode?.toString(),
      );
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: appException,
        response: err.response,
        type: err.type,
      ),
    );
  }
}
