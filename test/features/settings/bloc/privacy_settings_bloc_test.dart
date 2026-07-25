import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:dony/features/settings/data/models/privacy_settings_model.dart';
import 'package:dony/features/settings/data/repositories/privacy_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockPrivacySettingsRepository extends Mock
    implements PrivacySettingsRepository {}

class MockBox extends Mock implements Box<dynamic> {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockPrivacySettingsRepository mockRepo;
  late MockBox mockBox;
  late MockAnalyticsService mockAnalytics;

  setUpAll(() {
    registerFallbackValue(
      const PrivacySettingsModel(contactKycOnly: true, hidePhoneNumber: false),
    );
  });

  setUp(() {
    mockRepo = MockPrivacySettingsRepository();
    mockBox = MockBox();
    mockAnalytics = MockAnalyticsService();
    // Par défaut : Hive vide (aucune valeur cachée)
    when(() => mockBox.get(any())).thenReturn(null);
    // Les lectures à valeur par défaut doivent être stubbées séparément :
    // mocktail traite `get(key)` et `get(key, defaultValue: x)` comme deux
    // invocations distinctes, et un null non stubbé casserait le cast en bool.
    when(() => mockBox.get(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((i) => i.namedArguments[const Symbol('defaultValue')]);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockAnalytics.logEvent(any(),
        properties: any(named: 'properties'))).thenAnswer((_) async {});
  });

  PrivacySettingsBloc buildBloc() =>
      PrivacySettingsBloc(mockRepo, mockBox, mockAnalytics);

  group('PrivacySettingsBloc', () {
    // ── État initial ────────────────────────────────────────────────────────

    test('état initial est PrivacySettingsInitial quand Hive est vide', () {
      when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(null);
      final bloc = buildBloc();
      expect(bloc.state, isA<PrivacySettingsInitial>());
      bloc.close();
    });

    test('état initial est PrivacySettingsLoaded(true) quand Hive contient true', () {
      when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(true);
      final bloc = buildBloc();
      expect(bloc.state,
          isA<PrivacySettingsLoaded>()
              .having((s) => s.contactKycOnly, 'contactKycOnly', true));
      bloc.close();
    });

    test('état initial est PrivacySettingsLoaded(false) quand Hive contient false', () {
      when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(false);
      final bloc = buildBloc();
      expect(bloc.state,
          isA<PrivacySettingsLoaded>()
              .having((s) => s.contactKycOnly, 'contactKycOnly', false));
      bloc.close();
    });

    test('état initial relit aussi le masquage du numéro depuis Hive', () {
      when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(true);
      when(() => mockBox.get(HiveService.kHidePhoneNumber,
          defaultValue: any(named: 'defaultValue'))).thenReturn(true);
      final bloc = buildBloc();
      expect(bloc.state,
          isA<PrivacySettingsLoaded>()
              .having((s) => s.hidePhoneNumber, 'hidePhoneNumber', true));
      bloc.close();
    });

    // ── PrivacySettingsLoadRequested — sans cache Hive ──────────────────────

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'LoadRequested sans cache : émet Loading puis Loaded et écrit Hive',
      setUp: () {
        when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(null);
        when(() => mockRepo.fetch()).thenAnswer((_) async =>
            const PrivacySettingsModel(
                contactKycOnly: true, hidePhoneNumber: false));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const PrivacySettingsLoadRequested()),
      expect: () => [
        isA<PrivacySettingsLoading>(),
        isA<PrivacySettingsLoaded>()
            .having((s) => s.contactKycOnly, 'contactKycOnly', true),
      ],
      verify: (_) {
        verify(() => mockBox.put(HiveService.kContactKycOnly, true)).called(1);
        verify(() => mockBox.put(HiveService.kHidePhoneNumber, false)).called(1);
      },
    );

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'LoadRequested rapatrie le masquage décidé sur un autre appareil',
      setUp: () {
        when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(null);
        when(() => mockRepo.fetch()).thenAnswer((_) async =>
            const PrivacySettingsModel(
                contactKycOnly: true, hidePhoneNumber: true));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const PrivacySettingsLoadRequested()),
      expect: () => [
        isA<PrivacySettingsLoading>(),
        isA<PrivacySettingsLoaded>()
            .having((s) => s.hidePhoneNumber, 'hidePhoneNumber', true),
      ],
      verify: (_) {
        verify(() => mockBox.put(HiveService.kHidePhoneNumber, true)).called(1);
      },
    );

    // ── PrivacySettingsLoadRequested — avec cache Hive ──────────────────────

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'LoadRequested avec cache Hive : pas de Loading, reconcilie silencieusement',
      setUp: () {
        when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(false);
        when(() => mockRepo.fetch()).thenAnswer((_) async =>
            const PrivacySettingsModel(
                contactKycOnly: true, hidePhoneNumber: false));
      },
      build: buildBloc,
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
        when(() => mockRepo.fetch()).thenThrow(Exception('Network error'));
      },
      build: buildBloc,
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
        when(() => mockRepo.fetch()).thenThrow(Exception('Network error'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const PrivacySettingsLoadRequested()),
      // Aucun nouvel état émis : le Loaded(true) de Hive reste affiché
      expect: () => [],
    );

