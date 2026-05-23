import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:dony/features/settings/data/repositories/privacy_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockPrivacySettingsRepository extends Mock
    implements PrivacySettingsRepository {}

class MockBox extends Mock implements Box<dynamic> {}

void main() {
  late MockPrivacySettingsRepository mockRepo;
  late MockBox mockBox;

  setUp(() {
    mockRepo = MockPrivacySettingsRepository();
    mockBox = MockBox();
    // Par défaut : Hive vide (aucune valeur cachée)
    when(() => mockBox.get(any())).thenReturn(null);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
  });

  group('PrivacySettingsBloc', () {
    // ── État initial ────────────────────────────────────────────────────────

    test('état initial est PrivacySettingsInitial quand Hive est vide', () {
      when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(null);
      final bloc = PrivacySettingsBloc(mockRepo, mockBox);
      expect(bloc.state, isA<PrivacySettingsInitial>());
      bloc.close();
    });

    test('état initial est PrivacySettingsLoaded(true) quand Hive contient true', () {
      when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(true);
      final bloc = PrivacySettingsBloc(mockRepo, mockBox);
      expect(bloc.state,
          isA<PrivacySettingsLoaded>()
              .having((s) => s.contactKycOnly, 'contactKycOnly', true));
      bloc.close();
    });

    test('état initial est PrivacySettingsLoaded(false) quand Hive contient false', () {
      when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(false);
      final bloc = PrivacySettingsBloc(mockRepo, mockBox);
      expect(bloc.state,
          isA<PrivacySettingsLoaded>()
              .having((s) => s.contactKycOnly, 'contactKycOnly', false));
      bloc.close();
    });

    // ── PrivacySettingsLoadRequested — sans cache Hive ──────────────────────

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'LoadRequested sans cache : émet Loading puis Loaded et écrit Hive',
      setUp: () {
        when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(null);
        when(() => mockRepo.fetchContactKycOnly()).thenAnswer((_) async => true);
      },
      build: () => PrivacySettingsBloc(mockRepo, mockBox),
      act: (bloc) => bloc.add(const PrivacySettingsLoadRequested()),
      expect: () => [
        isA<PrivacySettingsLoading>(),
        isA<PrivacySettingsLoaded>()
            .having((s) => s.contactKycOnly, 'contactKycOnly', true),
      ],
      verify: (_) {
        verify(() => mockBox.put(HiveService.kContactKycOnly, true)).called(1);
      },
    );

    // ── PrivacySettingsLoadRequested — avec cache Hive ──────────────────────

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'LoadRequested avec cache Hive : pas de Loading, reconcilie silencieusement',
      setUp: () {
        when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(false);
        when(() => mockRepo.fetchContactKycOnly()).thenAnswer((_) async => true);
      },
      build: () => PrivacySettingsBloc(mockRepo, mockBox),
      act: (bloc) => bloc.add(const PrivacySettingsLoadRequested()),
      // Pas de PrivacySettingsLoading car Hive a déjà une valeur
      expect: () => [
        isA<PrivacySettingsLoaded>()
            .having((s) => s.contactKycOnly, 'contactKycOnly', true),
      ],
      verify: (_) {
        verify(() => mockBox.put(HiveService.kContactKycOnly, true)).called(1);
      },
    );

    // ── PrivacySettingsLoadRequested — erreur backend sans cache ────────────

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'LoadRequested erreur sans cache : émet Loading puis Error',
      setUp: () {
        when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(null);
        when(() => mockRepo.fetchContactKycOnly())
            .thenThrow(Exception('Network error'));
      },
      build: () => PrivacySettingsBloc(mockRepo, mockBox),
      act: (bloc) => bloc.add(const PrivacySettingsLoadRequested()),
      expect: () => [
        isA<PrivacySettingsLoading>(),
        isA<PrivacySettingsError>().having(
          (s) => s.message,
          'message',
          'Impossible de charger les préférences',
        ),
      ],
    );

    // ── PrivacySettingsLoadRequested — erreur backend avec cache ────────────

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'LoadRequested erreur avec cache Hive : conserve la valeur Hive sans erreur',
      setUp: () {
        when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(true);
        when(() => mockRepo.fetchContactKycOnly())
            .thenThrow(Exception('Network error'));
      },
      build: () => PrivacySettingsBloc(mockRepo, mockBox),
      act: (bloc) => bloc.add(const PrivacySettingsLoadRequested()),
      // Aucun nouvel état émis : le Loaded(true) de Hive reste affiché
      expect: () => [],
    );

    // ── ContactKycOnlyToggled — backend ok ──────────────────────────────────

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'Toggle(false) : update optimiste Hive + backend, pas de rollback',
      setUp: () {
        when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(true);
        when(() => mockRepo.updateContactKycOnly(false))
            .thenAnswer((_) async {});
      },
      build: () => PrivacySettingsBloc(mockRepo, mockBox),
      seed: () => const PrivacySettingsLoaded(contactKycOnly: true),
      act: (bloc) => bloc.add(const ContactKycOnlyToggled(false)),
      expect: () => [
        isA<PrivacySettingsLoaded>()
            .having((s) => s.contactKycOnly, 'contactKycOnly', false),
      ],
      verify: (_) {
        verify(() => mockBox.put(HiveService.kContactKycOnly, false)).called(1);
        verify(() => mockRepo.updateContactKycOnly(false)).called(1);
      },
    );

    // ── ContactKycOnlyToggled — erreur backend → rollback ───────────────────

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'Toggle(false) erreur backend : rollback Hive + état',
      setUp: () {
        when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(true);
        when(() => mockRepo.updateContactKycOnly(false))
            .thenAnswer((_) async => throw Exception('Server error'));
      },
      build: () => PrivacySettingsBloc(mockRepo, mockBox),
      seed: () => const PrivacySettingsLoaded(contactKycOnly: true),
      act: (bloc) => bloc.add(const ContactKycOnlyToggled(false)),
      expect: () => [
        isA<PrivacySettingsLoaded>()
            .having((s) => s.contactKycOnly, 'contactKycOnly', false),
        isA<PrivacySettingsLoaded>()
            .having((s) => s.contactKycOnly, 'contactKycOnly', true),
      ],
      verify: (_) {
        // Hive écrit false (optimiste) puis rollback à true
        verifyInOrder([
          () => mockBox.put(HiveService.kContactKycOnly, false),
          () => mockBox.put(HiveService.kContactKycOnly, true),
        ]);
      },
    );

    // ── Equality des états ──────────────────────────────────────────────────

    test('PrivacySettingsLoaded equality est correcte', () {
      const a = PrivacySettingsLoaded(contactKycOnly: true);
      const b = PrivacySettingsLoaded(contactKycOnly: true);
      const c = PrivacySettingsLoaded(contactKycOnly: false);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('PrivacySettingsError equality est correcte', () {
      const a = PrivacySettingsError('msg');
      const b = PrivacySettingsError('msg');
      const c = PrivacySettingsError('autre');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
