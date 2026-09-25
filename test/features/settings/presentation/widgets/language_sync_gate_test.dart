import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/bloc/language_sync_cubit.dart';
import 'package:dony/features/settings/bloc/language_sync_state.dart';
import 'package:dony/features/settings/data/repositories/user_language_repository.dart';
import 'package:dony/features/settings/presentation/widgets/language_sync_gate.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockLanguageSyncCubit extends MockCubit<LanguageSyncState>
    implements LanguageSyncCubit {}

class _MockUserLanguageRepository extends Mock
    implements UserLanguageRepository {}

UserModel _user() => const UserModel(
  id: 'u1',
  roles: ['ROLE_SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  preferredLanguage: 'fr',
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockLanguageSyncCubit cubit;

  setUpAll(() {
    registerFallbackValue(_user());
  });

  setUp(() {
    authBloc = _MockAuthBloc();
    cubit = _MockLanguageSyncCubit();
    when(() => authBloc.state).thenReturn(AuthAuthenticated(_user()));
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    when(
      () => cubit.sync(
        effective: any(named: 'effective'),
        user: any(named: 'user'),
      ),
    ).thenAnswer((_) async {});

    addTearDown(authBloc.close);
    addTearDown(cubit.close);
  });

  Widget wrap(Widget child) => MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<LanguageSyncCubit>.value(value: cubit),
    ],
    child: child,
  );

  testWidgets('langue fr résolue : sync appelé avec effective "fr"', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(wrap(const LanguageSyncGate(child: SizedBox.shrink()))),
    );

    verify(() => cubit.sync(effective: 'fr', user: _user())).called(1);
  });

  testWidgets('langue en résolue : sync appelé avec effective "en"', (
    tester,
  ) async {
    useEnglish();
    enableEnglish();

    await tester.pumpWidget(
      localizedApp(
        wrap(const LanguageSyncGate(child: SizedBox.shrink())),
        locale: AppL10n.en,
      ),
    );

    verify(() => cubit.sync(effective: 'en', user: _user())).called(1);
  });

  testWidgets(
    'connexion pendant que le gate est monté : sync rappelée avec le nouvel utilisateur',
    (tester) async {
      final loggedInUser = _user();
      // Invité au montage, puis connecté : le `BlocListener<AuthBloc>` doit
      // rejouer `sync` avec le nouvel utilisateur, sans attendre un
      // changement de langue.
      whenListen(
        authBloc,
        Stream.fromIterable([AuthAuthenticated(loggedInUser)]),
        initialState: const AuthGuestSessionReady(),
      );

      await tester.pumpWidget(
        localizedApp(wrap(const LanguageSyncGate(child: SizedBox.shrink()))),
      );
      await tester.pump();

      verify(() => cubit.sync(effective: 'fr', user: null)).called(1);
      verify(() => cubit.sync(effective: 'fr', user: loggedInUser)).called(1);
    },
  );

  testWidgets(
    'kEnglishEnabled faux : locale manuelle « en » ramenée à fr, préférence déjà fr → aucun appel réseau',
    (tester) async {
      // Bout en bout avec un vrai LanguageSyncCubit (pas de mock) : seul le
      // dépôt est simulé. Interrupteur forcé à `false` (`kEnglishEnabled`
      // vaut `true` depuis l'activation) — c'est justement ce que ce test
      // vérifie.
      AppL10n.debugEnglishEnabled = false;
      addTearDown(() => AppL10n.debugEnglishEnabled = null);
      final repository = _MockUserLanguageRepository();
      when(() => repository.update(any())).thenAnswer((_) async => true);
      final realCubit = LanguageSyncCubit(
        repository,
        makeEnabledAnalytics(MockAnalyticsBackend()),
      );
      addTearDown(realCubit.close);

      final realAuthBloc = _MockAuthBloc();
      when(() => realAuthBloc.state).thenReturn(AuthAuthenticated(_user()));
      when(() => realAuthBloc.stream).thenAnswer((_) => const Stream.empty());
      addTearDown(realAuthBloc.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: realAuthBloc),
            BlocProvider<LanguageSyncCubit>.value(value: realCubit),
          ],
          child: const MaterialApp(
            // Choix manuel « en », mais l'interrupteur reste éteint : le
            // callback doit ramener la locale effective à `fr`, exactement
            // comme dans `MaterialApp.router` de `app.dart`.
            locale: AppL10n.en,
            localeListResolutionCallback: AppL10n.localeListResolution,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LanguageSyncGate(child: SizedBox.shrink()),
          ),
        ),
      );

      verifyNever(() => repository.update(any()));
    },
  );
}
