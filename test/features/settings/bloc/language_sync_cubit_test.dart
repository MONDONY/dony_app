import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/bloc/language_sync_cubit.dart';
import 'package:dony/features/settings/bloc/language_sync_state.dart';
import 'package:dony/features/settings/data/repositories/user_language_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockUserLanguageRepository extends Mock
    implements UserLanguageRepository {}

UserModel _user({String? preferredLanguage}) => UserModel(
  id: 'u1',
  roles: const ['ROLE_SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  preferredLanguage: preferredLanguage,
);

void main() {
  late _MockUserLanguageRepository repository;
  late MockAnalyticsBackend backend;

  setUp(() {
    repository = _MockUserLanguageRepository();
    backend = MockAnalyticsBackend();
  });

  blocTest<LanguageSyncCubit, LanguageSyncState>(
    'sans utilisateur (invité ou déconnecté) : aucun appel',
    build: () => LanguageSyncCubit(repository, makeEnabledAnalytics(backend)),
    act: (c) => c.sync(effective: 'fr', user: null),
    expect: () => <LanguageSyncState>[],
    verify: (_) {
      verifyNever(() => repository.update(any()));
      verifyNever(() => backend.capture(any(), any()));
    },
  );

  blocTest<LanguageSyncCubit, LanguageSyncState>(
    'langue déjà à jour côté serveur : aucun appel, état synced',
    build: () => LanguageSyncCubit(repository, makeEnabledAnalytics(backend)),
    act: (c) => c.sync(
      effective: 'fr',
      user: _user(preferredLanguage: 'fr'),
    ),
    expect: () => [const LanguageSyncState(synced: 'fr')],
    verify: (_) => verifyNever(() => repository.update(any())),
  );

  blocTest<LanguageSyncCubit, LanguageSyncState>(
    'langue différente : un appel et l\'événement analytics',
    build: () {
      when(() => repository.update('en')).thenAnswer((_) async => true);
      return LanguageSyncCubit(
        repository,
        makeEnabledAnalytics(backend)..onConfigured(),
      );
    },
    act: (c) => c.sync(
      effective: 'en',
      user: _user(preferredLanguage: 'fr'),
    ),
    expect: () => [const LanguageSyncState(synced: 'en')],
    verify: (_) {
      verify(() => repository.update('en')).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.preferredLanguageSynced, {
          'language': 'en',
        }),
      ).called(1);
    },
  );

  blocTest<LanguageSyncCubit, LanguageSyncState>(
    'deuxième sync identique : pas de second appel',
    build: () {
      when(() => repository.update('en')).thenAnswer((_) async => true);
      return LanguageSyncCubit(
        repository,
        makeEnabledAnalytics(backend)..onConfigured(),
      );
    },
    act: (c) async {
      await c.sync(
        effective: 'en',
        user: _user(preferredLanguage: 'fr'),
      );
      await c.sync(
        effective: 'en',
        user: _user(preferredLanguage: 'fr'),
      );
    },
    expect: () => [const LanguageSyncState(synced: 'en')],
    verify: (_) => verify(() => repository.update('en')).called(1),
  );

  blocTest<LanguageSyncCubit, LanguageSyncState>(
    '404 (backend ancien) : pas de relance',
    build: () {
      when(() => repository.update('en')).thenAnswer((_) async => false);
      return LanguageSyncCubit(
        repository,
        makeEnabledAnalytics(backend)..onConfigured(),
      );
    },
    act: (c) async {
      await c.sync(
        effective: 'en',
        user: _user(preferredLanguage: 'fr'),
      );
      await c.sync(
        effective: 'en',
        user: _user(preferredLanguage: 'fr'),
      );
    },
    expect: () => <LanguageSyncState>[],
    verify: (_) {
      verify(() => repository.update('en')).called(1);
      verifyNever(() => backend.capture(any(), any()));
    },
  );

  blocTest<LanguageSyncCubit, LanguageSyncState>(
    'exception réseau : nouvel essai au sync suivant',
    build: () {
      when(() => repository.update('en')).thenThrow(Exception('network'));
      return LanguageSyncCubit(
        repository,
        makeEnabledAnalytics(backend)..onConfigured(),
      );
    },
    act: (c) async {
      await c.sync(
        effective: 'en',
        user: _user(preferredLanguage: 'fr'),
      );
      await c.sync(
        effective: 'en',
        user: _user(preferredLanguage: 'fr'),
      );
    },
    expect: () => <LanguageSyncState>[],
    verify: (_) {
      verify(() => repository.update('en')).called(2);
      verifyNever(() => backend.capture(any(), any()));
    },
  );

  blocTest<LanguageSyncCubit, LanguageSyncState>(
    'preferredLanguage == null (backend ancien) : un seul appel',
    build: () {
      when(() => repository.update('fr')).thenAnswer((_) async => true);
      return LanguageSyncCubit(
        repository,
        makeEnabledAnalytics(backend)..onConfigured(),
      );
    },
    act: (c) async {
      await c.sync(effective: 'fr', user: _user());
      await c.sync(effective: 'fr', user: _user());
    },
    expect: () => [const LanguageSyncState(synced: 'fr')],
    verify: (_) => verify(() => repository.update('fr')).called(1),
  );
}
