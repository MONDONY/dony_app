import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/data/chat_image_cache.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConversationRepository extends Mock
    implements ConversationRepository {}

DioException _http(int status) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response<dynamic>(
    statusCode: status,
    requestOptions: RequestOptions(path: '/x'),
  ),
);

void main() {
  late _MockConversationRepository repo;
  late ChatImageCache cache;

  setUpAll(() => registerFallbackValue(ChatImageVariant.thumb));

  setUp(() {
    repo = _MockConversationRepository();
    cache = ChatImageCache(repo, maxEntries: 2);
  });

  void stub(Future<Uint8List> Function() answer) => when(
    () => repo.fetchImage(any(), any(), variant: any(named: 'variant')),
  ).thenAnswer((_) => answer());

  Future<ChatImageLoad> settle(ChatImageLoad Function() read) async {
    await Future<void>.delayed(Duration.zero);
    return read();
  }

  test('charge une fois, clé messageId:variant', () async {
    stub(() async => Uint8List.fromList([1]));
    final a = cache.watch(
      conversationId: 'c',
      messageId: 'm',
      variant: ChatImageVariant.thumb,
    );
    final b = cache.watch(
      conversationId: 'c',
      messageId: 'm',
      variant: ChatImageVariant.thumb,
    );
    expect(identical(a, b), isTrue);
    expect(a.value, isA<ChatImageLoading>());
    expect(await settle(() => a.value), isA<ChatImageReady>());
    verify(
      () => repo.fetchImage('c', 'm', variant: ChatImageVariant.thumb),
    ).called(1);
    expect(ChatImageCache.keyFor('m', ChatImageVariant.full), 'm:full');
  });

  test('410 → expirée, sans nouvel essai possible', () async {
    stub(() async => throw _http(410));
    final a = cache.watch(
      conversationId: 'c',
      messageId: 'm',
      variant: ChatImageVariant.full,
    );
    expect(await settle(() => a.value), isA<ChatImageExpired>());
    cache.retry(
      conversationId: 'c',
      messageId: 'm',
      variant: ChatImageVariant.full,
    );
    expect(a.value, isA<ChatImageExpired>());
    verify(
      () => repo.fetchImage(any(), any(), variant: any(named: 'variant')),
    ).called(1);
  });

  test('échec réseau → échec, puis retry recharge', () async {
    var calls = 0;
    stub(() async {
      calls++;
      if (calls == 1) throw _http(500);
      return Uint8List.fromList([7]);
    });
    final a = cache.watch(
      conversationId: 'c',
      messageId: 'm',
      variant: ChatImageVariant.thumb,
    );
    expect(await settle(() => a.value), isA<ChatImageFailed>());
    cache.retry(
      conversationId: 'c',
      messageId: 'm',
      variant: ChatImageVariant.thumb,
    );
    expect(a.value, isA<ChatImageLoading>());
    expect(await settle(() => a.value), isA<ChatImageReady>());
  });

  test('octets vides → échec', () async {
    stub(() async => Uint8List(0));
    final a = cache.watch(
      conversationId: 'c',
      messageId: 'm',
      variant: ChatImageVariant.thumb,
    );
    expect(await settle(() => a.value), isA<ChatImageFailed>());
  });

  test('retry sur une clé inconnue charge ; LRU borné ; clear', () async {
    stub(() async => Uint8List.fromList([1]));
    cache.retry(
      conversationId: 'c',
      messageId: 'a',
      variant: ChatImageVariant.thumb,
    );
    cache.watch(
      conversationId: 'c',
      messageId: 'b',
      variant: ChatImageVariant.thumb,
    );
    cache.watch(
      conversationId: 'c',
      messageId: 'c',
      variant: ChatImageVariant.thumb,
    );
    expect(cache.length, 2);
    cache.clear();
    expect(cache.length, 0);
  });

  test('isUnavailable : 404/410, codes métier, NotFoundException', () {
    expect(ChatImageCache.isUnavailable(_http(404)), isTrue);
    expect(ChatImageCache.isUnavailable(_http(410)), isTrue);
    expect(ChatImageCache.isUnavailable(_http(500)), isFalse);
    expect(
      ChatImageCache.isUnavailable(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          error: const NetworkException('gone', code: '410'),
        ),
      ),
      isTrue,
    );
    expect(ChatImageCache.isUnavailable(const NotFoundException()), isTrue);
    expect(
      ChatImageCache.isUnavailable(
        const NetworkException('x', code: 'image-unavailable'),
      ),
      isTrue,
    );
    expect(ChatImageCache.isUnavailable(const OfflineException()), isFalse);
    expect(ChatImageCache.isUnavailable(StateError('x')), isFalse);
  });
}
