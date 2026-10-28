// Carte « Suivi du voyageur » de la fiche colis (vue expéditeur) : pastille
// d'état, avancement, ville la plus proche, historique des villes et lien vers
// la frise complète. Neutre quand le suivi n'est pas activé ou ancien.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/traveler_tracking_card_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tracking_card.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

final _nowUtc = DateTime.utc(2026, 10, 28, 12);

TravelerTrackingModel _tracking({
  TravelerTrackingStatus status = TravelerTrackingStatus.enRoute,
  Duration age = const Duration(minutes: 5),
  int? progressPct = 40,
  String? nearestCity = 'Marseille',
  List<TravelerTrackingPoint> history = const [],
}) => TravelerTrackingModel(
  status: status,
  lastUpdatedAt: _nowUtc.subtract(age),
  progressPct: progressPct,
  nearestCity: nearestCity,
  history: history,
);

BidModel _bid(String status, {TravelerTrackingModel? tracking}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 's-1',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  travelerTracking: tracking,
);

void main() {
  late _MockAnalytics analytics;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  setUp(() {
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    if (getIt.isRegistered<TravelerTrackingCardCubit>()) {
      getIt.unregister<TravelerTrackingCardCubit>();
    }
    getIt.registerFactory<TravelerTrackingCardCubit>(
      () => TravelerTrackingCardCubit(analytics: analytics),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<TravelerTrackingCardCubit>()) {
      getIt.unregister<TravelerTrackingCardCubit>();
    }
  });

  Widget host(
    TravelerTrackingModel tracking, {
    VoidCallback? onOpen,
    Locale locale = const Locale('fr'),
    DateTime? now,
  }) => MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: TravelerTrackingCard(
          tracking: tracking,
          onOpenTimeline: onOpen ?? () {},
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          now: () => now ?? _nowUtc,
        ),
      ),
    ),
  );

  Finder badge(String text) => find.descendant(
    of: find.byKey(const Key('traveler-tracking-badge')),
    matching: find.text(text),
  );

  group('contenu par état', () {
    testWidgets('showsEnRouteBadgeCityAndProgress', (tester) async {
      await tester.pumpWidget(host(_tracking()));

      expect(badge('En route'), findsOneWidget);
      expect(find.text('Près de Marseille'), findsOneWidget);
      expect(find.text('Mis à jour il y a 5 min'), findsOneWidget);
      expect(
        find.byKey(const Key('traveler-tracking-progress')),
        findsOneWidget,
      );
      expect(find.text('40 %'), findsOneWidget);
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Dakar'), findsOneWidget);
    });

    testWidgets('showsNotActivatedWithoutAlarm', (tester) async {
      await tester.pumpWidget(host(const TravelerTrackingModel()));

      expect(badge('Suivi non activé par le voyageur'), findsOneWidget);
      expect(find.byKey(const Key('traveler-tracking-progress')), findsNothing);
      expect(find.textContaining('Près de'), findsNothing);
      expect(
        find.text(
          "Le voyageur n'a pas activé le partage de sa position approximative.",
        ),
        findsOneWidget,
      );
      // Pastille neutre : ni la couleur de succès ni celle d'erreur.
      final cs = Theme.of(
        tester.element(find.byType(TravelerTrackingCard)),
      ).colorScheme;
      final deco =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byKey(const Key('traveler-tracking-badge')),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(deco.color, isNot(cs.successLight));
      expect(deco.color, isNot(cs.errorLight));
      expect(deco.gradient, isNull);
    });

    testWidgets('hidesPercentageWhenNull', (tester) async {
      await tester.pumpWidget(host(_tracking(progressPct: null)));

      expect(find.byKey(const Key('traveler-tracking-progress')), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('Près de Marseille'), findsOneWidget);
    });

    testWidgets('staleBadgeIsNeutral', (tester) async {
      await tester.pumpWidget(
        host(
          _tracking(
            status: TravelerTrackingStatus.stale,
            age: const Duration(hours: 3),
          ),
        ),
      );

      expect(badge('Dernière position il y a 3h'), findsOneWidget);
      expect(find.text('Près de Marseille'), findsOneWidget);
      final cs = Theme.of(
        tester.element(find.byType(TravelerTrackingCard)),
      ).colorScheme;
      final deco =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byKey(const Key('traveler-tracking-badge')),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(deco.color, isNot(cs.successLight));
      expect(deco.color, isNot(cs.errorLight));
      expect(deco.color, isNot(cs.warningLight));
    });

    testWidgets('arrivedShowsArrivedBadge', (tester) async {
      await tester.pumpWidget(
        host(
          _tracking(
            status: TravelerTrackingStatus.arrived,
            progressPct: null,
            nearestCity: 'Dakar',
          ),
        ),
      );

      expect(badge('Arrivé'), findsOneWidget);
      expect(find.byKey(const Key('traveler-tracking-progress')), findsNothing);
    });

    testWidgets('arrivedWithProgressFromBackShowsFullBar', (tester) async {
      await tester.pumpWidget(
        host(
          _tracking(
            status: TravelerTrackingStatus.arrived,
            progressPct: 100,
            nearestCity: 'Dakar',
          ),
        ),
      );
      expect(
        find.byKey(const Key('traveler-tracking-progress')),
        findsOneWidget,
      );
      expect(find.text('100 %'), findsOneWidget);
    });

    testWidgets('englishLabels', (tester) async {
      await tester.pumpWidget(host(_tracking(), locale: const Locale('en')));
      expect(badge('On the way'), findsOneWidget);
      expect(find.text('Near Marseille'), findsOneWidget);
      expect(find.text('Updated 5 min ago'), findsOneWidget);
      expect(find.text('See all steps and photos'), findsOneWidget);
    });
  });

  group('visibilité', () {
    test('hiddenWhenFieldAbsentFromOldBackend', () {
      for (final s in ['HANDED_OVER', 'IN_TRANSIT', 'ARRIVED', 'COMPLETED']) {
        expect(TravelerTrackingCard.shouldShow(_bid(s)), isFalse, reason: s);
      }
    });

    test('hiddenForStatusesWithoutTracking', () {
      for (final s in [
        'PENDING',
        'AWAITING_PAYMENT',
        'PAYMENT_ESCROWED',
        'ACCEPTED',
        'CANCELLED',
        'REJECTED',
        'EXPIRED',
      ]) {
        expect(
          TravelerTrackingCard.shouldShow(_bid(s, tracking: _tracking())),
          isFalse,
          reason: s,
        );
      }
    });

    test('shownForStatusesServedByBack', () {
      for (final s in ['HANDED_OVER', 'IN_TRANSIT', 'ARRIVED', 'COMPLETED']) {
        expect(
          TravelerTrackingCard.shouldShow(_bid(s, tracking: _tracking())),
          isTrue,
          reason: s,
        );
      }
    });
  });

  group('âge relatif', () {
    testWidgets('relativeAgeUsesLocalTime', (tester) async {
      // Horodatage UTC du back, horloge locale : même instant, même âge.
      await tester.pumpWidget(host(_tracking(), now: _nowUtc.toLocal()));
      expect(find.text('Mis à jour il y a 5 min'), findsOneWidget);
    });

    testWidgets('historyTimesShownInLocalTime', (tester) async {
      final at = DateTime.utc(2026, 10, 28, 9, 30);
      await tester.pumpWidget(
        host(
          _tracking(
            history: [TravelerTrackingPoint(city: 'Lyon', at: at)],
          ),
        ),
      );
      final expected = DateFormat.MMMd('fr').add_Hm().format(at.toLocal());
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('travelerTrackingAge thresholds', (tester) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              l = c.l10n;
              return const SizedBox();
            },
          ),
        ),
      );
      String age(Duration d) =>
          travelerTrackingAge(l, _nowUtc.subtract(d), _nowUtc);
      expect(age(const Duration(seconds: 20)), 'il y a < 1 min');
      expect(age(const Duration(minutes: 12)), 'il y a 12 min');
      expect(age(const Duration(hours: 5)), 'il y a 5h');
      expect(age(const Duration(hours: 50)), 'il y a 2 j');
      // Horloge du téléphone en retard : jamais d'âge négatif.
      expect(age(const Duration(minutes: -3)), 'il y a < 1 min');
    });
  });

  group('historique', () {
    final history = [
      TravelerTrackingPoint(city: 'Paris', at: DateTime.utc(2026, 10, 27, 8)),
      TravelerTrackingPoint(city: 'Lyon', at: DateTime.utc(2026, 10, 27, 12)),
      TravelerTrackingPoint(
        city: 'Marseille',
        at: DateTime.utc(2026, 10, 28, 9),
      ),
      TravelerTrackingPoint(city: 'Nice', at: DateTime.utc(2026, 10, 28, 11)),
    ];

    testWidgets('lastCityMarkedNowOrLastPosition: en route -> Maintenant', (
      tester,
    ) async {
      await tester.pumpWidget(host(_tracking(history: history)));

      // Les trois dernières villes seulement, dans l'ordre du temps.
      expect(find.text('Paris'), findsOneWidget); // étiquette du trajet
      final rows = find.byKey(const Key('traveler-tracking-history-row'));
      expect(rows, findsNWidgets(3));
      expect(find.text('Près de Lyon'), findsOneWidget);
      expect(find.text('Près de Marseille'), findsNWidgets(2)); // carte + ligne
      expect(find.text('Près de Nice'), findsOneWidget);
      expect(find.text('Maintenant'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Près de Lyon')).dy,
        lessThan(tester.getTopLeft(find.text('Près de Nice')).dy),
      );
    });

    testWidgets('lastCityMarkedNowOrLastPosition: stale -> Dernière position', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          _tracking(
            status: TravelerTrackingStatus.stale,
            age: const Duration(hours: 3),
            history: history,
          ),
        ),
      );
      expect(find.text('Dernière position, il y a 3h'), findsOneWidget);
      expect(find.text('Maintenant'), findsNothing);
    });

    testWidgets('sans historique : pas de liste, le lien reste', (
      tester,
    ) async {
      await tester.pumpWidget(host(_tracking()));
      expect(
        find.byKey(const Key('traveler-tracking-history-row')),
        findsNothing,
      );
      expect(find.text('Voir toutes les étapes et photos'), findsOneWidget);
    });

    testWidgets('le lien ouvre la frise et mesure l\'ouverture', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(host(_tracking(), onOpen: () => opened++));

      await tester.tap(find.text('Voir toutes les étapes et photos'));
      await tester.pump();

      expect(opened, 1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.travelerTrackingTimelineOpened,
          properties: {'status': 'en_route'},
        ),
      ).called(1);
    });
  });

  group('analytics', () {
    testWidgets('cardViewedEventFiredOnce', (tester) async {
      await tester.pumpWidget(
        host(
          _tracking(
            history: [TravelerTrackingPoint(city: 'Lyon', at: _nowUtc)],
          ),
        ),
      );
      // Reconstructions : aucun nouvel événement.
      await tester.pumpWidget(
        host(
          _tracking(
            history: [TravelerTrackingPoint(city: 'Lyon', at: _nowUtc)],
          ),
        ),
      );
      await tester.pump();

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.travelerTrackingCardViewed,
          properties: {'status': 'en_route', 'has_history': true},
        ),
      ).called(1);
    });
  });
}
