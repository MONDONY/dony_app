import 'dart:async';

import 'package:dony/core/services/trip_bids_events_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

// Accepter, refuser ou annuler un colis prévient l'écran du trajet resté
// dessous dans la pile : il relit le trajet et ses colis (compteurs et menu).

class _MockBidRepo extends Mock implements BidRepository {}

class _MockCancellationRepo extends Mock implements CancellationRepository {}

class _MockStripe extends Mock implements Stripe {}

BidModel _bid() => BidModel(
  id: 'bid1',
  announcementId: 'ann1',
  senderId: 's1',
  weightKg: 3,
  pricePerKg: 8,
  status: 'ACCEPTED',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late TripBidsEventsService events;
  late List<String?> received;
  late StreamSubscription<String?> sub;
  late _MockBidRepo repo;

  setUp(() {
    events = TripBidsEventsService();
    received = [];
    sub = events.changes.listen(received.add);
    repo = _MockBidRepo();
  });

  tearDown(() async {
    await sub.cancel();
    await events.dispose();
  });

  BidBloc bidBloc() {
    final a = makeEnabledAnalytics(MockAnalyticsBackend());
    a.onConfigured();
    return BidBloc(repo, a, tripBidsEvents: events);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('BidBloc : demande acceptée (carte, cash) prévient le trajet', () async {
    when(() => repo.acceptBid('bid1')).thenAnswer((_) async => _bid());
    final bloc = bidBloc()..add(BidAcceptRequested('bid1'));
    await bloc.stream.firstWhere((s) => s is BidAccepted);
    await settle();
    expect(received, ['ann1']);
    await bloc.close();
  });

  test(
    'BidBloc : demande acceptée en mobile money prévient le trajet',
    () async {
      when(
        () => repo.acceptMobileMoneyBid('bid1'),
      ).thenAnswer((_) async => _bid());
      final bloc = bidBloc()..add(BidAcceptMobileMoneyRequested('bid1'));
      await bloc.stream.firstWhere((s) => s is BidAccepted);
      await settle();
      expect(received, ['ann1']);
      await bloc.close();
    },
  );

  test('BidBloc : demande refusée prévient le trajet', () async {
    when(
      () => repo.rejectBid('bid1', reason: any(named: 'reason')),
    ).thenAnswer((_) async => _bid());
    final bloc = bidBloc()..add(BidRejectRequested('bid1'));
    await bloc.stream.firstWhere((s) => s is BidRejected);
    await settle();
    expect(received, ['ann1']);
    await bloc.close();
  });

  test('BidBloc : colis annulé prévient le trajet', () async {
    when(
      () => repo.cancelBid('bid1', reason: any(named: 'reason')),
    ).thenAnswer((_) async => _bid());
    final bloc = bidBloc()..add(BidCancelRequested('bid1', actor: 'traveler'));
    await bloc.stream.firstWhere((s) => s is BidCancelled);
    await settle();
    expect(received, ['ann1']);
    await bloc.close();
  });

  test('BidBloc : annulation avant paiement prévient le trajet', () async {
    when(() => repo.cancelBeforePayment('bid1')).thenAnswer((_) async => false);
    final bloc = bidBloc()
      ..add(BidCancelBeforePaymentRequested('bid1', paymentMethod: 'stripe'));
    await bloc.stream.firstWhere((s) => s is BidCancelledBeforePayment);
    await settle();
    expect(received, [null]);
    await bloc.close();
  });

  test('BidBloc : échec d’acceptation, aucun signal', () async {
    when(() => repo.acceptBid('bid1')).thenThrow(Exception('réseau'));
    final bloc = bidBloc()..add(BidAcceptRequested('bid1'));
    await bloc.stream.firstWhere((s) => s is BidError);
    await settle();
    expect(received, isEmpty);
    await bloc.close();
  });

  test('BidBloc sans service : pas de plantage', () async {
    when(() => repo.acceptBid('bid1')).thenAnswer((_) async => _bid());
    final a = makeEnabledAnalytics(MockAnalyticsBackend());
    await a.onConfigured();
    final bloc = BidBloc(repo, a)..add(BidAcceptRequested('bid1'));
    await bloc.stream.firstWhere((s) => s is BidAccepted);
    await bloc.close();
  });

  test('BidAcceptanceBloc : acceptation avec commission prévient', () async {
    when(() => repo.acceptBidWithCommission('bid1')).thenAnswer(
      (_) async => const AcceptanceResponse(status: AcceptanceStatus.accepted),
    );
    final bloc = BidAcceptanceBloc(repo, _MockStripe(), null, events)
      ..add(ace.BidAcceptRequested('bid1'));
    await bloc.stream.firstWhere((s) => s is acs.BidAccepted);
    await settle();
    expect(received, [null]);
    await bloc.close();
  });

  test('BidAcceptanceBloc : acceptation refusée, aucun signal', () async {
    when(() => repo.acceptBidWithCommission('bid1')).thenAnswer(
      (_) async =>
          const AcceptanceResponse(status: AcceptanceStatus.failed, error: 'x'),
    );
    final bloc = BidAcceptanceBloc(repo, _MockStripe(), null, events)
      ..add(ace.BidAcceptRequested('bid1'));
    await bloc.stream.firstWhere((s) => s is acs.BidFailed);
    await settle();
    expect(received, isEmpty);
    await bloc.close();
  });

  group('CancellationBloc', () {
    late _MockCancellationRepo cancelRepo;

    CancellationBloc cancelBloc() {
      final a = makeEnabledAnalytics(MockAnalyticsBackend());
      a.onConfigured();
      return CancellationBloc(cancelRepo, a, tripBidsEvents: events);
    }

    setUp(() => cancelRepo = _MockCancellationRepo());

    test('trajet annulé : prévient le trajet', () async {
      when(
        () => cancelRepo.cancelTrip(
          announcementId: any(named: 'announcementId'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer(
        (_) async => CancellationModel(
          announcementId: 'ann1',
          affectedBidsCount: 1,
          reason: 'x',
          rematchSuggestions: const [],
          cancelledAt: DateTime(2026),
        ),
      );
      final bloc = cancelBloc()
        ..add(CancellationTripRequested(announcementId: 'ann1', reason: 'x'));
      await bloc.stream.firstWhere((s) => s is CancellationSuccess);
      await settle();
      expect(received, ['ann1']);
      await bloc.close();
    });

    test('colis annulé après remise : prévient le trajet', () async {
      when(
        () => cancelRepo.cancelAfterHandover('bid1'),
      ).thenAnswer((_) async {});
      final bloc = cancelBloc()
        ..add(CancelAfterHandoverRequested('bid1', actor: 'traveler'));
      await bloc.stream.firstWhere((s) => s is CancelledAfterHandover);
      await settle();
      expect(received, [null]);
      await bloc.close();
    });

    test('annulation en échec : aucun signal', () async {
      when(
        () => cancelRepo.cancelAfterHandover('bid1'),
      ).thenThrow(Exception('réseau'));
      final bloc = cancelBloc()
        ..add(CancelAfterHandoverRequested('bid1', actor: 'traveler'));
      await bloc.stream.firstWhere((s) => s is CancellationError);
      await settle();
      expect(received, isEmpty);
      await bloc.close();
    });
  });
}
