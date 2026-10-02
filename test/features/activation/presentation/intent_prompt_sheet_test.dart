import 'package:dio/dio.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/data/activation_repository.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/widgets/intent_prompt_sheet.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ActivationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockRepo repo;
  bool? sheetResult;

  setUpAll(() {
    registerFallbackValue(UserIntent.sender);
    registerFallbackValue(IntentSource.prompt);
  });

  setUp(() {
    sheetResult = null;
    repo = _MockRepo();
    final analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerFactoryParam<
      IntentCubit,
      ({UserIntent? intent, String? destination}),
      void
    >(
      (initial, _) => IntentCubit(
        repo,
        analytics,
        initialIntent: initial.intent,
        initialDestination: initial.destination,
      ),
    );
  });

  tearDown(getIt.reset);

  Future<bool?> Function() open(
    WidgetTester tester, {
    UserIntent? initialIntent,
    String? initialDestination,
  }) {
    return () async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    sheetResult = await IntentPromptSheet.show(
                      context,
                      source: IntentSource.prompt,
                      initialIntent: initialIntent,
                      initialDestination: initialDestination,
                    );
                  },
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      return sheetResult;
    };
  }

  testWidgets('choix puis Continuer enregistre et ferme avec true', (
    tester,
  ) async {
    when(
      () => repo.declareIntent(
        intent: any(named: 'intent'),
        destinationCountry: any(named: 'destinationCountry'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});
    await open(tester)();

    final continueButton = find.byKey(const Key('intent-sheet-continue'));
    expect(continueButton, findsOneWidget);
    await tester.tap(find.byKey(const Key('intent-option-sender')));
    await tester.tap(find.byKey(const Key('intent-destination-CI')));
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    verify(
      () => repo.declareIntent(
        intent: UserIntent.sender,
        destinationCountry: 'CI',
        source: IntentSource.prompt,
      ),
    ).called(1);
    expect(find.byKey(const Key('intent-sheet-continue')), findsNothing);
    expect(sheetResult, isTrue);
  });

  testWidgets('erreur : la feuille reste ouverte avec un message', (
    tester,
  ) async {
    when(
      () => repo.declareIntent(
        intent: any(named: 'intent'),
        destinationCountry: any(named: 'destinationCountry'),
        source: any(named: 'source'),
      ),
    ).thenThrow(DioException(requestOptions: RequestOptions()));
    await open(
      tester,
      initialIntent: UserIntent.traveler,
      initialDestination: 'SN',
    )();

    await tester.tap(find.byKey(const Key('intent-sheet-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text("Impossible d'enregistrer votre choix pour l'instant."),
      findsOneWidget,
    );
    expect(find.byKey(const Key('intent-sheet-continue')), findsOneWidget);
  });
}
