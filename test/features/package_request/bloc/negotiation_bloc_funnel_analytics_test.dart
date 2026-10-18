// Mocktail exige le jeu exact d'arguments nommés de l'appel réel
// (`submitTrip(..., useCardForCommission: ...)` les passe tous) : les stubs
// répètent donc la valeur par défaut.
// ignore_for_file: avoid_redundant_argument_values
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements NegotiationRepository {}

NegotiationThread _thread({int rounds = 2, String currency = 'XOF'}) =>
    NegotiationThread(
      id: 't-1',
      packageRequestId: 'pr-1',
      travelerId: 'tr-1',
      travelerTravelDate: DateTime(2026, 6, 15),
      travelerAvailableKg: 10,
      status: NegotiationThreadStatus.open,
      currentPriceEur: 30,
      roundsCount: rounds,
      lastActivityAt: DateTime(2026, 5, 10),
      createdAt: DateTime(2026, 5, 10),
      messages: const [],
      currency: currency,
    );

/// Tunnel de négociation colis : chaque événement porte l'identité du fil
/// (`thread_id`, `request_id`, `round`, `currency`) pour relier offre,
/// acceptation, trajet et paiement, et les étapes autrefois muettes (refus,
/// trajet lié ou refusé, dépôt annulé, échecs) sont tracées.
void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;

  setUpAll(() => registerFallbackValue(PaymentMethod.stripe));

  setUp(() {
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
  });

  Future<NegotiationBloc> makeBloc() async {
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    return NegotiationBloc(repo, analytics: analytics);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Map<String, Object> captured(String event) =>
      verify(() => backend.capture(event, captureAny())).captured.single
          as Map<String, Object>;

  test(
    'offre de départ : identité du fil, devise du fil, context start',
    () async {
      when(
        () => repo.start(
          packageRequestId: any(named: 'packageRequestId'),
          proposedPriceEur: any(named: 'proposedPriceEur'),
          travelerTravelDate: any(named: 'travelerTravelDate'),
          travelerAvailableKg: any(named: 'travelerAvailableKg'),
          travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _thread(rounds: 1));
      final bloc = await makeBloc();

      bloc.add(
        NegotiationStartRequested(
          packageRequestId: 'pr-1',
          proposedPriceEur: 30,
          travelerTravelDate: DateTime(2026, 6, 15),
          travelerAvailableKg: 10,
        ),
      );
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await settle();

      expect(captured(AnalyticsEvents.negotiationOfferMade), {
        'thread_id': 't-1',
        'request_id': 'pr-1',
        'round': 1,
        'currency': 'XOF',
        'amount_bracket': '20-50',
        'context': 'start',
      });
    },
  );

  test('contre-offre en échec : negotiation_action_failed', () async {
    when(
      () => repo.counter(
        't-1',
        proposedPriceEur: any(named: 'proposedPriceEur'),
        body: any(named: 'body'),
      ),
    ).thenThrow(
      const ValidationException('Trop bas', code: 'negotiation/price-too-low'),
    );
    final bloc = await makeBloc();

    bloc.add(
      const NegotiationCounterRequested(threadId: 't-1', proposedPriceEur: 5),
    );
    await bloc.stream.firstWhere((s) => s is NegotiationError);
    await settle();

    expect(captured(AnalyticsEvents.negotiationActionFailed), {
      'action': 'counter',
      'error_code': 'negotiation/price-too-low',
      'thread_id': 't-1',
    });
  });

  test('refus : negotiation_offer_rejected sans le motif', () async {
    when(
      () => repo.reject('t-1', reason: any(named: 'reason')),
    ).thenAnswer((_) async {});
    final bloc = await makeBloc();

    bloc.add(
      const NegotiationRejectRequested(threadId: 't-1', reason: 'Trop cher'),
    );
    await bloc.stream.firstWhere((s) => s is NegotiationRejected);
    await settle();

    final props = captured(AnalyticsEvents.negotiationOfferRejected);
    expect(props, containsPair('thread_id', 't-1'));
    expect(props, containsPair('has_reason', true));
    expect(props.values, isNot(contains('Trop cher')));
  });

  test('trajet existant lié : negotiation_trip_linked mode existing', () async {
    when(
      () => repo.submitTrip(
        't-1',
        travelerAnnouncementId: 'ann-1',
        paymentMethod: PaymentMethod.cash,
        useCardForCommission: false,
      ),
    ).thenAnswer((_) async => _thread());
    final bloc = await makeBloc();

    bloc.add(
      const NegotiationSubmitTripRequested(
        threadId: 't-1',
        travelerAnnouncementId: 'ann-1',
        paymentMethod: PaymentMethod.cash,
      ),
    );
    await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
    await settle();

    final props = captured(AnalyticsEvents.negotiationTripLinked);
    expect(props, containsPair('mode', 'existing'));
    expect(props, containsPair('payment_method', 'CASH'));
    expect(props, containsPair('round', 2));
  });

  test('trajet bloqué par le moyen de paiement : trip_link_payment_blocked, '
      'pas d\'échec générique', () async {
    when(
      () => repo.submitTrip(
        't-1',
        travelerAnnouncementId: 'ann-1',
        paymentMethod: PaymentMethod.stripe,
        useCardForCommission: false,
      ),
    ).thenThrow(
      const ValidationException(
        'Carte requise',
        code: 'payment-method/card-capability-required',
      ),
    );
    final bloc = await makeBloc();

    bloc.add(
      const NegotiationSubmitTripRequested(
        threadId: 't-1',
        travelerAnnouncementId: 'ann-1',
        paymentMethod: PaymentMethod.stripe,
      ),
    );
    await bloc.stream.firstWhere((s) => s is NegotiationError);
    await settle();

    expect(captured(AnalyticsEvents.tripLinkPaymentBlocked), {
      'reason': 'no_card',
    });
    verifyNever(
      () => backend.capture(AnalyticsEvents.negotiationActionFailed, any()),
    );
  });

  test('trajet changé : mode changed ; échec : trip_link_changed', () async {
    when(
      () => repo.changeTrip('t-1', travelerAnnouncementId: 'ann-2'),
    ).thenAnswer((_) async => _thread());
    when(
      () => repo.changeTrip('t-1', travelerAnnouncementId: 'ann-3'),
    ).thenThrow(Exception('réseau'));
    final bloc = await makeBloc();

    bloc.add(
      const NegotiationChangeTripRequested(
        threadId: 't-1',
        travelerAnnouncementId: 'ann-2',
      ),
    );
    await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
    bloc.add(
      const NegotiationChangeTripRequested(
        threadId: 't-1',
        travelerAnnouncementId: 'ann-3',
      ),
    );
    await bloc.stream.firstWhere((s) => s is NegotiationError);
    await settle();

    expect(
      captured(AnalyticsEvents.negotiationTripLinked),
      containsPair('mode', 'changed'),
    );
    expect(
      captured(AnalyticsEvents.negotiationActionFailed),
      containsPair('action', 'trip_link_changed'),
    );
  });

  test('trajet refusé : negotiation_trip_refused', () async {
    when(
      () => repo.refuseTrip('t-1', reason: any(named: 'reason')),
    ).thenAnswer((_) async => _thread());
    final bloc = await makeBloc();

    bloc.add(const NegotiationRefuseTripRequested(threadId: 't-1'));
    await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
    await settle();

    expect(
      captured(AnalyticsEvents.negotiationTripRefused),
      containsPair('thread_id', 't-1'),
    );
  });

  test('trajet refusé en échec : action refuse_trip', () async {
    when(
      () => repo.refuseTrip('t-1', reason: any(named: 'reason')),
    ).thenThrow(Exception('réseau'));
    final bloc = await makeBloc();

    bloc.add(const NegotiationRefuseTripRequested(threadId: 't-1'));
    await bloc.stream.firstWhere((s) => s is NegotiationError);
    await settle();

    expect(
      captured(AnalyticsEvents.negotiationActionFailed),
      containsPair('action', 'refuse_trip'),
    );
  });

  test('dépôt annulé : negotiation_deposit_cancelled', () async {
    when(() => repo.cancelMobileMoneyDeposit('t-1')).thenAnswer((_) async {});
    when(() => repo.getById('t-1')).thenAnswer((_) async => _thread());
    final bloc = await makeBloc();

    bloc.add(const NegotiationCancelDepositRequested('t-1'));
    await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
    await settle();

    expect(captured(AnalyticsEvents.negotiationDepositCancelled), {
      'thread_id': 't-1',
    });
  });

  test('relance : identité du fil', () async {
    when(() => repo.nudge('t-1')).thenAnswer((_) async => _thread());
    final bloc = await makeBloc();

    bloc.add(const NegotiationNudgeRequested('t-1'));
    await bloc.stream.firstWhere((s) => s is NegotiationNudgeSent);
    await settle();

    expect(
      captured(AnalyticsEvents.negotiationNudgeSent),
      containsPair('thread_id', 't-1'),
    );
  });
}
