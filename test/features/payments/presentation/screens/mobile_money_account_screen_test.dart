import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/presentation/screens/mobile_money_account_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc
    extends MockBloc<MobileMoneyAccountEvent, MobileMoneyAccountState>
    implements MobileMoneyAccountBloc {}

const _orangeCi = MobileMoneyPayoutAccount(
  id: 'a1',
  provider: 'ORANGE_CIV',
  providerLabel: 'Orange Money',
  brand: 'ORANGE',
  country: 'CI',
  currency: 'XOF',
  msisdnMasked: '+225 •••• 56',
);

const _mtnCi = MobileMoneyPayoutAccount(
  id: 'a2',
  provider: 'MTN_MOMO_CIV',
  providerLabel: 'MTN MoMo',
  brand: 'MTN',
  country: 'CI',
  currency: 'XOF',
  msisdnMasked: '+225 •••• 12',
);

const _orangeSn = MobileMoneyPayoutAccount(
  id: 'a3',
  provider: 'ORANGE_SEN',
  providerLabel: 'Orange Money',
  brand: 'ORANGE',
  country: 'SN',
  currency: 'XOF',
  msisdnMasked: '+221 •••• 67',
);

const _lockedOrange = MobileMoneyPayoutAccount(
  id: 'a1',
  provider: 'ORANGE_CIV',
  providerLabel: 'Orange Money',
  brand: 'ORANGE',
  country: 'CI',
  currency: 'XOF',
  msisdnMasked: '+225 •••• 56',
  pendingPayouts: 2,
);

const _addPath = '/payments/mobile-money/account/add';

