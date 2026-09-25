import 'package:dio/dio.dart';
import 'package:dony/core/network/accept_language_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helpers.dart';

/// Capture les [RequestOptions] de la dernière requête, sans jamais aller sur
/// le réseau — même pattern que `offline_fast_fail_interceptor_test.dart`.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _CapturingAdapter adapter;
  late Dio dio;

  Dio buildDio({String Function()? language}) {
    adapter = _CapturingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(AcceptLanguageInterceptor(language: language));
    return dio;
  }

  group('AcceptLanguageInterceptor', () {
    test('language: () => \'en\' → en-tête Accept-Language = en', () async {
      final d = buildDio(language: () => 'en');

      await d.get<Map<String, dynamic>>('/x');

      expect(adapter.lastOptions?.headers['Accept-Language'], 'en');
    });

    test('défaut sans Intl.defaultLocale (AppL10n.localeName) → fr', () async {
      final d = buildDio();

      await d.get<Map<String, dynamic>>('/x');

      expect(adapter.lastOptions?.headers['Accept-Language'], 'fr');
    });

    test(
      'défaut avec Intl.defaultLocale = en (AppL10n.localeName) → en',
      () async {
        useEnglish();
        final d = buildDio();

        await d.get<Map<String, dynamic>>('/x');

        expect(adapter.lastOptions?.headers['Accept-Language'], 'en');
      },
    );

    test(
      'un en-tête Accept-Language déjà posé par un appelant est remplacé',
      () async {
        final d = buildDio(language: () => 'en');

        await d.get<Map<String, dynamic>>(
          '/x',
          options: Options(headers: {'Accept-Language': 'fr'}),
        );

        expect(adapter.lastOptions?.headers['Accept-Language'], 'en');
      },
    );
  });
}
