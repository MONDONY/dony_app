import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/habitual_operator_cubit.dart';
import 'package:dony/features/matching/data/models/mobile_money_network.dart';
import 'package:dony/features/payments/data/payer_phone_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMemory extends Mock implements PayerPhoneMemory {}

class _MockAnalytics extends Mock implements AnalyticsService {}

const _orangeCi = MobileMoneyNetwork(
  code: 'ORANGE_CIV',
  label: 'Orange Money',
  brand: 'ORANGE',
  country: 'CI',
);
const _orangeSn = MobileMoneyNetwork(
  code: 'ORANGE_SEN',
  label: 'Orange Money',
  brand: 'ORANGE',
  country: 'SN',
);
const _mtnCi = MobileMoneyNetwork(
  code: 'MTN_MOMO_CIV',
  label: 'MTN MoMo',
  brand: 'MTN',
  country: 'CI',
);

const _habitualOrangeCi = RememberedPayer(
  country: 'CI',
  operatorCode: 'ORANGE_CIV',
  e164: '+2250748840856',
);

void main() {
  late _MockMemory memory;
  late _MockAnalytics analytics;

  setUp(() {
    memory = _MockMemory();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  HabitualOperatorCubit build() => HabitualOperatorCubit(memory, analytics);

  blocTest<HabitualOperatorCubit, String?>(
    'opérateur habituel accepté : rien',
    build: () {
      when(() => memory.read()).thenAnswer((_) async => _habitualOrangeCi);
      return build();
    },
    act: (c) => c.load(const [_orangeCi, _mtnCi]),
    expect: () => <String?>[],
    verify: (_) => verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ),
  );

  blocTest<HabitualOperatorCubit, String?>(
    'opérateur non accepté : libellé de marque, event une fois sans numéro',
    build: () {
      when(() => memory.read()).thenAnswer((_) async => _habitualOrangeCi);
      return build();
    },
    act: (c) => c.load(const [_mtnCi]),
    expect: () => ['Orange'],
    verify: (_) {
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.mobileMoneyHabitualOperatorNotAcceptedViewed,
          properties: {'operator': 'ORANGE_CIV'},
        ),
      ).called(1);
    },
  );

  blocTest<HabitualOperatorCubit, String?>(
    'même marque acceptée dans un autre pays : le libellé précise le pays',
    build: () {
      when(() => memory.read()).thenAnswer((_) async => _habitualOrangeCi);
      return build();
    },
    act: (c) => c.load(const [_orangeSn]),
    expect: () => ['Orange CI'],
  );

  blocTest<HabitualOperatorCubit, String?>(
    'mémoire vide : rien, pas d\'event',
    build: () {
      when(() => memory.read()).thenAnswer((_) async => null);
      return build();
    },
    act: (c) => c.load(const [_mtnCi]),
    expect: () => <String?>[],
    verify: (_) => verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ),
  );

  blocTest<HabitualOperatorCubit, String?>(
    'liste vide (mobile money indisponible) : la mémoire n\'est pas lue',
    build: build,
    act: (c) => c.load(const []),
    expect: () => <String?>[],
    verify: (_) {
      verifyNever(() => memory.read());
      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
    },
  );

  blocTest<HabitualOperatorCubit, String?>(
    'ni carte ni espèces en repli : rien, pas d\'event',
    build: () {
      when(() => memory.read()).thenAnswer((_) async => _habitualOrangeCi);
      return build();
    },
    act: (c) => c.load(const [_mtnCi], fallbackAvailable: false),
    expect: () => <String?>[],
    verify: (_) => verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ),
  );

  test('cubit fermé pendant la lecture : aucun emit', () async {
    when(() => memory.read()).thenAnswer((_) async => _habitualOrangeCi);
    final c = build();
    final pending = c.load(const [_mtnCi]);
    await c.close();
    await pending;
    expect(c.state, isNull);
    verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    );
  });
}
