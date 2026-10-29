import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_sticky_bar.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockAcceptBloc extends MockBloc<BidAcceptanceEvent, BidAcceptanceState>
    implements BidAcceptanceBloc {}

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

BidModel _bid({
  required String status,
  bool voyageurConfirmed = false,
  DateTime? windowEnd,
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  String? arrivalCity,
  DateTime? departureAt,
  BidSupplement? supplement,
  List<BidAmendment> amendments = const [],
  String? cancellationNoShowStatus,
}) => BidModel(
  id: 'b1',
  cancellationNoShowStatus: cancellationNoShowStatus,
  supplement: supplement,
  amendments: amendments,
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  weightKg: 5,
  voyageurConfirmed: voyageurConfirmed,
  handoverDeadline: windowEnd,
  paymentMethod: paymentMethod,
  arrivalCity: arrivalCity,
  departureAt: departureAt,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

Future<void> _pump(WidgetTester tester, BidModel bid) async {
  final bidBloc = _MockBidBloc();
  final acceptBloc = _MockAcceptBloc();
  when(() => bidBloc.state).thenReturn(BidInitial());
  when(() => acceptBloc.state).thenReturn(BidAcceptanceInitial());

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          bottomNavigationBar: MultiBlocProvider(
            providers: [
              BlocProvider<BidBloc>.value(value: bidBloc),
              BlocProvider<BidAcceptanceBloc>.value(value: acceptBloc),
            ],
            child: TravelerStickyBar(bid: bid, isLoading: false),
          ),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TravelerStickyBar.hasAction', () {
    test('PENDING → true', () {
      expect(TravelerStickyBar.hasAction(_bid(status: 'PENDING')), isTrue);
    });
    // « Supprimer cette demande » a quitté le footer pour le menu ⋮.
    test('REJECTED → false (plus de footer)', () {
      expect(TravelerStickyBar.hasAction(_bid(status: 'REJECTED')), isFalse);
    });
    test('HANDED_OVER → true', () {
      expect(TravelerStickyBar.hasAction(_bid(status: 'HANDED_OVER')), isTrue);
    });
    test('IN_TRANSIT → true', () {
      expect(TravelerStickyBar.hasAction(_bid(status: 'IN_TRANSIT')), isTrue);
    });
    test('ACCEPTED confirmé → true (scan)', () {
      expect(
        TravelerStickyBar.hasAction(
          _bid(status: 'ACCEPTED', voyageurConfirmed: true),
        ),
        isTrue,
      );
    });
    test('ACCEPTED non confirmé sans fenêtre → true (confirmPresence)', () {
      expect(TravelerStickyBar.hasAction(_bid(status: 'ACCEPTED')), isTrue);
    });
    // Le back n'expire jamais un colis ACCEPTED et n'exige pas la présence
    // confirmée pour le départ : passé la date limite, le scan reste ouvert.
    test('ACCEPTED fenêtre dépassée non confirmé → true (scan)', () {
      expect(
        TravelerStickyBar.hasAction(
          _bid(
            status: 'ACCEPTED',
            windowEnd: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ),
        isTrue,
      );
    });
    test('COMPLETED → false', () {
      expect(TravelerStickyBar.hasAction(_bid(status: 'COMPLETED')), isFalse);
    });
    test('CANCELLED → false', () {
      expect(TravelerStickyBar.hasAction(_bid(status: 'CANCELLED')), isFalse);
    });
  });

  testWidgets('PENDING → Accepter / Refuser', (tester) async {
    await _pump(tester, _bid(status: 'PENDING'));
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
  });

  testWidgets('ACCEPTED confirmé → Scanner le colis', (tester) async {
    await _pump(tester, _bid(status: 'ACCEPTED', voyageurConfirmed: true));
    expect(find.text('Lire le QR du colis'), findsOneWidget);
  });

  testWidgets('supplément en attente → scan désactivé, libellé court', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        voyageurConfirmed: true,
        supplement: const BidSupplement(
          id: 'sup-1',
          status: BidSupplementStatus.proposed,
          grossAmount: 16.8,
          blocksHandover: true,
        ),
      ),
    );
    final button = tester.widget<DonyButton>(
      find.byKey(const Key('traveler-scan-btn')),
    );
    expect(button.onPressed, isNull);
    expect(button.label, 'Scan en attente');
    // La phrase complète vit dans une carte du corps, plus dans le footer.
    expect(find.textContaining('le scan est bloqué'), findsNothing);
  });

  testWidgets('scanDisabled_whenAmendmentBlocksHandover', (tester) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        voyageurConfirmed: true,
        amendments: const [
          BidAmendment(
            id: 'am-1',
            status: BidAmendmentStatus.proposed,
            rail: 'CASH',
            grossAmount: 26.8,
            blocksHandover: true,
          ),
        ],
      ),
    );
    final button = tester.widget<DonyButton>(
      find.byKey(const Key('traveler-scan-btn')),
    );
    expect(button.onPressed, isNull);
    expect(button.label, 'Scan en attente');
    expect(find.textContaining('le scan est bloqué'), findsNothing);
  });

  testWidgets('modification acceptée → scan possible', (tester) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        voyageurConfirmed: true,
        amendments: const [
          BidAmendment(
            id: 'am-1',
            status: BidAmendmentStatus.accepted,
            rail: 'CASH',
            grossAmount: 26.8,
          ),
        ],
      ),
    );
    final button = tester.widget<DonyButton>(
      find.byKey(const Key('traveler-scan-btn')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('supplément refusé → scan de nouveau possible', (tester) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        voyageurConfirmed: true,
        supplement: const BidSupplement(
          id: 'sup-1',
          status: BidSupplementStatus.declined,
          grossAmount: 16.8,
        ),
      ),
    );
    final button = tester.widget<DonyButton>(
      find.byKey(const Key('traveler-scan-btn')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('ACCEPTED non confirmé → Confirmer ma présence', (tester) async {
    await _pump(tester, _bid(status: 'ACCEPTED'));
    expect(find.text('Confirmer ma présence'), findsOneWidget);
  });

  testWidgets('IN_TRANSIT → Valider la remise', (tester) async {
    await _pump(tester, _bid(status: 'IN_TRANSIT'));
    expect(find.text('Valider la remise'), findsOneWidget);
  });

  // Seuls le départ et la remise sont obligatoires : dès le colis récupéré,
  // la remise est l'action principale. Le scan du transit (facultatif) a
  // quitté le footer pour le menu ⋮.
  testWidgets('HANDED_OVER → Valider la remise seule, sans transit', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'HANDED_OVER'));
    expect(find.text('Valider la remise'), findsOneWidget);
    expect(find.byType(DonyButton), findsOneWidget);
    expect(
      find.byKey(const Key('traveler-optional-transit-btn')),
      findsNothing,
    );
    expect(find.textContaining('Scanner le transit'), findsNothing);
  });

  testWidgets('IN_TRANSIT → Valider la remise, plus de transit proposé', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'IN_TRANSIT'));
    expect(find.text('Valider la remise'), findsOneWidget);
    expect(
      find.byKey(const Key('traveler-optional-transit-btn')),
      findsNothing,
    );
  });

  testWidgets('REJECTED → barre vide, Supprimer est dans le menu ⋮', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'REJECTED'));
    expect(find.text('Supprimer cette demande'), findsNothing);
    expect(find.byType(DonyButton), findsNothing);
  });

  testWidgets('COMPLETED → barre vide (SizedBox)', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'));
    expect(find.text('Lire le QR du colis'), findsNothing);
    expect(find.text('Valider la remise'), findsNothing);
    expect(find.text('Accepter'), findsNothing);
    expect(find.text('Supprimer cette demande'), findsNothing);
  });

  // ACCEPTED : confirmé ou non × avant ou après la date limite × absence de
  // l'expéditeur signalée ou contestée. Passé la date limite (ou une absence
  // signalée), la présence n'est plus à confirmer mais le colis peut encore
  // être remis : « Lire le QR du colis », le héros d'alerte reste dans
  // « À traiter ».
  group('ACCEPTED : présence, date limite, absence signalée', () {
    final past = DateTime.now().subtract(const Duration(hours: 1));
    final future = DateTime.now().add(const Duration(hours: 2));
    // (confirmé / non confirmé) × (avant / après la date limite) ×
    // (déclaration d'absence de l'expéditeur ouverte / aucune).
    // Déclaration ouverte, présence non confirmée : jamais de scan. Le back ne
    // regarde pas la déclaration au scan de départ et ne la clôt pas : sans
    // réponse sous 24 h, l'absence serait confirmée, le séquestre remboursé et
    // l'expéditeur pénalisé alors que le colis voyage.
    // Déclaration ouverte, présence confirmée : scan proposé, comme avant la
    // branche (risque connu, à traiter côté back).
    final cases = <String, (BidModel, String)>{
      'non confirmé, sans date limite': (_bid(status: 'ACCEPTED'), 'presence'),
      for (final confirmed in [false, true])
        for (final (moment, deadline) in [('avant', future), ('après', past)])
          for (final ns in [null, 'PENDING_CONFIRMATION', 'CONTESTED'])
            '${confirmed ? 'confirmé' : 'non confirmé'}, $moment la date '
                'limite, ${ns == null ? 'aucune déclaration' : 'absence $ns'}': (
              _bid(
                status: 'ACCEPTED',
                voyageurConfirmed: confirmed,
                windowEnd: deadline,
                cancellationNoShowStatus: ns,
              ),
              switch ((confirmed, deadline == past, ns != null)) {
                (true, _, _) => 'scan',
                (false, false, _) => 'presence',
                (false, true, false) => 'scan',
                (false, true, true) => 'none',
              },
            ),
    };
    for (final MapEntry(key: name, value: (bid, expected)) in cases.entries) {
      testWidgets('$name → $expected', (tester) async {
        expect(TravelerStickyBar.hasAction(bid), expected != 'none');
        await _pump(tester, bid);
        switch (expected) {
          case 'scan':
            expect(find.text('Lire le QR du colis'), findsOneWidget);
            expect(find.text('Confirmer ma présence'), findsNothing);
            final button = tester.widget<DonyButton>(
              find.byKey(const Key('traveler-scan-btn')),
            );
            expect(button.onPressed, isNotNull);
          case 'presence':
            expect(find.text('Confirmer ma présence'), findsOneWidget);
            expect(find.text('Lire le QR du colis'), findsNothing);
          default:
            expect(find.text('Lire le QR du colis'), findsNothing);
            expect(find.text('Confirmer ma présence'), findsNothing);
        }
      });
    }

    testWidgets('en anglais : date limite dépassée → « Scan the parcel QR »', (
      tester,
    ) async {
      useEnglish();
      await _pump(tester, _bid(status: 'ACCEPTED', windowEnd: past));
      expect(find.text('Scan the parcel QR'), findsOneWidget);
      expect(find.text('Confirm my presence'), findsNothing);
    });

    testWidgets('en anglais : avant la date limite → « Confirm my presence »', (
      tester,
    ) async {
      useEnglish();
      await _pump(tester, _bid(status: 'ACCEPTED', windowEnd: future));
      expect(find.text('Confirm my presence'), findsOneWidget);
    });

    testWidgets('date limite dépassée, supplément bloquant → scan éteint', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          status: 'ACCEPTED',
          windowEnd: past,
          supplement: const BidSupplement(
            id: 'sup-1',
            status: BidSupplementStatus.proposed,
            grossAmount: 17,
            blocksHandover: true,
          ),
        ),
      );
      final button = tester.widget<DonyButton>(
        find.byKey(const Key('traveler-scan-btn')),
      );
      expect(button.onPressed, isNull);
    });
  });

  testWidgets('CANCELLED → barre vide (SizedBox)', (tester) async {
    await _pump(tester, _bid(status: 'CANCELLED'));
    expect(find.text('Accepter'), findsNothing);
    expect(find.text('Annuler'), findsNothing);
    expect(find.text('Lire le QR du colis'), findsNothing);
    expect(find.text('Valider la remise'), findsNothing);
    expect(find.text('Supprimer cette demande'), findsNothing);
  });

  testWidgets(
    'ACCEPTED non confirmé avec fenêtre future → ConfirmPresenceBar',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'ACCEPTED',
          windowEnd: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      expect(find.text('Confirmer ma présence'), findsOneWidget);
    },
  );

  group('TravelerStickyBar.hasAction — cas supplémentaires', () {
    // Régression : un colis payé par carte (séquestré) expose aussi la barre
    // Accepter / Refuser, comme la carte de la liste (repris de l'ancien
    // fichier presentation/traveler_sticky_bar_test.dart).
    test('PAYMENT_ESCROWED → true (carte séquestrée, décision)', () {
      expect(
        TravelerStickyBar.hasAction(_bid(status: 'PAYMENT_ESCROWED')),
        isTrue,
      );
    });
    test('ARRIVED → true (remise)', () {
      expect(TravelerStickyBar.hasAction(_bid(status: 'ARRIVED')), isTrue);
    });
    for (final status in ['NO_SHOW', 'PARCEL_REFUSED']) {
      test('$status → false', () {
        expect(TravelerStickyBar.hasAction(_bid(status: status)), isFalse);
      });
    }
    test('DELIVERED → false', () {
      expect(TravelerStickyBar.hasAction(_bid(status: 'DELIVERED')), isFalse);
    });
    test('EXPIRED → false', () {
      expect(TravelerStickyBar.hasAction(_bid(status: 'EXPIRED')), isFalse);
    });
    test('ACCEPTED confirmé → true (scan)', () {
      expect(
        TravelerStickyBar.hasAction(
          _bid(status: 'ACCEPTED', voyageurConfirmed: true),
        ),
        isTrue,
      );
    });
  });

  // Régression staging : un bid accepté en mobile money passe en
  // AWAITING_PAYMENT (30 min pour le séquestre côté expéditeur) — la barre
  // ne portait aucun cas dédié et restait vide (SizedBox.shrink), sans
  // expliquer au voyageur pourquoi rien ne se passe. Scopé au mobile money
  // uniquement (seul rail concerné par cette attente de 30 min côté
  // voyageur) : hors périmètre pour les autres moyens de paiement.
  group('TravelerStickyBar.hasAction — AWAITING_PAYMENT', () {
    test('mobile money → false (phrase déplacée dans le corps)', () {
      expect(
        TravelerStickyBar.hasAction(
          _bid(
            status: 'AWAITING_PAYMENT',
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
        ),
        isFalse,
      );
    });

    test('stripe (défaut) → false, hors périmètre de ce fix', () {
      expect(
        TravelerStickyBar.hasAction(_bid(status: 'AWAITING_PAYMENT')),
        isFalse,
      );
    });
  });

  testWidgets(
    'AWAITING_PAYMENT mobile money → plus de footer (carte dans le corps)',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'AWAITING_PAYMENT',
          paymentMethod: BidPaymentMethod.mobileMoney,
        ),
      );

      expect(find.textContaining('En attente du paiement'), findsNothing);
      expect(find.byType(DonyButton), findsNothing);
      expect(find.text('Lire le QR du colis'), findsNothing);
      expect(find.text('Lire le QR de transit'), findsNothing);
      expect(find.text('Valider la remise'), findsNothing);
      expect(find.text('Accepter'), findsNothing);
      expect(find.text('Refuser'), findsNothing);
    },
  );

  testWidgets('tap Scanner le colis → Suivi poussé sur le trajet du colis', (
    tester,
  ) async {
    final bidBloc = _MockBidBloc();
    final acceptBloc = _MockAcceptBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => acceptBloc.state).thenReturn(BidAcceptanceInitial());

    final List<String> pushedRoutes = [];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            bottomNavigationBar: MultiBlocProvider(
              providers: [
                BlocProvider<BidBloc>.value(value: bidBloc),
                BlocProvider<BidAcceptanceBloc>.value(value: acceptBloc),
              ],
              child: TravelerStickyBar(
                bid: _bid(status: 'ACCEPTED', voyageurConfirmed: true),
                isLoading: false,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/tracking/validate',
          builder: (context, state) {
            pushedRoutes.add(state.uri.toString());
            return const Scaffold();
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    // Mode Valider du Suivi, sur le trajet du colis (FLUTTER-9N).
    await tester.tap(find.text('Lire le QR du colis'));
    await tester.pumpAndSettle();
    expect(pushedRoutes, [
      '/tracking/validate?trip=${_bid(status: 'ACCEPTED', voyageurConfirmed: true).announcementId}',
    ]);
  });

  /// Barre voyageur sous un vrai GoRouter, avec un AnnouncementBloc mocké :
  /// renvoie les routes poussées.
  Future<List<String>> pumpDeliver(
    WidgetTester tester,
    String status,
    AnnouncementBloc announcementBloc, {
    DateTime? departureAt,
    List<Object?>? windows,
  }) async {
    final bidBloc = _MockBidBloc();
    final acceptBloc = _MockAcceptBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => acceptBloc.state).thenReturn(BidAcceptanceInitial());
    final pushedRoutes = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            bottomNavigationBar: MultiBlocProvider(
              providers: [
                BlocProvider<BidBloc>.value(value: bidBloc),
                BlocProvider<BidAcceptanceBloc>.value(value: acceptBloc),
                BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
              ],
              child: TravelerStickyBar(
                bid: _bid(
                  status: status,
                  arrivalCity: 'Dakar',
                  departureAt: departureAt,
                ),
                isLoading: false,
              ),
            ),
          ),
        ),
        // Sentry FLUTTER-CX : remise directe par photo puis code, le colis
        // étant déjà ouvert (plus d'identification à refaire).
        GoRoute(
          path: '/tracking/scan/photo',
          builder: (context, state) {
            final extra = state.extra! as Map<String, dynamic>;
            pushedRoutes.add(
              '/tracking/scan/photo:${extra['bidId']}:${extra['etape']}',
            );
            windows?.add(extra['deliveryWindow']);
            return const Scaffold();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('traveler-deliver-btn')));
    await tester.pumpAndSettle();
    return pushedRoutes;
  }

  group('Valider la remise', () {
    late _MockAnnouncementBloc announcementBloc;

    setUpAll(() {
      registerFallbackValue(
        AnnouncementTripMarkArrivedRequested(announcementId: 'x'),
      );
    });

    setUp(() {
      announcementBloc = _MockAnnouncementBloc();
      when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    });

    testWidgets('arrivée déjà déclarée (ARRIVED) : remise directe', (
      tester,
    ) async {
      final pushed = await pumpDeliver(tester, 'ARRIVED', announcementBloc);

      expect(find.text('Vous êtes arrivé à Dakar ?'), findsNothing);
      expect(pushed, contains('/tracking/scan/photo:b1:ARRIVEE'));
      verifyNever(() => announcementBloc.add(any()));
    });

    // Sentry FLUTTER-5S : sans déclaration, l'expéditeur n'était pas prévenu.
    testWidgets('en route : « Oui, je suis arrivé » déclare puis remet', (
      tester,
    ) async {
      final pushed = await pumpDeliver(tester, 'IN_TRANSIT', announcementBloc);
      expect(pushed, isEmpty);
      expect(find.text('Vous êtes arrivé à Dakar ?'), findsOneWidget);

      await tester.tap(find.text('Oui, je suis arrivé'));
      await tester.pumpAndSettle();

      final added = verify(
        () => announcementBloc.add(captureAny()),
      ).captured.single;
      expect(added, isA<AnnouncementTripMarkArrivedRequested>());
      expect(
        (added as AnnouncementTripMarkArrivedRequested).announcementId,
        'a1',
      );
      expect(pushed, contains('/tracking/scan/photo:b1:ARRIVEE'));
    });

    testWidgets('en route : « Pas encore » remet sans rien déclarer', (
      tester,
    ) async {
      final pushed = await pumpDeliver(tester, 'HANDED_OVER', announcementBloc);

      await tester.tap(find.text('Pas encore, remettre le colis'));
      await tester.pumpAndSettle();

      verifyNever(() => announcementBloc.add(any()));
      expect(pushed, contains('/tracking/scan/photo:b1:ARRIVEE'));
    });

    // FLUTTER-CB : le back refuse la remise avant le départ (422
    // trip-not-departed). Le bouton reste éteint, libellé court ; la phrase
    // d'explication est dans une carte du corps.
    testWidgets('trajet pas encore parti : bouton désactivé, libellé court', (
      tester,
    ) async {
      final pushed = await pumpDeliver(
        tester,
        'ARRIVED',
        announcementBloc,
        departureAt: DateTime.now().add(const Duration(days: 1)),
      );

      final button = tester.widget<DonyButton>(
        find.byKey(const Key('traveler-deliver-btn')),
      );
      expect(button.onPressed, isNull);
      expect(button.label, 'Disponible au départ');
      expect(find.textContaining('Disponible après le départ'), findsNothing);
      expect(pushed, isEmpty);
    });

    testWidgets('trajet parti : remise ouverte, départ transmis au flux', (
      tester,
    ) async {
      final windows = <Object?>[];
      final departure = DateTime.now().subtract(const Duration(hours: 2));
      final pushed = await pumpDeliver(
        tester,
        'ARRIVED',
        announcementBloc,
        departureAt: departure,
        windows: windows,
      );

      expect(find.text('Disponible au départ'), findsNothing);
      expect(pushed, contains('/tracking/scan/photo:b1:ARRIVEE'));
      expect(
        windows.single,
        isA<DeliveryWindow>().having((w) => w.opensAt, 'opensAt', departure),
      );
    });

    testWidgets('départ inconnu : remise ouverte (le serveur tranche)', (
      tester,
    ) async {
      final windows = <Object?>[];
      final pushed = await pumpDeliver(
        tester,
        'ARRIVED',
        announcementBloc,
        windows: windows,
      );

      expect(pushed, contains('/tracking/scan/photo:b1:ARRIVEE'));
      expect(windows.single, isNull);
    });
  });
}
