import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/presentation/screens/mobile_money_payout_account_add_screen.dart';
import 'package:dony/features/payments/presentation/widgets/payer_account_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/payer_account_test_doubles.dart';

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

const _lockedOrangeCi = MobileMoneyPayoutAccount(
  id: 'a1',
  provider: 'ORANGE_CIV',
  providerLabel: 'Orange Money',
  brand: 'ORANGE',
  country: 'CI',
  currency: 'XOF',
  msisdnMasked: '+225 •••• 56',
  pendingPayouts: 2,
);

const _withOrange = MobileMoneyAccountLoaded(
  MobileMoneyPayoutAccounts(accounts: [_orangeCi]),
);

const _noAccount = MobileMoneyAccountLoaded(MobileMoneyPayoutAccounts());

/// Écran « Ajouter un compte » / « Changer de numéro » : bloc pays,
/// opérateur, numéro du composant partagé, relecture du numéro, envoi.
void main() {
  late _MockBloc bloc;
  late MockPayerAccountCubit cubit;
  late StreamController<MobileMoneyAccountState> states;
  late StreamController<PayerAccountState> payer;
  late List<Object?> popped;

  setUpAll(() {
    registerFallbackValue(const MobileMoneyAccountsRequested());
    registerFallbackValue((country: '', operator: ''));
    registerFallbackValue(<String>{});
  });

  setUp(() {
    bloc = _MockBloc();
    cubit = MockPayerAccountCubit();
    states = StreamController<MobileMoneyAccountState>.broadcast();
    popped = [];
  });

  tearDown(() async {
    await states.close();
    await payer.close();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    MobileMoneyAccountState state = _noAccount,
    PayerAccountState payerState = kPayerReady,
    String? accountId,
    FixedPayerAccount? fixed,
    ThemeData? theme,
    Locale locale = AppL10n.fr,
    bool settle = true,
  }) async {
    whenListen(bloc, states.stream, initialState: state);
    payer = stubPayerAccount(cubit, payerState);
    when(
      () => cubit.configure(
        currency: any(named: 'currency'),
        allowedOperators: any(named: 'allowedOperators'),
        fixed: any(named: 'fixed'),
      ),
    ).thenAnswer((_) async {});
    when(() => cubit.restrictOperators(any())).thenReturn(null);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  popped.add(await context.push<bool>('/add')),
              child: const Text('open-add'),
            ),
          ),
        ),
        GoRoute(
          path: '/add',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<MobileMoneyAccountBloc>.value(value: bloc),
              BlocProvider<PayerAccountCubit>.value(value: cubit),
            ],
            child: MobileMoneyPayoutAccountAddScreen(
              accountId: accountId,
              fixed: fixed,
            ),
          ),
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-add'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Bouton en chargement (animation sans fin) : quelques images.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  DonyButton continueButton(WidgetTester tester) =>
      tester.widget<DonyButton>(find.byKey(const Key('payout-add-continue')));

  Future<void> continueAndReview(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('payout-add-continue')));
    await tester.pumpAndSettle();
  }

  group('ajout', () {
    testWidgets('en-tête, section du composant, libellé « Ajouté »', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Ajouter un compte'), findsOneWidget);
      expect(find.byType(DonyFeedbackButton), findsOneWidget);
      expect(find.byType(DonyAppBarBackButton), findsOneWidget);
      expect(find.text('COMPTE QUI REÇOIT'), findsOneWidget);
      final section = tester.widget<PayerAccountSection>(
        find.byType(PayerAccountSection),
      );
      expect(section.disallowedOperatorLabel, 'Ajouté');
      expect(
        section.notAllowedMessage!('Orange Money'),
        'Vous avez déjà un compte Orange Money.',
      );
      verify(
        () => cubit.configure(
          currency: any(named: 'currency'),
          allowedOperators: any(named: 'allowedOperators'),
          fixed: any(named: 'fixed', that: isNull),
        ),
      ).called(1);
    });

    testWidgets('opérateurs déjà ajoutés retirés de ceux permis', (
      tester,
    ) async {
      await pumpScreen(tester, state: _withOrange);

      verify(
        () => cubit.restrictOperators({'MTN_MOMO_CIV', 'ORANGE_SEN'}),
      ).called(1);
    });

    testWidgets('aucun compte : aucune restriction', (tester) async {
      await pumpScreen(tester);

      verify(() => cubit.restrictOperators(null)).called(1);
    });

    testWidgets('catalogue arrivé après la liste : restriction posée', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        state: _withOrange,
        payerState: const PayerAccountState(),
      );
      verifyNever(() => cubit.restrictOperators(any()));

      payer.add(kPayerReady);
      await tester.pumpAndSettle();

      verify(
        () => cubit.restrictOperators({'MTN_MOMO_CIV', 'ORANGE_SEN'}),
      ).called(1);
    });

    testWidgets('« Continuer » inactif tant que le numéro n\'est pas reconnu', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(continueButton(tester).onPressed, isNull);
    });

    testWidgets('« Continuer » inactif tant que la liste n\'est pas lue', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        state: const MobileMoneyAccountLoading(),
        payerState: kPayerRecognized,
      );

      expect(continueButton(tester).onPressed, isNull);
    });

    testWidgets('écriture en cours : bouton en chargement, sans effet', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        state: const MobileMoneyAccountLoaded(
          MobileMoneyPayoutAccounts(),
          submitting: true,
        ),
        payerState: kPayerRecognized,
        settle: false,
      );

      expect(continueButton(tester).isLoading, isTrue);
      expect(continueButton(tester).onPressed, isNull);
    });

    testWidgets('relecture : numéro groupé, opérateur et pays', (tester) async {
      await pumpScreen(tester, payerState: kPayerRecognized);

      expect(continueButton(tester).onPressed, isNotNull);
      await continueAndReview(tester);

      expect(find.text("C'est bien votre numéro ?"), findsOneWidget);
      expect(find.text('+225 07 48 84 08 56'), findsOneWidget);
      expect(find.text("Orange Money · Côte d'Ivoire"), findsOneWidget);
    });

    testWidgets('« Corriger » ne soumet rien', (tester) async {
      await pumpScreen(tester, payerState: kPayerRecognized);
      await continueAndReview(tester);

      await tester.tap(find.byKey(const Key('payout-review-edit')));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any()));
      expect(find.byType(PayerAccountSection), findsOneWidget);
    });

    testWidgets('« Oui » soumet AddRequested(e164, opérateur)', (tester) async {
      await pumpScreen(tester, payerState: kPayerRecognized);
      await continueAndReview(tester);

      await tester.tap(find.byKey(const Key('payout-review-confirm')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          const MobileMoneyAccountAddRequested(
            phoneNumber: '+2250748840856',
            provider: 'ORANGE_CIV',
          ),
        ),
      ).called(1);
    });

    testWidgets('après un refus, « Continuer » reste possible', (tester) async {
      await pumpScreen(
        tester,
        state: const MobileMoneyAccountActionFailed(
          MobileMoneyPayoutAccounts(),
          NetworkException('offline'),
        ),
        payerState: kPayerRecognized,
      );

      expect(continueButton(tester).onPressed, isNotNull);
    });

    testWidgets('ActionDone : l\'écran se ferme en rendant true', (
      tester,
    ) async {
      await pumpScreen(tester, payerState: kPayerRecognized);

      states.add(
        const MobileMoneyAccountActionDone(
          MobileMoneyPayoutAccounts(accounts: [_orangeCi]),
          MobileMoneyAccountAction.added,
        ),
      );
      await tester.pumpAndSettle();

      expect(popped, [true]);
      expect(find.text('open-add'), findsOneWidget);
    });

    testWidgets('ActionFailed : message, saisie gardée', (tester) async {
      await pumpScreen(tester, payerState: kPayerRecognized);

      states.add(
        const MobileMoneyAccountActionFailed(
          MobileMoneyPayoutAccounts(),
          NetworkException('offline'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(PayerAccountSection), findsOneWidget);
      expect(popped, isEmpty);
    });

    testWidgets('liste illisible : message et « Réessayer »', (tester) async {
      await pumpScreen(
        tester,
        state: const MobileMoneyAccountError(NetworkException('offline')),
        payerState: kPayerRecognized,
      );

      expect(find.text('Impossible de charger vos comptes'), findsOneWidget);
      expect(continueButton(tester).onPressed, isNull);
      await tester.tap(find.text('Réessayer'));

      verify(() => bloc.add(const MobileMoneyAccountsRequested())).called(1);
    });

    testWidgets('back sans catalogue des versements : message d\'erreur', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        payerState: const PayerAccountState(status: PayerAccountStatus.legacy),
      );

      expect(find.text('Une erreur est survenue'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      verify(() => cubit.load()).called(1);
    });
  });

  group('changement de numéro', () {
    const fixed = (country: 'CI', operator: 'ORANGE_CIV');

    testWidgets('titre, compte imposé au composant', (tester) async {
      await pumpScreen(
        tester,
        state: _withOrange,
        accountId: 'a1',
        fixed: fixed,
      );

      expect(find.text('Changer de numéro'), findsOneWidget);
      verify(
        () => cubit.configure(
          currency: any(named: 'currency'),
          allowedOperators: any(named: 'allowedOperators'),
          fixed: fixed,
        ),
      ).called(1);
      verifyNever(() => cubit.restrictOperators(any()));
    });

    testWidgets('sans pays dans l\'adresse : compte imposé une fois la '
        'liste lue', (tester) async {
      await pumpScreen(
        tester,
        state: const MobileMoneyAccountLoading(),
        accountId: 'a1',
      );
      verifyNever(
        () => cubit.configure(
          currency: any(named: 'currency'),
          allowedOperators: any(named: 'allowedOperators'),
          fixed: any(named: 'fixed'),
        ),
      );

      states.add(_withOrange);
      await tester.pumpAndSettle();

      verify(
        () => cubit.configure(
          currency: any(named: 'currency'),
          allowedOperators: any(named: 'allowedOperators'),
          fixed: fixed,
        ),
      ).called(1);
    });

    testWidgets('numéro d\'un autre opérateur : message de correction, '
        'jamais « déjà un compte »', (tester) async {
      await pumpScreen(
        tester,
        state: _withOrange,
        accountId: 'a1',
        fixed: fixed,
        payerState: const PayerAccountState(
          status: PayerAccountStatus.ready,
          countries: kPayerCountries,
          country: kCoteDIvoire,
          operator: kOrangeCiv,
          localNumber: '0544556677',
          e164: '+2250544556677',
          recognition: RecognitionStatus.notAllowed,
          rejectedOperator: kMtnCiv,
          fixed: true,
        ),
      );

      expect(
        find.text(
          "C'est un numéro MTN MoMo. Saisissez un numéro Orange Money.",
        ),
        findsOneWidget,
      );
      expect(find.textContaining('déjà un compte'), findsNothing);
      expect(continueButton(tester).onPressed, isNull);
    });

    testWidgets('anglais : message de correction traduit', (tester) async {
      await pumpScreen(
        tester,
        state: _withOrange,
        accountId: 'a1',
        fixed: fixed,
        locale: AppL10n.en,
        payerState: const PayerAccountState(
          status: PayerAccountStatus.ready,
          countries: kPayerCountries,
          country: kCoteDIvoire,
          operator: kOrangeCiv,
          localNumber: '0544556677',
          e164: '+2250544556677',
          recognition: RecognitionStatus.notAllowed,
          rejectedOperator: kMtnCiv,
          fixed: true,
        ),
      );

      expect(
        find.text(
          'This number belongs to MTN MoMo. Enter your Orange Money number.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('« Oui » envoie NumberChangeRequested', (tester) async {
      await pumpScreen(
        tester,
        state: _withOrange,
        payerState: kPayerRecognized,
        accountId: 'a1',
        fixed: fixed,
      );
      await continueAndReview(tester);
      await tester.tap(find.byKey(const Key('payout-review-confirm')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          const MobileMoneyAccountNumberChangeRequested(
            account: _orangeCi,
            phoneNumber: '+2250748840856',
          ),
        ),
      ).called(1);
    });

    testWidgets('409 verrouillé : feuille bloquée avec le nombre du compte', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        state: const MobileMoneyAccountLoaded(
          MobileMoneyPayoutAccounts(accounts: [_lockedOrangeCi]),
        ),
        payerState: kPayerRecognized,
        accountId: 'a1',
        fixed: fixed,
      );

      states.add(
        const MobileMoneyAccountActionFailed(
          MobileMoneyPayoutAccounts(accounts: [_lockedOrangeCi]),
          ConflictException('locked', code: 'mobile-money-account-locked'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('2 colis attendent encore leur versement sur ce compte.'),
        findsOneWidget,
      );
      expect(popped, isEmpty);
    });

    testWidgets('compte déjà retiré : message, bouton inactif', (tester) async {
      await pumpScreen(
        tester,
        payerState: kPayerRecognized,
        accountId: 'a1',
        fixed: fixed,
      );

      expect(find.text('Ce compte a déjà été retiré.'), findsOneWidget);
      expect(continueButton(tester).onPressed, isNull);
    });
  });

  group('langue et thème', () {
    testWidgets('anglais : titres traduits', (tester) async {
      await pumpScreen(tester, locale: AppL10n.en);

      expect(find.text('Add an account'), findsOneWidget);
      expect(find.text('RECEIVING ACCOUNT'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('thème sombre, 360 px : aucun débordement', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpScreen(
        tester,
        payerState: kPayerRecognized,
        theme: AppTheme.dark(),
      );
      await continueAndReview(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('+225 07 48 84 08 56'), findsOneWidget);
    });
  });
}
