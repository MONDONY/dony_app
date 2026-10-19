import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_country_field.dart';
import 'package:dony/features/payments/presentation/widgets/payer_account_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/payer_account_test_doubles.dart';

/// Bloc « compte qui paie » de la recharge (maquettes v3, écrans 1 à 4) :
/// pays en autocomplétion, puis opérateur, puis numéro, et le retour de la
/// reconnaissance du numéro.
void main() {
  late MockPayerAccountCubit cubit;

  setUp(() {
    cubit = MockPayerAccountCubit();
  });

  Widget harness({
    ThemeData? theme,
    bool disableAnimations = false,
    Locale locale = AppL10n.fr,
  }) {
    return MaterialApp(
      theme: theme ?? AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: Scaffold(
            body: BlocProvider<PayerAccountCubit>.value(
              value: cubit,
              child: ListView(
                padding: const EdgeInsets.all(DonySpacing.lg),
                children: const [PayerAccountSection()],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpWith(WidgetTester tester, PayerAccountState state) async {
    final controller = stubPayerAccount(cubit, state);
    addTearDown(controller.close);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
  }

  group('pays', () {
    testWidgets('countryField_typingFiltersAndShowsUpcomingAsDisabled', (
      tester,
    ) async {
      await pumpWith(tester, kPayerReady);

      expect(find.text('COMPTE QUI PAIE'), findsOneWidget);
      expect(find.byKey(const Key('mm-country-field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('mm-country-field')), 'Mal');
      await tester.pumpAndSettle();

      expect(find.text('Mali'), findsOneWidget);
      expect(find.text('Bientôt'), findsOneWidget);
      expect(find.text('Mobile money pas encore disponible'), findsOneWidget);
      expect(find.text('Sénégal'), findsNothing);
      // Seul résultat, et « Bientôt » : l'écran passe à l'état du pays pas
      // encore ouvert, sans que la ligne soit choisie.
      verify(() => cubit.selectCountry('ML')).called(1);

      await tester.tap(find.text('Mali'));
      await tester.pumpAndSettle();

      verifyNever(() => cubit.selectCountry(any()));
      expect(find.text('Mal'), findsOneWidget, reason: 'saisie inchangée');
      expect(find.text('Mali'), findsOneWidget, reason: 'liste encore ouverte');
    });

    testWidgets(
      'pays servi : sous-titre des opérateurs, le toucher le choisit',
      (tester) async {
        await pumpWith(tester, kPayerReady);

        await tester.enterText(
          find.byKey(const Key('mm-country-field')),
          'cote',
        );
        await tester.pumpAndSettle();

        expect(find.text("Côte d'Ivoire"), findsOneWidget);
        expect(find.text('Orange Money, MTN MoMo'), findsOneWidget);
        verifyNever(() => cubit.selectCountry(any()));

        await tester.tap(find.text("Côte d'Ivoire"));
        await tester.pumpAndSettle();

        verify(() => cubit.selectCountry('CI')).called(1);
      },
    );

    testWidgets('pays hors catalogue : texte « pas disponible pour ce pays »', (
      tester,
    ) async {
      await pumpWith(tester, kPayerReady);

      await tester.enterText(
        find.byKey(const Key('mm-country-field')),
        'Allemagne',
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Le mobile money n'est pas disponible pour ce pays."),
        findsOneWidget,
      );
      verifyNever(() => cubit.selectCountry(any()));
    });

    testWidgets("la saisie d'un pays « Bientôt » qui change efface l'état", (
      tester,
    ) async {
      final controller = stubPayerAccount(
        cubit,
        kPayerReady.copyWith(unavailableCountry: 'ML'),
      );
      addTearDown(controller.close);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      // Retour sur l'écran : la recherche reprend le pays « Bientôt ».
      expect(find.text('Mali'), findsWidgets);
      expect(
        find.text(
          'En attendant, rechargez par carte bancaire ou avec un code de '
          'recharge.',
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('mm-country-field')), 'S');
      await tester.pumpAndSettle();

      verify(() => cubit.clearCountry()).called(1);
    });

    testWidgets('pays choisi : drapeau, nom, bouton pour effacer', (
      tester,
    ) async {
      await pumpWith(tester, kPayerReady.copyWith(country: kCoteDIvoire));

      expect(find.byKey(const Key('mm-country-field')), findsNothing);
      expect(find.text("Côte d'Ivoire"), findsOneWidget);
      expect(find.text('Pays'), findsOneWidget);

      await tester.tap(find.byTooltip('Effacer'));
      await tester.pump();

      verify(() => cubit.clearCountry()).called(1);
    });
  });

  group('opérateur', () {
    testWidgets('operatorPills_appearOnlyAfterCountry', (tester) async {
      final controller = stubPayerAccount(cubit, kPayerReady);
      addTearDown(controller.close);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mm-operator-ORANGE_CIV')), findsNothing);
      expect(find.text('Opérateur'), findsNothing);

      controller.add(kPayerReady.copyWith(country: kCoteDIvoire));
      await tester.pumpAndSettle();

      expect(find.text('Opérateur'), findsOneWidget);
      expect(find.byKey(const Key('mm-operator-ORANGE_CIV')), findsOneWidget);
      expect(find.byKey(const Key('mm-operator-MTN_MOMO_CIV')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mm-operator-MTN_MOMO_CIV')));
      await tester.pumpAndSettle();

      verify(() => cubit.selectOperator('MTN_MOMO_CIV')).called(1);
    });
  });

  group('numéro', () {
    testWidgets('numberField_appearsOnlyAfterOperator_withDialCodePrefix', (
      tester,
    ) async {
      final controller = stubPayerAccount(
        cubit,
        kPayerReady.copyWith(country: kCoteDIvoire),
      );
      addTearDown(controller.close);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mm-number-field')), findsNothing);

      controller.add(
        kPayerReady.copyWith(country: kCoteDIvoire, operator: kOrangeCiv),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mm-number-field')), findsOneWidget);
      expect(find.text('+225'), findsOneWidget);
      expect(find.text('Numéro Orange Money'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('mm-number-field')),
        '07 48 84 08 56',
      );
      await tester.pump();

      verify(() => cubit.phoneChanged('07 48 84 08 56')).called(1);
    });

    testWidgets(
      'affiche le numéro rendu par le cubit sans jamais le lui renvoyer',
      (tester) async {
        const withOperator = PayerAccountState(
          status: PayerAccountStatus.ready,
          countries: kPayerCountries,
          country: kCoteDIvoire,
          operator: kOrangeCiv,
        );
        final controller = stubPayerAccount(cubit, withOperator);
        addTearDown(controller.close);
        await tester.pumpWidget(harness());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('mm-number-field')),
          '+225 07 48 84 08 56',
        );
        await tester.pump();
        verify(() => cubit.phoneChanged('+225 07 48 84 08 56')).called(1);

        // Le cubit retire l'indicatif collé : le champ montre la partie
        // locale, sans repasser par `phoneChanged`.
        controller.add(
          withOperator.copyWith(
            localNumber: '0748840856',
            e164: '+2250748840856',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0748840856'), findsOneWidget);
        verifyNever(() => cubit.phoneChanged(any()));
      },
    );

    testWidgets('numéro mémorisé : le champ démarre prérempli', (tester) async {
      await pumpWith(tester, kPayerRecognized);

      expect(find.text('0748840856'), findsOneWidget);
      verifyNever(() => cubit.phoneChanged(any()));
    });
  });

  group('reconnaissance', () {
    testWidgets('reconnu : ligne de confirmation', (tester) async {
      await pumpWith(tester, kPayerRecognized);

      expect(find.text('Numéro Orange Money reconnu'), findsOneWidget);
    });

    testWidgets('autoSwitched_showsNotice', (tester) async {
      await pumpWith(
        tester,
        kPayerRecognized.copyWith(
          operator: kMtnCiv,
          recognition: RecognitionStatus.autoSwitched,
          switchedFrom: 'ORANGE_CIV',
        ),
      );

      expect(
        find.text("C'est un numéro MTN MoMo : l'opérateur a été changé."),
        findsOneWidget,
      );
      expect(find.text('Numéro MTN MoMo reconnu'), findsNothing);
    });

    testWidgets('choix manuel respecté : aucun bandeau', (tester) async {
      await pumpWith(
        tester,
        kPayerRecognized.copyWith(
          operator: kMtnCiv,
          recognition: RecognitionStatus.overridden,
        ),
      );

      expect(find.textContaining('reconnu'), findsNothing);
      expect(find.textContaining("l'opérateur a été changé"), findsNothing);
      expect(find.textContaining('aucun opérateur'), findsNothing);
    });

    testWidgets('non reconnu : message', (tester) async {
      await pumpWith(
        tester,
        kPayerRecognized.copyWith(recognition: RecognitionStatus.unrecognized),
      );

      expect(
        find.text("Ce numéro n'est reconnu par aucun opérateur de ce pays."),
        findsOneWidget,
      );
    });

    testWidgets('coupure réseau : message et « Réessayer »', (tester) async {
      await pumpWith(
        tester,
        kPayerRecognized.copyWith(recognition: RecognitionStatus.failed),
      );

      expect(
        find.text('Vérification impossible pour le moment.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(() => cubit.retryRecognition()).called(1);
    });

    testWidgets('vérification en cours : indicateur dans le champ', (
      tester,
    ) async {
      final controller = stubPayerAccount(
        cubit,
        kPayerRecognized.copyWith(recognition: RecognitionStatus.checking),
      );
      addTearDown(controller.close);
      await tester.pumpWidget(harness());
      // Jamais pumpAndSettle : l'indicateur tourne en boucle.
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.descendant(
          of: find.byKey(const Key('mm-number-field')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });
  });

  group('états du catalogue', () {
    testWidgets('chargement : squelette, aucun champ', (tester) async {
      await pumpWith(tester, const PayerAccountState());

      expect(find.byKey(const Key('mm-country-field')), findsNothing);
      expect(find.byKey(const Key('payer-account-loading')), findsOneWidget);
    });

    testWidgets('erreur : bandeau et « Réessayer » relance le chargement', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const PayerAccountState(status: PayerAccountStatus.error),
      );

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(() => cubit.load()).called(1);
    });

    testWidgets("back ancien (legacy) : rien n'est rendu", (tester) async {
      await pumpWith(
        tester,
        const PayerAccountState(status: PayerAccountStatus.legacy),
      );

      expect(find.text('COMPTE QUI PAIE'), findsNothing);
      expect(find.byType(MobileMoneyCountryField), findsNothing);
    });
  });

  testWidgets(
    'réduction du mouvement : les lignes apparaissent sans animation',
    (tester) async {
      final controller = stubPayerAccount(cubit, kPayerRecognized);
      addTearDown(controller.close);
      await tester.pumpWidget(harness(disableAnimations: true));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(PayerAccountSection),
          matching: find.byType(Animate),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('anglais : libellés traduits', (tester) async {
    final controller = stubPayerAccount(cubit, kPayerRecognized);
    addTearDown(controller.close);
    await tester.pumpWidget(harness(locale: AppL10n.en));
    await tester.pumpAndSettle();

    expect(find.text('PAYING ACCOUNT'), findsOneWidget);
    expect(find.text('Operator'), findsOneWidget);
    expect(find.text('Orange Money number'), findsOneWidget);
    expect(find.text('Orange Money number recognised'), findsOneWidget);
  });

  testWidgets('thème sombre : rendu complet sans débordement', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final controller = stubPayerAccount(
      cubit,
      kPayerRecognized.copyWith(
        operator: kMtnCiv,
        recognition: RecognitionStatus.autoSwitched,
        switchedFrom: 'ORANGE_CIV',
      ),
    );
    addTearDown(controller.close);
    await tester.pumpWidget(harness(theme: AppTheme.dark()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
