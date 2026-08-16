import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:dony/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

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

  setUpAll(() async {
    await initializeDateFormatting('fr');
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
    getIt.registerFactory<NegotiationBloc>(() => negoBloc);
    getIt.registerLazySingleton<PriceEstimationRepository>(() => priceRepo);
    getIt.registerLazySingleton<AnnouncementRepository>(() => announcementRepo);
  });

  tearDown(() async {
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
                desiredDate: DateTime(2026, 6, 12),
                dateToleranceDays: 3,
                transportMode: TransportMode.plane,
                initialDate: initialDate,
                isFirmPrice: isFirmPrice,
                targetPriceEur: targetPriceEur,
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
          builder: (routeCtx, _) => Scaffold(
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
          ),
        ),
      ],
    ),
    theme: AppTheme.light(),
  );

  group('MakeOfferBottomSheet — garde-fou de sortie', () {
    /// Ouvre la feuille et laisse passer les deux post-frames qui figent la
    /// signature de référence.
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(wrap(initialDate: DateTime(2026, 6, 12)));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pump();
    }

    /// Saisit un message : modification utilisateur incontestable.
    Future<void> typeSomething(WidgetTester tester) async {
      await tester.enterText(
        find.byType(TextFormField).last,
        'Je peux prendre ce colis',
      );
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
        // `onCloseRequested`, la croix viderait la saisie sans rien demander.
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

  group('MakeOfferBottomSheet', () {
    testWidgets('initialDate fourni → champ date affiche la valeur formatée', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(initialDate: DateTime(2026, 6, 12)));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('12 juin 2026'), findsOneWidget);
      expect(find.text('Sélectionner…'), findsNothing);
    });

    testWidgets('sans initialDate → champ date affiche Sélectionner', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Sélectionner…'), findsOneWidget);
    });

    testWidgets(
      'prix ferme → champ verrouillé + envoie le prix EXACT (pas arrondi)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            initialDate: DateTime(2026, 6, 12),
            isFirmPrice: true,
            targetPriceEur: 35.5,
          ),
        );
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();

        // Framing « prendre » et non « négocier ».
        expect(find.text('Prendre ce colis'), findsOneWidget);
        expect(find.text('PRIX FERME'), findsOneWidget);
        expect(find.text('Faire une offre'), findsNothing);
        // Prix affiché EXACT (35,50), jamais arrondi à 36.
        expect(find.text('35.50'), findsOneWidget);
        expect(find.text('Prendre à 35,50 €'), findsOneWidget);

        // Un trajet doit être sélectionné avant de pouvoir soumettre.
        // `ensureVisible` : la feuille défile (TripPickerSection pousse le
        // contenu sous le pli de la fenêtre de test), sinon le tap atterrit
        // hors du viewport visible.
        await tester.ensureVisible(
          find.byKey(const Key('trip-tile-select-inkwell')),
        );
        await tester.tap(find.byKey(const Key('trip-tile-select-inkwell')));
        await tester.pumpAndSettle();

        // Soumission → événement avec le prix EXACT (régression firm-price-must-match).
        await tester.tap(find.text('Prendre à 35,50 €'));
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

    testWidgets('le bouton d\'envoi reste désactivé tant qu\'aucun trajet '
        'n\'est sélectionné', (tester) async {
      await tester.pumpWidget(wrap(initialDate: DateTime(2026, 6, 12)));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      final sendButton = find.widgetWithText(DonyButton, 'Envoyer l\'offre');
      expect(tester.widget<DonyButton>(sendButton).onPressed, isNull);

      // Prix requis par le validateur du formulaire (aucun prix cible fourni
      // ici, contrairement au test « prix ferme »).
      await tester.enterText(find.byType(TextFormField).first, '25');
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('trip-tile-select-inkwell')),
      );
      await tester.tap(find.byKey(const Key('trip-tile-select-inkwell')));
      await tester.pumpAndSettle();

      expect(tester.widget<DonyButton>(sendButton).onPressed, isNotNull);

      await tester.tap(sendButton);
      await tester.pump();
      verify(
        () => negoBloc.add(
          any(
            that: isA<NegotiationStartRequested>().having(
              (e) => e.travelerAnnouncementId,
              'travelerAnnouncementId',
              'ann-1',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets(
      'annulation de /trips/create garde la feuille ouverte avec la saisie '
      'intacte (pas de perte de données)',
      (tester) async {
        await tester.pumpWidget(wrap(initialDate: DateTime(2026, 6, 12)));
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '25');
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Créer un nouveau trajet'));
        await tester.tap(find.text('Créer un nouveau trajet'));
        await tester.pumpAndSettle();

        // On est bien sur l'écran factice /trips/create.
        expect(find.text('Simuler annulation'), findsOneWidget);
        await tester.tap(find.text('Simuler annulation'));
        await tester.pumpAndSettle();

        // La feuille d'offre est toujours là, avec le prix saisi conservé.
        expect(find.text('Faire une offre'), findsOneWidget);
        expect(find.text('25'), findsOneWidget);
      },
    );

    testWidgets(
      'création réussie de /trips/create ferme bien la feuille d\'offre',
      (tester) async {
        await tester.pumpWidget(wrap(initialDate: DateTime(2026, 6, 12)));
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();

        // Prix requis par la validation du formulaire avant de naviguer vers
        // /trips/create (fix : plus question d'y créer un trajet dédié avec
        // un prix invalide/0 qui serait de toute façon rejeté par le backend).
        await tester.enterText(find.byType(TextFormField).first, '25');
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Créer un nouveau trajet'));
        await tester.tap(find.text('Créer un nouveau trajet'));
        await tester.pumpAndSettle();

        expect(find.text('Simuler trajet créé'), findsOneWidget);
        await tester.tap(find.text('Simuler trajet créé'));
        await tester.pumpAndSettle();

        // La feuille d'offre est fermée (comportement historique préservé).
        expect(find.text('Faire une offre'), findsNothing);
      },
    );

    testWidgets(
      'prix vide → "Créer un nouveau trajet" ne navigue pas (formulaire invalide)',
      (tester) async {
        await tester.pumpWidget(wrap(initialDate: DateTime(2026, 6, 12)));
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Créer un nouveau trajet'));
        await tester.tap(find.text('Créer un nouveau trajet'));
        await tester.pumpAndSettle();

        // Toujours sur la feuille d'offre, jamais parti vers /trips/create :
        // sans ce garde, le voyageur remplirait tout le wizard trajet avant
        // que le backend ne rejette un prix à 0.
        expect(find.text('Simuler trajet créé'), findsNothing);
        expect(find.text('Faire une offre'), findsOneWidget);
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

        await tester.pumpWidget(wrap(initialDate: DateTime(2026, 6, 12)));
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '25');
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Créer un nouveau trajet'));
        await tester.tap(find.text('Créer un nouveau trajet'));
        await tester.pumpAndSettle();
        expect(find.text('Simuler trajet créé'), findsOneWidget);

        // Le NegotiationBloc est partagé avec /trips/create (même instance) —
        // simule l'émission que produirait le vrai CreateTripScreen une fois
        // le trajet dédié créé, AVANT que sa propre navigation (pop) ne se
        // déclenche.
        controller.add(NegotiationLoaded(_sampleThread()));
        await tester.pump();

        // Le listener de la feuille (montée en dessous) doit rester muet :
        // sans le garde `_creatingDedicatedTripElsewhere`, "Offre envoyée"
        // apparaîtrait ici en plus du feedback propre à CreateTripScreen.
        expect(find.text('Offre envoyée'), findsNothing);

        await tester.tap(find.text('Simuler trajet créé'));
        await tester.pumpAndSettle();

        expect(find.text('Faire une offre'), findsNothing);
      },
    );
  });
}
