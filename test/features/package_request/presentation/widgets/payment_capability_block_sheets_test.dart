import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/presentation/widgets/payment_capability_block_sheets.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/currency_test_doubles.dart';
import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/stripe_account_test_doubles.dart';

void main() {
  setUpAll(() => registerFallbackValue(const StripeAccountStatusLoaded()));

  Widget wrap({required MockStripeAccountBloc bloc, String? country = 'FR'}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, _) => Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<StripeAccountBloc>.value(value: bloc),
                BlocProvider<BusinessPrefsBloc>.value(
                  value: stubBusinessPrefsBloc(
                    state: BusinessPrefsState(country: country),
                  ),
                ),
              ],
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => showCardCapabilityRequiredSheet(ctx),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/connect/onboarding/intro',
          builder: (_, _) => const Scaffold(body: Text('ONBOARDING')),
        ),
        GoRoute(
          path: '/settings/preferences',
          builder: (ctx, _) => Scaffold(
            body: TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('PREFS'),
            ),
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
  }

  testWidgets(
    'Stripe disponible dans le pays → titre, corps et bouton d\'activation',
    (tester) async {
      await tester.pumpWidget(wrap(bloc: stubStripeAccountBloc()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(find.text('Paiement carte requis'), findsOneWidget);
      expect(
        find.textContaining('Active les paiements par carte'),
        findsOneWidget,
      );
      expect(find.text('Activer le paiement carte'), findsOneWidget);

      await tester.tap(find.text('Activer le paiement carte'));
      await tester.pumpAndSettle();

      expect(find.text('ONBOARDING'), findsOneWidget);
    },
  );

  testWidgets(
    'Stripe indisponible dans le pays → titre et bouton de fermeture',
    (tester) async {
      await tester.pumpWidget(
        wrap(bloc: stubStripeAccountBloc(state: stripeCountryUnavailableState)),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(find.text('Colis indisponible'), findsOneWidget);
      expect(
        find.textContaining('ne permet pas encore d\'ouvrir un compte'),
        findsOneWidget,
      );
      expect(find.text('J\'ai compris'), findsOneWidget);

      await tester.tap(find.text('J\'ai compris'));
      await tester.pumpAndSettle();

      expect(find.text('Colis indisponible'), findsNothing);
    },
  );

  testWidgets('anglais : titre, corps et bouton traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(wrap(bloc: stubStripeAccountBloc()));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.text('Card payment required'), findsOneWidget);
    expect(find.textContaining('Activate card payments'), findsWidgets);
  });

  testWidgets(
    'anglais, Stripe indisponible : titre et bouton "Got it" traduits',
    (tester) async {
      useEnglish();
      await tester.pumpWidget(
        wrap(bloc: stubStripeAccountBloc(state: stripeCountryUnavailableState)),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(find.text('Parcel unavailable'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
    },
  );

  group('pays du profil (FLUTTER-E9)', () {
    testWidgets(
      'pays connu non couvert → pays affiché + lien vers les préférences, '
      'statut redemandé au retour',
      (tester) async {
        final bloc = stubStripeAccountBloc(
          state: stripeCountryUnavailableState,
        );
        await tester.pumpWidget(wrap(bloc: bloc, country: 'SN'));
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();

        expect(
          find.text('Votre pays de résidence (profil) : Sénégal'),
          findsOneWidget,
        );
        expect(find.text('Modifier mon pays de résidence'), findsOneWidget);

        await tester.tap(find.text('Modifier mon pays de résidence'));
        await tester.pumpAndSettle();
        expect(find.text('PREFS'), findsOneWidget);
        expect(find.text('Colis indisponible'), findsNothing);
        verifyNever(
          () => bloc.add(any(that: isA<StripeAccountStatusRefreshed>())),
        );

        await tester.tap(find.text('PREFS'));
        await tester.pumpAndSettle();
        verify(
          () => bloc.add(any(that: isA<StripeAccountStatusRefreshed>())),
        ).called(1);
      },
    );

    testWidgets(
      'pays vide → « renseigne ton pays », jamais « pas disponible dans ton '
      'pays »',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            bloc: stubStripeAccountBloc(state: stripeCountryUnavailableState),
            country: null,
          ),
        );
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Renseigne ton pays de résidence pour activer le paiement carte',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('ne permet pas encore'), findsNothing);
        expect(find.text('Colis indisponible'), findsNothing);
        expect(find.text('Paiement carte requis'), findsOneWidget);

        await tester.tap(find.byKey(const Key('card-capability-set-country')));
        await tester.pumpAndSettle();
        expect(find.text('PREFS'), findsOneWidget);
      },
    );

    testWidgets('pays blanc traité comme vide', (tester) async {
      await tester.pumpWidget(
        wrap(
          bloc: stubStripeAccountBloc(state: stripeCountryUnavailableState),
          country: '  ',
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('card-capability-country-missing')),
        findsOneWidget,
      );
    });

    testWidgets('anglais : pays du profil traduit', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        wrap(bloc: stubStripeAccountBloc(state: stripeCountryUnavailableState)),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(
        find.text('Your country of residence (profile): France'),
        findsOneWidget,
      );
      expect(find.text('Change my country of residence'), findsOneWidget);
    });
  });

  group('acceptsCardOnly', () {
    test('carte seule → vrai', () {
      expect(acceptsCardOnly({PaymentMethod.stripe}), isTrue);
    });
    test('carte + rail retiré (Wave) → toujours carte seule', () {
      expect(
        acceptsCardOnly({PaymentMethod.stripe, PaymentMethod.wave}),
        isTrue,
      );
    });
    test('carte + espèces ou mobile money → faux', () {
      expect(
        acceptsCardOnly({PaymentMethod.stripe, PaymentMethod.cash}),
        isFalse,
      );
      expect(
        acceptsCardOnly({PaymentMethod.stripe, PaymentMethod.mobileMoney}),
        isFalse,
      );
    });
    test('sans carte ou vide → faux', () {
      expect(acceptsCardOnly({PaymentMethod.cash}), isFalse);
      expect(acceptsCardOnly(const {}), isFalse);
    });
  });

  group('knownCardCapabilityGap', () {
    test('statut inconnu (initial, chargement, erreur) → null', () {
      for (final s in const <StripeAccountState>[
        StripeAccountInitial(),
        StripeAccountLoading(),
        StripeAccountLoadError(),
      ]) {
        expect(knownCardCapabilityGap(s, profileCountry: 'FR'), isNull);
      }
    });
    test('compte complet → null', () {
      expect(
        knownCardCapabilityGap(
          const StripeAccountReady(
            ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
          ),
          profileCountry: 'FR',
        ),
        isNull,
      );
    });
    test('pays couvert, pas de compte → activatable', () {
      expect(
        knownCardCapabilityGap(
          const StripeAccountReady(
            ConnectAccountStatus(status: 'PENDING_ONBOARDING'),
          ),
          profileCountry: 'FR',
        ),
        CardCapabilityGap.activatable,
      );
    });
    test('pays non couvert : vide → countryMissing, sinon unsupported', () {
      expect(
        knownCardCapabilityGap(
          stripeCountryUnavailableState,
          profileCountry: null,
        ),
        CardCapabilityGap.countryMissing,
      );
      expect(
        knownCardCapabilityGap(
          stripeCountryUnavailableState,
          profileCountry: 'SN',
        ),
        CardCapabilityGap.countryUnsupported,
      );
    });
  });
}
