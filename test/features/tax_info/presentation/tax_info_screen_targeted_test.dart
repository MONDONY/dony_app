import 'dart:async';

import 'package:dony/core/currency/country_picker.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tax_info/bloc/tax_info_cubit.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/models/tax_info_update.dart';
import 'package:dony/features/tax_info/data/repositories/tax_info_repository.dart';
import 'package:dony/features/tax_info/presentation/screens/tax_info_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../tax_info_targeted_fixtures.dart';
import '../tax_info_test_helpers.dart';

class _MockRepo extends Mock implements TaxInfoRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

/// Écran « Informations fiscales » avec le contrat de collecte ciblée
/// (yadony-back #730). L'ancien contrat reste couvert par
/// `tax_info_screen_test.dart`.
void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  setUpAll(() => registerFallbackValue(const TaxInfoUpdate()));

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  Future<TaxInfoCubit> pump(
    WidgetTester tester,
    TaxInfo info, {
    Locale locale = AppL10n.fr,
  }) async {
    useNarrowScreen(tester);
    when(() => repo.fetch()).thenAnswer((_) async => info);
    final cubit = TaxInfoCubit(repo, analytics);
    unawaited(cubit.load());
    addTearDown(cubit.close);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/profile/tax-info'),
              child: const Text('ACCUEIL'),
            ),
          ),
        ),
        GoRoute(
          path: '/profile/tax-info',
          builder: (_, _) =>
              BlocProvider.value(value: cubit, child: const TaxInfoScreen()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.tap(find.text('ACCUEIL'));
    await tester.pumpAndSettle();
    return cubit;
  }

  Finder save() => find.byKey(const Key('tax_info_save'));
  bool saveEnabled(WidgetTester tester) =>
      tester.widget<DonyButton>(save()).onPressed != null;
  Finder byKey(String key) => find.byKey(Key(key));

  String richText(WidgetTester tester, String key) =>
      tester.widget<Text>(byKey(key)).textSpan!.toPlainText();

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> pickCountry(WidgetTester tester, String name) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(CountryPickerList),
        matching: find.byType(TextField),
      ),
      name,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  TaxInfoUpdate captured() =>
      verify(() => repo.update(captureAny())).captured.single as TaxInfoUpdate;

  group('pays inconnu : seul le pays est demandé', () {
    testWidgets('vue pays seul, bouton grisé avec son aide', (tester) async {
      await pump(tester, kResidence);
      expect(find.text(fr.taxInfoResidenceTitle), findsOneWidget);
      expect(find.text(fr.taxInfoResidenceBody), findsOneWidget);
      expect(byKey('tax_info_residence'), findsOneWidget);
      expect(byKey('tax_info_number'), findsNothing);
      expect(byKey('tax_info_street'), findsNothing);
      expect(byKey('tax_info_first_name'), findsNothing);
      expect(find.text(fr.taxInfoSaveMissingResidence), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hors Union : enregistré, rien d\'autre, écran fermé', (
      tester,
    ) async {
      when(
        () => repo.saveResidenceCountry('CI'),
      ).thenAnswer((_) async => kOutOfScope);
      await pump(tester, kResidence);
      await tester.tap(byKey('tax_info_residence'));
      await tester.pumpAndSettle();
      await pickCountry(tester, 'Côte d\'Ivoire');
      expect(find.text('Côte d\'Ivoire'), findsOneWidget);
      expect(saveEnabled(tester), isTrue);
      await tester.tap(save());
      await tester.pumpAndSettle();
      verify(() => repo.saveResidenceCountry('CI')).called(1);
      expect(find.text(fr.taxInfoResidenceSaved), findsOneWidget);
      expect(find.text('ACCUEIL'), findsOneWidget);
    });

    testWidgets('résident de l\'Union : l\'écran montre aussitôt ce qui '
        'manque', (tester) async {
      when(
        () => repo.saveResidenceCountry('FR'),
      ).thenAnswer((_) async => kFranceDiditNifMissing);
      await pump(tester, kResidence);
      await tester.tap(byKey('tax_info_residence'));
      await tester.pumpAndSettle();
      await pickCountry(tester, 'France');
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(find.text(fr.taxInfoResidenceSavedMore), findsOneWidget);
      expect(byKey('tax_info_number'), findsOneWidget);
      expect(byKey('tax_info_residence'), findsNothing);
    });

    testWidgets('pays verrouillé : message, rien de fermé', (tester) async {
      when(
        () => repo.saveResidenceCountry(any()),
      ).thenThrow(const TaxInfoException(kTaxResidenceLockedCode));
      await pump(tester, kResidence);
      await tester.tap(byKey('tax_info_residence'));
      await tester.pumpAndSettle();
      await pickCountry(tester, 'France');
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(find.text(fr.taxInfoErrorCountryLocked), findsOneWidget);
      expect(byKey('tax_info_residence'), findsOneWidget);
    });

    testWidgets('activation des paiements en cours : renvoi vers Réglages', (
      tester,
    ) async {
      when(
        () => repo.saveResidenceCountry(any()),
      ).thenThrow(const TaxInfoException(kTaxResidenceResetsPayoutCode));
      await pump(tester, kResidence);
      await tester.tap(byKey('tax_info_residence'));
      await tester.pumpAndSettle();
      await pickCountry(tester, 'France');
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(find.text(fr.taxInfoErrorCountryResetsPayout), findsOneWidget);
    });

    testWidgets('« Plus tard » ferme sans rien enregistrer', (tester) async {
      await pump(tester, kResidence);
      await tester.tap(byKey('tax_info_later'));
      await tester.pumpAndSettle();
      expect(find.text('ACCUEIL'), findsOneWidget);
      verifyNever(() => repo.saveResidenceCountry(any()));
    });
  });

  group('INFO_REQUIRED : seulement ce qui manque', () {
    testWidgets('France + pièce complète : seul le numéro fiscal, le reste '
        'en lecture seule', (tester) async {
      await pump(tester, kFranceDiditNifMissing);
      expect(
        richText(tester, 'tax_info_collect_intro'),
        '${fr.taxInfoCollectIntro} ${fr.taxInfoCollectNoTax}',
      );
      expect(
        find.text(
          'Nous avons déjà repris les informations de votre pièce '
          'd\'identité. Il nous manque seulement : votre numéro fiscal.',
        ),
        findsOneWidget,
      );
      expect(find.text(fr.taxInfoWhereToFind), findsOneWidget);
      expect(find.text(fr.taxInfoLearnMore), findsOneWidget);
      // Lecture seule : valeurs de la pièce, aucun champ pour elles.
      expect(byKey('tax_info_known_id'), findsOneWidget);
      expect(find.text(fr.taxInfoKnownTitle), findsOneWidget);
      expect(find.text('Awa Diallo'), findsOneWidget);
      expect(find.text('12 avril 1990'), findsOneWidget);
      expect(
        find.text('1 rue de la République\n69001 Lyon\nFrance'),
        findsOneWidget,
      );
      expect(byKey('tax_info_first_name'), findsNothing);
      expect(byKey('tax_info_birth_date'), findsNothing);
      expect(byKey('tax_info_street'), findsNothing);
      expect(byKey('tax_info_not_my_address'), findsOneWidget);
      // Seul le bloc numéro fiscal.
      expect(byKey('tax_info_number'), findsOneWidget);
      expect(byKey('tax_info_country'), findsOneWidget);
      expect(byKey('tax_info_vat'), findsOneWidget);
      expect(byKey('tax_info_no_number'), findsOneWidget);
      expect(byKey('tax_info_birth_place'), findsNothing);
      // Jamais téléphone, e-mail, nationalité ni copie de pièce.
      for (final word in ['Téléphone', 'E-mail', 'Nationalité', 'Photo']) {
        expect(find.textContaining(word), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('numéro français : 12 chiffres refusés aussitôt, 13 '
        'acceptés et envoyés', (tester) async {
      when(() => repo.update(any())).thenAnswer((_) async => kComplete);
      await pump(tester, kFranceDiditNifMissing);
      await tester.enterText(byKey('tax_info_number'), '123456789012');
      await tester.pump();
      expect(find.text(fr.taxInfoNumberFrInvalid), findsOneWidget);
      expect(saveEnabled(tester), isFalse);

      await tester.enterText(byKey('tax_info_number'), '1234567890123');
      await tester.pump();
      expect(find.text(fr.taxInfoNumberFrInvalid), findsNothing);
      expect(saveEnabled(tester), isTrue);
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(captured().toJson(), {
        'taxIdentificationNumber': '1234567890123',
        'taxCountry': 'FR',
      });
      expect(find.text(fr.taxInfoSaved), findsOneWidget);
      expect(find.text('ACCUEIL'), findsOneWidget);
    });

    testWidgets('« Ce n\'est plus mon adresse » : ressaisie, puis retour à '
        'l\'adresse de la pièce', (tester) async {
      when(() => repo.update(any())).thenAnswer((_) async => kComplete);
      await pump(tester, kFranceDiditNifMissing);
      await tapVisible(tester, byKey('tax_info_not_my_address'));
      expect(byKey('tax_info_street'), findsOneWidget);
      expect(byKey('tax_info_not_my_address'), findsNothing);
      expect(find.text('Pays de résidence : France'), findsOneWidget);
      await tester.enterText(byKey('tax_info_street'), '12 rue des Lilas');
      await tester.enterText(byKey('tax_info_postal_code'), '13001');
      await tester.enterText(byKey('tax_info_city'), 'Marseille');
      await tester.enterText(byKey('tax_info_number'), '1234567890123');
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(captured().toJson()['address'], {
        'street': '12 rue des Lilas',
        'postalCode': '13001',
        'city': 'Marseille',
      });
    });

    testWidgets('« Garder l\'adresse de ma pièce » annule la ressaisie', (
      tester,
    ) async {
      await pump(tester, kFranceDiditNifMissing);
      await tapVisible(tester, byKey('tax_info_not_my_address'));
      await tester.enterText(byKey('tax_info_street'), 'x');
      await tapVisible(tester, byKey('tax_info_keep_address'));
      expect(byKey('tax_info_street'), findsNothing);
      expect(byKey('tax_info_not_my_address'), findsOneWidget);
    });

    testWidgets('sans numéro fiscal : le lieu de naissance le remplace', (
      tester,
    ) async {
      when(() => repo.update(any())).thenAnswer((_) async => kBirthPlaceSaved);
      await pump(tester, kFranceDiditNifMissing);
      await tapVisible(tester, byKey('tax_info_no_number'));
      expect(byKey('tax_info_number'), findsNothing);
      expect(byKey('tax_info_vat'), findsNothing);
      expect(byKey('tax_info_birth_place'), findsOneWidget);
      expect(find.text(fr.taxInfoBirthPlaceHint), findsOneWidget);
      expect(find.text(fr.taxInfoSaveMissingBirthPlace), findsOneWidget);
      await tester.enterText(
        byKey('tax_info_birth_place'),
        'Saint-Louis, Sénégal',
      );
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(captured().toJson(), {'birthPlace': 'Saint-Louis, Sénégal'});
    });

    testWidgets('lieu de naissance déjà enregistré : case cochée, aide '
        'adaptée', (tester) async {
      await pump(tester, kBirthPlaceSaved);
      expect(
        tester.widget<DonyCheckbox>(byKey('tax_info_no_number')).value,
        isTrue,
      );
      expect(find.text(fr.taxInfoBirthPlaceSaved), findsOneWidget);
      // Adresse du profil : carte à part, sans lien de remplacement.
      expect(byKey('tax_info_known_profile'), findsOneWidget);
      expect(byKey('tax_info_not_my_address'), findsNothing);
    });

    testWidgets('rien de la pièce : nom, date, adresse et numéro demandés, '
        'sans « déjà repris »', (tester) async {
      when(() => repo.update(any())).thenAnswer((_) async => kComplete);
      await pump(tester, kAllMissing);
      expect(
        find.text(
          'Il nous manque seulement : vos nom et prénom, votre date de '
          'naissance, votre adresse et votre numéro fiscal.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining(fr.taxInfoCollectPrefilled), findsNothing);
      expect(byKey('tax_info_known_id'), findsNothing);
      expect(find.text(fr.taxInfoSaveMissingName), findsOneWidget);

      await tester.enterText(byKey('tax_info_first_name'), 'Jeanne');
      await tester.enterText(byKey('tax_info_last_name'), 'Martin');
      await tester.pump();
      expect(find.text(fr.taxInfoSaveMissingBirthDate), findsOneWidget);

      await tapVisible(tester, byKey('tax_info_birth_date'));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      final ok = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      ).okButtonLabel;
      await tester.tap(find.text(ok));
      await tester.pumpAndSettle();
      final year = DateTime.now().year - 30;
      expect(find.text('1 janvier $year'), findsOneWidget);
      expect(find.text(fr.taxInfoSaveMissingAddress), findsOneWidget);

      await tester.enterText(byKey('tax_info_street'), 'Rue Neuve 3');
      await tester.enterText(byKey('tax_info_postal_code'), '1000');
      await tester.enterText(byKey('tax_info_city'), 'Bruxelles');
      await tester.enterText(byKey('tax_info_number'), '85.07.30-033.28');
      await tester.pump();
      expect(find.text('Belgique'), findsOneWidget);
      expect(saveEnabled(tester), isTrue);
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(captured().toJson(), {
        'taxIdentificationNumber': '85.07.30-033.28',
        'taxCountry': 'BE',
        'firstName': 'Jeanne',
        'lastName': 'Martin',
        'birthDate': '$year-01-01',
        'address': {
          'street': 'Rue Neuve 3',
          'postalCode': '1000',
          'city': 'Bruxelles',
        },
      });
    });

    testWidgets('identité du profil, numéro déjà fourni : seule l\'adresse, '
        'sans aide sur le numéro', (tester) async {
      await pump(tester, kProfileAddressMissing);
      expect(
        find.text('Il nous manque seulement : votre adresse.'),
        findsOneWidget,
      );
      expect(find.text(fr.taxInfoWhereToFind), findsNothing);
      expect(find.text(fr.taxInfoKnownProfileTitle), findsOneWidget);
      expect(find.text('Jeanne Martin'), findsOneWidget);
      expect(find.text('****0123'), findsOneWidget);
      expect(byKey('tax_info_street'), findsOneWidget);
      expect(byKey('tax_info_number'), findsNothing);
      expect(byKey('tax_info_no_number'), findsNothing);
    });

    testWidgets('422 sur la ville : erreur sous la ville, pas de message '
        'global', (tester) async {
      when(() => repo.update(any())).thenThrow(
        const TaxInfoException('tax-info-invalid', field: 'address.city'),
      );
      await pump(tester, kProfileAddressMissing);
      await tester.enterText(byKey('tax_info_street'), 'r');
      await tester.enterText(byKey('tax_info_postal_code'), 'p');
      await tester.enterText(byKey('tax_info_city'), 'c');
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(find.text(fr.taxInfoFieldInvalid), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.enterText(byKey('tax_info_city'), 'Lyon');
      await tester.pump();
      expect(find.text(fr.taxInfoFieldInvalid), findsNothing);
    });

    testWidgets('422 lecture seule : message global', (tester) async {
      when(() => repo.update(any())).thenThrow(
        const TaxInfoException('tax-info-read-only', field: 'birthDate'),
      );
      await pump(tester, kFranceDiditNifMissing);
      await tester.enterText(byKey('tax_info_number'), '1234567890123');
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(find.text(fr.taxInfoErrorReadOnly), findsOneWidget);
    });
  });

  group('COMPLETE et hors périmètre', () {
    testWidgets('COMPLETE : « Tout est à jour », rien à demander', (
      tester,
    ) async {
      await pump(tester, kComplete);
      expect(byKey('tax_info_complete'), findsOneWidget);
      expect(find.text(fr.taxInfoCompleteTitle), findsOneWidget);
      expect(find.text(fr.taxInfoCompleteBody), findsOneWidget);
      expect(find.text('****0123'), findsOneWidget);
      expect(byKey('tax_info_number'), findsNothing);
      expect(byKey('tax_info_edit'), findsOneWidget);

      // « Modifier » : seulement le numéro, avec la règle française.
      await tester.tap(byKey('tax_info_edit'));
      await tester.pumpAndSettle();
      expect(byKey('tax_info_number'), findsOneWidget);
      expect(byKey('tax_info_no_number'), findsNothing);
      expect(find.text(fr.taxInfoReason), findsOneWidget);
      await tester.enterText(byKey('tax_info_number'), '123456789012');
      await tester.pump();
      expect(find.text(fr.taxInfoNumberFrInvalid), findsOneWidget);
    });

    testWidgets('NE_PAS_SOLLICITER : l\'écran se ferme seul, avec un mot', (
      tester,
    ) async {
      await pump(tester, kOutOfScope);
      expect(find.text(fr.taxInfoNotConcerned), findsOneWidget);
      expect(find.text('ACCUEIL'), findsOneWidget);
      expect(byKey('tax_info_save'), findsNothing);
    });
  });

  group('FR et EN à 360 dp', () {
    for (final entry in {
      'fr': (AppL10n.fr, fr),
      'en': (AppL10n.en, en),
    }.entries) {
      final (locale, l) = entry.value;

      testWidgets('${entry.key} : pays seul, boutons sur une ligne', (
        tester,
      ) async {
        await pump(tester, kResidence, locale: locale);
        expect(find.text(l.taxInfoResidenceTitle), findsOneWidget);
        expectOneLineNotShrunk(tester, save());
        expectOneLineNotShrunk(tester, byKey('tax_info_later'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} : numéro manquant, boutons et liens sur une '
          'ligne, même hauteur', (tester) async {
        await pump(tester, kFranceDiditNifMissing, locale: locale);
        expect(tester.takeException(), isNull);
        expectOneLineNotShrunk(tester, save());
        expectOneLineNotShrunk(tester, byKey('tax_info_later'));
        expect(tester.getSize(save()).height, 52);
        expect(
          tester.getSize(byKey('tax_info_later')).height,
          tester.getSize(save()).height,
        );
        await tester.ensureVisible(byKey('tax_info_learn_more'));
        await tester.pumpAndSettle();
        expectOneLineNotShrunk(tester, byKey('tax_info_learn_more'));
        await tester.ensureVisible(byKey('tax_info_not_my_address'));
        await tester.pumpAndSettle();
        expectOneLineNotShrunk(tester, byKey('tax_info_not_my_address'));
        await tester.tap(byKey('tax_info_not_my_address'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(byKey('tax_info_keep_address'));
        await tester.pumpAndSettle();
        expectOneLineNotShrunk(tester, byKey('tax_info_keep_address'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} : tout à saisir, aucune exception', (
        tester,
      ) async {
        await pump(tester, kAllMissing, locale: locale);
        expect(find.text(l.taxInfoFirstNameLabel), findsOneWidget);
        expect(find.text(l.taxInfoSaveMissingName), findsOneWidget);
        expectOneLineNotShrunk(tester, save());
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} : tout est à jour', (tester) async {
        await pump(tester, kComplete, locale: locale);
        expect(find.text(l.taxInfoCompleteTitle), findsOneWidget);
        expectOneLineNotShrunk(tester, byKey('tax_info_edit'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('en : en-tête en anglais', (tester) async {
      await pump(tester, kFranceDiditNifMissing, locale: AppL10n.en);
      expect(
        find.text(
          'We have already taken the information from your ID document. '
          'We only need: your tax identification number.',
        ),
        findsOneWidget,
      );
      expect(find.text('This is no longer my address'), findsOneWidget);
      expect(find.text('April 12, 1990'), findsOneWidget);
    });
  });
}
