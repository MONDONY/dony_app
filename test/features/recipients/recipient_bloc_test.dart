import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/repositories/recipient_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRecipientRepository extends Mock implements RecipientRepository {}

const _r1 = Recipient(
  id: 'r-1',
  fullName: 'Mamadou Diallo',
  phoneE164: '+221771234567',
  city: 'Dakar',
  country: 'SN',
);

const _r2 = Recipient(
  id: 'r-2',
  fullName: 'Aminata Koné',
  phoneE164: '+22507891234',
  city: 'Abidjan',
  country: 'CI',
);

void main() {
  late MockRecipientRepository repository;

  setUp(() {
    repository = MockRecipientRepository();
  });

  group('RecipientBloc', () {
    test('initial state is correct', () {
      final bloc = RecipientBloc(repository);
      expect(bloc.state.status, RecipientStatus.initial);
      expect(bloc.state.recipients, isEmpty);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    blocTest<RecipientBloc, RecipientState>(
      'RecipientLoaded → success + list',
      build: () {
        when(() => repository.getAll()).thenAnswer((_) async => [_r1, _r2]);
        return RecipientBloc(repository);
      },
      act: (bloc) => bloc.add(const RecipientLoaded()),
      expect: () => [
        isA<RecipientState>()
            .having((s) => s.status, 'status', RecipientStatus.loading),
        isA<RecipientState>()
            .having((s) => s.status, 'status', RecipientStatus.success)
            .having((s) => s.recipients, 'recipients', [_r1, _r2]),
      ],
    );

    blocTest<RecipientBloc, RecipientState>(
      'RecipientLoaded → error state when repository throws',
      build: () {
        when(() => repository.getAll()).thenThrow(Exception('Network error'));
        return RecipientBloc(repository);
      },
      act: (bloc) => bloc.add(const RecipientLoaded()),
      expect: () => [
        isA<RecipientState>()
            .having((s) => s.status, 'status', RecipientStatus.loading),
        isA<RecipientState>()
            .having((s) => s.status, 'status', RecipientStatus.error)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );

    blocTest<RecipientBloc, RecipientState>(
      'RecipientCreated → adds to list',
      build: () {
        const created = Recipient(
          id: 'r-3',
          fullName: 'Alpha Bah',
          phoneE164: '+22365432100',
          city: 'Bamako',
          country: 'ML',
        );
        when(() => repository.create(any())).thenAnswer((_) async => created);
        return RecipientBloc(repository)
          ..emit(const RecipientState(
            status: RecipientStatus.success,
            recipients: [_r1, _r2],
          ));
      },
      act: (bloc) => bloc.add(const RecipientCreated(
        fullName: 'Alpha Bah',
        phoneE164: '+22365432100',
        city: 'Bamako',
        country: 'ML',
      )),
      expect: () => [
        isA<RecipientState>()
            .having((s) => s.status, 'status', RecipientStatus.loading),
        isA<RecipientState>()
            .having((s) => s.status, 'status', RecipientStatus.success)
            .having((s) => s.recipients.length, 'length', 3),
      ],
    );

    blocTest<RecipientBloc, RecipientState>(
      'RecipientDeleted → removes from list',
      build: () {
        when(() => repository.delete('r-1')).thenAnswer((_) async {});
        return RecipientBloc(repository)
          ..emit(const RecipientState(
            status: RecipientStatus.success,
            recipients: [_r1, _r2],
          ));
      },
      act: (bloc) => bloc.add(const RecipientDeleted('r-1')),
      expect: () => [
        isA<RecipientState>()
            .having((s) => s.status, 'status', RecipientStatus.success)
            .having((s) => s.recipients.length, 'length', 1)
            .having((s) => s.recipients.first.id, 'id', 'r-2'),
      ],
    );

    blocTest<RecipientBloc, RecipientState>(
      'RecipientDeleted → error when repository throws',
      build: () {
        when(() => repository.delete('r-1')).thenThrow(Exception('Server error'));
        return RecipientBloc(repository)
          ..emit(const RecipientState(
            status: RecipientStatus.success,
            recipients: [_r1],
          ));
      },
      act: (bloc) => bloc.add(const RecipientDeleted('r-1')),
      expect: () => [
        isA<RecipientState>()
            .having((s) => s.status, 'status', RecipientStatus.error)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );
  });
}
