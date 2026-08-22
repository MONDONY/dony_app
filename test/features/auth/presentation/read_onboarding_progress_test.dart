import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';
import '../../../helpers/stripe_account_test_doubles.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _MockBusinessPrefsBloc
    extends MockBloc<BusinessPrefsEvent, BusinessPrefsState>
    implements BusinessPrefsBloc {}

class _FakeBusinessPrefsEvent extends Fake implements BusinessPrefsEvent {}

/// `readOnboardingProgress` est le seul point impur d'`onboarding_step.dart` :
/// il lit `AuthBloc`, `StripeAccountBloc` et `BusinessPrefsBloc` fournis à
/// l'échelle de l'app. Ces tests verrouillent son contrat sur
/// `countryFallback` — le paramètre qui a corrigé une régression réelle
/// (revue tâche 4) : `router.dart` doit pouvoir lui passer une source plus
/// fraîche que `BusinessPrefsBloc.state.country` (`state.extra`, juste après
/// un `CountryOnboardingCubit.select()` réussi, qui n'écrit jamais dans ce
/// Bloc — seulement dans Hive, sans dispatcher `CountryChanged`).
void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
    registerFallbackValue(_FakeBusinessPrefsEvent());
  });

  late _MockAuthBloc authBloc;
  late MockStripeAccountBloc stripeBloc;
  late _MockBusinessPrefsBloc businessPrefsBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    stripeBloc = stubStripeAccountBloc();
    businessPrefsBloc = _MockBusinessPrefsBloc();
    when(() => authBloc.state).thenReturn(const AuthInitial());
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    // Le Bloc jamais resynchronisé après `CountryOnboardingCubit.select()` :
    // `country` reste `null` dans tous les tests de ce fichier.
    when(() => businessPrefsBloc.state).thenReturn(const BusinessPrefsState());
    when(
      () => businessPrefsBloc.stream,
    ).thenAnswer((_) => const Stream.empty());

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(
      makeDisabledAnalytics(MockAnalyticsBackend()),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  Future<OnboardingProgress> readVia(
    WidgetTester tester, {
    String? countryFallback,
  }) async {
    late OnboardingProgress result;
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<StripeAccountBloc>.value(value: stripeBloc),
          BlocProvider<BusinessPrefsBloc>.value(value: businessPrefsBloc),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              result = readOnboardingProgress(
                context,
                current: OnboardingStep.address,
                countryFallback: countryFallback,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return result;
  }

  testWidgets('sans countryFallback explicite, le pays reste non fait quand '
      'BusinessPrefsBloc.state.country est null (repli par défaut inchangé)', (
    tester,
  ) async {
    final progress = await readVia(tester);

    expect(progress.done.contains(OnboardingStep.country), isFalse);
  });

  testWidgets(
    'countryFallback explicite (le pays arrive par `extra`) compte l\'étape '
    'Pays comme faite même si BusinessPrefsBloc.state.country est null — '
    'verrouille la régression corrigée sur router.dart',
    (tester) async {
      final progress = await readVia(tester, countryFallback: 'FR');

      expect(progress.done.contains(OnboardingStep.country), isTrue);
    },
  );
}
