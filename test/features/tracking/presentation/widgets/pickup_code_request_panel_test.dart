import 'package:dio/dio.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tracking/bloc/pickup_code_request_cubit.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:dony/features/tracking/presentation/widgets/pickup_code_request_panel.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockTrackingRepository extends Mock implements TrackingRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late _MockTrackingRepository repository;
  late _MockAnalyticsService analytics;

  setUp(() {
    repository = _MockTrackingRepository();
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerFactory<PickupCodeRequestCubit>(
      () => PickupCodeRequestCubit(repository, analytics),
    );
    DonySnackbar.clearDedup();
  });

  tearDown(() => getIt.unregister<PickupCodeRequestCubit>());

  Future<void> pump(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale ?? const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: PickupCodeRequestPanel(bidId: 'bid-1', source: 'test'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('appui : demande envoyée, confirmation affichée', (tester) async {
    when(
      () => repository.requestNewCode('bid-1'),
    ).thenAnswer((_) async => (requestedAt: null, nextRequestAllowedAt: null));
    await pump(tester);
    expect(find.text('Demander un nouveau code'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pickup-code-request-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(() => repository.requestNewCode('bid-1')).called(1);
    expect(find.byKey(const Key('pickup-code-request-sent')), findsOneWidget);
    expect(find.byKey(const Key('pickup-code-request-button')), findsNothing);
    // Bloc de confirmation + snackbar.
    expect(find.text("Demande envoyée à l'expéditeur"), findsWidgets);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('429 : délai restant en minutes, le bouton reste', (
    tester,
  ) async {
    final options = RequestOptions(path: '/tracking/bid-1/request-code');
    final next = DateTime.now().toUtc().add(
      const Duration(minutes: 11, seconds: 30),
    );
    when(() => repository.requestNewCode('bid-1')).thenThrow(
      DioException(
        requestOptions: options,
        error: const RateLimitException(),
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 429,
          data: {
            'code': 'code-request-too-soon',
            'nextRequestAllowedAt': next.toIso8601String(),
          },
        ),
        type: DioExceptionType.badResponse,
      ),
    );
    await pump(tester);

    await tester.tap(find.byKey(const Key('pickup-code-request-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Demande déjà envoyée, réessayez dans 12 min'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('pickup-code-request-button')), findsOneWidget);
  });

  testWidgets('429 sans échéance : « quelques minutes » (EN)', (tester) async {
    when(
      () => repository.requestNewCode('bid-1'),
    ).thenThrow(const RateLimitException());
    enableEnglish();
    await pump(tester, locale: const Locale('en'));
    expect(find.text('Request a new code'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pickup-code-request-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Request already sent, try again in a few minutes'),
      findsOneWidget,
    );
  });

  testWidgets('erreur : présentée, le bouton reste disponible', (tester) async {
    when(
      () => repository.requestNewCode('bid-1'),
    ).thenThrow(const ConflictException('x', code: 'code-still-valid'));
    await pump(tester);

    await tester.tap(find.byKey(const Key('pickup-code-request-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('pickup-code-request-sent')), findsNothing);
    expect(find.byKey(const Key('pickup-code-request-button')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  test('needsPickupCodeRequest : code bloqué ou expiré seulement', () {
    expect(needsPickupCodeRequest('code-blocked'), isTrue);
    expect(needsPickupCodeRequest('code-expired'), isTrue);
    expect(needsPickupCodeRequest('code-incorrect'), isFalse);
    expect(needsPickupCodeRequest(null), isFalse);
  });
}
