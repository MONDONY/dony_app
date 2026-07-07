import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/repositories/recipient_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRecipientRepository extends Mock implements RecipientRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

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
  late MockAnalyticsService analytics;

  setUp(() {
    repository = MockRecipientRepository();
    analytics = MockAnalyticsService();
    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
  });

  group('RecipientBloc', () {
    test('initial state is correct', () {
      final bloc = RecipientBloc(repository, analytics);
      expect(bloc.state.status, RecipientStatus.initial);
      expect(bloc.state.recipients, isEmpty);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    blocTest<RecipientBloc, RecipientState>(
      'RecipientLoaded → success + list',
      build: () {
        when(() => repository.getAll()).thenAnswer((_) async => [_r1, _r2]);
        return RecipientBloc(repository, analytics);
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
        return RecipientBloc(repository, analytics);
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
        return RecipientBloc(repository, analytics);
      },
      seed: () => const RecipientState(
        status: RecipientStatus.success,
        recipients: [_r1, _r2],
      ),
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
      verify: (_) {
        verify(() => analytics.logEvent(any(that: contains('recipient_created'))))
            .called(1);
      },
    );

    blocTest<RecipientBloc, RecipientState>(
      'RecipientDeleted → removes from list',
      build: () {
        when(() => repository.delete('r-1')).thenAnswer((_) async {});
        return RecipientBloc(repository, analytics);
      },
      seed: () => const RecipientState(
        status: RecipientStatus.success,
        recipients: [_r1, _r2],
      ),
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
        return RecipientBloc(repository, analytics);
      },
      seed: () => const RecipientState(
        status: RecipientStatus.success,
        recipients: [_r1],
      ),
      act: (bloc) => bloc.add(const RecipientDeleted('r-1')),
      expect: () => [
        isA<RecipientState>()
            .having((s) => s.status, 'status', RecipientStatus.error)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );

    blocTest<RecipientBloc, RecipientState>(
      'RecipientCreated with isDefault clears previous default locally',
      build: () {
        const newDefault = Recipient(
          id: 'r-3',
          fullName: 'Awa',
          phoneE164: '+221771234567',
          city: 'Dakar',
          country: 'SN',
          isDefault: true,
        );
        when(() => repository.create(any())).thenAnswer((_) async => newDefault);
        return RecipientBloc(repository, analytics);
      },
      seed: () => const RecipientState(
        status: RecipientStatus.success,
        recipients: [
          Recipient(
            id: 'r-1',
            fullName: 'Old Default',
            phoneE164: '+221000000000',
            city: 'Dakar',
            country: 'SN',
            isDefault: true,
          ),
        ],
      ),
      act: (bloc) => bloc.add(const RecipientCreated(
        fullName: 'Awa',
        phoneE164: '+221771234567',
        city: 'Dakar',
        country: 'SN',
        isDefault: true,
      )),
      expect: () => [
        isA<RecipientState>()
            .having((s) => s.status, 'status', RecipientStatus.loading),
        isA<RecipientState>()
            .having(
                (s) => s.recipients.where((r) => r.isDefault).length,
                'un seul défaut',
                1)
            .having((s) => s.recipients.last.isDefault, 'nouveau = défaut', true),
      ],
    );

    blocTest<RecipientBloc, RecipientState>(
      'RecipientDefaultSet sends full update payload with isDefault true',
      build: () {
        const updatedAsDefault = Recipient(
          id: 'r-2',
          fullName: 'Aminata Koné',
          phoneE164: '+22507891234',
          city: 'Abidjan',
          country: 'CI',
          isDefault: true,
        );
        when(() => repository.update(any(), any()))
            .thenAnswer((_) async => updatedAsDefault);
        return RecipientBloc(repository, analytics);
      },
      seed: () => const RecipientState(
        status: RecipientStatus.success,
        recipients: [_r1, _r2],
      ),
      act: (bloc) => bloc.add(const RecipientDefaultSet('r-2')),
      verify: (_) {
        final payload = verify(() => repository.update('r-2', captureAny()))
            .captured
            .single as Map<String, dynamic>;
        expect(payload['isDefault'], true);
        expect(payload['fullName'], _r2.fullName);
      },
    );

    blocTest<RecipientBloc, RecipientState>(
      'RecipientDefaultSet clears default on other locally-held recipients',
      build: () {
        const updatedAsDefault = Recipient(
          id: 'r-2',
          fullName: 'Aminata Koné',
          phoneE164: '+22507891234',
          city: 'Abidjan',
          country: 'CI',
          isDefault: true,
        );
        when(() => repository.update(any(), any()))
            .thenAnswer((_) async => updatedAsDefault);
        return RecipientBloc(repository, analytics);
      },
      seed: () => const RecipientState(
        status: RecipientStatus.success,
        recipients: [
          Recipient(
            id: 'r-1',
            fullName: 'Mamadou Diallo',
            phoneE164: '+221771234567',
            city: 'Dakar',
            country: 'SN',
            isDefault: true,
          ),
          _r2,
        ],
      ),
      act: (bloc) => bloc.add(const RecipientDefaultSet('r-2')),
      expect: () => [
        isA<RecipientState>()
            .having((s) => s.recipients.where((r) => r.isDefault).length,
                'un seul défaut', 1)
            .having((s) => s.recipients.firstWhere((r) => r.id == 'r-2').isDefault,
                'r-2 défaut', true),
      ],
      verify: (_) {
        verify(() => analytics.logEvent(any(that: contains('recipient_default_set'))))
            .called(1);
      },
    );

    blocTest<RecipientBloc, RecipientState>(
      'RecipientUpdated with isDefault clears default on other locally-held recipients',
      build: () {
        const updatedAsDefault = Recipient(
          id: 'r-1',
          fullName: 'Mamadou Diallo',
          phoneE164: '+221771234567',
          city: 'Dakar',
          country: 'SN',
          isDefault: true,
        );
        when(() => repository.update(any(), any()))
            .thenAnswer((_) async => updatedAsDefault);
        return RecipientBloc(repository, analytics);
      },
      seed: () => const RecipientState(
        status: RecipientStatus.success,
        recipients: [
          _r1,
          Recipient(
            id: 'r-2',
            fullName: 'Aminata Koné',
            phoneE164: '+22507891234',
            city: 'Abidjan',
            country: 'CI',
            isDefault: true,
          ),
        ],
      ),
      act: (bloc) => bloc.add(const RecipientUpdated(
        id: 'r-1',
        fullName: 'Mamadou Diallo',
        phoneE164: '+221771234567',
        city: 'Dakar',
        country: 'SN',
        isDefault: true,
      )),
      expect: () => [
        isA<RecipientState>()
            .having((s) => s.status, 'status', RecipientStatus.loading),
        isA<RecipientState>()
            .having((s) => s.recipients.where((r) => r.isDefault).length,
                'un seul défaut', 1)
            .having((s) => s.recipients.firstWhere((r) => r.id == 'r-1').isDefault,
                'r-1 défaut', true),
      ],
    );

    blocTest<RecipientBloc, RecipientState>(
      'RecipientPicked → logs analytics event without emitting state',
      build: () => RecipientBloc(repository, analytics),
      act: (bloc) => bloc.add(const RecipientPicked('saved')),
      expect: () => <RecipientState>[],
      verify: (_) {
        verify(() => analytics.logEvent(
              any(that: contains('recipient_selected')),
              properties: {'source': 'saved'},
            )).called(1);
      },
    );
  });
}
