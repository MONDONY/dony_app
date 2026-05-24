import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/bloc/data_export_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockApiClient;
  late MockDio mockDio;

  setUp(() {
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockApiClient.dio).thenReturn(mockDio);
  });

  group('DataExportBloc', () {
    test('état initial est DataExportInitial', () {
      final bloc = DataExportBloc(mockApiClient);
      expect(bloc.state, isA<DataExportInitial>());
      bloc.close();
    });

    blocTest<DataExportBloc, DataExportState>(
      'DataExportRequested émet Loading puis Success si API OK',
      build: () {
        when(() => mockDio.get('/users/me/export'))
            .thenAnswer((_) async => Response(
                  requestOptions: RequestOptions(path: '/users/me/export'),
                  statusCode: 200,
                ));
        return DataExportBloc(mockApiClient);
      },
      act: (bloc) => bloc.add(const DataExportRequested()),
      expect: () => [
        isA<DataExportLoading>(),
        isA<DataExportSuccess>(),
      ],
      verify: (_) =>
          verify(() => mockDio.get('/users/me/export')).called(1),
    );

    blocTest<DataExportBloc, DataExportState>(
      'DataExportRequested émet Loading puis Error si API échoue (DioException)',
      build: () {
        when(() => mockDio.get('/users/me/export')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/users/me/export'),
            message: 'Erreur réseau',
            type: DioExceptionType.connectionError,
          ),
        );
        return DataExportBloc(mockApiClient);
      },
      act: (bloc) => bloc.add(const DataExportRequested()),
      expect: () => [
        isA<DataExportLoading>(),
        isA<DataExportError>(),
      ],
    );

    blocTest<DataExportBloc, DataExportState>(
      'DataExportRequested émet Loading puis Error si exception générique',
      build: () {
        when(() => mockDio.get('/users/me/export'))
            .thenThrow(Exception('network error'));
        return DataExportBloc(mockApiClient);
      },
      act: (bloc) => bloc.add(const DataExportRequested()),
      expect: () => [
        isA<DataExportLoading>(),
        isA<DataExportError>(),
      ],
    );

    blocTest<DataExportBloc, DataExportState>(
      'DataExportError contient le message de l\'exception',
      build: () {
        when(() => mockDio.get('/users/me/export'))
            .thenThrow(Exception('custom error message'));
        return DataExportBloc(mockApiClient);
      },
      act: (bloc) => bloc.add(const DataExportRequested()),
      expect: () => [
        isA<DataExportLoading>(),
        isA<DataExportError>().having(
          (s) => s.message,
          'message',
          isNotEmpty,
        ),
      ],
    );
  });
}
