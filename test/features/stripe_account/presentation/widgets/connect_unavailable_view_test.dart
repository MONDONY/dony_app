import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/widgets/connect_unavailable_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/currency_test_doubles.dart';
import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/stripe_account_test_doubles.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

const _ctaKey = Key('connect-unavailable-change-country-cta');
const _countryCardKey = Key('connect-unavailable-residence-country');

void main() {
  late MockStripeAccountBloc stripeBloc;
  late _MockAnalyticsService analytics;

  setUpAll(() => registerFallbackValue(const StripeAccountStatusLoaded()));

  setUp(() {
    stripeBloc = stubStripeAccountBloc(state: stripeCountryUnavailableState);
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
  });

  tearDown(getIt.reset);

  Widget buildWidget({BusinessPrefsState? prefs}) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) {
            const view = ConnectUnavailableView(
              title: 'Recevoir mes paiements',
            );
            return BlocProvider<StripeAccountBloc>.value(
              value: stripeBloc,
              child: prefs == null
                  ? view
                  : BlocProvider<BusinessPrefsBloc>.value(
                      value: stubBusinessPrefsBloc(state: prefs),
                      child: view,
                    ),
            );
          },
        ),
        GoRoute(
          path: '/settings/preferences',
          builder: (ctx, _) => Scaffold(
            body: TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('PREFS'),
            ),
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  /// Draine les timers flutter_animate de la mascotte avant la fin du test.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('pays déclaré non couvert : nommé avec son drapeau, bouton '
      'de correction et phrase sur les espèces', (tester) async {
    await tester.pumpWidget(
      buildWidget(prefs: const BusinessPrefsState(country: 'CI')),
    );
    await tester.pump();

    expect(find.text('Recevoir mes paiements'), findsOneWidget);
    expect(find.text('Pas encore disponible\ndans votre pays'), findsOneWidget);
    expect(find.byKey(_countryCardKey), findsOneWidget);
    expect(find.text('Pays de résidence déclaré'), findsOneWidget);
    expect(find.text("Côte d'Ivoire"), findsOneWidget);
    expect(find.text('🇨🇮'), findsOneWidget);
    expect(
      find.textContaining('corrigez votre pays de résidence'),
      findsOneWidget,
    );
    expect(find.textContaining('mobile money'), findsOneWidget);
    expect(find.byKey(_ctaKey), findsOneWidget);
    expect(find.text('Modifier mon pays de résidence'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('le bouton ouvre Réglages › Préférences, trace l\'intention et '
      'redemande le statut Connect au retour', (tester) async {
    await tester.pumpWidget(
      buildWidget(prefs: const BusinessPrefsState(country: 'CI')),
    );
    await tester.pump();

    await tester.tap(find.byKey(_ctaKey));
    await tester.pumpAndSettle();
    expect(find.text('PREFS'), findsOneWidget);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.connectUnavailableChangeCountryTapped,
        properties: {'country_set': true},
      ),
    ).called(1);
    verifyNever(() => stripeBloc.add(const StripeAccountStatusRefreshed()));

    await tester.tap(find.text('PREFS'));
    await tester.pumpAndSettle();
    verify(
      () => stripeBloc.add(const StripeAccountStatusRefreshed()),
    ).called(1);

    await drain(tester);
  });

  testWidgets('pays vide : invite à le renseigner, même bouton', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget(prefs: const BusinessPrefsState()));
    await tester.pump();

    expect(find.byKey(_countryCardKey), findsNothing);
    expect(
      find.textContaining('Renseignez votre pays de résidence'),
      findsOneWidget,
    );
    expect(find.textContaining('mobile money'), findsNothing);
    expect(find.byKey(_ctaKey), findsOneWidget);

    await tester.tap(find.byKey(_ctaKey));
    await tester.pumpAndSettle();
    expect(find.text('PREFS'), findsOneWidget);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.connectUnavailableChangeCountryTapped,
        properties: {'country_set': false},
      ),
    ).called(1);

    await drain(tester);
  });

  testWidgets(
    'sans préférences fournies : rendu tolérant, comme un pays vide',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(
        find.textContaining('Renseignez votre pays de résidence'),
        findsOneWidget,
      );
      expect(find.byKey(_ctaKey), findsOneWidget);

      await drain(tester);
    },
  );

  testWidgets('pays verrouillé (compte Stripe créé) : pas de bouton, '
      'renvoi au support', (tester) async {
    await tester.pumpWidget(
      buildWidget(
        prefs: const BusinessPrefsState(country: 'CI', countryLocked: true),
      ),
    );
    await tester.pump();

    expect(find.text("Côte d'Ivoire"), findsOneWidget);
    expect(find.byKey(_ctaKey), findsNothing);
    expect(find.textContaining('contactez le support'), findsOneWidget);
    expect(
      find.textContaining('corrigez votre pays de résidence'),
      findsNothing,
    );

    await drain(tester);
  });

  testWidgets('en anglais : textes et bouton traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      buildWidget(prefs: const BusinessPrefsState(country: 'US')),
    );
    await tester.pump();

    // Le titre reste celui passé par l'appelant, jamais traduit ici.
    expect(find.text('Recevoir mes paiements'), findsOneWidget);
    expect(find.text('Not available yet\nin your country'), findsOneWidget);
    expect(find.text('Declared country of residence'), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    expect(
      find.textContaining('update your country of residence'),
      findsOneWidget,
    );
    expect(find.text('Update my country of residence'), findsOneWidget);

    await drain(tester);
  });
}
