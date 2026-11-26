import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/publish_gate/bloc/publish_kyc_gate_cubit.dart';
import 'package:dony/features/publish_gate/data/models/publish_commitments.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockAnalytics analytics;

  setUp(() {
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  PublishKycGateCubit build({
    PublishCommitmentRole role = PublishCommitmentRole.traveler,
    bool resumedFromGate = false,
  }) => PublishKycGateCubit(
    role: role,
    analytics: analytics,
    resumedFromGate: resumedFromGate,
  );

  test('état initial : rien de montré', () {
    final cubit = build();
    expect(cubit.state, const PublishKycGateState());
    expect(cubit.state.pending, isFalse);
  });

  test('open : brouillon gardé AVANT la feuille, puis shown tracé', () async {
    final cubit = build();
    final order = <String>[];
    final states = <PublishKycGateState>[];
    final sub = cubit.stream.listen(states.add);
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async => order.add('shown'));

    await cubit.open(
      kycStatus: 'NOT_STARTED',
      saveDraft: () async {
        order.add('save');
        return true;
      },
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(order, ['save', 'shown']);
    expect(states, [const PublishKycGateState(shown: true, draftSaved: true)]);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.publishKycGateShown,
        properties: {'role': 'traveler', 'kyc_status': 'not_started'},
      ),
    ).called(1);
    await cubit.close();
  });

  test('open : écriture refusée ou en échec, la feuille s\'ouvre quand même '
      '(draftSaved faux)', () async {
    final cubit = build(role: PublishCommitmentRole.sender);
    await cubit.open(kycStatus: 'PENDING', saveDraft: () async => false);
    expect(cubit.state.draftSaved, isFalse);
    expect(cubit.state.pending, isTrue);

    await cubit.open(
      kycStatus: 'REJECTED',
      saveDraft: () async => throw StateError('trousseau'),
    );
    expect(cubit.state.draftSaved, isFalse);
    expect(cubit.state.kycStatus, 'REJECTED');
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.publishKycGateShown,
        properties: {'role': 'sender', 'kyc_status': 'pending'},
      ),
    ).called(1);
    await cubit.close();
  });

  test('open sans brouillon local (modification) : rien de gardé', () async {
    final cubit = build();
    await cubit.open(kycStatus: 'NOT_STARTED');
    expect(cubit.state.shown, isTrue);
    expect(cubit.state.draftSaved, isFalse);
    await cubit.close();
  });

  test('open après fermeture : tracé mais aucun état émis', () async {
    final cubit = build();
    await cubit.close();
    await cubit.open(kycStatus: 'NOT_STARTED');
    expect(cubit.state.shown, isFalse);
  });

  test('verifyTapped : trace le rôle', () async {
    final cubit = build(role: PublishCommitmentRole.sender);
    cubit.verifyTapped();
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.publishKycGateVerifyTapped,
        properties: {'role': 'sender'},
      ),
    ).called(1);
    await cubit.close();
  });

  test('publicationSucceeded : rien si la vérification n\'avait pas arrêté '
      'la publication', () async {
    final cubit = build();
    cubit.publicationSucceeded();
    verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    );
    await cubit.close();
  });

  test(
    'publicationSucceeded après la feuille : resumed, une seule fois',
    () async {
      final cubit = build();
      await cubit.open(kycStatus: 'NOT_STARTED');
      cubit
        ..publicationSucceeded()
        ..publicationSucceeded();
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.publishKycGateResumed,
          properties: {'role': 'traveler'},
        ),
      ).called(1);
      await cubit.close();
    },
  );

  test('brouillon gardé par la vérification puis repris : resumed', () async {
    final cubit = build(
      role: PublishCommitmentRole.sender,
      resumedFromGate: true,
    );
    cubit.publicationSucceeded();
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.publishKycGateResumed,
        properties: {'role': 'sender'},
      ),
    ).called(1);
    await cubit.close();
  });
}
