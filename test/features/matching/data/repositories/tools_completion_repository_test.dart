import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/features/matching/data/repositories/tools_completion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late ToolsCompletionRepository repository;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repository = ToolsCompletionRepository(mockClient);
  });

  group('ToolsCompletionRepository', () {
    group('getToolsCompletion', () {
      test(
        'appelle GET /users/me/tools-completion et parse la réponse',
        () async {
          when(() => mockDio.get('/users/me/tools-completion')).thenAnswer(
            (_) async => Response(
              data: {
                'total': 5,
                'ready': 1,
                'tools': [
                  {'key': 'addresses', 'count': 2, 'ready': true},
                ],
              },
              statusCode: 200,
              requestOptions: RequestOptions(
                path: '/users/me/tools-completion',
              ),
            ),
          );

          final model = await repository.getToolsCompletion();

          verify(() => mockDio.get('/users/me/tools-completion')).called(1);
          expect(model.countOf(ToolKey.addresses), 2);
          expect(model.ready, 1);
          expect(model.total, 5);
        },
      );

      test('propage l\'erreur Dio', () async {
        when(() => mockDio.get('/users/me/tools-completion')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/users/me/tools-completion'),
          ),
        );

        expect(
          () => repository.getToolsCompletion(),
          throwsA(isA<DioException>()),
        );
      });
    });
  });
}
