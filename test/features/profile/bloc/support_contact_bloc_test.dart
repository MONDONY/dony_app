import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/profile/bloc/support_contact_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SupportContactBloc bloc;

  setUp(() => bloc = SupportContactBloc());
  tearDown(() => bloc.close());

  test('initial state is empty and invalid', () {
    expect(bloc.state.category, isEmpty);
    expect(bloc.state.subject, isEmpty);
    expect(bloc.state.message, isEmpty);
    expect(bloc.state.isValid, isFalse);
    expect(bloc.state.submitStatus, SupportSubmitStatus.idle);
  });

  group('SupportCategorySelected', () {
    blocTest<SupportContactBloc, SupportContactState>(
      'updates category',
      build: () => bloc,
      act: (b) => b.add(const SupportCategorySelected('Paiement')),
      expect: () => [
        predicate<SupportContactState>((s) => s.category == 'Paiement'),
      ],
    );
  });

  group('SupportSubjectChanged', () {
    blocTest<SupportContactBloc, SupportContactState>(
      'updates subject',
      build: () => bloc,
      act: (b) => b.add(const SupportSubjectChanged('Mon sujet')),
      expect: () => [
        predicate<SupportContactState>((s) => s.subject == 'Mon sujet'),
      ],
    );
  });

  group('SupportMessageChanged', () {
    blocTest<SupportContactBloc, SupportContactState>(
      'updates message',
      build: () => bloc,
      act: (b) => b.add(const SupportMessageChanged('Un message détaillé')),
      expect: () => [
        predicate<SupportContactState>(
          (s) => s.message == 'Un message détaillé',
        ),
      ],
    );
  });

  group('isValid', () {
    test('returns false when only category is set', () {
      bloc.add(const SupportCategorySelected('Paiement'));
      expect(bloc.state.isValid, isFalse);
    });

    test('returns false when subject is too short (< 5 chars)', () {
      bloc
        ..add(const SupportCategorySelected('Paiement'))
        ..add(const SupportSubjectChanged('Pb'))
        ..add(
          const SupportMessageChanged(
            'Un message suffisamment long pour valider le formulaire',
          ),
        );
      expect(bloc.state.isValid, isFalse);
    });

    test('returns false when message is too short (< 20 chars)', () {
      bloc
        ..add(const SupportCategorySelected('Paiement'))
        ..add(const SupportSubjectChanged('Mon problème'))
        ..add(const SupportMessageChanged('Court'));
      expect(bloc.state.isValid, isFalse);
    });

    blocTest<SupportContactBloc, SupportContactState>(
      'returns true when all fields are valid',
      build: () => bloc,
      act: (b) => b
        ..add(const SupportCategorySelected('Paiement'))
        ..add(const SupportSubjectChanged('Problème remboursement'))
        ..add(
          const SupportMessageChanged(
            'Je n\'ai pas été remboursé suite à l\'annulation de ma commande.',
          ),
        ),
      verify: (b) => expect(b.state.isValid, isTrue),
    );
  });

  group('SupportSubmitRequested', () {
    blocTest<SupportContactBloc, SupportContactState>(
      'emits submitting when state is valid',
      build: () => bloc,
      act: (b) {
        b
          ..add(const SupportCategorySelected('Bug technique'))
          ..add(const SupportSubjectChanged('Problème connexion app'))
          ..add(
            const SupportMessageChanged(
              'L\'application plante au démarrage depuis la mise à jour.',
            ),
          );
        b.add(const SupportSubmitRequested());
      },
      verify: (b) =>
          expect(b.state.submitStatus, SupportSubmitStatus.submitting),
    );

    blocTest<SupportContactBloc, SupportContactState>(
      'does not emit submitting when state is invalid',
      build: () => bloc,
      act: (b) => b.add(const SupportSubmitRequested()),
      expect: () => <SupportContactState>[],
    );
  });
}