/// Écran « Versement mobile money » : liste des comptes de versement, menu
/// ⋯ (changer de numéro, retirer), ajout, encarts et états.
void main() {
  late _MockBloc bloc;
  late StreamController<MobileMoneyAccountState> states;

  /// Résultat que l'écran d'ajout factice rendra au retour.
  bool? addResult;

  /// URI poussées vers l'écran d'ajout.
  late List<Uri> pushed;

  setUpAll(() {
    registerFallbackValue(const MobileMoneyAccountsRequested());
  });

  setUp(() {
    bloc = _MockBloc();
    states = StreamController<MobileMoneyAccountState>.broadcast();
    addResult = null;
    pushed = [];
  });

  tearDown(() => states.close());

  Future<void> pumpScreen(
    WidgetTester tester,
    MobileMoneyAccountState state, {
    bool settle = true,
    ThemeData? theme,
    Locale locale = AppL10n.fr,
  }) async {
    whenListen(bloc, states.stream, initialState: state);
    final router = GoRouter(
      initialLocation: '/payments/mobile-money/account',
      routes: [
        GoRoute(
          path: '/payments/mobile-money/account',
          builder: (_, _) => BlocProvider<MobileMoneyAccountBloc>.value(
            value: bloc,
            child: const MobileMoneyAccountScreen(),
          ),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, s) {
                pushed.add(s.uri);
                return Scaffold(
                  body: TextButton(
                    onPressed: () => context.pop(addResult),
                    child: const Text('fake-add-back'),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: theme ?? AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Loaded loaded(
    List<MobileMoneyPayoutAccount> accounts, {
    List<MobileMoneyProviderOption> suggested = const [],
    bool legacy = false,
    bool submitting = false,
  }) => MobileMoneyAccountLoaded(
    MobileMoneyPayoutAccounts(
      accounts: accounts,
      suggested: suggested,
      legacy: legacy,
    ),
    submitting: submitting,
  );

  Future<void> openMenu(WidgetTester tester, String accountId) async {
    await tester.tap(find.byKey(Key('payout-account-menu-$accountId')));
    await tester.pumpAndSettle();
  }

  group('chargement et erreurs', () {
    testWidgets('état initial : indicateur de chargement et titre', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const MobileMoneyAccountInitial(),
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Versement mobile money'), findsOneWidget);
    });

    testWidgets('chargement en cours : indicateur de chargement', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const MobileMoneyAccountLoading(),
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('échec sans liste : « Réessayer » relit la liste', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const MobileMoneyAccountError(NetworkException('offline')),
      );

      expect(find.text('Impossible de charger vos comptes'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));

      verify(() => bloc.add(const MobileMoneyAccountsRequested())).called(1);
    });

    testWidgets('écriture refusée : la liste connue reste affichée', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const MobileMoneyAccountActionFailed(
          MobileMoneyPayoutAccounts(accounts: [_orangeCi]),
          NetworkException('offline'),
        ),
      );

      expect(find.text('Orange Money'), findsOneWidget);
      expect(find.text('Impossible de charger vos comptes'), findsNothing);
    });

    testWidgets('corps dans une SafeArea sans marge haute', (tester) async {
      await pumpScreen(tester, loaded(const [_orangeCi]));

      final safe = tester.widget<SafeArea>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(SafeArea),
            )
            .first,
      );
      expect(safe.top, isFalse);
    });
  });

  group('liste', () {
    testWidgets('deux comptes : ligne, numéro masqué, pays, encart', (
      tester,
    ) async {
      await pumpScreen(tester, loaded(const [_orangeCi, _mtnCi]));

      expect(find.text('VOS COMPTES'), findsOneWidget);
      expect(find.text('Orange Money'), findsOneWidget);
      expect(find.text('MTN MoMo'), findsOneWidget);
      expect(find.text("+225 •••• 56 · Côte d'Ivoire"), findsOneWidget);
      expect(find.text("+225 •••• 12 · Côte d'Ivoire"), findsOneWidget);
      expect(find.byType(DonyBrandMark), findsNWidgets(2));
      expect(
        find.text(
          'Les expéditeurs vous paient avec Orange Money et MTN MoMo. '
          'Vous recevez sur le compte du même réseau.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ajouter un compte'), findsOneWidget);
    });

    testWidgets('même marque dans deux pays : « Orange CI » / « Orange SN »', (
      tester,
    ) async {
      await pumpScreen(tester, loaded(const [_orangeCi, _orangeSn]));

      expect(find.text('Orange CI'), findsOneWidget);
      expect(find.text('Orange SN'), findsOneWidget);
      expect(find.text('+221 •••• 67 · Sénégal'), findsOneWidget);
      expect(
        find.textContaining('vous paient avec Orange CI et Orange SN.'),
        findsOneWidget,
      );
    });

    testWidgets('⋯ ouvre le menu « Changer de numéro » / « Retirer »', (
      tester,
    ) async {
      await pumpScreen(tester, loaded(const [_orangeCi]));

      await openMenu(tester, 'a1');

      expect(find.text('Changer de numéro'), findsOneWidget);
      expect(find.text('Retirer'), findsOneWidget);
    });

    testWidgets('encart des réseaux suggérés (comptes repris)', (tester) async {
      await pumpScreen(
        tester,
        loaded(
          const [_orangeCi],
          suggested: const [
            MobileMoneyProviderOption(code: 'MTN_MOMO_CIV', label: 'MTN MoMo'),
            MobileMoneyProviderOption(code: 'MOOV_CIV', label: 'Moov Money'),
          ],
        ),
      );

      expect(
        find.text(
          'Vous acceptiez aussi MTN MoMo et Moov Money sur le même numéro. '
          "Ajoutez un compte pour chacun afin d'être payé sur le bon réseau.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('sans compte : explication et bouton « Ajouter un compte »', (
      tester,
    ) async {
      await pumpScreen(tester, loaded(const []));

      expect(
        find.text(
          'Ajoutez le compte mobile money qui recevra vos gains. Il peut '
          'être différent de votre numéro Yadony.',
        ),
        findsOneWidget,
      );
      expect(find.text('VOS COMPTES'), findsNothing);
      expect(
        find.widgetWithText(DonyButton, 'Ajouter un compte'),
        findsOneWidget,
      );
    });

    testWidgets('repli ancien contrat avec un compte : pas d\'ajout', (
      tester,
    ) async {
      await pumpScreen(tester, loaded(const [_orangeCi], legacy: true));

      expect(find.text('Orange Money'), findsOneWidget);
      expect(find.text('Ajouter un compte'), findsNothing);
      await openMenu(tester, 'a1');
      expect(find.text('Retirer'), findsOneWidget);
    });

    testWidgets('compte sans pays connu : numéro masqué seul', (tester) async {
      const noCountry = MobileMoneyPayoutAccount(
        id: 'legacy',
        provider: 'ORANGE_CIV',
        providerLabel: 'Orange Money',
        brand: 'ORANGE',
        country: '',
        currency: '',
        msisdnMasked: '+225 •••• 56',
      );
      await pumpScreen(tester, loaded(const [noCountry], legacy: true));

      expect(find.text('+225 •••• 56'), findsOneWidget);
    });

    testWidgets('repli ancien contrat sans compte : ajout possible', (
      tester,
    ) async {
      await pumpScreen(tester, loaded(const [], legacy: true));

      expect(
        find.widgetWithText(DonyButton, 'Ajouter un compte'),
        findsOneWidget,
      );
    });
  });

  group('ajout et changement de numéro', () {
    testWidgets('« Ajouter un compte » pousse l\'ajout puis relit si true', (
      tester,
    ) async {
      addResult = true;
      await pumpScreen(tester, loaded(const [_orangeCi]));

      await tester.tap(find.text('Ajouter un compte'));
      await tester.pumpAndSettle();
      expect(pushed.single.path, _addPath);
      expect(pushed.single.queryParameters, isEmpty);

      await tester.tap(find.text('fake-add-back'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const MobileMoneyAccountsRequested())).called(1);
    });

    testWidgets('retour sans changement : aucune relecture', (tester) async {
      addResult = null;
      await pumpScreen(tester, loaded(const []));

      await tester.tap(find.widgetWithText(DonyButton, 'Ajouter un compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('fake-add-back'));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any()));
    });

    testWidgets('retour pendant une écriture : aucune relecture', (
      tester,
    ) async {
      addResult = true;
      await pumpScreen(tester, loaded(const [_orangeCi]));

      await tester.tap(find.text('Ajouter un compte'));
      await tester.pumpAndSettle();
      states.add(loaded(const [_orangeCi], submitting: true));
      await tester.pump();
      await tester.tap(find.text('fake-add-back'));
      // Barre de progression indéterminée : pas de pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      verifyNever(() => bloc.add(any()));
    });

    testWidgets('« Changer de numéro » pousse le compte, l\'opérateur, le '
        'pays', (tester) async {
      addResult = true;
      await pumpScreen(tester, loaded(const [_orangeCi]));

      await openMenu(tester, 'a1');
      await tester.tap(find.text('Changer de numéro'));
      await tester.pumpAndSettle();

      expect(pushed.single.path, _addPath);
      expect(pushed.single.queryParameters, {
        'account': 'a1',
        'provider': 'ORANGE_CIV',
        'country': 'CI',
      });
      await tester.tap(find.text('fake-add-back'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const MobileMoneyAccountsRequested())).called(1);
    });
  });

  group('retrait et compte bloqué', () {
    testWidgets('retrait confirmé : MobileMoneyAccountRemoveRequested', (
      tester,
    ) async {
      await pumpScreen(tester, loaded(const [_orangeCi, _mtnCi]));

      await openMenu(tester, 'a1');
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();

      expect(find.text('Retirer Orange Money ?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('payout-remove-confirm')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(const MobileMoneyAccountRemoveRequested(_orangeCi)),
      ).called(1);
    });

    testWidgets('retrait annulé : rien n\'est envoyé', (tester) async {
      await pumpScreen(tester, loaded(const [_orangeCi]));

      await openMenu(tester, 'a1');
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('payout-remove-cancel')));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any()));
    });

    testWidgets('compte verrouillé : « Retirer » ouvre la feuille bloquée', (
      tester,
    ) async {
      await pumpScreen(tester, loaded(const [_lockedOrange]));

      await openMenu(tester, 'a1');
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();

      expect(
        find.text('2 colis attendent encore leur versement sur ce compte.'),
        findsOneWidget,
      );
      expect(find.text('Retirer Orange Money ?'), findsNothing);
      await tester.tap(find.text('Compris'));
      await tester.pumpAndSettle();
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('compte verrouillé : « Changer de numéro » aussi', (
      tester,
    ) async {
      await pumpScreen(tester, loaded(const [_lockedOrange]));

      await openMenu(tester, 'a1');
      await tester.tap(find.text('Changer de numéro'));
      await tester.pumpAndSettle();

      expect(
        find.text('2 colis attendent encore leur versement sur ce compte.'),
        findsOneWidget,
      );
      expect(pushed, isEmpty);
    });

    testWidgets('409 verrouillé après le retrait : feuille bloquée', (
      tester,
    ) async {
      // Liste lue avant le paiement du colis : le compte paraît libre, le
      // back refuse. Le nombre exact est inconnu, au moins un colis attend.
      await pumpScreen(tester, loaded(const [_orangeCi]));
      await openMenu(tester, 'a1');
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('payout-remove-confirm')));
      await tester.pumpAndSettle();

      states.add(
        const MobileMoneyAccountActionFailed(
          MobileMoneyPayoutAccounts(accounts: [_orangeCi]),
          ConflictException('locked', code: 'mobile-money-account-locked'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('1 colis attend encore son versement sur ce compte.'),
        findsOneWidget,
      );
      // La liste est relue : la ligne passe bloquée avec le vrai nombre.
      verify(() => bloc.add(const MobileMoneyAccountsRequested())).called(1);
      await tester.tap(find.text('Compris'));
      await tester.pumpAndSettle();
      states.add(loaded(const [_lockedOrange]));
      await tester.pumpAndSettle();
      await openMenu(tester, 'a1');
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();
      expect(
        find.text('2 colis attendent encore leur versement sur ce compte.'),
        findsOneWidget,
      );
    });

    testWidgets('autre refus : message d\'erreur, liste gardée', (
      tester,
    ) async {
      await pumpScreen(tester, loaded(const [_orangeCi]));

      states.add(
        const MobileMoneyAccountActionFailed(
          MobileMoneyPayoutAccounts(accounts: [_orangeCi]),
          NetworkException('offline'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Orange Money'), findsOneWidget);
      // Refus sans rapport avec un versement en attente : pas de relecture.
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('écriture en cours : barre de progression, menu inactif', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        loaded(const [_orangeCi], submitting: true),
        settle: false,
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final menu = tester.widget<PopupMenuButton<Object?>>(
        find.byKey(const Key('payout-account-menu-a1')),
      );
      expect(menu.enabled, isFalse);
    });
  });

  group('accessibilité, langue, thème', () {
    testWidgets('pastille hors sémantique, libellé annoncé', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, loaded(const [_orangeCi]));

      expect(find.bySemanticsLabel('ORANGE'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Orange Money')), findsWidgets);
      expect(find.byTooltip('Options du compte Orange Money'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('anglais : titre et libellés traduits', (tester) async {
      await pumpScreen(
        tester,
        loaded(const [_orangeCi, _mtnCi]),
        locale: AppL10n.en,
      );

      expect(find.text('Mobile money payout'), findsOneWidget);
      expect(find.text('YOUR ACCOUNTS'), findsOneWidget);
      expect(find.text('Add an account'), findsOneWidget);
      expect(
        find.textContaining('Senders pay you with Orange Money and MTN MoMo.'),
        findsOneWidget,
      );
    });

    testWidgets('thème sombre, 360 px : aucun débordement', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpScreen(
        tester,
        loaded(
          const [_orangeCi, _orangeSn, _mtnCi],
          suggested: const [
            MobileMoneyProviderOption(code: 'MOOV_CIV', label: 'Moov Money'),
          ],
        ),
        theme: AppTheme.dark(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Orange CI'), findsOneWidget);
    });

    testWidgets('réduction du mouvement : lignes affichées sans animation', (
      tester,
    ) async {
      whenListen(bloc, states.stream, initialState: loaded(const [_orangeCi]));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: AppL10n.fr,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlocProvider<MobileMoneyAccountBloc>.value(
              value: bloc,
              child: const MobileMoneyAccountScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Orange Money'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}

typedef Loaded = MobileMoneyAccountLoaded;