    // ── ContactKycOnlyToggled — backend ok ──────────────────────────────────

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'Toggle(false) : update optimiste Hive + backend, pas de rollback',
      setUp: () {
        when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(true);
        when(() => mockRepo.update(any())).thenAnswer((_) async {});
      },
      build: buildBloc,
      seed: () => const PrivacySettingsLoaded(contactKycOnly: true),
      act: (bloc) => bloc.add(const ContactKycOnlyToggled(false)),
      expect: () => [
        isA<PrivacySettingsLoaded>()
            .having((s) => s.contactKycOnly, 'contactKycOnly', false),
      ],
      verify: (_) {
        verify(() => mockBox.put(HiveService.kContactKycOnly, false)).called(1);
        verify(() => mockRepo.update(const PrivacySettingsModel(
            contactKycOnly: false, hidePhoneNumber: false))).called(1);
      },
    );

    // ── ContactKycOnlyToggled — erreur backend → rollback ───────────────────

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'Toggle(false) erreur backend : rollback Hive + état',
      setUp: () {
        when(() => mockBox.get(HiveService.kContactKycOnly)).thenReturn(true);
        when(() => mockRepo.update(any()))
            .thenAnswer((_) async => throw Exception('Server error'));
      },
      build: buildBloc,
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

    // ── HidePhoneNumberToggled ──────────────────────────────────────────────

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'masquer son numéro : état + Hive + backend, et l\'autre préférence est préservée',
      setUp: () {
        when(() => mockRepo.update(any())).thenAnswer((_) async {});
      },
      build: buildBloc,
      seed: () => const PrivacySettingsLoaded(contactKycOnly: true),
      act: (bloc) => bloc.add(const HidePhoneNumberToggled(true)),
      expect: () => [
        isA<PrivacySettingsLoaded>()
            .having((s) => s.hidePhoneNumber, 'hidePhoneNumber', true)
            .having((s) => s.contactKycOnly, 'contactKycOnly', true),
      ],
      verify: (_) {
        verify(() => mockBox.put(HiveService.kHidePhoneNumber, true)).called(1);
        // Le PUT porte les deux préférences : masquer son numéro ne doit pas
        // emporter avec lui le réglage « profils vérifiés uniquement ».
        verify(() => mockRepo.update(const PrivacySettingsModel(
            contactKycOnly: true, hidePhoneNumber: true))).called(1);
        verify(() => mockAnalytics.logEvent(
              AnalyticsEvents.phoneVisibilityToggled,
              properties: {'hidden': true},
            )).called(1);
      },
    );

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'masquage refusé par le backend : rollback, et rien n\'est tracké',
      setUp: () {
        when(() => mockRepo.update(any()))
            .thenAnswer((_) async => throw Exception('Server error'));
      },
      build: buildBloc,
      seed: () => const PrivacySettingsLoaded(contactKycOnly: true),
      act: (bloc) => bloc.add(const HidePhoneNumberToggled(true)),
      expect: () => [
        isA<PrivacySettingsLoaded>()
            .having((s) => s.hidePhoneNumber, 'hidePhoneNumber', true),
        isA<PrivacySettingsLoaded>()
            .having((s) => s.hidePhoneNumber, 'hidePhoneNumber', false),
      ],
      verify: (_) {
        verifyInOrder([
          () => mockBox.put(HiveService.kHidePhoneNumber, true),
          () => mockBox.put(HiveService.kHidePhoneNumber, false),
        ]);
        // Un réglage qui n'a pas pris ne doit pas apparaître dans les stats
        // comme une décision de l'utilisateur.
        verifyNever(() => mockAnalytics.logEvent(
              AnalyticsEvents.phoneVisibilityToggled,
              properties: any(named: 'properties'),
            ));
      },
    );

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'révéler à nouveau son numéro repasse le drapeau à false',
      setUp: () {
        when(() => mockRepo.update(any())).thenAnswer((_) async {});
      },
      build: buildBloc,
      seed: () => const PrivacySettingsLoaded(
          contactKycOnly: false, hidePhoneNumber: true),
      act: (bloc) => bloc.add(const HidePhoneNumberToggled(false)),
      expect: () => [
        isA<PrivacySettingsLoaded>()
            .having((s) => s.hidePhoneNumber, 'hidePhoneNumber', false)
            .having((s) => s.contactKycOnly, 'contactKycOnly', false),
      ],
      verify: (_) {
        verify(() => mockAnalytics.logEvent(
              AnalyticsEvents.phoneVisibilityToggled,
              properties: {'hidden': false},
            )).called(1);
      },
    );

    // ── Equality des états ──────────────────────────────────────────────────

    test('PrivacySettingsLoaded equality est correcte', () {
      const a = PrivacySettingsLoaded(contactKycOnly: true);
      const b = PrivacySettingsLoaded(contactKycOnly: true);
      const c = PrivacySettingsLoaded(contactKycOnly: false);
      const d = PrivacySettingsLoaded(contactKycOnly: true, hidePhoneNumber: true);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('PrivacySettingsError equality est correcte', () {
      const a = PrivacySettingsError('msg');
      const b = PrivacySettingsError('msg');
      const c = PrivacySettingsError('autre');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith ne touche que le champ fourni', () {
      const base = PrivacySettingsLoaded(contactKycOnly: true);
      expect(base.copyWith(hidePhoneNumber: true),
          const PrivacySettingsLoaded(contactKycOnly: true, hidePhoneNumber: true));
      expect(base.copyWith(), base);
    });

    test('equality des events est correcte', () {
      expect(const HidePhoneNumberToggled(true),
          equals(const HidePhoneNumberToggled(true)));
      expect(const HidePhoneNumberToggled(true).hashCode,
          equals(const HidePhoneNumberToggled(true).hashCode));
      expect(const HidePhoneNumberToggled(true),
          isNot(equals(const HidePhoneNumberToggled(false))));
      // Deux events distincts portant la même valeur ne doivent pas se confondre :
      // `MockBloc.add` les vérifie par égalité dans les tests d'écran.
      expect(const HidePhoneNumberToggled(true),
          isNot(equals(const ContactKycOnlyToggled(true))));
      expect(const ContactKycOnlyToggled(true).hashCode,
          equals(const ContactKycOnlyToggled(true).hashCode));
    });
  });
}
