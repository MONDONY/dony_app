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
import 'package:dony/features/payments/presentation/screens/mobile_money_account_screen.dart';
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

  const activeAccount = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.active,
    msisdnMasked: '+225 07 ** ** 67',
    providerLabel: 'Wave',
    country: 'CI',
    currency: 'XOF',
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
        'les deux champs remplis et identiques (normalisés) → le bouton '
        'envoie ActivateRequested avec le numéro',
        (tester) async {
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
          await tester.pump();

          await tester.tap(find.text('Activer le versement mobile money'));
          await tester.pump();

          verify(
            () => bloc.add(
              const MobileMoneyAccountActivateRequested(
                phoneNumber: '+221773456789',
              ),
            ),
          ).called(1);
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
        'bouton, qui envoie alors le numéro normalisé',
        (tester) async {
          stub(const MobileMoneyAccountLoaded(notConfiguredAccount));

          await pumpScreen(tester, authBloc: _authBlocWithPhone(null));

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

          // Même numéro, écrit avec des espaces différents : la normalisation
          // les fait coïncider.
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
              ),
            ),
          ).called(1);
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
        'confirmation vide et bouton inactif jusqu\'à confirmation '
        'identique',
        (tester) async {
          stub(const MobileMoneyAccountLoaded(notConfiguredAccount));

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
              ),
            ),
          ).called(1);
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
      'les deux champs remplis et identiques → le bouton Réactiver envoie '
      'ActivateRequested avec le numéro',
      (tester) async {
        stub(const MobileMoneyAccountLoaded(disabledAccount));

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

        await tester.tap(find.text('Réactiver'));
        await tester.pump();

        verify(
          () => bloc.add(
            const MobileMoneyAccountActivateRequested(
              phoneNumber: '+221773456789',
            ),
          ),
        ).called(1);
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
}
