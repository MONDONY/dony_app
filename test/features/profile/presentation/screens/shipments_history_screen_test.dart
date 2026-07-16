import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/profile/presentation/screens/shipments_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class FakeBidEvent extends Fake implements BidEvent {}

BidModel _bid({
  required String id,
  required String status,
  String? travelerName,
}) => BidModel(
  id: id,
  announcementId: 'ann-1',
  senderId: 'user-1',
  senderKycVerified: true,
  senderIsProAccount: false,
  senderKiloPro: false,
  weightKg: 2.0,
  status: status,
  voyageurConfirmed: false,
  confirmationCodeRefreshCount: 0,
  createdAt: DateTime(2025, 3, 10),
  updatedAt: DateTime(2025, 3, 12),
  travelerKycVerified: true,
  travelerIsProAccount: false,
  travelerKiloPro: false,
  senderHasRated: false,
  travelerHasRated: false,
  travelerName: travelerName,
);

Widget _wrap(BidBloc bloc) => BlocProvider<BidBloc>.value(
  value: bloc,
  child: MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const ShipmentsHistoryScreen()),
        GoRoute(
          path: '/bids/:id/detail',
          builder: (_, __) => const Scaffold(body: Text('Detail')),
        ),
      ],
    ),
  ),
);

void main() {
  // Épingle le taux de commission : ces tests assertent des montants
  // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
  setUpAll(() => setDonyCommissionRate(0.12));
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  late MockBidBloc bloc;

  setUpAll(() => registerFallbackValue(FakeBidEvent()));

  setUp(() {
    bloc = MockBidBloc();
    when(() => bloc.state).thenReturn(BidInitial());
  });

  testWidgets('shows loading shimmer when BidLoading', (tester) async {
    when(() => bloc.state).thenReturn(BidLoading());
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(ShipmentsHistoryScreen), findsOneWidget);
    expect(find.text('Historique des livraisons'), findsOneWidget);
  });

  testWidgets('shows empty state when no delivered bids', (tester) async {
    when(() => bloc.state).thenReturn(
      BidListLoaded([
        _bid(id: 'b1', status: 'PENDING'),
        _bid(id: 'b2', status: 'ACCEPTED'),
      ]),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('Aucune livraison'), findsOneWidget);
  });

  testWidgets('shows completed bids list', (tester) async {
    when(() => bloc.state).thenReturn(BidListLoaded([
      _bid(id: 'b1', status: 'COMPLETED', travelerName: 'Mamadou Diallo'),
      _bid(id: 'b2', status: 'PENDING'),
    ]));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Mamadou Diallo'), findsOneWidget);
    expect(find.text('Voir détails'), findsOneWidget);
  });

  testWidgets('shows fully populated completed bid card', (tester) async {
    final fullBid = BidModel(
      id: 'b-full',
      announcementId: 'ann-1',
      senderId: 'user-1',
      senderKycVerified: true,
      senderIsProAccount: false,
      senderKiloPro: false,
      weightKg: 3.5,
      declaredValueEur: 200,
      description: 'Médicaments',
      status: 'COMPLETED',
      voyageurConfirmed: true,
      confirmationCodeRefreshCount: 0,
      createdAt: DateTime(2025, 3, 1),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      travelerName: 'Fatoumata Bah',
      travelerId: 'traveler-1',
      travelerAverageRating: 4.8,
      travelerKycVerified: true,
      travelerIsProAccount: false,
      travelerKiloPro: false,
      senderHasRated: true,
      travelerHasRated: false,
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      pricePerKg: 15.0,
    );

    when(() => bloc.state).thenReturn(BidListLoaded([fullBid]));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Fatoumata Bah'), findsOneWidget);
    expect(find.text('Paris → Dakar'), findsOneWidget);
    expect(
      find.textContaining('59'),
      findsOneWidget,
    ); // brut = 52,5 net × 1,12 = 58,8 → « 59 € » (jamais le net)
    expect(find.textContaining('Médicaments'), findsOneWidget);
  });

  testWidgets('today date shows Aujourd\'hui', (tester) async {
    final todayBid = BidModel(
      id: 'today',
      announcementId: 'ann-1',
      senderId: 'user-1',
      senderKycVerified: true,
      senderIsProAccount: false,
      senderKiloPro: false,
      weightKg: 1.0,
      status: 'COMPLETED',
      voyageurConfirmed: true,
      confirmationCodeRefreshCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      travelerName: 'Alpha Diallo',
      travelerKycVerified: true,
      travelerIsProAccount: false,
      travelerKiloPro: false,
      senderHasRated: false,
      travelerHasRated: false,
    );

    when(() => bloc.state).thenReturn(BidListLoaded([todayBid]));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text("Aujourd'hui"), findsOneWidget);
  });

  testWidgets(
      'régression : un bid DELIVERED (legacy) est exclu, un bid COMPLETED s\'affiche',
      (tester) async {
    // Le backend n'émet jamais DELIVERED — le statut terminal d'une livraison
    // réussie est COMPLETED. Un éventuel bid legacy DELIVERED ne doit pas
    // apparaître dans l'historique.
    when(() => bloc.state).thenReturn(BidListLoaded([
      _bid(id: 'legacy', status: 'DELIVERED', travelerName: 'Legacy Voyageur'),
      _bid(id: 'done', status: 'COMPLETED', travelerName: 'Awa Ndiaye'),
    ]));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Awa Ndiaye'), findsOneWidget);
    expect(find.text('Legacy Voyageur'), findsNothing);
  });

  testWidgets('shows error state when BidError', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(BidError(const ServerException('Erreur serveur')));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('Erreur de chargement'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('retry button dispatches BidMyListRequested', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(BidError(const ServerException('Erreur serveur')));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(any(that: isA<BidMyListRequested>()))).called(1);
  });
}
