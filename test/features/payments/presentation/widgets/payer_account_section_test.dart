import 'dart:ui' show Tristate;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_country_field.dart';
import 'package:dony/features/payments/presentation/widgets/payer_account_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
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
    Widget section = const PayerAccountSection(),
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
                children: [section],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpWith(
    WidgetTester tester,
    PayerAccountState state, {
    Widget section = const PayerAccountSection(),
  }) async {
    final controller = stubPayerAccount(cubit, state);
    addTearDown(controller.close);
    await tester.pumpWidget(harness(section: section));
    await tester.pumpAndSettle();
  }

  group('pays', () {
    testWidgets('countryField_tapUpcoming_showsUnavailableNotice', (
      tester,
    ) async {
      final controller = stubPayerAccount(cubit, kPayerReady);
      addTearDown(controller.close);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('COMPTE QUI PAIE'), findsOneWidget);
      expect(find.byKey(const Key('mm-country-field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('mm-country-field')), 'Mal');
      await tester.pumpAndSettle();

      expect(find.text('Mali'), findsOneWidget);
      expect(find.text('Bientôt'), findsOneWidget);
      expect(find.text('Mobile money pas encore disponible'), findsOneWidget);
      expect(find.text('Sénégal'), findsNothing);
      // La frappe seule ne choisit rien : aucun événement ne part.
      verifyNever(() => cubit.selectCountry(any()));
      verifyNever(() => cubit.clearCountry());

      await tester.tap(find.text('Mali'));
      await tester.pumpAndSettle();
      verify(() => cubit.selectCountry('ML')).called(1);

      controller.add(kPayerReady.copyWith(unavailableCountry: 'ML'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'En attendant, rechargez par carte bancaire ou avec un code de '
          'recharge.',
        ),
        findsOneWidget,
      );
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
        verifyNever(() => cubit.clearCountry());
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

    testWidgets('countryField_clearedQuery_leavesUpcomingState', (
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

      // Modifier la saisie sans rien choisir ne change pas l'état.
      await tester.enterText(find.byKey(const Key('mm-country-field')), 'S');
      await tester.pumpAndSettle();
      verifyNever(() => cubit.clearCountry());

      // Vider le champ revient à l'état normal.
      await tester.enterText(find.byKey(const Key('mm-country-field')), '');
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

    // PROD-1G : l'indicatif était collé en haut de la case (prefixIcon
    // étiré à 48 px), au-dessus du texte d'aide centré.
    testWidgets('numberField_dialCodePrefix_isVerticallyCentered', (
      tester,
    ) async {
      await pumpWith(
        tester,
        kPayerReady.copyWith(country: kCoteDIvoire, operator: kOrangeCiv),
      );

      final dialCenter = tester.getCenter(
        find.byKey(const Key('mm-number-dial-code')),
      );
      final labelCenter = tester.getCenter(find.text('Numéro Orange Money'));
      final input = find.descendant(
        of: find.byKey(const Key('mm-number-field')),
        matching: find.byType(EditableText),
      );
      final inputCenter = tester.getCenter(input);
      final fieldRect = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('mm-number-field')),
          matching: find.byType(InputDecorator),
        ),
      );

      expect((dialCenter.dy - labelCenter.dy).abs(), lessThanOrEqualTo(2));
      expect((dialCenter.dy - inputCenter.dy).abs(), lessThanOrEqualTo(2));
      expect((dialCenter.dy - fieldRect.center.dy).abs(), lessThanOrEqualTo(2));

      // Le texte saisi reste aligné avec l'indicatif.
      await tester.enterText(input, '07 48 84 08 56');
      await tester.pumpAndSettle();
      expect(
        (tester.getCenter(find.byKey(const Key('mm-number-dial-code'))).dy -
                tester.getCenter(input).dy)
            .abs(),
        lessThanOrEqualTo(2),
      );
    });

    testWidgets('numberField_groupsDigitsByTwo', (tester) async {
      await pumpWith(
        tester,
        kPayerReady.copyWith(country: kCoteDIvoire, operator: kOrangeCiv),
      );

      await tester.enterText(
        find.byKey(const Key('mm-number-field')),
        '0748840856',
      );
      await tester.pump();

      expect(find.text('07 48 84 08 56'), findsOneWidget);
      verify(() => cubit.phoneChanged('07 48 84 08 56')).called(1);

      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('mm-number-field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.selection.baseOffset, '07 48 84 08 56'.length);

      // Effacer l'espace devant le curseur retire le chiffre qui le précède.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '07 4884 08 56',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump();
      expect(find.text('07 48 40 85 6'), findsOneWidget);
      expect(field.controller.selection.baseOffset, 4);
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

        expect(find.text('07 48 84 08 56'), findsOneWidget);
        verifyNever(() => cubit.phoneChanged(any()));
      },
    );

    testWidgets('numéro mémorisé : le champ démarre prérempli', (tester) async {
      await pumpWith(tester, kPayerRecognized);

      expect(find.text('07 48 84 08 56'), findsOneWidget);
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

  group('devise imposée et opérateurs permis', () {
    /// Côte d'Ivoire ouverte, seul MTN accepté.
    final onlyMtn = kPayerReady.copyWith(
      country: kCoteDIvoire,
      allowedOperators: const {'MTN_MOMO_CIV'},
    );

    testWidgets('section_disallowedPill_greyedWithLabel_notTappable', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpWith(tester, onlyMtn);

      final orange = find.byKey(const Key('mm-operator-ORANGE_CIV'));
      final mtn = find.byKey(const Key('mm-operator-MTN_MOMO_CIV'));
      expect(
        tester
            .widget<Opacity>(
              find.descendant(of: orange, matching: find.byType(Opacity)),
            )
            .opacity,
        0.4,
      );
      expect(
        find.descendant(of: mtn, matching: find.byType(Opacity)),
        findsNothing,
      );
      // Libellé sous le nom, sur la seule pastille grisée.
      expect(find.text('Non accepté'), findsOneWidget);
      expect(
        find.descendant(of: orange, matching: find.text('Non accepté')),
        findsOneWidget,
      );

      SemanticsNode semanticsOf(Finder pill) => tester.getSemantics(
        find
            .descendant(
              of: pill,
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.label != null,
              ),
            )
            .first,
      );

      final node = semanticsOf(orange);
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      final enabled = semanticsOf(mtn);
      expect(enabled.flagsCollection.isEnabled, Tristate.isTrue);

      await tester.tap(orange);
      await tester.pump();
      verifyNever(() => cubit.selectOperator(any()));

      await tester.tap(mtn);
      await tester.pump();
      verify(() => cubit.selectOperator('MTN_MOMO_CIV')).called(1);
      semantics.dispose();
    });

    testWidgets('section_noRestriction_noPillGreyed', (tester) async {
      await pumpWith(tester, kPayerReady.copyWith(country: kCoteDIvoire));

      expect(find.text('Non accepté'), findsNothing);
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('section_customDisallowedLabel', (tester) async {
      await pumpWith(
        tester,
        onlyMtn,
        section: const PayerAccountSection(disallowedOperatorLabel: 'Ajouté'),
      );

      expect(find.text('Ajouté'), findsOneWidget);
      expect(find.text('Non accepté'), findsNothing);
    });

    testWidgets('section_notAllowed_showsMessage', (tester) async {
      await pumpWith(
        tester,
        kPayerRecognized.copyWith(
          allowedOperators: const {'ORANGE_CIV'},
          recognition: RecognitionStatus.notAllowed,
          rejectedOperator: kMtnCiv,
        ),
      );

      expect(
        find.text("C'est un numéro MTN MoMo, que ce voyageur n'accepte pas."),
        findsOneWidget,
      );
      // L'opérateur choisi reste Orange : aucune bascule affichée.
      expect(find.text('Numéro Orange Money'), findsOneWidget);
    });

    testWidgets('section_notAllowed_customMessage', (tester) async {
      await pumpWith(
        tester,
        kPayerRecognized.copyWith(
          allowedOperators: const {'ORANGE_CIV'},
          recognition: RecognitionStatus.notAllowed,
          rejectedOperator: kMtnCiv,
        ),
        section: PayerAccountSection(
          notAllowedMessage: (operator) => '$operator déjà ajouté',
        ),
      );

      expect(find.text('MTN MoMo déjà ajouté'), findsOneWidget);
    });

    testWidgets('section_notAllowed_withoutRejectedOperator_noMessage', (
      tester,
    ) async {
      await pumpWith(
        tester,
        kPayerRecognized.copyWith(recognition: RecognitionStatus.notAllowed),
      );

      expect(find.textContaining('n\'accepte pas'), findsNothing);
    });

    testWidgets('section_numberHelper_shown', (tester) async {
      await pumpWith(
        tester,
        kPayerRecognized,
        section: const PayerAccountSection(
          numberHelper: "Le vôtre ou celui d'un proche.",
        ),
      );

      expect(find.text("Le vôtre ou celui d'un proche."), findsOneWidget);
    });

    testWidgets('section_withoutNumberHelper_noHelper', (tester) async {
      await pumpWith(tester, kPayerRecognized);

      expect(find.text("Le vôtre ou celui d'un proche."), findsNothing);
    });

    testWidgets('countryField_otherCurrency_greyedWithSubtitle', (
      tester,
    ) async {
      const cameroon = MobileMoneyCountry(
        country: 'CM',
        currency: 'XAF',
        operators: [
          MobileMoneyOperator(
            code: 'MTN_MOMO_CMR',
            label: 'MTN MoMo',
            brand: 'MTN',
          ),
        ],
      );
      await pumpWith(
        tester,
        const PayerAccountState(
          status: PayerAccountStatus.ready,
          currency: 'XOF',
          countries: MobileMoneyCountries(
            available: [kCoteDIvoire],
            otherCurrency: [cameroon],
            upcoming: ['ML'],
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('mm-country-field')), 'Cam');
      await tester.pumpAndSettle();

      expect(find.text('Cameroun'), findsOneWidget);
      expect(find.text('Ce paiement se fait en XOF'), findsOneWidget);
      // Grisé, pas de pastille « Bientôt » ni de liste d'opérateurs.
      expect(find.text('Bientôt'), findsNothing);
      expect(find.text('MTN MoMo'), findsNothing);

      await tester.tap(find.text('Cameroun'));
      await tester.pumpAndSettle();
      verifyNever(() => cubit.selectCountry(any()));

      // Un pays de la devise reste choisissable dans la même liste.
      await tester.enterText(find.byKey(const Key('mm-country-field')), 'cote');
      await tester.pumpAndSettle();
      await tester.tap(find.text("Côte d'Ivoire"));
      await tester.pumpAndSettle();
      verify(() => cubit.selectCountry('CI')).called(1);
    });

    testWidgets('countryField_otherCurrency_submitNeverSelects', (
      tester,
    ) async {
      const cameroon = MobileMoneyCountry(country: 'CM', currency: 'XAF');
      await pumpWith(
        tester,
        const PayerAccountState(
          status: PayerAccountStatus.ready,
          currency: 'XOF',
          countries: MobileMoneyCountries(otherCurrency: [cameroon]),
        ),
      );

      await tester.enterText(find.byKey(const Key('mm-country-field')), 'Cam');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      verifyNever(() => cubit.selectCountry(any()));
    });

    testWidgets('countryField_otherCurrency_withoutCurrency_noSubtitle', (
      tester,
    ) async {
      const cameroon = MobileMoneyCountry(country: 'CM', currency: 'XAF');
      await pumpWith(
        tester,
        const PayerAccountState(
          status: PayerAccountStatus.ready,
          countries: MobileMoneyCountries(otherCurrency: [cameroon]),
        ),
      );

      await tester.enterText(find.byKey(const Key('mm-country-field')), 'Cam');
      await tester.pumpAndSettle();

      expect(find.text('Cameroun'), findsOneWidget);
      expect(find.textContaining('Ce paiement se fait en'), findsNothing);
    });

    testWidgets(
      'réduction du mouvement : le retour du numéro change de taille sans '
      'AnimatedSize ni exception',
      (tester) async {
        final controller = stubPayerAccount(cubit, kPayerRecognized);
        addTearDown(controller.close);
        await tester.pumpWidget(harness(disableAnimations: true));
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(PayerAccountSection),
            matching: find.byType(AnimatedSize),
          ),
          findsNothing,
        );

        // Message présent, puis absent, puis plus long : la taille de la zone
        // de retour change à chaque étape.
        controller.add(
          kPayerRecognized.copyWith(recognition: RecognitionStatus.idle),
        );
        await tester.pump();
        controller.add(
          kPayerRecognized.copyWith(
            recognition: RecognitionStatus.unrecognized,
          ),
        );
        await tester.pump();
        controller.add(
          kPayerRecognized.copyWith(recognition: RecognitionStatus.failed),
        );
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          find.text('Vérification impossible pour le moment.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('anglais : libellés traduits', (tester) async {
      final controller = stubPayerAccount(
        cubit,
        kPayerRecognized.copyWith(
          allowedOperators: const {'ORANGE_CIV'},
          recognition: RecognitionStatus.notAllowed,
          rejectedOperator: kMtnCiv,
        ),
      );
      addTearDown(controller.close);
      await tester.pumpWidget(harness(locale: AppL10n.en));
      await tester.pumpAndSettle();

      expect(find.text('Not accepted'), findsOneWidget);
      expect(
        find.text(
          'This is a MTN MoMo number, which this traveler does not accept.',
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
