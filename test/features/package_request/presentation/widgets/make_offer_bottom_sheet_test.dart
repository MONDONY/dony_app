import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/price_estimate.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:dony/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockPriceEstimationRepository extends Mock
    implements PriceEstimationRepository {}

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

/// Trajet du voyageur compatible avec la demande ouverte par `wrap()`
/// (Paris → Dakar, poids 5 kg, date 12 juin 2026 — alignée sur l'`initialDate`
/// utilisée par les tests qui sélectionnent un trajet, pour rester dans la
/// fenêtre de tolérance de `TripPickerSection`).
AnnouncementModel _sampleAnnouncement() => AnnouncementModel(
  id: 'ann-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 6, 12),
  availableKg: 20.0,
  totalKg: 20.0,
  pricePerKg: 8.0,
  status: 'ACTIVE',
  bidsCount: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Minimal `NegotiationThread` fixture for `NegotiationLoaded` state pushes —
/// mirrors `_fakeThread` in create_trip_screen_test.dart.
NegotiationThread _sampleThread() => NegotiationThread(
  id: 'thread-new-1',
  packageRequestId: 'pr-1',
  travelerId: 'trav-1',
  travelerTravelDate: DateTime(2026, 6, 12),
  travelerAvailableKg: 5,
  status: NegotiationThreadStatus.open,
  currentPriceEur: 25,
  roundsCount: 1,
  lastActivityAt: DateTime(2026, 6),
  createdAt: DateTime(2026, 6),
  messages: const [],
);

void main() {
  late _MockNegotiationBloc negoBloc;
  late _MockPriceEstimationRepository priceRepo;
  late _MockAnnouncementRepository announcementRepo;
  late _MockAnalyticsService analytics;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    registerFallbackValue(
      NegotiationStartRequested(
        packageRequestId: 'x',
        proposedPriceEur: 1,
        travelerTravelDate: DateTime(2026),
        travelerAvailableKg: 1,
      ),
    );
  });

  setUp(() {
    negoBloc = _MockNegotiationBloc();
    priceRepo = _MockPriceEstimationRepository();
    announcementRepo = _MockAnnouncementRepository();
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    when(() => negoBloc.state).thenReturn(const NegotiationInitial());
    when(
      () => negoBloc.stream,
    ).thenAnswer((_) => const Stream<NegotiationState>.empty());
    when(
      () => priceRepo.estimate(
        from: any(named: 'from'),
        to: any(named: 'to'),
        weight: any(named: 'weight'),
      ),
    ).thenThrow(Exception('no estimate'));
    when(() => announcementRepo.getMyAnnouncements()).thenAnswer(
      (_) async => (announcements: [_sampleAnnouncement()], totalElements: 1),
    );

    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
    if (getIt.isRegistered<PriceEstimationRepository>()) {
      getIt.unregister<PriceEstimationRepository>();
    }
    if (getIt.isRegistered<AnnouncementRepository>()) {
      getIt.unregister<AnnouncementRepository>();
    }
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerFactory<NegotiationBloc>(() => negoBloc);
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    getIt.registerLazySingleton<PriceEstimationRepository>(() => priceRepo);
    getIt.registerLazySingleton<AnnouncementRepository>(() => announcementRepo);
  });

  tearDown(() async {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
    if (getIt.isRegistered<PriceEstimationRepository>()) {
      getIt.unregister<PriceEstimationRepository>();
    }
    if (getIt.isRegistered<AnnouncementRepository>()) {
      getIt.unregister<AnnouncementRepository>();
    }
  });

  Widget wrap({
    DateTime? initialDate,
    bool isFirmPrice = false,
    double? targetPriceEur,
    double? displayPriceEur,
    DateTime? desiredDate,
    int dateToleranceDays = 3,
    bool flexibleDate = false,
    void Function(Object? extra)? onTripsCreate,
  }) => MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, state) => Builder(
            builder: (innerCtx) => ElevatedButton(
              onPressed: () => MakeOfferBottomSheet.show(
                innerCtx,
                packageRequestId: 'pr-1',
                weightKg: 5,
                departureCity: 'Paris',
                arrivalCity: 'Dakar',
                // Aligné sur `_sampleAnnouncement().departureDate` (12 juin
                // 2026) pour que le trajet reste dans la fenêtre de tolérance
                // de TripPickerSection.
                desiredDate: flexibleDate
                    ? null
                    : desiredDate ?? DateTime(2026, 6, 12),
                dateToleranceDays: dateToleranceDays,
                transportMode: TransportMode.plane,
                initialDate: initialDate,
                isFirmPrice: isFirmPrice,
                targetPriceEur: targetPriceEur,
                displayPriceEur: displayPriceEur,
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
        GoRoute(
          path: '/negotiations/:id',
          builder: (_, _) => const Scaffold(body: Text('Négociation')),
        ),
        // Écran factice simulant /trips/create : deux boutons pour rejouer
        // les deux issues réelles observées dans create_trip_screen.dart —
        // succès → `pop(true)`, annulation/retour → `pop()` (aucune valeur).
        GoRoute(
          path: '/trips/create',
          builder: (routeCtx, routeState) {
            onTripsCreate?.call(routeState.extra);
            return Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(routeCtx).pop(true),
                    child: const Text('Simuler trajet créé'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(routeCtx).pop(),
                    child: const Text('Simuler annulation'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
    theme: AppTheme.light(),
  );

  // ── Helpers de parcours ───────────────────────────────────────────────────

  /// Ouvre la feuille (étape 1) et laisse passer les post-frames qui figent la
  /// signature de référence et préviennent le pied fixe.
  Future<void> open(WidgetTester tester, {Widget? app}) async {
    await tester.pumpWidget(app ?? wrap(initialDate: DateTime(2026, 6, 12)));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();
  }

  // Un seul `DonyButton` dans la feuille : le bouton principal du pied fixe.
  final continueButton = find.byType(DonyButton);
  final priceField = find.byKey(const Key('make-offer-price-field'));
  final capacityField = find.byKey(const Key('make-offer-capacity-field'));
  final messageField = find.byKey(const Key('make-offer-message-field'));
  final dateField = find.byKey(const Key('make-offer-date-field'));
  final tripTile = find.byKey(const Key('trip-tile-select-inkwell'));

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
  }

  Future<void> pickTrip(WidgetTester tester) async {
    await tester.ensureVisible(tripTile);
    await tester.tap(tripTile);
    await tester.pumpAndSettle();
  }

  /// Étape 1 → trajet choisi → étape 2.
  Future<void> toPriceStep(WidgetTester tester) async {
    await pickTrip(tester);
    await tapContinue(tester);
  }

  /// Jusqu'au récapitulatif, avec [price] saisi à l'étape 2 si fourni.
  Future<void> toRecapStep(WidgetTester tester, {String? price}) async {
    await toPriceStep(tester);
    if (price != null) {
      await tester.enterText(priceField, price);
      await tester.pumpAndSettle();
    }
    await tapContinue(tester);
  }

  /// Étape 1 → « Créer un nouveau trajet » → étape 2 (le trajet reste à créer).
  Future<void> toNewTripPriceStep(
    WidgetTester tester, {
    String label = 'Créer un nouveau trajet',
  }) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('MakeOfferBottomSheet — garde-fou de sortie', () {
    /// Saisit un prix à l'étape 2 : modification utilisateur incontestable.
    Future<void> typeSomething(WidgetTester tester) async {
      await toPriceStep(tester);
      await tester.enterText(priceField, '40');
      await tester.pumpAndSettle();
    }

    /// Simule le retour système (Android) / swipe back (iOS).
    Future<void> systemBack(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    testWidgets(
      'sans saisie, le retour système ferme la feuille sans confirmation',
      (tester) async {
        await open(tester);
        expect(find.text('Faire une offre'), findsOneWidget);

        await systemBack(tester);

        expect(find.text('Quitter sans enregistrer ?'), findsNothing);
        expect(find.text('Faire une offre'), findsNothing);
      },
    );

    testWidgets('après saisie, le retour système demande confirmation', (
      tester,
    ) async {
      await open(tester);
      await typeSomething(tester);

      await systemBack(tester);

      expect(find.text('Quitter sans enregistrer ?'), findsOneWidget);
      expect(find.textContaining('ne seront pas'), findsOneWidget);
      // La feuille est toujours là tant qu'on n'a pas confirmé.
      expect(find.text('Faire une offre'), findsOneWidget);
    });

    testWidgets(
      'après saisie, le glissement vers le bas ne ferme pas la feuille',
      (tester) async {
        // `ModalBottomSheetRoute` n'honore PAS `PopScope` pour le glissement
        // (vérifié sur Flutter 3.44 : la feuille se fermait malgré le garde).
        // La feuille est donc ouverte avec `enableDrag: false`, et ce test
        // verrouille cette décision.
        await open(tester);
        await typeSomething(tester);

        await tester.drag(find.text('Faire une offre'), const Offset(0, 600));
        await tester.pumpAndSettle();

        expect(find.text('Faire une offre'), findsOneWidget);
      },
    );

    testWidgets(
      'après saisie, la croix de la feuille demande aussi confirmation',
      (tester) async {
        // `Navigator.pop()` ne consulte pas `PopScope` : sans le détour par
        // `maybePop`, la croix viderait la saisie sans rien demander.
        await open(tester);
        await typeSomething(tester);

        final closeBtn = find.ancestor(
          of: find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
          matching: find.byType(IconButton),
        );
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();

        expect(find.text('Quitter sans enregistrer ?'), findsOneWidget);
        expect(find.text('Faire une offre'), findsOneWidget);
      },
    );

    testWidgets('« Quitter » confirmé ferme bien la feuille', (tester) async {
      await open(tester);
      await typeSomething(tester);
      await systemBack(tester);

      await tester.tap(find.text('Quitter'));
      await tester.pumpAndSettle();

      expect(find.text('Faire une offre'), findsNothing);
    });
  });

  group('MakeOfferBottomSheet — étape 1 : le trajet', () {
    testWidgets('rappel de la demande, indicateur d\'étape, bouton grisé avec '
        'son explication', (tester) async {
      await open(tester);

      expect(find.text('Étape 1 sur 3 · Trajet'), findsOneWidget);
      // Pas de retour à la première étape.
      expect(find.byKey(const Key('make-offer-back')), findsNothing);
      final recap = find.byKey(const Key('make-offer-request-recap'));
      expect(
        find.descendant(of: recap, matching: find.text('Paris')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: recap, matching: find.text('Dakar')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: recap,
          matching: find.textContaining('5 kg', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(continueButton, findsOneWidget);
      expect(tester.widget<DonyButton>(continueButton).onPressed, isNull);
      expect(find.text('Choisissez un trajet pour continuer'), findsOneWidget);
    });

    testWidgets('choisir un trajet active « Continuer » et mène au prix', (
      tester,
    ) async {
      await open(tester);
      await pickTrip(tester);

      expect(tester.widget<DonyButton>(continueButton).onPressed, isNotNull);
      expect(find.text('Choisissez un trajet pour continuer'), findsNothing);

      await tapContinue(tester);

      expect(find.text('Étape 2 sur 3 · Prix'), findsOneWidget);
      expect(priceField, findsOneWidget);
    });

    testWidgets('demande sans date : « Date flexible » dans le rappel', (
      tester,
    ) async {
      await open(tester, app: wrap(flexibleDate: true));

      final recap = find.byKey(const Key('make-offer-request-recap'));
      expect(
        find.descendant(
          of: recap,
          matching: find.textContaining('Date flexible', findRichText: true),
        ),
        findsOneWidget,
      );
    });

    testWidgets('chaque étape est mesurée une fois affichée', (tester) async {
      await open(tester);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.makeOfferStepViewed,
          properties: {
            'step': 'trip',
            'price_type': 'negotiable',
            'new_trip': false,
          },
        ),
      ).called(1);

      await toPriceStep(tester);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.makeOfferStepViewed,
          properties: {
            'step': 'price',
            'price_type': 'negotiable',
            'new_trip': false,
          },
        ),
      ).called(1);
    });
  });

  group('MakeOfferBottomSheet — étape 2 : prix et capacité', () {
    testWidgets('prix vide : « Continuer » grisé avec l\'explication', (
      tester,
    ) async {
      await open(tester);
      await toPriceStep(tester);

      expect(find.text('Étape 2 sur 3 · Prix'), findsOneWidget);
      expect(tester.widget<DonyButton>(continueButton).onPressed, isNull);
      expect(find.text('Saisissez un prix valide'), findsOneWidget);

      await tester.enterText(priceField, '25');
      await tester.pumpAndSettle();

      expect(tester.widget<DonyButton>(continueButton).onPressed, isNotNull);
      expect(find.text('Saisissez un prix valide'), findsNothing);
    });

    testWidgets('prix à zéro : toujours refusé', (tester) async {
      await open(tester);
      await toPriceStep(tester);

      await tester.enterText(priceField, '0');
      await tester.pumpAndSettle();

      expect(tester.widget<DonyButton>(continueButton).onPressed, isNull);
      expect(find.text('Saisissez un prix valide'), findsOneWidget);
    });

    testWidgets('capacité à zéro : explication dédiée', (tester) async {
      await open(tester);
      await toPriceStep(tester);
      await tester.enterText(priceField, '25');
      await tester.enterText(capacityField, '0');
      await tester.pumpAndSettle();

      expect(tester.widget<DonyButton>(continueButton).onPressed, isNull);
      expect(find.text('Saisissez une capacité valide'), findsOneWidget);
    });

    testWidgets('le prix se saisit au clavier : seuls chiffres, virgule et '
        'point passent', (tester) async {
      await open(tester);
      await toPriceStep(tester);

      await tester.enterText(priceField, 'ab12,5€');
      await tester.pumpAndSettle();

      expect(tester.widget<TextFormField>(priceField).controller!.text, '12,5');
    });

    testWidgets('− et + ajustent le prix (jamais sous 1)', (tester) async {
      await open(tester);
      await toPriceStep(tester);
      await tester.enterText(priceField, '25');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Augmenter le prix'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(priceField).controller!.text, '26');

      await tester.tap(find.byTooltip('Baisser le prix'));
      await tester.tap(find.byTooltip('Baisser le prix'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(priceField).controller!.text, '24');

      await tester.enterText(priceField, '1');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Baisser le prix'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(priceField).controller!.text, '1');
    });

    testWidgets('prix à partir de 1 000 : pas de 100', (tester) async {
      await open(tester);
      await toPriceStep(tester);
      await tester.enterText(priceField, '62000');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Augmenter le prix'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(priceField).controller!.text,
        '62100',
      );
    });

    testWidgets('prix vide : « + » repart de 1', (tester) async {
      await open(tester);
      await toPriceStep(tester);

      await tester.tap(find.byTooltip('Augmenter le prix'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextFormField>(priceField).controller!.text, '1');
    });

    testWidgets('− et + ajustent la capacité par kilo, jamais sous 0,5', (
      tester,
    ) async {
      await open(tester);
      await toPriceStep(tester);
      // Le colis pèse 5 kg : la capacité proposée démarre à 5,0.
      expect(
        tester.widget<TextFormField>(capacityField).controller!.text,
        '5.0',
      );

      await tester.tap(find.byTooltip('Plus de kilos'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(capacityField).controller!.text,
        '6.0',
      );

      await tester.enterText(capacityField, '1');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Moins de kilos'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(capacityField).controller!.text,
        '0.5',
      );
    });

    testWidgets('sur un trajet existant, pas de champ date (la date est celle '
        'du trajet)', (tester) async {
      await open(tester);
      await toPriceStep(tester);

      expect(dateField, findsNothing);
      expect(
        find.byKey(const Key('make-offer-travel-date-hint')),
        findsNothing,
      );
    });

    testWidgets('« Retour » ramène au trajet, choix conservé', (tester) async {
      await open(tester);
      await toPriceStep(tester);

      await tester.tap(find.byKey(const Key('make-offer-back')));
      await tester.pumpAndSettle();

      expect(find.text('Étape 1 sur 3 · Trajet'), findsOneWidget);
      expect(tester.widget<DonyButton>(continueButton).onPressed, isNotNull);
    });
  });

  group('MakeOfferBottomSheet — étape 3 : récapitulatif et envoi', () {
    testWidgets(
      'récap : corridor, départ, capacité, prix, message facultatif',
      (tester) async {
        await open(tester);
        await toRecapStep(tester, price: '25');

        expect(find.text('Étape 3 sur 3 · Récap et message'), findsOneWidget);
        final recap = find.byKey(const Key('make-offer-recap'));
        expect(
          find.descendant(of: recap, matching: find.text('Paris')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: recap, matching: find.text('Dakar')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: recap,
            matching: find.text(
              DateFormat.yMMMEd('fr').format(DateTime(2026, 6, 12)),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: recap, matching: find.text('5 kg')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: recap, matching: find.textContaining('25')),
          findsOneWidget,
        );
        expect(messageField, findsOneWidget);
        expect(find.text('MESSAGE'), findsOneWidget);
        expect(
          find.widgetWithText(DonyButton, 'Envoyer l\'offre'),
          findsOneWidget,
        );
      },
    );

    testWidgets('envoyer : prix, capacité, trajet et date du trajet partent '
        'dans l\'événement', (tester) async {
      await open(tester);
      await toRecapStep(tester, price: '25');

      await tester.tap(find.widgetWithText(DonyButton, 'Envoyer l\'offre'));
      await tester.pump();

      verify(
        () => negoBloc.add(
          any(
            that: isA<NegotiationStartRequested>()
                .having((e) => e.packageRequestId, 'packageRequestId', 'pr-1')
                .having((e) => e.proposedPriceEur, 'proposedPriceEur', 25)
                .having((e) => e.travelerAvailableKg, 'travelerAvailableKg', 5)
                .having(
                  (e) => e.travelerAnnouncementId,
                  'travelerAnnouncementId',
                  'ann-1',
                )
                .having(
                  (e) => e.travelerTravelDate,
                  'travelerTravelDate',
                  DateTime(2026, 6, 12),
                )
                .having((e) => e.body, 'body', isNull)
                .having((e) => e.isFirmPrice, 'isFirmPrice', false),
          ),
        ),
      ).called(1);
    });

    testWidgets('le message saisi part avec l\'offre', (tester) async {
      await open(tester);
      await toRecapStep(tester, price: '25,5');
      await tester.enterText(messageField, '  Je voyage ce jour-là  ');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DonyButton, 'Envoyer l\'offre'));
      await tester.pump();

      verify(
        () => negoBloc.add(
          any(
            that: isA<NegotiationStartRequested>()
                .having((e) => e.proposedPriceEur, 'proposedPriceEur', 25.5)
                .having((e) => e.body, 'body', 'Je voyage ce jour-là'),
          ),
        ),
      ).called(1);
    });

    testWidgets('« Retour » du récap ramène au prix, saisie conservée', (
      tester,
    ) async {
      await open(tester);
      await toRecapStep(tester, price: '25');

      await tester.tap(find.byKey(const Key('make-offer-back')));
      await tester.pumpAndSettle();

      expect(find.text('Étape 2 sur 3 · Prix'), findsOneWidget);
      expect(tester.widget<TextFormField>(priceField).controller!.text, '25');
    });
  });

  group('MakeOfferBottomSheet — prix ferme', () {
    testWidgets(
      'champ verrouillé, sans − ni +, et envoie le prix EXACT (pas arrondi)',
      (tester) async {
        await open(
          tester,
          app: wrap(
            initialDate: DateTime(2026, 6, 12),
            isFirmPrice: true,
            targetPriceEur: 35.5,
          ),
        );

        // Framing « prendre » et non « négocier ».
        expect(find.text('Prendre ce colis'), findsOneWidget);
        expect(find.text('Faire une offre'), findsNothing);

        await toPriceStep(tester);
        expect(find.text('PRIX FERME'), findsOneWidget);
        // Prix affiché EXACT (35,50), jamais arrondi à 36.
        expect(
          tester.widget<TextFormField>(priceField).controller!.text,
          '35.50',
        );
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: priceField,
                  matching: find.byType(TextField),
                ),
              )
              .readOnly,
          isTrue,
        );
        expect(find.byTooltip('Baisser le prix'), findsNothing);
        expect(find.byTooltip('Augmenter le prix'), findsNothing);
        // Pas de jauge : le prix n'est pas négociable.
        expect(find.byKey(const Key('make-offer-market-gauge')), findsNothing);

        await tapContinue(tester);
        expect(find.text('Prendre à 35,50\u{a0}€'), findsOneWidget);
        expect(find.textContaining('ferme'), findsOneWidget);

        // Soumission → événement avec le prix EXACT (régression
        // firm-price-must-match).
        await tester.tap(find.text('Prendre à 35,50\u{a0}€'));
        await tester.pump();
        verify(
          () => negoBloc.add(
            any(
              that: isA<NegotiationStartRequested>()
                  .having((e) => e.proposedPriceEur, 'proposedPriceEur', 35.5)
                  .having((e) => e.isFirmPrice, 'isFirmPrice', true),
            ),
          ),
        ).called(1);
      },
    );

    // FLUTTER-56 : le bouton annonçait le net sous une carte qui montrait le
    // brut. La feuille montre le prix publié, le net en « vous recevez », et
    // envoie toujours le net.
    testWidgets(
      'prix publié en brut : brut affiché, « vous recevez » net, net envoyé',
      (tester) async {
        await open(
          tester,
          app: wrap(
            initialDate: DateTime(2026, 6, 12),
            isFirmPrice: true,
            targetPriceEur: 41,
            displayPriceEur: 46,
          ),
        );
        await toPriceStep(tester);

        expect(
          tester.widget<TextFormField>(priceField).controller!.text,
          '46.00',
        );
        expect(find.byKey(const Key('firm-price-you-receive')), findsOneWidget);
        expect(find.textContaining('41,00'), findsOneWidget);

        await tapContinue(tester);
        expect(find.text('Prendre à 46,00\u{a0}€'), findsOneWidget);
        await tester.tap(find.text('Prendre à 46,00\u{a0}€'));
        await tester.pump();

        verify(
          () => negoBloc.add(
            any(
              that: isA<NegotiationStartRequested>().having(
                (e) => e.proposedPriceEur,
                'proposedPriceEur',
                41,
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('sans montant connu : bouton « Prendre ce colis » à la fin, '
        'mais le prix manquant bloque l\'étape', (tester) async {
      await open(
        tester,
        app: wrap(initialDate: DateTime(2026, 6, 12), isFirmPrice: true),
      );
      await toPriceStep(tester);

      expect(tester.widget<DonyButton>(continueButton).onPressed, isNull);
      expect(find.text('Saisissez un prix valide'), findsOneWidget);
    });
  });

  group('MakeOfferBottomSheet — nouveau trajet', () {
    testWidgets(
      '« Créer un nouveau trajet » mène au prix, avec le champ date',
      (tester) async {
        await open(tester);
        await toNewTripPriceStep(tester);

        expect(find.text('Étape 2 sur 3 · Prix'), findsOneWidget);
        expect(dateField, findsOneWidget);
        expect(
          find.byKey(const Key('make-offer-travel-date-hint')),
          findsOneWidget,
        );
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.makeOfferStepViewed,
            properties: {
              'step': 'price',
              'price_type': 'negotiable',
              'new_trip': true,
            },
          ),
        ).called(1);
      },
    );

    testWidgets('sans date choisie : « Continuer » grisé avec l\'explication', (
      tester,
    ) async {
      await open(tester, app: wrap());
      await toNewTripPriceStep(tester);
      await tester.enterText(priceField, '25');
      await tester.pumpAndSettle();

      expect(tester.widget<DonyButton>(continueButton).onPressed, isNull);
      expect(
        find.text('Choisissez votre date de voyage pour continuer'),
        findsOneWidget,
      );
    });

    testWidgets('le bouton final propose de créer le trajet, sans envoyer '
        'd\'offre', (tester) async {
      await open(tester);
      await toNewTripPriceStep(tester);
      await tester.enterText(priceField, '25');
      await tester.pumpAndSettle();
      await tapContinue(tester);

      expect(find.widgetWithText(DonyButton, 'Envoyer l\'offre'), findsNothing);
      expect(
        find.widgetWithText(DonyButton, 'Créer un nouveau trajet'),
        findsOneWidget,
      );
    });

    testWidgets(
      'annulation de /trips/create garde la feuille ouverte avec la saisie '
      'intacte (pas de perte de données)',
      (tester) async {
        await open(tester);
        await toNewTripPriceStep(tester);
        await tester.enterText(priceField, '25');
        await tester.pumpAndSettle();
        await tapContinue(tester);

        await tester.tap(
          find.widgetWithText(DonyButton, 'Créer un nouveau trajet'),
        );
        await tester.pumpAndSettle();

        // On est bien sur l'écran factice /trips/create.
        expect(find.text('Simuler annulation'), findsOneWidget);
        await tester.tap(find.text('Simuler annulation'));
        await tester.pumpAndSettle();

        // La feuille d'offre est toujours là, au récapitulatif, avec le prix
        // saisi conservé.
        expect(find.text('Faire une offre'), findsOneWidget);
        expect(find.text('Étape 3 sur 3 · Récap et message'), findsOneWidget);
        expect(find.textContaining('25'), findsWidgets);
      },
    );

    testWidgets(
      'création réussie de /trips/create ferme bien la feuille d\'offre',
      (tester) async {
        await open(tester);
        await toNewTripPriceStep(tester);
        await tester.enterText(priceField, '25');
        await tester.pumpAndSettle();
        await tapContinue(tester);

        await tester.tap(
          find.widgetWithText(DonyButton, 'Créer un nouveau trajet'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Simuler trajet créé'), findsOneWidget);
        await tester.tap(find.text('Simuler trajet créé'));
        await tester.pumpAndSettle();

        // La feuille d'offre est fermée (comportement historique préservé).
        expect(find.text('Faire une offre'), findsNothing);
      },
    );

    testWidgets(
      'un état NegotiationLoaded émis PENDANT /trips/create ne fait réagir '
      'ni la feuille (double snackbar/pop) — seul CreateTripScreen traite '
      'l\'émission',
      (tester) async {
        final controller = StreamController<NegotiationState>.broadcast();
        addTearDown(controller.close);
        when(() => negoBloc.stream).thenAnswer((_) => controller.stream);

        await open(tester);
        await toNewTripPriceStep(tester);
        await tester.enterText(priceField, '25');
        await tester.pumpAndSettle();
        await tapContinue(tester);
        await tester.tap(
          find.widgetWithText(DonyButton, 'Créer un nouveau trajet'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Simuler trajet créé'), findsOneWidget);

        // Le NegotiationBloc est partagé avec /trips/create (même instance) —
        // simule l'émission que produirait le vrai CreateTripScreen une fois
        // le trajet dédié créé, AVANT que sa propre navigation (pop) ne se
        // déclenche.
        controller.add(NegotiationLoaded(_sampleThread()));
        await tester.pump();

        // Le listener de la feuille (montée en dessous) doit rester muet :
        // sans le garde `_creatingDedicatedTripElsewhere`, « Offre envoyée »
        // apparaîtrait ici en plus du feedback propre à CreateTripScreen.
        expect(find.text('Offre envoyée'), findsNothing);

        await tester.tap(find.text('Simuler trajet créé'));
        await tester.pumpAndSettle();

        expect(find.text('Faire une offre'), findsNothing);
      },
    );

    testWidgets('initialDate fourni → champ date affiche la valeur formatée', (
      tester,
    ) async {
      await open(tester);
      await toNewTripPriceStep(tester);

      // Texte exact du champ : l'aide sous le champ cite aussi la date de la
      // demande (« demande du 12 juin 2026 »).
      expect(
        find.text(DateFormat.yMMMEd('fr').format(DateTime(2026, 6, 12))),
        findsOneWidget,
      );
      expect(find.text('Sélectionner…'), findsNothing);
    });

    testWidgets('non-régression motif de date : DateFormat.yMMMEd(fr) rend '
        'exactement comme l\'ancien motif \'EEE d MMM yyyy\'', (tester) async {
      final date = DateTime(2026, 10, 6);
      await open(tester, app: wrap(initialDate: date));
      await toNewTripPriceStep(tester);

      final oldPatternRendering = DateFormat(
        'EEE d MMM yyyy',
        'fr',
      ).format(date);
      expect(find.text(oldPatternRendering), findsOneWidget);
    });

    testWidgets('sans initialDate → champ date affiche Sélectionner', (
      tester,
    ) async {
      await open(tester, app: wrap());
      await toNewTripPriceStep(tester);

      expect(find.text('Sélectionner…'), findsOneWidget);
    });

    testWidgets('le trajet à créer reçoit prix, capacité, message et date', (
      tester,
    ) async {
      Object? extra;
      await open(
        tester,
        app: wrap(
          initialDate: DateTime(2026, 6, 12),
          onTripsCreate: (e) => extra = e,
        ),
      );
      await toNewTripPriceStep(tester);
      await tester.enterText(priceField, '25');
      await tester.pumpAndSettle();
      await tapContinue(tester);
      await tester.enterText(messageField, 'Bonjour');
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DonyButton, 'Créer un nouveau trajet'),
      );
      await tester.pumpAndSettle();

      expect(extra, isA<CreateTripArgs>());
      final lock = (extra! as CreateTripArgs).lockContext!;
      expect(lock.agreedPriceEur, 25);
      expect(lock.offerAvailableKg, 5);
      expect(lock.offerBody, 'Bonjour');
      expect(lock.packageRequestId, 'pr-1');
    });
  });

  group('MakeOfferBottomSheet — anglais', () {
    testWidgets('prix ferme, sans montant connu → texte traduit', (
      tester,
    ) async {
      useEnglish();
      await open(
        tester,
        app: wrap(initialDate: DateTime(2026, 6, 12), isFirmPrice: true),
      );

      expect(find.text('Take this parcel'), findsWidgets);
      expect(find.text('Faire une offre'), findsNothing);
      await toPriceStep(tester);
      expect(find.text('FIXED PRICE'), findsOneWidget);
    });

    testWidgets('offre négociable : parcours entier traduit', (tester) async {
      useEnglish();
      await open(tester);

      expect(find.text('Make an offer'), findsOneWidget);
      expect(find.text('Step 1 of 3 · Trip'), findsOneWidget);
      expect(find.text('Pick a trip to continue'), findsOneWidget);

      await toPriceStep(tester);
      expect(find.text('Step 2 of 3 · Price'), findsOneWidget);
      expect(find.text('YOUR PRICE'), findsOneWidget);
      expect(find.text('CAPACITY'), findsOneWidget);
      expect(find.text('Enter a valid price'), findsOneWidget);
      expect(find.byTooltip('Raise the price'), findsOneWidget);

      await tester.enterText(priceField, '25');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DonyButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 3 · Summary and message'), findsOneWidget);
      expect(find.text('Departure'), findsOneWidget);
      expect(find.text('MESSAGE'), findsOneWidget);
      expect(find.textContaining('optional'), findsOneWidget);
      expect(find.widgetWithText(DonyButton, 'Send offer'), findsOneWidget);
    });

    testWidgets('non-régression motif de date : DateFormat.yMMMEd(en)', (
      tester,
    ) async {
      useEnglish();
      final date = DateTime(2026, 10, 6);
      await open(tester, app: wrap(initialDate: date));
      await toNewTripPriceStep(tester, label: 'Create a new trip');

      final expected = DateFormat.yMMMEd('en').format(date);
      expect(find.text(expected), findsOneWidget);
    });
  });

  group('MakeOfferBottomSheet — estimation du marché', () {
    Widget wrapWithEstimate(PriceEstimateConfidence confidence) {
      when(
        () => priceRepo.estimate(
          from: any(named: 'from'),
          to: any(named: 'to'),
          weight: any(named: 'weight'),
          currency: any(named: 'currency'),
        ),
      ).thenAnswer(
        (_) async => PriceEstimate(
          lowEur: 30,
          highEur: 45,
          confidence: confidence,
          sampleSize: 12,
        ),
      );
      return wrap(initialDate: DateTime(2026, 6, 12));
    }

    Future<void> atPriceStep(
      WidgetTester tester,
      PriceEstimateConfidence confidence,
    ) async {
      await open(tester, app: wrapWithEstimate(confidence));
      await toPriceStep(tester);
    }

    testWidgets(
      'français : "élevée", jamais le mot anglais "high" affiché brut',
      (tester) async {
        await atPriceStep(tester, PriceEstimateConfidence.high);

        expect(find.text('élevée'), findsOneWidget);
        expect(find.text('high'), findsNothing);
      },
    );

    testWidgets('français : "moyenne"', (tester) async {
      await atPriceStep(tester, PriceEstimateConfidence.medium);

      expect(find.text('moyenne'), findsOneWidget);
    });

    testWidgets('français : "faible"', (tester) async {
      await atPriceStep(tester, PriceEstimateConfidence.low);

      expect(find.text('faible'), findsOneWidget);
    });

    testWidgets('anglais : "high"/"medium"/"low" traduits via clé ARB', (
      tester,
    ) async {
      useEnglish();
      await atPriceStep(tester, PriceEstimateConfidence.high);

      expect(find.text('high'), findsOneWidget);
      expect(find.text('élevée'), findsNothing);
    });

    testWidgets('la jauge situe le prix saisi dans la fourchette du marché', (
      tester,
    ) async {
      await atPriceStep(tester, PriceEstimateConfidence.medium);
      final status = find.byKey(const Key('make-offer-gauge-status'));

      // Prix vide : rien n'est dessiné.
      expect(find.byKey(const Key('make-offer-market-gauge')), findsNothing);

      await tester.enterText(priceField, '38');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(status).data, 'Dans le prix du marché');

      await tester.enterText(priceField, '20');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(status).data, 'Sous le prix du marché');

      await tester.enterText(priceField, '80');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(status).data, 'Au-dessus du marché');
    });

    testWidgets('sans estimation : pas de jauge', (tester) async {
      await open(tester);
      await toPriceStep(tester);
      await tester.enterText(priceField, '38');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('make-offer-market-gauge')), findsNothing);
    });
  });

  group('MakeOfferBottomSheet — fenêtre de la date de voyage (FLUTTER-E7)', () {
    DateTime today() => DateUtils.dateOnly(DateTime.now());
    DateTime day(int offset) {
      final t = today();
      return DateTime(t.year, t.month, t.day + offset);
    }

    /// Ouvre la feuille jusqu'au champ date, qui n'existe que pour un trajet à
    /// créer.
    Future<void> openAtDate(
      WidgetTester tester,
      Widget app, {
      String label = 'Créer un nouveau trajet',
    }) async {
      await open(tester, app: app);
      await toNewTripPriceStep(tester, label: label);
    }

    Future<DatePickerDialog> openPicker(WidgetTester tester) async {
      await tester.ensureVisible(dateField);
      await tester.tap(dateField);
      await tester.pumpAndSettle();
      return tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    }

    testWidgets('le sélecteur est borné à souhaitée ± tolérance', (
      tester,
    ) async {
      await openAtDate(tester, wrap(desiredDate: day(20)));
      final picker = await openPicker(tester);
      expect(picker.firstDate, day(17));
      expect(picker.lastDate, day(23));
      expect(picker.initialDate, day(20));
    });

    testWidgets('la borne basse ne passe jamais avant aujourd\'hui', (
      tester,
    ) async {
      await openAtDate(tester, wrap(desiredDate: day(1), dateToleranceDays: 5));
      final picker = await openPicker(tester);
      expect(picker.firstDate, today());
      expect(picker.lastDate, day(6));
    });

    testWidgets('une date pré-remplie hors fenêtre est ramenée dedans', (
      tester,
    ) async {
      await openAtDate(
        tester,
        wrap(initialDate: day(60), desiredDate: day(20)),
      );
      final picker = await openPicker(tester);
      expect(picker.initialDate, day(23));
    });

    testWidgets('tolérance 0 : seul le jour souhaité, aide dédiée', (
      tester,
    ) async {
      await openAtDate(
        tester,
        wrap(desiredDate: day(10), dateToleranceDays: 0),
      );
      final desired = DateFormat.yMMMd('fr').format(day(10));
      expect(
        find.text(
          'Le $desired uniquement (date de la demande, sans tolérance)',
        ),
        findsOneWidget,
      );
      final picker = await openPicker(tester);
      expect(picker.firstDate, day(10));
      expect(picker.lastDate, day(10));
    });

    testWidgets(
      'demande sans date : aucune fenêtre imposée, aide « Date flexible »',
      (tester) async {
        await openAtDate(
          tester,
          wrap(flexibleDate: true, dateToleranceDays: 0),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.text('Date flexible : choisissez le jour de votre départ.'),
          findsOneWidget,
        );
        final picker = await openPicker(tester);
        expect(picker.firstDate, today());
        expect(picker.lastDate, day(365));
        expect(picker.initialDate, day(1));
      },
    );

    testWidgets('demande sans date : aide traduite en anglais', (tester) async {
      useEnglish();
      await openAtDate(
        tester,
        wrap(flexibleDate: true, dateToleranceDays: 0),
        label: 'Create a new trip',
      );
      expect(
        find.text('Flexible date: pick the day you leave.'),
        findsOneWidget,
      );
    });

    testWidgets('aide sous le champ, en français', (tester) async {
      await openAtDate(tester, wrap(desiredDate: day(20)));
      final fmt = DateFormat.yMMMd('fr');
      expect(
        find.text(
          'Entre le ${fmt.format(day(17))} et le ${fmt.format(day(23))} '
          '(demande du ${fmt.format(day(20))} ± 3 j)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('aide sous le champ, en anglais', (tester) async {
      useEnglish();
      await openAtDate(
        tester,
        wrap(desiredDate: day(20)),
        label: 'Create a new trip',
      );
      final fmt = DateFormat.yMMMd('en');
      expect(
        find.text(
          'Between ${fmt.format(day(17))} and ${fmt.format(day(23))} '
          '(requested ${fmt.format(day(20))} ± 3 d)',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'le trajet dédié reçoit la date choisie, ramenée dans la fenêtre',
      (tester) async {
        Object? extra;
        await openAtDate(
          tester,
          wrap(
            initialDate: day(60),
            desiredDate: day(20),
            onTripsCreate: (e) => extra = e,
          ),
        );
        await tester.enterText(priceField, '25');
        await tester.pumpAndSettle();
        await tapContinue(tester);
        await tester.tap(
          find.widgetWithText(DonyButton, 'Créer un nouveau trajet'),
        );
        await tester.pumpAndSettle();

        expect(extra, isA<CreateTripArgs>());
        final lock = (extra! as CreateTripArgs).lockContext!;
        expect(lock.preferredDate, day(23));
        expect(lock.desiredDate, day(20));
      },
    );
  });
}
