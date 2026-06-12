import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
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

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockAcceptBloc extends MockBloc<BidAcceptanceEvent, BidAcceptanceState>
    implements BidAcceptanceBloc {}

BidModel _bid({
  required String status,
  bool voyageurConfirmed = false,
  DateTime? windowStart,
  DateTime? windowEnd,
}) =>
    BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: status,
      weightKg: 5,
      voyageurConfirmed: voyageurConfirmed,
      handoverWindowStart: windowStart,
      handoverWindowEnd: windowEnd,
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
    MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    ),
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
            _bid(status: 'ACCEPTED', voyageurConfirmed: true)),
        isTrue,
      );
    });
    test('ACCEPTED non confirmé sans fenêtre → true (confirmPresence)', () {
      expect(
        TravelerStickyBar.hasAction(_bid(status: 'ACCEPTED')),
        isTrue,
      );
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
    expect(find.text('Scanner le colis'), findsOneWidget);
  });

  testWidgets('ACCEPTED non confirmé → Confirmer ma présence', (tester) async {
    await _pump(tester, _bid(status: 'ACCEPTED'));
    expect(find.text('Confirmer ma présence'), findsOneWidget);
  });

  testWidgets('IN_TRANSIT → Valider la remise', (tester) async {
    await _pump(tester, _bid(status: 'IN_TRANSIT'));
    expect(find.text('Valider la remise'), findsOneWidget);
  });

  testWidgets('HANDED_OVER → Valider la remise', (tester) async {
    await _pump(tester, _bid(status: 'HANDED_OVER'));
    expect(find.text('Valider la remise'), findsOneWidget);
  });

  testWidgets('REJECTED → Supprimer cette demande', (tester) async {
    await _pump(tester, _bid(status: 'REJECTED'));
    expect(find.text('Supprimer cette demande'), findsOneWidget);
  });

  testWidgets('COMPLETED → barre vide (SizedBox)', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'));
    expect(find.text('Scanner le colis'), findsNothing);
    expect(find.text('Valider la remise'), findsNothing);
    expect(find.text('Accepter'), findsNothing);
    expect(find.text('Supprimer cette demande'), findsNothing);
  });

  testWidgets('ACCEPTED fenêtre expirée non confirmé → barre vide',
      (tester) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        windowEnd: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    expect(find.text('Scanner le colis'), findsNothing);
    expect(find.text('Confirmer ma présence'), findsNothing);
  });

  testWidgets('CANCELLED → barre vide (SizedBox)', (tester) async {
    await _pump(tester, _bid(status: 'CANCELLED'));
    expect(find.text('Accepter'), findsNothing);
    expect(find.text('Annuler'), findsNothing);
    expect(find.text('Scanner le colis'), findsNothing);
    expect(find.text('Valider la remise'), findsNothing);
    expect(find.text('Supprimer cette demande'), findsNothing);
  });

  testWidgets('ACCEPTED non confirmé avec fenêtre future → ConfirmPresenceBar',
      (tester) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        windowEnd: DateTime.now().add(const Duration(hours: 2)),
      ),
    );
    expect(find.text('Confirmer ma présence'), findsOneWidget);
  });

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
            _bid(status: 'ACCEPTED', voyageurConfirmed: true)),
        isTrue,
      );
    });
  });

  testWidgets('tap Scanner le colis → GoRouter push déclenché', (tester) async {
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
          path: '/tracking/scan',
          builder: (context, state) {
            pushedRoutes.add('/tracking/scan');
            return const Scaffold();
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scanner le colis'));
    await tester.pumpAndSettle();
    expect(pushedRoutes, contains('/tracking/scan'));
  });

  testWidgets('tap Valider la remise → GoRouter push déclenché', (tester) async {
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
                bid: _bid(status: 'IN_TRANSIT'),
                isLoading: false,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/tracking/confirm',
          builder: (context, state) {
            pushedRoutes.add('/tracking/confirm');
            return const Scaffold();
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Valider la remise'));
    await tester.pumpAndSettle();
    expect(pushedRoutes, contains('/tracking/confirm'));
  });
}
