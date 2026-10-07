import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/messaging/data/chat_image_cache.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/presentation/chat_photo_preview_screen.dart';
import 'package:dony/features/messaging/presentation/chat_photo_viewer_screen.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockConvRepo extends Mock implements ConversationRepository {}

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Aperçu avant envoi et visionneuse plein écran (FLUTTER-B4).
void main() {
  setUpAll(() => registerFallbackValue(ChatImageVariant.full));

  Future<void> pumpRouter(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('aperçu', () {
    late bool? result;

    GoRouter router() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await context.push<bool>('/preview');
              },
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/preview',
          builder: (_, _) => ChatPhotoPreviewScreen(bytes: _png),
        ),
      ],
    );

    setUp(() => result = null);

    testWidgets('« Envoyer » rend true', (tester) async {
      await pumpRouter(tester, router());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-photo-preview-image')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-photo-preview-send')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('« Annuler » et ✕ rendent false', (tester) async {
      await pumpRouter(tester, router());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-photo-preview-cancel')));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('visionneuse', () {
    late _MockConvRepo repo;

    setUp(() => repo = _MockConvRepo());

    GoRouter router(ChatImageCache cache) => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/viewer'),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/viewer',
          builder: (_, _) => ChatPhotoViewerScreen(
            args: const ChatPhotoViewerArgs(
              conversationId: 'conv-1',
              messageId: 'p1',
            ),
            cache: cache,
          ),
        ),
      ],
    );

    testWidgets('variante full chargée, zoomable, ✕ referme', (tester) async {
      when(
        () => repo.fetchImage(any(), any(), variant: any(named: 'variant')),
      ).thenAnswer((_) async => _png);
      await pumpRouter(tester, router(ChatImageCache(repo)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat-photo-viewer-image')), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      verify(
        () => repo.fetchImage('conv-1', 'p1', variant: ChatImageVariant.full),
      ).called(1);

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('410 → « Photo expirée »', (tester) async {
      when(
        () => repo.fetchImage(any(), any(), variant: any(named: 'variant')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response<dynamic>(
            statusCode: 410,
            requestOptions: RequestOptions(path: '/x'),
          ),
        ),
      );
      await pumpRouter(tester, router(ChatImageCache(repo)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat-photo-viewer-expired')),
        findsOneWidget,
      );
      expect(find.text('Photo expirée'), findsOneWidget);
    });

    testWidgets('échec réseau → tap pour réessayer', (tester) async {
      var calls = 0;
      when(
        () => repo.fetchImage(any(), any(), variant: any(named: 'variant')),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return _png;
      });
      await pumpRouter(tester, router(ChatImageCache(repo)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Touchez pour réessayer'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-photo-viewer-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-photo-viewer-image')), findsOneWidget);
    });
  });
}
