import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_sticky_bar.dart';
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
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  weightKg: 5,
  voyageurConfirmed: voyageurConfirmed,
  handoverDeadline: windowEnd,
  paymentMethod: paymentMethod,
  arrivalCity: arrivalCity,
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
    test('REJECTED → true', () {
      expect(TravelerStickyBar.hasAction(_bid(status: 'REJECTED')), isTrue);
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
    test('ACCEPTED fenêtre dépassée non confirmé → false', () {
      expect(
        TravelerStickyBar.hasAction(
          _bid(
            status: 'ACCEPTED',
            windowEnd: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ),
        isFalse,
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

  testWidgets('ACCEPTED non confirmé → Confirmer ma présence', (tester) async {
    await _pump(tester, _bid(status: 'ACCEPTED'));
    expect(find.text('Confirmer ma présence'), findsOneWidget);
  });

  testWidgets('IN_TRANSIT → Valider la remise', (tester) async {
    await _pump(tester, _bid(status: 'IN_TRANSIT'));
    expect(find.text('Valider la remise'), findsOneWidget);
  });

  // Seuls le départ et la remise sont obligatoires : dès le colis récupéré,
  // la remise est l'action principale, le transit une option.
  testWidgets('HANDED_OVER → Valider la remise + transit facultatif', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'HANDED_OVER'));
    expect(find.text('Valider la remise'), findsOneWidget);
    expect(
      find.byKey(const Key('traveler-optional-transit-btn')),
      findsOneWidget,
    );
    expect(find.text('Scanner le transit (facultatif)'), findsOneWidget);
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

  testWidgets('REJECTED → Supprimer cette demande', (tester) async {
    await _pump(tester, _bid(status: 'REJECTED'));
    expect(find.text('Supprimer cette demande'), findsOneWidget);
  });

  testWidgets('COMPLETED → barre vide (SizedBox)', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'));
    expect(find.text('Lire le QR du colis'), findsNothing);
    expect(find.text('Valider la remise'), findsNothing);
    expect(find.text('Accepter'), findsNothing);
    expect(find.text('Supprimer cette demande'), findsNothing);
  });

  testWidgets('ACCEPTED fenêtre expirée non confirmé → barre vide', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        windowEnd: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    expect(find.text('Lire le QR du colis'), findsNothing);
    expect(find.text('Confirmer ma présence'), findsNothing);
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
    test('mobile money → true (ligne d\'information, pas un bouton)', () {
      expect(
        TravelerStickyBar.hasAction(
          _bid(
            status: 'AWAITING_PAYMENT',
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
        ),
        isTrue,
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
    'AWAITING_PAYMENT mobile money → ligne d\'information, aucune action',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'AWAITING_PAYMENT',
          paymentMethod: BidPaymentMethod.mobileMoney,
        ),
      );

      expect(
        find.text("En attente du paiement de l'expéditeur (mobile money)."),
        findsOneWidget,
      );
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
    AnnouncementBloc announcementBloc,
  ) async {
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
                bid: _bid(status: status, arrivalCity: 'Dakar'),
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
            return const Scaffold();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider la remise'));
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
  });

  testWidgets('anglais — HANDED_OVER : transit facultatif traduit', (
    tester,
  ) async {
    useEnglish();
    await _pump(tester, _bid(status: 'HANDED_OVER'));

    expect(find.text('Scan transit (optional)'), findsOneWidget);
  });
}
