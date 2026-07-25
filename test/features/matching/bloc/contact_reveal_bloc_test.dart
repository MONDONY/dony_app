import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidRepository extends Mock implements BidRepository {}

void main() {
  late _MockBidRepository repository;

  setUp(() => repository = _MockBidRepository());

  group('ContactRevealBloc', () {
    blocTest<ContactRevealBloc, ContactRevealState>(
      'demande le numéro au repository et le publie',
      build: () {
        when(() => repository.getCounterpartyPhone('b1'))
            .thenAnswer((_) async => '+221701234567');
        return ContactRevealBloc(repository);
      },
      act: (bloc) => bloc.add(const ContactRevealRequested('b1')),
      expect: () => [
        isA<ContactRevealLoading>(),
        isA<ContactRevealSuccess>()
            .having((s) => s.phoneNumber, 'phoneNumber', '+221701234567'),
      ],
      verify: (_) => verify(() => repository.getCounterpartyPhone('b1')).called(1),
    );

    blocTest<ContactRevealBloc, ContactRevealState>(
      'compte sans numéro → succès à null, pas une erreur',
      build: () {
        when(() => repository.getCounterpartyPhone('b1'))
            .thenAnswer((_) async => null);
        return ContactRevealBloc(repository);
      },
      act: (bloc) => bloc.add(const ContactRevealRequested('b1')),
      expect: () => [
        isA<ContactRevealLoading>(),
        isA<ContactRevealSuccess>().having((s) => s.phoneNumber, 'phoneNumber', isNull),
      ],
    );

    blocTest<ContactRevealBloc, ContactRevealState>(
      'refus du serveur → état d\'erreur exploitable par l\'UI',
      build: () {
        when(() => repository.getCounterpartyPhone('b1'))
            .thenThrow(const ForbiddenException('Numéro non communicable'));
        return ContactRevealBloc(repository);
      },
      act: (bloc) => bloc.add(const ContactRevealRequested('b1')),
      expect: () => [
        isA<ContactRevealLoading>(),
        isA<ContactRevealError>().having(
            (s) => s.error.message, 'message', 'Numéro non communicable'),
      ],
    );

    blocTest<ContactRevealBloc, ContactRevealState>(
      'double tap pendant le chargement → une seule requête',
      build: () {
        when(() => repository.getCounterpartyPhone('b1')).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return '+221701234567';
        });
        return ContactRevealBloc(repository);
      },
      act: (bloc) => bloc
        ..add(const ContactRevealRequested('b1'))
        ..add(const ContactRevealRequested('b1')),
      wait: const Duration(milliseconds: 60),
      verify: (_) => verify(() => repository.getCounterpartyPhone('b1')).called(1),
    );
  });
}
