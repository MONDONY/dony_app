import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/currency_onboarding_cubit.dart';
import 'package:dony/features/auth/presentation/screens/currency_selection_screen.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockBusinessPrefsRepository extends Mock
    implements BusinessPrefsRepository {}

class MockBox extends Mock implements Box<dynamic> {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class FakeUserBusinessPrefsDto extends Fake implements UserBusinessPrefsDto {}

const _prefs = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'EUR',
  pickupRadiusKm: 10,
  defaultPackageWeightKg: 23,
  minBidPriceEur: 0,
);

void main() {
  late MockBusinessPrefsRepository repository;
  late MockBox prefs;
  late MockAnalyticsService analytics;
  late CurrencyOnboardingCubit cubit;

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const CurrencySelectionScreen(),
          ),
        ),
        GoRoute(
          path: '/auth/referral-code',
          builder: (_, _) => const Scaffold(body: Text('Referral route')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  setUpAll(() {
    registerFallbackValue(FakeUserBusinessPrefsDto());
  });

  setUp(() {
    repository = MockBusinessPrefsRepository();
    prefs = MockBox();
    analytics = MockAnalyticsService();
    when(() => repository.fetchPrefs()).thenAnswer((_) async => _prefs);
    when(() => repository.updatePrefs(any())).thenAnswer((_) async {});
    when(() => prefs.put(any(), any())).thenAnswer((_) async {});
    when(() => analytics.logEvent(any())).thenAnswer((_) async {});
    cubit = CurrencyOnboardingCubit(repository, prefs, analytics);
  });

  tearDown(() => cubit.close());

  testWidgets(
    'affiche le catalogue complet avec nom, ISO, symbole et état sélectionné',
    (tester) async {
      await pumpScreen(tester);

      expect(find.text('Euro'), findsOneWidget);
      expect(find.text('EUR'), findsOneWidget);
      expect(find.text('€'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Sélectionner Euro, EUR, €'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Franc CFA Centre'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Franc CFA Centre'), findsOneWidget);
      expect(find.text('XAF'), findsOneWidget);
    },
  );

  testWidgets('sélection réussie navigue seulement après la persistance', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.bySemanticsLabel('Sélectionner Euro, EUR, €'));
    await tester.pumpAndSettle();

    expect(find.text('Referral route'), findsOneWidget);
  });

  testWidgets(
    'échec backend affiche une erreur puis retry réussit sans navigation prématurée',
    (tester) async {
      var attempts = 0;
      when(() => repository.fetchPrefs()).thenAnswer((_) async {
        attempts += 1;
        if (attempts == 1) throw Exception('offline');
        return _prefs;
      });
      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel('Sélectionner Euro, EUR, €'));
      await tester.pumpAndSettle();
      expect(
        find.text('Impossible d’enregistrer la devise. Réessayez.'),
        findsOneWidget,
      );
      expect(find.text('Referral route'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Sélectionner Euro, EUR, €'));
      await tester.pumpAndSettle();
      expect(find.text('Referral route'), findsOneWidget);
    },
  );

  testWidgets(
    'passer n’impose aucune devise au serveur, mais adopte la sienne',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Passer pour l’instant'));
      await tester.pumpAndSettle();

      // Passer, c'est ne rien choisir : aucune écriture des préférences.
      verifyNever(() => repository.updatePrefs(any()));
      // La devise n'est pour autant pas inventée côté client — on lit celle que
      // le backend porte déjà et on la met en cache local.
      verify(() => repository.fetchPrefs()).called(1);
      verify(() => prefs.put(HiveService.kCurrencyCode, 'EUR')).called(1);
      verify(
        () => prefs.put(HiveService.kCurrencyOnboardingSeen, true),
      ).called(1);
      expect(find.text('Referral route'), findsOneWidget);
    },
  );
}
