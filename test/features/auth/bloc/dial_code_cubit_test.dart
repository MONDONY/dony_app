import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/phone/phone_country.dart';
import 'package:dony/features/auth/bloc/dial_code_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final civ = phoneCountryFor('+225')!;
  final senegal = phoneCountryFor('+221')!;

  group('DialCodeCubit', () {
    test('démarre sur la France', () {
      final cubit = DialCodeCubit();
      addTearDown(cubit.close);
      expect(cubit.state.dialCode, '+33');
      expect(cubit.state.flag, '🇫🇷');
    });

    blocTest<DialCodeCubit, PhoneCountry>(
      'retient le pays choisi',
      build: DialCodeCubit.new,
      act: (cubit) => cubit.select(civ),
      expect: () => [civ],
    );

    blocTest<DialCodeCubit, PhoneCountry>(
      'garde le dernier choix après plusieurs changements',
      build: DialCodeCubit.new,
      act: (cubit) => cubit
        ..select(civ)
        ..select(senegal),
      expect: () => [civ, senegal],
      verify: (cubit) => expect(cubit.state.dialCode, '+221'),
    );

    test(
      'le choix survit à un échec d\'authentification, il ne vit plus dans AuthBloc',
      () {
        // Régression : l'indicatif était un champ de AuthInitial, réémis nu à
        // chaque erreur. Le pays revenait à la France tout seul et le code SMS
        // partait vers le mauvais destinataire à la soumission suivante.
        final cubit = DialCodeCubit();
        addTearDown(cubit.close);
        cubit.select(civ);
        expect(cubit.state.dialCode, '+225');
      },
    );
  });
}
