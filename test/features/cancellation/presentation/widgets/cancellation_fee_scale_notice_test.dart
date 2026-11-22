import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_fee_scale_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../cancellation_fee_test_support.dart';

final _now = kFeeEffectiveFrom.add(const Duration(days: 2));

CancellationFeeTier _t(int days, double rate) =>
    CancellationFeeTier(minDaysBefore: days, rate: rate);

CancellationFeeConfigModel _custom() => CancellationFeeConfigModel(
  active: true,
  effectiveFrom: kFeeEffectiveFrom,
  capEur: 45,
  tiers: [_t(7, 0), _t(2, 0.15), _t(0, 0.5)],
);

Widget _app({Locale locale = const Locale('fr')}) => localizedApp(
  Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: CancellationFeeScaleNotice(clock: () => _now),
    ),
  ),
  locale: locale,
);

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  const narrow = Size(360, 800);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  final notice = find.byKey(const Key('cancel-fee-scale-notice'));

  group('ligne', () {
    testWidgets('frais allumés : ligne et lien, FR', (tester) async {
      phone(tester);
      await registerFeeConfig(config: kActiveFeeConfig);
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(notice, findsOneWidget);
      expect(
        find.textContaining(
          'Annulation : des frais peuvent s\'appliquer après acceptation par '
          'le voyageur. Voir le barème',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('frais allumés : EN', (tester) async {
      phone(tester);
      await registerFeeConfig(config: kActiveFeeConfig);
      await tester.pumpWidget(_app(locale: const Locale('en')));
      await tester.pump();
      expect(
        find.textContaining(
          'Cancellation: a fee may apply once the traveler has accepted. '
          'See the fee scale',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('éteint : rien, aucune place prise', (tester) async {
      await registerFeeConfig(config: CancellationFeeConfigModel.inactive);
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(notice, findsNothing);
      expect(tester.getSize(find.byType(CancellationFeeScaleNotice)).height, 0);
    });

    testWidgets('configuration absente (404) : rien', (tester) async {
      await registerFeeConfig();
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(notice, findsNothing);
    });

    testWidgets('sans cubit enregistré : rien', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(notice, findsNothing);
    });

    testWidgets('date d\'effet pas encore passée : rien', (tester) async {
      await registerFeeConfig(config: kActiveFeeConfig);
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: CancellationFeeScaleNotice(
              clock: () => kFeeEffectiveFrom.subtract(const Duration(days: 1)),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(notice, findsNothing);
    });

    testWidgets('paliers vides : rien', (tester) async {
      await registerFeeConfig(
        config: CancellationFeeConfigModel(
          active: true,
          effectiveFrom: kFeeEffectiveFrom,
          capEur: 30,
        ),
      );
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(notice, findsNothing);
    });
  });

  group('feuille', () {
    Future<void> open(WidgetTester tester, Locale locale) async {
      phone(tester);
      await tester.pumpWidget(_app(locale: locale));
      await tester.pump();
      await tester.tap(notice);
      await tester.pumpAndSettle();
    }

    testWidgets('FR : barème type depuis la config', (tester) async {
      await registerFeeConfig(config: kActiveFeeConfig);
      await open(tester, const Locale('fr'));
      expect(find.text('Barème des frais d\'annulation'), findsOneWidget);
      expect(
        find.text('Plus de 5 jours avant le départ : aucun frais'),
        findsOneWidget,
      );
      expect(find.text('De 5 jours à 3 jours : 10 %'), findsOneWidget);
      expect(find.text('De 3 jours à 1 jour : 20 %'), findsOneWidget);
      expect(
        find.text('Moins d\'un jour, jour du départ ou après : 30 %'),
        findsOneWidget,
      );
      expect(
        find.text('Plafond : ${formatPriceIn(30, 'EUR')} par colis'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Le montant exact est affiché avant que vous confirmiez une '
          'annulation.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Les frais ne s\'appliquent pas aux paiements en espèces.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('EN : barème type depuis la config', (tester) async {
      await registerFeeConfig(config: kActiveFeeConfig);
      await open(tester, const Locale('en'));
      expect(find.text('Cancellation fee scale'), findsOneWidget);
      expect(
        find.text('More than 5 days before departure: no fee'),
        findsOneWidget,
      );
      expect(find.text('From 5 days to 3 days: 10%'), findsOneWidget);
      expect(find.text('From 3 days to 1 day: 20%'), findsOneWidget);
      expect(
        find.text('Less than 1 day, on the day of departure or after: 30%'),
        findsOneWidget,
      );
      expect(
        find.text('Cap: ${formatPriceIn(30, 'EUR')} per parcel'),
        findsOneWidget,
      );
      expect(
        find.text(
          'The exact amount is shown before you confirm a cancellation.',
        ),
        findsOneWidget,
      );
      expect(find.text('Fees do not apply to cash payments.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('paliers personnalisés : rien n\'est codé en dur (FR)', (
      tester,
    ) async {
      await registerFeeConfig(config: _custom());
      await open(tester, const Locale('fr'));
      expect(
        find.text('Plus de 7 jours avant le départ : aucun frais'),
        findsOneWidget,
      );
      expect(find.text('De 7 jours à 2 jours : 15 %'), findsOneWidget);
      expect(
        find.text('Moins de 2 jours, jour du départ ou après : 50 %'),
        findsOneWidget,
      );
      expect(
        find.text('Plafond : ${formatPriceIn(45, 'EUR')} par colis'),
        findsOneWidget,
      );
      expect(find.textContaining('10 %'), findsNothing);
      expect(find.textContaining('30 %'), findsNothing);
    });

    testWidgets('paliers personnalisés (EN)', (tester) async {
      await registerFeeConfig(config: _custom());
      await open(tester, const Locale('en'));
      expect(find.text('From 7 days to 2 days: 15%'), findsOneWidget);
      expect(
        find.text('Less than 2 days, on the day of departure or after: 50%'),
        findsOneWidget,
      );
    });

    testWidgets('sans plafond dans la config : ligne Plafond omise', (
      tester,
    ) async {
      await registerFeeConfig(
        config: CancellationFeeConfigModel(
          active: true,
          effectiveFrom: kFeeEffectiveFrom,
          tiers: kActiveFeeConfig.tiers,
        ),
      );
      await open(tester, const Locale('fr'));
      expect(find.textContaining('Plafond'), findsNothing);
      expect(find.textContaining('par colis'), findsNothing);
    });

    testWidgets('le bouton OK est dans le pied collant et ferme la feuille', (
      tester,
    ) async {
      await registerFeeConfig(config: kActiveFeeConfig);
      await open(tester, const Locale('fr'));
      final close = find.byKey(const Key('cancel-fee-scale-close'));
      expect(close, findsOneWidget);
      // Hors du contenu défilant : aucun DonyButton parmi les descendants du
      // scroll de la feuille.
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(DonyButton),
        ),
        findsNothing,
      );
      expect(find.text('OK'), findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.text('Barème des frais d\'annulation'), findsNothing);
    });

    testWidgets('ouverture : événement analytics sans montant', (tester) async {
      await registerFeeConfig(config: kActiveFeeConfig);
      final analytics = _MockAnalytics();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerSingleton<AnalyticsService>(analytics);
      addTearDown(() => getIt.unregister<AnalyticsService>());
      await open(tester, const Locale('fr'));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.cancellationFeeScaleOpened,
          properties: {'source': 'bid_checkout'},
        ),
      ).called(1);
    });
  });
}
