import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tax_info/bloc/tax_info_cubit.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/repositories/tax_info_repository.dart';
import 'package:dony/features/tax_info/presentation/screens/tax_info_screen.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_info_labels.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_residence_picker.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../helpers/recording_url_launcher.dart';
import '../tax_info_test_helpers.dart';

class _MockRepo extends Mock implements TaxInfoRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

const _ask = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.solliciter,
  residenceCountry: 'FR',
);
const _done = TaxInfo(
  provided: true,
  solicitation: TaxInfoSolicitation.dejaFourni,
  maskedTaxIdentificationNumber: '****1234',
  taxCountry: 'SN',
  vatNumberProvided: true,
  maskedVatNumber: '****789',
);
const _doneNoVat = TaxInfo(
  provided: true,
  solicitation: TaxInfoSolicitation.dejaFourni,
  maskedTaxIdentificationNumber: '****1234',
  taxCountry: 'SN',
);
const _none = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.nePasSolliciter,
);

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => repo.fetch()).thenAnswer((_) async => _ask);
  });

  void stubSave(Future<TaxInfo> Function() answer) => when(
    () => repo.save(
      taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
      taxCountry: any(named: 'taxCountry'),
      vatNumber: any(named: 'vatNumber'),
    ),
  ).thenAnswer((_) => answer());

  Future<TaxInfoCubit> pump(
    WidgetTester tester, {
    Locale locale = AppL10n.fr,
    bool settle = true,
  }) async {
    useNarrowScreen(tester);
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
    return cubit;
  }

  Finder save() => find.byKey(const Key('tax_info_save'));
  bool saveEnabled(WidgetTester tester) =>
      tester.widget<DonyButton>(save()).onPressed != null;

  group('chargement', () {
    testWidgets('spinner pendant la lecture', (tester) async {
      final gate = Completer<TaxInfo>();
      when(() => repo.fetch()).thenAnswer((_) => gate.future);
      await pump(tester, settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(save(), findsNothing);
      gate.complete(_ask);
      await tester.pumpAndSettle();
      expect(save(), findsOneWidget);
    });

    testWidgets('échec réseau : message et « Réessayer »', (tester) async {
      when(() => repo.fetch()).thenThrow(const TaxInfoException('network'));
      await pump(tester);
      expect(find.text(fr.taxInfoFailureTitle), findsOneWidget);
      expect(find.text(fr.taxInfoFailureBody), findsOneWidget);

      when(() => repo.fetch()).thenAnswer((_) async => _ask);
      await tester.tap(find.text(fr.commonRetry));
      await tester.pumpAndSettle();
      expect(save(), findsOneWidget);
    });

    testWidgets('404 (fonction absente) : « Rien à renseigner », aucun '
        'formulaire, aucune erreur', (tester) async {
      when(() => repo.fetch()).thenThrow(const TaxInfoUnavailableException());
      await pump(tester);
      expect(find.text(fr.taxInfoUnavailableTitle), findsOneWidget);
      expect(find.text(fr.taxInfoUnavailableBody), findsOneWidget);
      expect(save(), findsNothing);
      expect(find.text(fr.taxInfoFailureTitle), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(fr.taxInfoClose));
      await tester.pumpAndSettle();
      expect(find.text('ACCUEIL'), findsOneWidget);
    });

    testWidgets('NE_PAS_SOLLICITER : « Rien à renseigner », aucun '
        'formulaire', (tester) async {
      when(() => repo.fetch()).thenAnswer((_) async => _none);
      await pump(tester);
      expect(find.text(fr.taxInfoUnavailableTitle), findsOneWidget);
      expect(save(), findsNothing);
      expect(find.byKey(const Key('tax_info_number')), findsNothing);
    });
  });

  group('formulaire (SOLLICITER)', () {
    testWidgets('motif, rassurance, lien, trois champs, deux boutons', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(fr.taxInfoScreenTitle), findsOneWidget);
      expect(
        find.text(
          'Obligation légale de transmission à l\'administration fiscale. '
          'Vos informations sont chiffrées.',
        ),
        findsOneWidget,
      );
      expect(find.text(fr.taxInfoNeverBlocking), findsOneWidget);
      expect(find.text(fr.taxInfoLearnMore), findsOneWidget);
      expect(find.text(fr.taxInfoNumberLabel), findsOneWidget);
      expect(find.text(fr.taxInfoCountryLabel), findsOneWidget);
      expect(find.text(fr.taxInfoVatLabel), findsOneWidget);
      expect(find.text(fr.taxInfoNumberHint), findsOneWidget);
      expect(find.text(fr.taxInfoSave), findsOneWidget);
      expect(find.text(fr.taxInfoLater), findsOneWidget);
      // Pays proposé d'après la résidence.
      expect(find.text('France'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Enregistrer » grisé tant que le numéro est invalide, avec '
        'une aide d\'erreur claire', (tester) async {
      await pump(tester);
      expect(saveEnabled(tester), isFalse);

      await tester.enterText(find.byKey(const Key('tax_info_number')), '12');
      await tester.pump();
      expect(find.text(fr.taxInfoNumberInvalid), findsOneWidget);
      expect(find.text(fr.taxInfoNumberHint), findsNothing);
      expect(saveEnabled(tester), isFalse);

      await tester.enterText(find.byKey(const Key('tax_info_number')), '12@4');
      await tester.pump();
      expect(find.text(fr.taxInfoNumberInvalid), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        '12 34-56/7.8',
      );
      await tester.pump();
      expect(find.text(fr.taxInfoNumberInvalid), findsNothing);
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('le numéro est limité à 40 caractères', (tester) async {
      await pump(tester);
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        '1' * 60,
      );
      await tester.pump();
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('tax_info_number')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text.length, 40);
    });

    testWidgets('clavier : ni correcteur, ni suggestions, ni apprentissage, '
        'majuscules, sur le numéro fiscal ET la TVA', (tester) async {
      await pump(tester);
      for (final key in ['tax_info_number', 'tax_info_vat']) {
        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(TextField),
          ),
        );
        expect(field.autocorrect, isFalse, reason: key);
        expect(field.enableSuggestions, isFalse, reason: key);
        expect(field.enableIMEPersonalizedLearning, isFalse, reason: key);
        expect(field.textCapitalization, TextCapitalization.characters);
        expect(field.keyboardType, TextInputType.text, reason: key);
      }
    });

    testWidgets('TVA invalide : erreur sous la TVA, bouton grisé avec une aide '
        'claire ; vide, la TVA est permise', (tester) async {
      await pump(tester);
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        '12345678',
      );
      await tester.pump();
      expect(saveEnabled(tester), isTrue);

      await tester.enterText(find.byKey(const Key('tax_info_vat')), 'F1');
      await tester.pump();
      expect(find.text(fr.taxInfoNumberInvalid), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
      expect(find.text(fr.taxInfoSaveMissingVat), findsOneWidget);

      await tester.enterText(find.byKey(const Key('tax_info_vat')), '');
      await tester.pump();
      expect(find.text(fr.taxInfoNumberInvalid), findsNothing);
      expect(saveEnabled(tester), isTrue);
      expect(find.byKey(const Key('tax_info_save_missing')), findsNothing);
    });

    testWidgets('aide au-dessus d\'« Enregistrer » grisé : numéro puis pays', (
      tester,
    ) async {
      when(() => repo.fetch()).thenAnswer(
        (_) async => const TaxInfo(
          provided: false,
          solicitation: TaxInfoSolicitation.solliciter,
        ),
      );
      await pump(tester);
      // Résidence inconnue : pas de pays proposé.
      expect(find.text(fr.taxInfoCountryHint), findsOneWidget);
      expect(find.text(fr.taxInfoSaveMissingNumber), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        '12345678',
      );
      await tester.pump();
      expect(find.text(fr.taxInfoSaveMissingNumber), findsNothing);
      expect(find.text(fr.taxInfoSaveMissingCountry), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('422 sur la TVA : l\'erreur s\'affiche sous la TVA, pas sous '
        'le numéro, et s\'efface avec la TVA', (tester) async {
      stubSave(
        () async => throw const TaxInfoException(
          'tax-info-invalid',
          status: 422,
          field: 'vatNumber',
        ),
      );
      await pump(tester);
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        '12345678',
      );
      await tester.enterText(find.byKey(const Key('tax_info_vat')), 'FR1234');
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();

      final errorFinder = find.text(fr.taxInfoErrorInvalid);
      expect(errorFinder, findsOneWidget);
      // Sous le champ TVA : on lit l'erreur dans le décor de ce champ.
      final vatError = tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('tax_info_vat')),
              matching: find.byType(TextField),
            ),
          )
          .decoration
          ?.errorText;
      final numberError = tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('tax_info_number')),
              matching: find.byType(TextField),
            ),
          )
          .decoration
          ?.errorText;
      expect(vatError, fr.taxInfoErrorInvalid);
      expect(numberError, isNull);

      // Modifier le numéro n'efface pas l'erreur de la TVA.
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        '123456789',
      );
      await tester.pump();
      expect(find.text(fr.taxInfoErrorInvalid), findsOneWidget);

      await tester.enterText(find.byKey(const Key('tax_info_vat')), 'FR12345');
      await tester.pump();
      expect(find.text(fr.taxInfoErrorInvalid), findsNothing);
    });

    testWidgets('422 sur le numéro : erreur sous le numéro et effacée quand '
        'le numéro change', (tester) async {
      stubSave(
        () async => throw const TaxInfoException(
          'tax-info-invalid',
          field: 'taxIdentificationNumber',
        ),
      );
      await pump(tester);
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        '12345678',
      );
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();
      final numberError = tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('tax_info_number')),
              matching: find.byType(TextField),
            ),
          )
          .decoration
          ?.errorText;
      expect(numberError, fr.taxInfoErrorInvalid);
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        '12345679',
      );
      await tester.pump();
      expect(find.text(fr.taxInfoErrorInvalid), findsNothing);
    });

    testWidgets('choix du pays : catalogue de l\'app et toute l\'Union', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('tax_info_country')));
      await tester.pumpAndSettle();
      expect(find.byType(TaxResidencePickerList), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('tax_residence_search')),
        'Sénégal',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tax_residence_SN')));
      await tester.pumpAndSettle();
      expect(find.byType(TaxResidencePickerList), findsNothing);
      expect(find.text('Sénégal'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tax_info_country')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('tax_residence_search')),
        'pologne',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tax_residence_PL')));
      await tester.pumpAndSettle();
      expect(find.text('Pologne'), findsOneWidget);
    });

    testWidgets('enregistrement réussi : envoi rogné, confirmation, écran '
        'fermé', (tester) async {
      stubSave(() async => _done);
      await pump(tester);
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        ' 12345678 ',
      );
      await tester.enterText(find.byKey(const Key('tax_info_vat')), 'FR99');
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();

      verify(
        () => repo.save(
          taxIdentificationNumber: ' 12345678 ',
          taxCountry: 'FR',
          vatNumber: 'FR99',
        ),
      ).called(1);
      expect(find.text(fr.taxInfoSaved), findsOneWidget);
      expect(find.text('ACCUEIL'), findsOneWidget);
    });

    testWidgets('chargement du bouton et double appui : un seul envoi', (
      tester,
    ) async {
      final gate = Completer<TaxInfo>();
      stubSave(() => gate.future);
      await pump(tester);
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        '12345678',
      );
      await tester.pump();
      await tester.tap(save());
      await tester.pump();
      expect(tester.widget<DonyButton>(save()).isLoading, isTrue);
      await tester.tap(save(), warnIfMissed: false);
      await tester.tap(save(), warnIfMissed: false);
      await tester.pump();
      // « Plus tard » est neutralisé pendant l'envoi.
      expect(
        tester
            .widget<DonyButton>(find.byKey(const Key('tax_info_later')))
            .onPressed,
        isNull,
      );

      gate.complete(_done);
      await tester.pumpAndSettle();
      verify(
        () => repo.save(
          taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
          taxCountry: any(named: 'taxCountry'),
          vatNumber: any(named: 'vatNumber'),
        ),
      ).called(1);
    });

    testWidgets('422 : message clair sous le champ, sans recopier la valeur, '
        'formulaire gardé', (tester) async {
      stubSave(
        () async =>
            throw const TaxInfoException('tax-info-invalid', status: 422),
      );
      await pump(tester);
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        'SECRET-9999',
      );
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(find.text(fr.taxInfoErrorInvalid), findsOneWidget);
      expect(find.textContaining('SECRET-9999'), findsOneWidget); // le champ
      // Une seule occurrence : sous le champ, pas en doublon dans un snackbar.
      expect(find.text(fr.taxInfoErrorInvalid).evaluate().length, 1);
      expect(saveEnabled(tester), isTrue);
      expect(find.text('ACCUEIL'), findsNothing);

      // Corriger le numéro retire l'erreur.
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        'SECRET-0000',
      );
      await tester.pump();
      expect(find.text(fr.taxInfoErrorInvalid), findsNothing);
    });

    testWidgets('réseau : snackbar, formulaire gardé', (tester) async {
      stubSave(() async => throw const TaxInfoException('network'));
      await pump(tester);
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        '12345678',
      );
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(find.text(fr.taxInfoErrorNetwork), findsOneWidget);
      expect(save(), findsOneWidget);
    });

    testWidgets('404 dac7-disabled à l\'envoi : fonction absente', (
      tester,
    ) async {
      stubSave(
        () async => throw const TaxInfoUnavailableException(status: 404),
      );
      await pump(tester);
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        '12345678',
      );
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(find.text(fr.taxInfoErrorUnavailable), findsOneWidget);
      expect(find.text(fr.taxInfoUnavailableTitle), findsOneWidget);
      expect(save(), findsNothing);
    });

    testWidgets('« Plus tard » ferme sans rien enregistrer', (tester) async {
      await pump(tester);
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        '12345678',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('tax_info_later')));
      await tester.pumpAndSettle();
      expect(find.text('ACCUEIL'), findsOneWidget);
      verifyNever(
        () => repo.save(
          taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
          taxCountry: any(named: 'taxCountry'),
          vatNumber: any(named: 'vatNumber'),
        ),
      );
      verify(
        () => analytics.logEvent(
          'tax_info_later',
          properties: {'source': 'screen'},
        ),
      ).called(1);
    });

    testWidgets('« Plus tard » sans pile (lien profond) : retour au profil', (
      tester,
    ) async {
      useNarrowScreen(tester);
      final cubit = TaxInfoCubit(repo, analytics);
      unawaited(cubit.load());
      addTearDown(cubit.close);
      final router = GoRouter(
        initialLocation: '/profile/tax-info',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) => const Scaffold(body: Text('PROFIL')),
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
          locale: AppL10n.fr,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tax_info_later')));
      await tester.pumpAndSettle();
      expect(find.text('PROFIL'), findsOneWidget);
    });

    testWidgets('« En savoir plus » ouvre impots.gouv.fr dans le navigateur '
        'externe', (tester) async {
      final launcher = RecordingUrlLauncher();
      installUrlLauncher(launcher, addTearDown);
      await pump(tester);
      await tester.tap(find.byKey(const Key('tax_info_learn_more')));
      await tester.pumpAndSettle();
      expect(launcher.urls, hasLength(1));
      expect(
        launcher.urls.single,
        'https://www.impots.gouv.fr/economie-collaborative-et-plateformes-numeriques',
      );
      expect(kTaxInfoLearnMoreUrl.scheme, 'https');
      expect(launcher.modes.single, PreferredLaunchMode.externalApplication);
    });
  });

  group('fiche (DEJA_FOURNI)', () {
    setUp(() => when(() => repo.fetch()).thenAnswer((_) async => _done));

    testWidgets('forme masquée, pays, TVA masquée, jamais de formulaire', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(fr.taxInfoSummaryTitle), findsOneWidget);
      expect(find.text('****1234'), findsOneWidget);
      expect(find.text('Sénégal'), findsOneWidget);
      expect(find.text('****789'), findsOneWidget);
      expect(find.byKey(const Key('tax_info_number')), findsNothing);
      expect(save(), findsNothing);
      expect(find.text(fr.taxInfoEdit), findsOneWidget);
      expect(find.text(fr.taxInfoLater), findsNothing);
    });

    testWidgets('sans TVA : « Non renseigné »', (tester) async {
      when(() => repo.fetch()).thenAnswer((_) async => _doneNoVat);
      await pump(tester);
      expect(find.text(fr.taxInfoVatNone), findsOneWidget);
    });

    testWidgets('« Modifier » ouvre un formulaire vide, « Annuler » revient '
        'sans rien enregistrer', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('tax_info_edit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tax_info_number')), findsOneWidget);
      expect(find.text(fr.taxInfoCancelEdit), findsOneWidget);
      expect(find.text(fr.taxInfoLater), findsNothing);
      // Pays du numéro déjà enregistré.
      expect(find.text('Sénégal'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tax_info_later')));
      await tester.pumpAndSettle();
      expect(find.text('****1234'), findsOneWidget);
      expect(find.text('ACCUEIL'), findsNothing);
      verifyNever(
        () => repo.save(
          taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
          taxCountry: any(named: 'taxCountry'),
          vatNumber: any(named: 'vatNumber'),
        ),
      );
    });

    testWidgets('modification enregistrée : on n\'affiche que la forme '
        'masquée de la réponse', (tester) async {
      stubSave(() async => _done);
      await pump(tester);
      await tester.tap(find.byKey(const Key('tax_info_edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('tax_info_number')),
        'NOUVEAU-5678',
      );
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(find.text(fr.taxInfoSaved), findsOneWidget);
      expect(find.textContaining('NOUVEAU-5678'), findsNothing);
    });
  });

  group('FR et EN à 360 dp', () {
    for (final entry in {
      'fr': (AppL10n.fr, fr),
      'en': (AppL10n.en, en),
    }.entries) {
      final (locale, l) = entry.value;

      testWidgets('${entry.key} : formulaire, libellés sur une ligne, '
          'hauteur des boutons inchangée', (tester) async {
        await pump(tester, locale: locale);
        expect(tester.takeException(), isNull);

        expect(find.text(l.taxInfoScreenTitle), findsOneWidget);
        expect(find.text(l.taxInfoReason), findsOneWidget);
        final saveFinder = find.byKey(const Key('tax_info_save'));
        final laterFinder = find.byKey(const Key('tax_info_later'));
        expectOneLineNotShrunk(tester, saveFinder);
        expectOneLineNotShrunk(tester, laterFinder);
        expectOneLineNotShrunk(
          tester,
          find.byKey(const Key('tax_info_learn_more')),
        );
        // Même hauteur pour les deux boutons : aucun libellé n'en change.
        expect(tester.getSize(saveFinder).height, 52);
        expect(
          tester.getSize(laterFinder).height,
          tester.getSize(saveFinder).height,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} : fiche, bouton « Modifier » sur une ligne', (
        tester,
      ) async {
        when(() => repo.fetch()).thenAnswer((_) async => _done);
        await pump(tester, locale: locale);
        expect(find.text(l.taxInfoSummaryTitle), findsOneWidget);
        expectOneLineNotShrunk(tester, find.byKey(const Key('tax_info_edit')));
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('tax_info_edit')));
        await tester.pumpAndSettle();
        expectOneLineNotShrunk(tester, find.byKey(const Key('tax_info_later')));
        expect(find.text(l.taxInfoCancelEdit), findsOneWidget);
      });

      testWidgets('${entry.key} : 422 sous le champ, sans exception', (
        tester,
      ) async {
        stubSave(() async => throw const TaxInfoException('tax-info-invalid'));
        await pump(tester, locale: locale);
        await tester.enterText(
          find.byKey(const Key('tax_info_number')),
          '12345678',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('tax_info_save')));
        await tester.pumpAndSettle();
        expect(find.text(l.taxInfoErrorInvalid), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('en : motif en anglais, lien « Learn more »', (tester) async {
      await pump(tester, locale: AppL10n.en);
      expect(find.text('Tax information'), findsOneWidget);
      expect(find.text('Learn more'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
