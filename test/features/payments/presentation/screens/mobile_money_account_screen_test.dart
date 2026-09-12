import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/presentation/screens/mobile_money_account_screen.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_networks_checklist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends Mock implements MobileMoneyAccountBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

/// [phoneNumber] nul ou vide simule un compte Firebase sans téléphone
/// (vérification SMS pas encore configurée).
AuthBloc _authBlocWithPhone(String? phoneNumber) {
  final authBloc = _MockAuthBloc();
  whenListen(
    authBloc,
    const Stream<AuthState>.empty(),
    initialState: AuthAuthenticated(
      UserModel(
        id: 'u1',
        roles: const [],
        kycStatus: 'VERIFIED',
        status: 'ACTIVE',
        phoneNumber: phoneNumber,
      ),
    ),
  );
  return authBloc;
}

void main() {
  late _MockBloc bloc;

  const notConfiguredAccount = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.notConfigured,
  );

  // `providers` porte désormais la pastille de réseau affichée dans la carte
  // « Réseaux acceptés » de la nouvelle vue active : sans elle, `providerLabel`
  // (champ de repli, non lu par cette carte) ne s'afficherait nulle part.
  const activeAccount = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.active,
    msisdnMasked: '+225 07 ** ** 67',
    providerLabel: 'Wave',
    country: 'CI',
    currency: 'XOF',
    providers: [MobileMoneyProviderOption(code: 'WAVE_CIV', label: 'Wave')],
  );

  const disabledAccount = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.disabled,
  );

  // Numéro précédent connu (compte réactivé depuis un état désactivé) : le
  // formulaire affiche un rappel dédié dans ce cas, absent quand
  // msisdnMasked est nul (disabledAccount ci-dessus).
  const disabledAccountWithNumber = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.disabled,
    msisdnMasked: '+225 07 ** ** 67',
  );

  const catalog = MobileMoneyProviderCatalog(
    country: 'CI',
    currency: 'XOF',
    msisdnMasked: '+225 •••• 36',
    detected: 'ORANGE_CIV',
    providers: [
      MobileMoneyProviderOption(
        code: 'ORANGE_CIV',
        label: 'Orange Money',
        detected: true,
      ),
      MobileMoneyProviderOption(code: 'WAVE_CIV', label: 'Wave'),
    ],
  );
  const activeWithNetworks = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.active,
    msisdnMasked: '+225 •••• 36',
    provider: 'ORANGE_CIV',
    providerLabel: 'Orange Money',
    country: 'CI',
    currency: 'XOF',
    providers: [
      MobileMoneyProviderOption(code: 'ORANGE_CIV', label: 'Orange Money'),
      MobileMoneyProviderOption(code: 'WAVE_CIV', label: 'Wave'),
    ],
  );

  setUpAll(() {
    // MobileMoneyAccountEvent est sealed : le fallback est un vrai événement.
    registerFallbackValue(const MobileMoneyAccountRequested());
  });

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.add(any())).thenReturn(null);
  });

  void stub(MobileMoneyAccountState state) {
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => Stream<MobileMoneyAccountState>.value(state));
  }

  /// [settle] reste faux tant qu'un CircularProgressIndicator tourne : son
  /// animation ne s'arrête jamais et ferait expirer pumpAndSettle.
  ///
  /// [authBloc] optionnel : le formulaire de numéro de versement lit
  /// `AuthBloc` pour pré-remplir son premier champ mais tolère son absence
  /// (`ProviderNotFoundException` rattrapée, champ vide, jamais de
  /// plantage) — la plupart des tests ne le fournissent donc pas.
  Future<void> pumpScreen(
    WidgetTester tester, {
    bool settle = true,
    AuthBloc? authBloc,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<MobileMoneyAccountBloc>.value(
            value: bloc,
            child: const MobileMoneyAccountScreen(),
          ),
        ),
      ],
    );
    final app = MaterialApp.router(routerConfig: router);
    await tester.pumpWidget(
      authBloc == null
          ? app
          : BlocProvider<AuthBloc>.value(value: authBloc, child: app),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  /// Widget `TextField` interne au [DonyTextField] portant [key], pour lire
  /// le texte réellement affiché par son contrôleur.
  TextField textFieldByKey(Key key) =>
      (find.descendant(
            of: find.byKey(key),
            matching: find.byType(TextField),
          )).evaluate().single.widget
          as TextField;

  testWidgets('état initial : indicateur de chargement', (tester) async {
    stub(const MobileMoneyAccountInitial());

    await pumpScreen(tester, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Versement mobile money'), findsOneWidget);
  });

  testWidgets('chargement en cours : indicateur de chargement', (tester) async {
    stub(const MobileMoneyAccountLoading());

    await pumpScreen(tester, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  group('Zone sûre', () {
    testWidgets('le corps est protégé de la barre de navigation système', (
      tester,
    ) async {
      stub(const MobileMoneyAccountInitial());
      await pumpScreen(tester, settle: false);
      await tester.pump();
      // L'AppBar porte sa propre SafeArea (haut seulement) : on cible celle
      // du corps, qui protège le bouton bas de la barre de navigation.
      expect(
        find.byWidgetPredicate(
          (w) => w is SafeArea && !w.top && w.bottom,
          description: 'SafeArea du corps (bas seulement)',
        ),
        findsOneWidget,
      );
    });
  });

  // Décision produit (round 2) : le numéro mobile money est désormais
  // TOUJOURS demandé pour activer le versement, qu'il y ait ou non un
  // numéro sur le profil — il peut légitimement différer du numéro Firebase
  // (le backend PR #274 privilégie le numéro fourni, puis le numéro
  // Firebase, puis 422 mobile-money-phone-required). Le formulaire
  // `_PayoutNumberForm` s'affiche donc systématiquement pour `Loaded` et
  // pour `PhoneRequired`, qui rendent désormais la même vue.
  group(
    'Vue non configurée — formulaire de numéro de versement (toujours affiché)',
    () {
      testWidgets(
        'formulaire affiché avec l\'explication et les deux champs, bouton '
        'inactif tant que rien n\'est saisi (sans AuthBloc)',
        (tester) async {
          stub(const MobileMoneyAccountLoaded(notConfiguredAccount));

          await pumpScreen(tester);

          expect(find.text('Numéro de versement'), findsOneWidget);
          expect(find.text('Confirme le numéro'), findsOneWidget);
          expect(
            find.textContaining(
              'Indique le numéro mobile money qui recevra tes versements. '
              'Il peut être différent de ton numéro Yadony',
            ),
            findsOneWidget,
          );
          expect(
            find.text('Activer le versement mobile money'),
            findsOneWidget,
          );

          final button = tester.widget<DonyButton>(find.byType(DonyButton));
          expect(button.onPressed, isNull);
        },
      );

      testWidgets(
        'les deux champs remplis et identiques (normalisés) : le réseau '
        'détecté est déjà coché, le bouton envoie ActivateRequested avec '
        'le numéro et les réseaux',
        (tester) async {
          // Le bouton exige désormais aussi le catalogue et au moins un
          // réseau coché (voir le groupe « catalogue dans le formulaire ») :
          // le catalogue est donc déjà chargé au premier pump.
          stub(
            const MobileMoneyAccountProvidersLoaded(
              notConfiguredAccount,
              catalog,
            ),
          );

          await pumpScreen(tester);

          // Le réseau détecté est pré-coché dès l'arrivée du catalogue,
          // avant toute saisie (round 1, Ruling A5 : présélection dès
          // initState, pas seulement sur une transition ultérieure).
          expect(
            tester
                .widget<DonyOperatorTile>(
                  find.byKey(const Key('network-ORANGE_CIV')),
                )
                .selected,
            isTrue,
          );

          await tester.enterText(
            find.byKey(const Key('payout-phone-field')),
            '+221773456789',
          );
          await tester.pump();
          await tester.enterText(
            find.byKey(const Key('payout-phone-confirm-field')),
            '+221773456789',
          );
          await tester.pump();

          final button = tester.widget<DonyButton>(
            find.widgetWithText(
              DonyButton,
              'Activer le versement mobile money',
            ),
          );
          expect(button.onPressed, isNotNull);

          await tester.tap(find.text('Activer le versement mobile money'));
          await tester.pump();

          verify(
            () => bloc.add(
              const MobileMoneyAccountActivateRequested(
                phoneNumber: '+221773456789',
                providers: ['ORANGE_CIV'],
              ),
            ),
          ).called(1);

          // Purge le timer de re-demande du catalogue (déjà chargé ici) pour
          // ne pas laisser de Timer en attente à la fin du test.
          await tester.pump(const Duration(milliseconds: 450));
        },
      );

      testWidgets(
        'utilisateur connecté sans numéro → premier champ démarre vide',
        (tester) async {
          stub(const MobileMoneyAccountLoaded(notConfiguredAccount));

          await pumpScreen(tester, authBloc: _authBlocWithPhone(null));

          expect(
            textFieldByKey(const Key('payout-phone-field')).controller!.text,
            isEmpty,
          );
        },
      );

      testWidgets(
        'numéro vide côté profil (chaîne vide, pas seulement nul) → premier '
        'champ démarre vide aussi',
        (tester) async {
          stub(const MobileMoneyAccountLoaded(notConfiguredAccount));

          await pumpScreen(tester, authBloc: _authBlocWithPhone(''));

          expect(
            textFieldByKey(const Key('payout-phone-field')).controller!.text,
            isEmpty,
          );
        },
      );

      testWidgets(
        'les deux saisies doivent coïncider (normalisées) pour activer le '
        'bouton (réseau détecté déjà coché), qui envoie alors le numéro '
        'normalisé et les réseaux',
        (tester) async {
          stub(
            const MobileMoneyAccountProvidersLoaded(
              notConfiguredAccount,
              catalog,
            ),
          );

          await pumpScreen(tester, authBloc: _authBlocWithPhone(null));

          // Le réseau détecté est pré-coché dès l'arrivée du catalogue,
          // avant toute saisie.
          expect(
            tester
                .widget<DonyOperatorTile>(
                  find.byKey(const Key('network-ORANGE_CIV')),
                )
                .selected,
            isTrue,
          );

          await tester.enterText(
            find.byKey(const Key('payout-phone-field')),
            '+221 77 345 67 89',
          );
          await tester.pump();
          // Saisies différentes : le bouton reste inactif.
          await tester.enterText(
            find.byKey(const Key('payout-phone-confirm-field')),
            '+221 77 345 67 88',
          );
          await tester.pump();

          var button = tester.widget<DonyButton>(find.byType(DonyButton));
          expect(button.onPressed, isNull);

          // Même numéro, écrit avec des espaces différents : la
          // normalisation les fait coïncider. Le réseau détecté reste
          // coché : le bouton s'active directement.
          await tester.enterText(
            find.byKey(const Key('payout-phone-confirm-field')),
            '+221773456789',
          );
          await tester.pump();

          button = tester.widget<DonyButton>(find.byType(DonyButton));
          expect(button.onPressed, isNotNull);

          await tester.tap(find.text('Activer le versement mobile money'));
          await tester.pump();

          verify(
            () => bloc.add(
              const MobileMoneyAccountActivateRequested(
                phoneNumber: '+221773456789',
                providers: ['ORANGE_CIV'],
              ),
            ),
          ).called(1);

          // Purge le timer de re-demande du catalogue (déjà chargé ici)
          // pour ne pas laisser de Timer en attente à la fin du test.
          await tester.pump(const Duration(milliseconds: 450));
        },
      );

      testWidgets(
        'état PhoneRequired → formulaire affiché, premier champ pré-rempli '
        'avec le numéro du profil (le backend fait autorité sur le refus, '
        'pas sur le pré-remplissage)',
        (tester) async {
          stub(const MobileMoneyAccountPhoneRequired(notConfiguredAccount));

          await pumpScreen(
            tester,
            authBloc: _authBlocWithPhone('+221770000000'),
          );

          expect(find.text('Numéro de versement'), findsOneWidget);
          // Jamais de snackbar pour ce cas : ce n'est pas une
          // MobileMoneyAccountError.
          expect(find.byType(SnackBar), findsNothing);
          expect(
            textFieldByKey(const Key('payout-phone-field')).controller!.text,
            '+221770000000',
          );
        },
      );

      testWidgets(
        'utilisateur connecté avec un numéro → premier champ pré-rempli, '
        'confirmation vide, bouton inactif jusqu\'à confirmation identique '
        '(réseau détecté déjà coché)',
        (tester) async {
          stub(
            const MobileMoneyAccountProvidersLoaded(
              notConfiguredAccount,
              catalog,
            ),
          );

          await pumpScreen(
            tester,
            authBloc: _authBlocWithPhone('+221771234567'),
          );

          expect(
            textFieldByKey(const Key('payout-phone-field')).controller!.text,
            '+221771234567',
          );
          expect(
            textFieldByKey(
              const Key('payout-phone-confirm-field'),
            ).controller!.text,
            isEmpty,
          );
          // Le réseau détecté est déjà coché, mais la confirmation est
          // encore vide : le bouton reste inactif.
          expect(
            tester
                .widget<DonyOperatorTile>(
                  find.byKey(const Key('network-ORANGE_CIV')),
                )
                .selected,
            isTrue,
          );

          var button = tester.widget<DonyButton>(find.byType(DonyButton));
          expect(button.onPressed, isNull);

          await tester.enterText(
            find.byKey(const Key('payout-phone-confirm-field')),
            '+221771234567',
          );
          await tester.pump();

          button = tester.widget<DonyButton>(find.byType(DonyButton));
          expect(button.onPressed, isNotNull);

          await tester.tap(find.text('Activer le versement mobile money'));
          await tester.pump();

          verify(
            () => bloc.add(
              const MobileMoneyAccountActivateRequested(
                phoneNumber: '+221771234567',
                providers: ['ORANGE_CIV'],
              ),
            ),
          ).called(1);

          // Purge le timer de re-demande du catalogue (déjà chargé ici)
          // pour ne pas laisser de Timer en attente à la fin du test.
          await tester.pump(const Duration(milliseconds: 450));
        },
      );
    },
  );

  group('Vue active', () {
    testWidgets('opérateur, numéro masqué, devise et badge actif', (
      tester,
    ) async {
      stub(const MobileMoneyAccountLoaded(activeAccount));

      await pumpScreen(tester);

      expect(find.text('Wave'), findsOneWidget);
      expect(find.text('+225 07 ** ** 67'), findsOneWidget);
      expect(find.text('XOF'), findsOneWidget);
      expect(find.text('ACTIF'), findsOneWidget);
      expect(find.text('Désactiver'), findsOneWidget);
    });

    testWidgets('le bouton envoie DisableRequested', (tester) async {
      stub(const MobileMoneyAccountLoaded(activeAccount));

      await pumpScreen(tester);

      await tester.tap(find.text('Désactiver'));
      await tester.pump();

      verify(
        () => bloc.add(const MobileMoneyAccountDisableRequested()),
      ).called(1);
    });
  });

  // Décision produit (round 2) : la réactivation redemande elle aussi
  // toujours un numéro (même formulaire que l'activation initiale), avec un
  // rappel du numéro masqué précédent quand il est connu.
  group('Vue désactivée', () {
    testWidgets(
      'formulaire affiché sans rappel de numéro (aucun numéro précédent '
      'connu), bouton Réactiver inactif sans saisie',
      (tester) async {
        stub(const MobileMoneyAccountLoaded(disabledAccount));

        await pumpScreen(tester);

        expect(
          find.text(
            'Ton versement est désactivé. Indique le numéro mobile money '
            'pour le réactiver.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('précédent'), findsNothing);
        expect(find.text('Numéro de versement'), findsOneWidget);
        expect(find.text('Confirme le numéro'), findsOneWidget);
        expect(find.text('Réactiver'), findsOneWidget);

        final button = tester.widget<DonyButton>(find.byType(DonyButton));
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'numéro précédent connu → rappel affiché avec le numéro masqué',
      (tester) async {
        stub(const MobileMoneyAccountLoaded(disabledAccountWithNumber));

        await pumpScreen(tester);

        expect(
          find.text(
            'Ton versement est désactivé. Indique le numéro mobile money '
            'pour le réactiver (précédent : +225 07 ** ** 67).',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'les deux champs remplis et identiques (réseau détecté déjà coché) → '
      'le bouton Réactiver envoie ActivateRequested avec le numéro et les '
      'réseaux',
      (tester) async {
        stub(const MobileMoneyAccountProvidersLoaded(disabledAccount, catalog));

        await pumpScreen(tester);

        // Le réseau détecté est pré-coché dès l'arrivée du catalogue, avant
        // toute saisie.
        expect(
          tester
              .widget<DonyOperatorTile>(
                find.byKey(const Key('network-ORANGE_CIV')),
              )
              .selected,
          isTrue,
        );

        await tester.enterText(
          find.byKey(const Key('payout-phone-field')),
          '+221773456789',
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('payout-phone-confirm-field')),
          '+221773456789',
        );
        await tester.pump();

        final button = tester.widget<DonyButton>(
          find.widgetWithText(DonyButton, 'Réactiver'),
        );
        expect(button.onPressed, isNotNull);

        await tester.tap(find.text('Réactiver'));
        await tester.pump();

        verify(
          () => bloc.add(
            const MobileMoneyAccountActivateRequested(
              phoneNumber: '+221773456789',
              providers: ['ORANGE_CIV'],
            ),
          ),
        ).called(1);

        // Purge le timer de re-demande du catalogue (déjà chargé ici) pour
        // ne pas laisser de Timer en attente à la fin du test.
        await tester.pump(const Duration(milliseconds: 450));
      },
    );
  });

  testWidgets(
    'Updating : le bouton passe en isLoading et le tap n\'envoie rien',
    (tester) async {
      stub(const MobileMoneyAccountUpdating(notConfiguredAccount));

      await pumpScreen(tester, settle: false);

      final button = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(button.isLoading, isTrue);

      await tester.tap(find.byType(DonyButton));
      await tester.pump();

      verifyNever(() => bloc.add(any()));
    },
  );

  testWidgets('Error avec compte connu : la vue du compte est affichée', (
    tester,
  ) async {
    stub(
      const MobileMoneyAccountError(
        NetworkException('boom interne'),
        account: activeAccount,
      ),
    );

    await pumpScreen(tester);

    // Jamais le détail technique brut affiché à l'utilisateur.
    expect(find.text('boom interne'), findsNothing);
    expect(find.text('Wave'), findsOneWidget);
    expect(find.text('ACTIF'), findsOneWidget);
    // Le listener a bien déclenché ErrorPresenter (snackbar générique).
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets(
    'Error sans compte connu : état vide, Réessayer relance la demande',
    (tester) async {
      stub(const MobileMoneyAccountError(NetworkException('boom interne')));

      await pumpScreen(tester);

      expect(find.text('boom interne'), findsNothing);
      expect(find.text('Impossible de charger ton compte'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(() => bloc.add(const MobileMoneyAccountRequested())).called(1);
    },
  );

  group('catalogue dans le formulaire', () {
    testWidgets(
      'non configuré : invite à confirmer le numéro, bouton désactivé',
      (tester) async {
        stub(const MobileMoneyAccountLoaded(notConfiguredAccount));
        await pumpScreen(tester);
        expect(
          find.text('Confirme ton numéro pour voir les réseaux disponibles.'),
          findsOneWidget,
        );
        final button = tester.widget<DonyButton>(
          find.widgetWithText(DonyButton, 'Activer le versement mobile money'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'saisir deux fois le même numéro demande le catalogue après le délai',
      (tester) async {
        stub(const MobileMoneyAccountLoaded(notConfiguredAccount));
        await pumpScreen(tester);
        await tester.enterText(
          find.byKey(const Key('payout-phone-field')),
          '+225 07 08 09 10 36',
        );
        await tester.enterText(
          find.byKey(const Key('payout-phone-confirm-field')),
          '+225 07 08 09 10 36',
        );
        await tester.pump(const Duration(milliseconds: 450));
        verify(
          () => bloc.add(
            const MobileMoneyAccountProvidersRequested(
              phoneNumber: '+2250708091036',
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'catalogue chargé : liste des réseaux, détecté pré-coché, bouton actif',
      (tester) async {
        stub(
          const MobileMoneyAccountProvidersLoaded(
            notConfiguredAccount,
            catalog,
          ),
        );
        await pumpScreen(tester);
        expect(find.text('Tous les réseaux'), findsOneWidget);
        expect(find.text('Orange Money'), findsOneWidget);
        expect(find.text('Wave'), findsOneWidget);
        expect(find.text("Côte d'Ivoire, XOF"), findsOneWidget);
        expect(
          find.text(
            "L'expéditeur paie avec l'un des réseaux cochés. Tu reçois sur ce même réseau.",
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<DonyOperatorTile>(
                find.byKey(const Key('network-ORANGE_CIV')),
              )
              .selected,
          isTrue,
        );

        // Confirme un numéro pour observer le bouton s'activer (réseau
        // détecté déjà coché). Le timer de re-demande programmé par cette
        // saisie est purgé après coup, sans effet sur les assertions
        // ci-dessus.
        await tester.enterText(
          find.byKey(const Key('payout-phone-field')),
          '+221773456789',
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('payout-phone-confirm-field')),
          '+221773456789',
        );
        await tester.pump();

        final button = tester.widget<DonyButton>(
          find.widgetWithText(DonyButton, 'Activer le versement mobile money'),
        );
        expect(button.onPressed, isNotNull);

        await tester.pump(const Duration(milliseconds: 450));
      },
    );

    testWidgets('catalogue en chargement : squelette', (tester) async {
      stub(const MobileMoneyAccountProvidersLoading(notConfiguredAccount));
      await pumpScreen(tester);
      expect(find.byType(MobileMoneyNetworksSkeleton), findsOneWidget);
    });

    testWidgets('catalogue en erreur : bandeau, pas de snackbar', (
      tester,
    ) async {
      stub(
        const MobileMoneyAccountProvidersError(
          notConfiguredAccount,
          ValidationException('x', code: 'mobile-money-account-unsupported'),
        ),
      );
      await pumpScreen(tester);
      expect(find.byType(DonyStatusBanner), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'catalogue en erreur : « Réessayer » redemande le catalogue pour le '
      'numéro confirmé',
      (tester) async {
        stub(
          const MobileMoneyAccountProvidersError(
            notConfiguredAccount,
            ValidationException('x', code: 'mobile-money-account-unsupported'),
          ),
        );
        await pumpScreen(tester);
        await tester.enterText(
          find.byKey(const Key('payout-phone-field')),
          '+221773456789',
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('payout-phone-confirm-field')),
          '+221773456789',
        );
        await tester.pump();

        await tester.ensureVisible(find.text('Réessayer'));
        await tester.tap(find.text('Réessayer'));
        await tester.pump();

        verify(
          () => bloc.add(
            const MobileMoneyAccountProvidersRequested(
              phoneNumber: '+221773456789',
            ),
          ),
        ).called(1);

        // Purge le timer de re-demande programmé par la saisie ci-dessus
        // pour ne pas laisser de Timer en attente à la fin du test.
        await tester.pump(const Duration(milliseconds: 450));
      },
    );

    testWidgets(
      'ancien back sans catalogue (404) : bandeau info à la place de la '
      'checklist, activation possible dès le numéro confirmé, sans réseau',
      (tester) async {
        stub(
          const MobileMoneyAccountProvidersUnavailable(notConfiguredAccount),
        );
        await pumpScreen(tester);

        expect(
          find.text(
            "Le choix des réseaux n'est pas encore disponible. Ton "
            'opérateur sera détecté automatiquement.',
          ),
          findsOneWidget,
        );
        expect(find.byType(MobileMoneyNetworksChecklist), findsNothing);

        expect(
          tester
              .widget<DonyButton>(
                find.widgetWithText(
                  DonyButton,
                  'Activer le versement mobile money',
                ),
              )
              .onPressed,
          isNull,
        );

        await tester.enterText(
          find.byKey(const Key('payout-phone-field')),
          '+221773456789',
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('payout-phone-confirm-field')),
          '+221773456789',
        );
        await tester.pump();

        expect(
          tester
              .widget<DonyButton>(
                find.widgetWithText(
                  DonyButton,
                  'Activer le versement mobile money',
                ),
              )
              .onPressed,
          isNotNull,
        );

        await tester.tap(
          find.widgetWithText(DonyButton, 'Activer le versement mobile money'),
        );
        await tester.pump();

        // Le back ancien accepte {phoneNumber} seul : le repository omet
        // providers vide plutôt que de l'envoyer explicitement.
        verify(
          () => bloc.add(
            const MobileMoneyAccountActivateRequested(
              phoneNumber: '+221773456789',
              providers: [],
            ),
          ),
        ).called(1);

        // Purge le timer de re-demande de catalogue programmé par la
        // saisie ci-dessus, sans effet sur les assertions précédentes.
        await tester.pump(const Duration(milliseconds: 450));
      },
    );

    testWidgets(
      'catalogue vide : message dédié, aucune checklist, bouton inactif',
      (tester) async {
        const emptyCatalog = MobileMoneyProviderCatalog(
          country: 'CI',
          currency: 'XOF',
        );
        stub(
          const MobileMoneyAccountProvidersLoaded(
            notConfiguredAccount,
            emptyCatalog,
          ),
        );
        await pumpScreen(tester);

        expect(
          find.text('Aucun réseau disponible sur ce numéro.'),
          findsOneWidget,
        );
        expect(find.byType(MobileMoneyNetworksChecklist), findsNothing);

        await tester.enterText(
          find.byKey(const Key('payout-phone-field')),
          '+221773456789',
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('payout-phone-confirm-field')),
          '+221773456789',
        );
        await tester.pump();

        final button = tester.widget<DonyButton>(
          find.widgetWithText(DonyButton, 'Activer le versement mobile money'),
        );
        expect(button.onPressed, isNull);

        await tester.pump(const Duration(milliseconds: 450));
      },
    );

    testWidgets('les saisies divergent après un catalogue chargé : envoie '
        'ProvidersCleared', (tester) async {
      stub(const MobileMoneyAccountLoaded(notConfiguredAccount));
      await pumpScreen(tester);

      await tester.enterText(
        find.byKey(const Key('payout-phone-field')),
        '+221773456789',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('payout-phone-confirm-field')),
        '+221773456789',
      );
      // Laisse le débounce demander le catalogue une première fois.
      await tester.pump(const Duration(milliseconds: 450));
      verify(
        () => bloc.add(
          const MobileMoneyAccountProvidersRequested(
            phoneNumber: '+221773456789',
          ),
        ),
      ).called(1);

      // Les saisies divergent à nouveau : le catalogue ne correspond plus
      // à rien de confirmé.
      await tester.enterText(
        find.byKey(const Key('payout-phone-confirm-field')),
        '+221773456780',
      );
      await tester.pump();

      verify(
        () => bloc.add(const MobileMoneyAccountProvidersCleared()),
      ).called(1);
    });

    testWidgets('catalogue et sélection survivent à Updating puis Error : la '
        'checklist et le bouton actif sont de retour, un nouveau tap renvoie '
        'les mêmes réseaux', (tester) async {
      final controller = StreamController<MobileMoneyAccountState>();
      addTearDown(controller.close);
      const loaded = MobileMoneyAccountProvidersLoaded(
        notConfiguredAccount,
        catalog,
      );
      whenListen(bloc, controller.stream, initialState: loaded);

      await pumpScreen(tester);

      await tester.enterText(
        find.byKey(const Key('payout-phone-field')),
        '+221773456789',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('payout-phone-confirm-field')),
        '+221773456789',
      );
      await tester.pump();

      // Réseau détecté déjà coché, numéro confirmé : le bouton est actif.
      var button = tester.widget<DonyButton>(
        find.widgetWithText(DonyButton, 'Activer le versement mobile money'),
      );
      expect(button.onPressed, isNotNull);

      // Simule ce que ferait le vrai bloc après le tap sur ce bouton :
      // Updating (sans catalogue dans ses props) puis un échec réseau
      // (Error, sans catalogue non plus).
      controller.add(const MobileMoneyAccountUpdating(notConfiguredAccount));
      await tester.pump();

      // La checklist reste visible (catalogue retenu localement) pendant
      // que le bouton passe en chargement (isLoading remplace le libellé
      // par un spinner : on cible le bouton par type, pas par texte).
      expect(find.byType(MobileMoneyNetworksChecklist), findsOneWidget);
      button = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(button.isLoading, isTrue);

      controller.add(
        const MobileMoneyAccountError(
          NetworkException('boom'),
          account: notConfiguredAccount,
        ),
      );
      await tester.pump();

      // Le catalogue retenu et la sélection sont toujours là : la
      // checklist et le bouton actif sont de retour.
      expect(find.byType(MobileMoneyNetworksChecklist), findsOneWidget);
      expect(
        tester
            .widget<DonyOperatorTile>(
              find.byKey(const Key('network-ORANGE_CIV')),
            )
            .selected,
        isTrue,
      );
      button = tester.widget<DonyButton>(
        find.widgetWithText(DonyButton, 'Activer le versement mobile money'),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(find.text('Activer le versement mobile money'));
      await tester.pump();

      verify(
        () => bloc.add(
          const MobileMoneyAccountActivateRequested(
            phoneNumber: '+221773456789',
            providers: ['ORANGE_CIV'],
          ),
        ),
      ).called(1);

      // Purge le timer de re-demande du catalogue (déjà chargé ici) pour
      // ne pas laisser de Timer en attente à la fin du test.
      await tester.pump(const Duration(milliseconds: 450));
    });
  });

  group('vue active', () {
    testWidgets(
      'affiche numéro, pays, devise, réseaux acceptés et les trois actions',
      (tester) async {
        stub(const MobileMoneyAccountLoaded(activeWithNetworks));
        await pumpScreen(tester);
        expect(find.text('+225 •••• 36'), findsOneWidget);
        expect(find.text("Côte d'Ivoire"), findsOneWidget);
        expect(find.text('XOF'), findsOneWidget);
        expect(find.text('Réseaux acceptés'), findsOneWidget);
        expect(find.text('Orange Money'), findsOneWidget);
        expect(find.text('Wave'), findsOneWidget);
        expect(find.text('Modifier'), findsOneWidget);
        expect(find.text('Changer de numéro'), findsOneWidget);
        expect(find.text('Désactiver'), findsOneWidget);
      },
    );

    testWidgets('« Changer de numéro » envoie l\'event', (tester) async {
      stub(const MobileMoneyAccountLoaded(activeWithNetworks));
      await pumpScreen(tester);
      await tester.tap(find.text('Changer de numéro'));
      verify(
        () => bloc.add(const MobileMoneyAccountChangeNumberRequested()),
      ).called(1);
    });

    testWidgets('en édition du numéro : formulaire avec « Annuler »', (
      tester,
    ) async {
      stub(
        const MobileMoneyAccountLoaded(activeWithNetworks, editingNumber: true),
      );
      await pumpScreen(tester);
      expect(find.byKey(const Key('payout-phone-field')), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      verify(
        () => bloc.add(const MobileMoneyAccountChangeNumberCancelled()),
      ).called(1);
    });

    testWidgets(
      '« Modifier » ouvre la feuille et demande le catalogue du numéro enregistré',
      (tester) async {
        stub(const MobileMoneyAccountLoaded(activeWithNetworks));
        await pumpScreen(tester);
        await tester.tap(find.text('Modifier'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        verify(
          () => bloc.add(const MobileMoneyAccountProvidersRequested()),
        ).called(1);
        expect(find.text('Enregistrer'), findsOneWidget);
      },
    );

    testWidgets(
      'feuille : décocher/recocher plusieurs réseaux → Enregistrer envoie '
      'les codes dans l\'ordre du catalogue, inactif sans aucun réseau '
      'coché',
      (tester) async {
        final controller = StreamController<MobileMoneyAccountState>();
        addTearDown(controller.close);
        const loaded = MobileMoneyAccountLoaded(activeWithNetworks);
        whenListen(bloc, controller.stream, initialState: loaded);

        await pumpScreen(tester);
        await tester.tap(find.text('Modifier'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        controller.add(
          const MobileMoneyAccountProvidersLoaded(activeWithNetworks, catalog),
        );
        await tester.pump();

        // Les deux réseaux du compte sont déjà cochés par défaut (repris de
        // account.providers à l'ouverture de la feuille) : les décocher
        // tous les deux désactive Enregistrer.
        await tester.ensureVisible(find.byKey(const Key('network-ORANGE_CIV')));
        await tester.tap(find.byKey(const Key('network-ORANGE_CIV')));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('network-WAVE_CIV')));
        await tester.tap(find.byKey(const Key('network-WAVE_CIV')));
        await tester.pump();

        var button = tester.widget<DonyButton>(
          find.widgetWithText(DonyButton, 'Enregistrer'),
        );
        expect(button.onPressed, isNull);

        // Recoche dans l'ordre inverse du catalogue (Wave puis Orange).
        await tester.tap(find.byKey(const Key('network-WAVE_CIV')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('network-ORANGE_CIV')));
        await tester.pump();

        button = tester.widget<DonyButton>(
          find.widgetWithText(DonyButton, 'Enregistrer'),
        );
        expect(button.onPressed, isNotNull);

        await tester.tap(find.text('Enregistrer'));
        await tester.pump();

        verify(
          () => bloc.add(
            const MobileMoneyAccountProvidersUpdateRequested([
              'ORANGE_CIV',
              'WAVE_CIV',
            ]),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'feuille : catalogue vide → message dédié, Enregistrer inactif',
      (tester) async {
        final controller = StreamController<MobileMoneyAccountState>();
        addTearDown(controller.close);
        const loaded = MobileMoneyAccountLoaded(activeWithNetworks);
        whenListen(bloc, controller.stream, initialState: loaded);

        await pumpScreen(tester);
        await tester.tap(find.text('Modifier'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        const emptyCatalog = MobileMoneyProviderCatalog(
          country: 'CI',
          currency: 'XOF',
        );
        controller.add(
          const MobileMoneyAccountProvidersLoaded(
            activeWithNetworks,
            emptyCatalog,
          ),
        );
        await tester.pump();

        expect(
          find.text('Aucun réseau disponible sur ce numéro.'),
          findsOneWidget,
        );
        final button = tester.widget<DonyButton>(
          find.widgetWithText(DonyButton, 'Enregistrer'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets('feuille : catalogue en erreur → « Réessayer » redemande le '
        'catalogue du numéro enregistré', (tester) async {
      final controller = StreamController<MobileMoneyAccountState>();
      addTearDown(controller.close);
      const loaded = MobileMoneyAccountLoaded(activeWithNetworks);
      whenListen(bloc, controller.stream, initialState: loaded);

      await pumpScreen(tester);
      await tester.tap(find.text('Modifier'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      controller.add(
        const MobileMoneyAccountProvidersError(
          activeWithNetworks,
          NetworkException('boom'),
        ),
      );
      await tester.pump();

      expect(find.byType(DonyStatusBanner), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      // La première demande vient de l'ouverture de la feuille, la
      // seconde du tap « Réessayer ».
      verify(
        () => bloc.add(const MobileMoneyAccountProvidersRequested()),
      ).called(2);
    });

    testWidgets(
      'feuille : ancien back sans catalogue (404) → même bandeau info, '
      'Enregistrer reste inactif',
      (tester) async {
        final controller = StreamController<MobileMoneyAccountState>();
        addTearDown(controller.close);
        const loaded = MobileMoneyAccountLoaded(activeWithNetworks);
        whenListen(bloc, controller.stream, initialState: loaded);

        await pumpScreen(tester);
        await tester.tap(find.text('Modifier'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        controller.add(
          const MobileMoneyAccountProvidersUnavailable(activeWithNetworks),
        );
        await tester.pump();

        expect(
          find.text(
            "Le choix des réseaux n'est pas encore disponible. Ton "
            'opérateur sera détecté automatiquement.',
          ),
          findsOneWidget,
        );
        final button = tester.widget<DonyButton>(
          find.widgetWithText(DonyButton, 'Enregistrer'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets('compte actif, changement de numéro puis échec réseau : le '
        'formulaire reste affiché (editingNumber survit à Error)', (
      tester,
    ) async {
      final controller = StreamController<MobileMoneyAccountState>();
      addTearDown(controller.close);
      const loaded = MobileMoneyAccountLoaded(activeWithNetworks);
      whenListen(bloc, controller.stream, initialState: loaded);

      await pumpScreen(tester);
      await tester.tap(find.text('Changer de numéro'));
      await tester.pump();

      controller.add(
        const MobileMoneyAccountLoaded(activeWithNetworks, editingNumber: true),
      );
      await tester.pump();
      expect(find.byKey(const Key('payout-phone-field')), findsOneWidget);

      controller.add(
        const MobileMoneyAccountError(
          NetworkException('boom'),
          account: activeWithNetworks,
          editingNumber: true,
        ),
      );
      await tester.pump();

      // Le formulaire de changement de numéro reste affiché malgré
      // l'échec : pas de retour furtif à la vue active.
      expect(find.byKey(const Key('payout-phone-field')), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });
  });
}
