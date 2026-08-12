import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/bloc/diagnostics_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockApiClient;
  late MockDio mockDio;

  setUp(() {
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockApiClient.dio).thenReturn(mockDio);
    PackageInfo.setMockInitialValues(
      appName: 'Yadony',
      packageName: 'com.dony.app',
      version: '1.2.3',
      buildNumber: '42',
      buildSignature: '',
    );
  });

  group('DiagnosticsBloc', () {
    test('etat initial est vide', () {
      final bloc = DiagnosticsBloc(mockApiClient);
      expect(bloc.state.appVersion, isNull);
      expect(bloc.state.buildNumber, isNull);
      expect(bloc.state.isPinging, isFalse);
      expect(bloc.state.apiOk, isNull);
      bloc.close();
    });

    test('DiagnosticsState.copyWith preserve les valeurs non specifiees', () {
      const state = DiagnosticsState(
        appVersion: '1.0.0',
        buildNumber: '42',
        isPinging: false,
        apiOk: true,
      );
      final copy = state.copyWith(isPinging: true);
      expect(copy.appVersion, equals('1.0.0'));
      expect(copy.buildNumber, equals('42'));
      expect(copy.isPinging, isTrue);
      // apiOk est null car copyWith(apiOk: null) remet a null intentionnellement
    });

    test('DiagnosticsState props sont corrects', () {
      const state = DiagnosticsState(
        appVersion: '2.0',
        buildNumber: '99',
        isPinging: true,
        apiOk: false,
      );
      expect(state.props, equals(['2.0', '99', true, false]));
    });

    blocTest<DiagnosticsBloc, DiagnosticsState>(
      'DiagnosticsLoadRequested emets appVersion et buildNumber',
      build: () => DiagnosticsBloc(mockApiClient),
      act: (bloc) => bloc.add(const DiagnosticsLoadRequested()),
      expect: () => [
        isA<DiagnosticsState>()
            .having((s) => s.appVersion, 'appVersion', '1.2.3')
            .having((s) => s.buildNumber, 'buildNumber', '42'),
      ],
    );

    blocTest<DiagnosticsBloc, DiagnosticsState>(
      'ApiPingRequested emet isPinging=true puis apiOk=true si succes',
      build: () {
        when(() => mockDio.get('/actuator/health')).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/actuator/health'),
            statusCode: 200,
          ),
        );
        return DiagnosticsBloc(mockApiClient);
      },
      act: (bloc) => bloc.add(const ApiPingRequested()),
      expect: () => [
        isA<DiagnosticsState>()
            .having((s) => s.isPinging, 'isPinging', isTrue)
            .having((s) => s.apiOk, 'apiOk', isNull),
        isA<DiagnosticsState>()
            .having((s) => s.isPinging, 'isPinging', isFalse)
            .having((s) => s.apiOk, 'apiOk', isTrue),
      ],
    );

    blocTest<DiagnosticsBloc, DiagnosticsState>(
      'ApiPingRequested emet apiOk=false si DioException',
      build: () {
        when(() => mockDio.get('/actuator/health')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/actuator/health'),
            type: DioExceptionType.connectionError,
          ),
        );
        return DiagnosticsBloc(mockApiClient);
      },
      act: (bloc) => bloc.add(const ApiPingRequested()),
      expect: () => [
        isA<DiagnosticsState>()
            .having((s) => s.isPinging, 'isPinging', isTrue)
            .having((s) => s.apiOk, 'apiOk', isNull),
        isA<DiagnosticsState>()
            .having((s) => s.isPinging, 'isPinging', isFalse)
            .having((s) => s.apiOk, 'apiOk', isFalse),
      ],
    );

    blocTest<DiagnosticsBloc, DiagnosticsState>(
      'ApiPingRequested emet apiOk=false si exception generique',
      build: () {
        when(
          () => mockDio.get('/actuator/health'),
        ).thenThrow(Exception('network error'));
        return DiagnosticsBloc(mockApiClient);
      },
      act: (bloc) => bloc.add(const ApiPingRequested()),
      expect: () => [
        isA<DiagnosticsState>().having((s) => s.isPinging, 'isPinging', isTrue),
        isA<DiagnosticsState>()
            .having((s) => s.isPinging, 'isPinging', isFalse)
            .having((s) => s.apiOk, 'apiOk', isFalse),
      ],
    );

    blocTest<DiagnosticsBloc, DiagnosticsState>(
      'plusieurs ApiPingRequested successifs fonctionnent',
      build: () {
        var callCount = 0;
        when(() => mockDio.get('/actuator/health')).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) throw Exception('first fail');
          return Response(
            requestOptions: RequestOptions(path: '/actuator/health'),
            statusCode: 200,
          );
        });
        return DiagnosticsBloc(mockApiClient);
      },
      act: (bloc) async {
        bloc.add(const ApiPingRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ApiPingRequested());
      },
      expect: () => [
        // premier ping
        isA<DiagnosticsState>().having((s) => s.isPinging, 'isPinging', isTrue),
        isA<DiagnosticsState>()
            .having((s) => s.isPinging, 'isPinging', isFalse)
            .having((s) => s.apiOk, 'apiOk', isFalse),
        // deuxieme ping
        isA<DiagnosticsState>().having((s) => s.isPinging, 'isPinging', isTrue),
        isA<DiagnosticsState>()
            .having((s) => s.isPinging, 'isPinging', isFalse)
            .having((s) => s.apiOk, 'apiOk', isTrue),
      ],
    );
  });
}
