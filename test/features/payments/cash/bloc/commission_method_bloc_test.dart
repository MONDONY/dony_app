import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:dony/features/payments/cash/data/repositories/commission_method_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCommissionMethodRepository extends Mock
    implements CommissionMethodRepository {}

const _fakeCard = CommissionMethod(
  brand: 'visa',
  last4: '4242',
  expMonth: 12,
  expYear: 2028,
  expirationStatus: ExpirationStatus.valid,
);

void main() {
  late MockCommissionMethodRepository repo;

  setUp(() {
    repo = MockCommissionMethodRepository();
  });

  blocTest<CommissionMethodBloc, CommissionMethodState>(
    'load emits Loading then Loaded when repo returns card',
    build: () {
      when(() => repo.load()).thenAnswer((_) async => _fakeCard);
      return CommissionMethodBloc(repo);
    },
    act: (b) => b.add(CommissionMethodLoadRequested()),
    expect: () => [
      isA<CommissionMethodLoading>(),
      isA<CommissionMethodLoaded>(),
    ],
  );

  blocTest<CommissionMethodBloc, CommissionMethodState>(
    'load emits NotConfigured when repo returns null',
    build: () {
      when(() => repo.load()).thenAnswer((_) async => null);
      return CommissionMethodBloc(repo);
    },
    act: (b) => b.add(CommissionMethodLoadRequested()),
    expect: () => [
      isA<CommissionMethodLoading>(),
      isA<CommissionMethodNotConfigured>(),
    ],
  );

  blocTest<CommissionMethodBloc, CommissionMethodState>(
    'load emits Error on exception',
    build: () {
      when(() => repo.load()).thenThrow(Exception('network'));
      return CommissionMethodBloc(repo);
    },
    act: (b) => b.add(CommissionMethodLoadRequested()),
    expect: () => [
      isA<CommissionMethodLoading>(),
      isA<CommissionMethodError>(),
    ],
  );

  blocTest<CommissionMethodBloc, CommissionMethodState>(
    'setup emits SetupInProgress with clientSecret',
    build: () {
      when(() => repo.startSetup()).thenAnswer((_) async => 'seti_x');
      return CommissionMethodBloc(repo);
    },
    act: (b) => b.add(CommissionMethodSetupRequested()),
    expect: () => [isA<CommissionMethodSetupInProgress>()],
    verify: (b) {
      final state = b.state as CommissionMethodSetupInProgress;
      expect(state.clientSecret, 'seti_x');
    },
  );

  blocTest<CommissionMethodBloc, CommissionMethodState>(
    'SetupCompleted triggers reload',
    build: () {
      when(() => repo.savePaymentMethod(any())).thenAnswer((_) async {});
      when(() => repo.load()).thenAnswer((_) async => _fakeCard);
      return CommissionMethodBloc(repo);
    },
    act: (b) => b.add(CommissionMethodSetupCompleted('pm_test_123')),
    expect: () => [
      isA<CommissionMethodLoading>(),
      isA<CommissionMethodLoaded>(),
    ],
  );

  blocTest<CommissionMethodBloc, CommissionMethodState>(
    'SetupCancelled triggers reload',
    build: () {
      when(() => repo.load()).thenAnswer((_) async => null);
      return CommissionMethodBloc(repo);
    },
    act: (b) => b.add(CommissionMethodSetupCancelled()),
    expect: () => [
      isA<CommissionMethodLoading>(),
      isA<CommissionMethodNotConfigured>(),
    ],
  );

  blocTest<CommissionMethodBloc, CommissionMethodState>(
    'delete emits Loading then NotConfigured',
    build: () {
      when(() => repo.remove()).thenAnswer((_) async {});
      when(() => repo.load()).thenAnswer((_) async => null);
      return CommissionMethodBloc(repo);
    },
    act: (b) => b.add(CommissionMethodDeleteRequested()),
    expect: () => [
      isA<CommissionMethodLoading>(),
      isA<CommissionMethodNotConfigured>(),
    ],
  );
}
