import 'dart:async';

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

UserModel _user({String id = 'u1', String? preferredLanguage}) => UserModel(
  id: id,
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

  // ── Passe finale (relecture) ─────────────────────────────────────────────

  blocTest<LanguageSyncCubit, LanguageSyncState>(
    'fr → en → fr : deux appels, jamais bloqué par un preferredLanguage périmé',
    build: () {
      when(() => repository.update('en')).thenAnswer((_) async => true);
      when(() => repository.update('fr')).thenAnswer((_) async => true);
      return LanguageSyncCubit(
        repository,
        makeEnabledAnalytics(backend)..onConfigured(),
      );
    },
    act: (c) async {
      // `user.preferredLanguage` reste 'fr' dans les trois appels : AuthBloc
      // ne se met jamais à jour après un PATCH. La comparaison doit donc
      // porter sur la dernière langue *serveur* connue, pas ce champ.
      final user = _user(preferredLanguage: 'fr');
      await c.sync(effective: 'fr', user: user); // déjà à jour : 0 appel
      await c.sync(effective: 'en', user: user); // appel 1
      await c.sync(effective: 'fr', user: user); // appel 2 (retour à fr)
    },
    expect: () => [
      const LanguageSyncState(synced: 'fr'),
      const LanguageSyncState(synced: 'en'),
      const LanguageSyncState(synced: 'fr'),
    ],
    verify: (_) {
      verify(() => repository.update('en')).called(1);
      verify(() => repository.update('fr')).called(1);
    },
  );

  blocTest<LanguageSyncCubit, LanguageSyncState>(
    'changement de compte (A → B) : la langue tentée par A ne bloque pas B',
    build: () {
      when(() => repository.update('en')).thenAnswer((_) async => true);
      return LanguageSyncCubit(
        repository,
        makeEnabledAnalytics(backend)..onConfigured(),
      );
    },
    act: (c) async {
      // A synchronise 'en' puis se déconnecte (l'app reste en anglais).
      await c.sync(
        effective: 'en',
        user: _user(id: 'user-a', preferredLanguage: 'fr'),
      );
      // B se connecte avec un compte serveur toujours en 'fr', app en 'en' :
      // avant le correctif, 'en' déjà globalement tenté bloquait B.
      await c.sync(
        effective: 'en',
        user: _user(id: 'user-b', preferredLanguage: 'fr'),
      );
    },
    // Un seul état émis : A et B convergent tous les deux vers `synced: 'en'`,
    // valeur identique à la précédente donc non réémise par le Cubit — la
    // preuve que B a bien été synchronisé passe par le compte d'appels.
    expect: () => [const LanguageSyncState(synced: 'en')],
    verify: (_) => verify(() => repository.update('en')).called(2),
  );

  test(
    'deux sync concurrents pour la même langue : un seul appel réseau',
    () async {
      final completer = Completer<bool>();
      when(() => repository.update('en')).thenAnswer((_) => completer.future);
      final analytics = makeEnabledAnalytics(backend);
      unawaited(analytics.onConfigured());
      final cubit = LanguageSyncCubit(repository, analytics);
      addTearDown(cubit.close);
      final user = _user(preferredLanguage: 'fr');

      // Ni l'un ni l'autre n'est attendu individuellement avant l'autre : le
      // second `sync` doit voir `_inFlight` déjà posé par le premier, qui n'a
      // pas encore résolu son PATCH.
      final first = cubit.sync(effective: 'en', user: user);
      final second = cubit.sync(effective: 'en', user: user);

      completer.complete(true);
      await first;
      await second;

      verify(() => repository.update('en')).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.preferredLanguageSynced, {
          'language': 'en',
        }),
      ).called(1);
    },
  );
}
