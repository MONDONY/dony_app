import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

/// Photos de la messagerie (FLUTTER-B4) : envoi par le back, lecture par l'API.
void main() {
  late _MockDio dio;
  late ConversationRepository repository;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    final client = _MockApiClient();
    dio = _MockDio();
    when(() => client.dio).thenReturn(dio);
    repository = ConversationRepository(client);
  });

  group('sendImage', () {
    test('POST multipart sur /images, rend le messageId du back', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response<dynamic>(
          data: {'messageId': 'abc123'},
          statusCode: 201,
          requestOptions: RequestOptions(path: '/conversations/c1/images'),
        ),
      );

      final id = await repository.sendImage(
        'c1',
        Uint8List.fromList([0xFF, 0xD8, 0xFF]),
        replyToId: 'm1',
      );

      expect(id, 'abc123');
      final captured =
          verify(
                () => dio.post<dynamic>(
                  '/conversations/c1/images',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as FormData;
      expect(captured.fields.map((f) => '${f.key}=${f.value}'), [
        'replyToId=m1',
      ]);
      final file = captured.files.single;
      expect(file.key, 'file');
      expect(file.value.contentType?.mimeType, 'image/jpeg');
    });

    test(
      'sans réponse : aucun champ replyToId ; corps illisible → ""',
      () async {
        when(
          () => dio.post<dynamic>(any(), data: any(named: 'data')),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            data: 'oops',
            statusCode: 201,
            requestOptions: RequestOptions(path: '/x'),
          ),
        );

        final id = await repository.sendImage('c1', Uint8List.fromList([1]));

        expect(id, '');
        final captured =
            verify(
                  () =>
                      dio.post<dynamic>(any(), data: captureAny(named: 'data')),
                ).captured.single
                as FormData;
        expect(captured.fields, isEmpty);
      },
    );
  });

  group('fetchImage', () {
    test('GET des octets, variante en paramètre', () async {
      when(
        () => dio.get<List<int>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<List<int>>(
          data: [1, 2, 3],
          statusCode: 200,
          requestOptions: RequestOptions(path: '/x'),
        ),
      );

      final bytes = await repository.fetchImage(
        'c1',
        'm1',
        variant: ChatImageVariant.thumb,
      );

      expect(bytes, Uint8List.fromList([1, 2, 3]));
      final options =
          verify(
                () => dio.get<List<int>>(
                  '/conversations/c1/messages/m1/image',
                  queryParameters: {'variant': 'thumb'},
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as Options;
      expect(options.responseType, ResponseType.bytes);
    });

    test('corps vide → octets vides', () async {
      when(
        () => dio.get<List<int>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<List<int>>(
          statusCode: 200,
          requestOptions: RequestOptions(path: '/x'),
        ),
      );

      final bytes = await repository.fetchImage(
        'c1',
        'm1',
        variant: ChatImageVariant.full,
      );

      expect(bytes, isEmpty);
      expect(ChatImageVariant.full.apiValue, 'full');
    });
  });
}
