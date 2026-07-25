import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/settings/bloc/pin_status_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalAuthService extends Mock implements LocalAuthService {}

void main() {
  late MockLocalAuthService service;

  setUp(() => service = MockLocalAuthService());

  group('PinStatusCubit', () {
    /// L'état de départ ne peut pas être connu : le secure storage est
    /// asynchrone. `configured` reste nul, et l'écran affiche alors le défaut
    /// d'un compte neuf (verrouillage éteint).
    test('état initial : configured inconnu', () {
      final cubit = PinStatusCubit(service);
      expect(cubit.state.configured, isNull);
      expect(cubit.state.isBusy, isFalse);
      cubit.close();
    });

    blocTest<PinStatusCubit, PinStatusState>(
      'refresh lit le secure storage : code présent',
      setUp: () => when(service.isPinSet).thenAnswer((_) async => true),
      build: () => PinStatusCubit(service),
      act: (cubit) => cubit.refresh(),
      expect: () => [
        const PinStatusState(configured: true),
      ],
    );

    blocTest<PinStatusCubit, PinStatusState>(
      'refresh lit le secure storage : aucun code',
      setUp: () => when(service.isPinSet).thenAnswer((_) async => false),
      build: () => PinStatusCubit(service),
      act: (cubit) => cubit.refresh(),
      expect: () => [
        const PinStatusState(configured: false),
      ],
    );

    blocTest<PinStatusCubit, PinStatusState>(
      'disable efface le code et repasse à désactivé',
      setUp: () => when(service.clearPin).thenAnswer((_) async {}),
      build: () => PinStatusCubit(service),
      seed: () => const PinStatusState(configured: true),
      act: (cubit) => cubit.disable(),
      expect: () => [
        const PinStatusState(configured: true, isBusy: true),
        const PinStatusState(configured: false),
      ],
      verify: (_) => verify(service.clearPin).called(1),
    );

    test('égalité de PinStatusState porte sur les deux champs', () {
      expect(const PinStatusState(configured: true),
          equals(const PinStatusState(configured: true)));
      expect(const PinStatusState(configured: true),
          isNot(equals(const PinStatusState(configured: false))));
      expect(const PinStatusState(configured: true),
          isNot(equals(const PinStatusState(configured: true, isBusy: true))));
      expect(const PinStatusState(configured: true).hashCode,
          equals(const PinStatusState(configured: true).hashCode));
    });
  });
}
