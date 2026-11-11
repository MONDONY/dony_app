import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tax_info/bloc/tax_info_cubit.dart';
import 'package:dony/features/tax_info/bloc/tax_info_signal.dart';
import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/models/tax_info_update.dart';
import 'package:dony/features/tax_info/data/repositories/tax_info_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../tax_info_targeted_fixtures.dart';

class _MockRepo extends Mock implements TaxInfoRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;

  setUpAll(() => registerFallbackValue(const TaxInfoUpdate()));

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  TaxInfoCubit build() => TaxInfoCubit(repo, analytics);

  Future<TaxInfoCubit> loaded(TaxInfo info) async {
    when(() => repo.fetch()).thenAnswer((_) async => info);
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  group('état : ce que l\'écran demande', () {
    test('pays inconnu : seul le pays', () {
      const s = TaxInfoState(load: TaxInfoLoadStatus.ready, info: kResidence);
      expect(s.asksResidence, isTrue);
      expect(s.asksName, isFalse);
      expect(s.asksAddress, isFalse);
      expect(s.asksTaxNumber, isFalse);
      expect(s.showsTaxNumberFields, isFalse);
      expect(s.showsSummary, isFalse);
      expect(s.firstMissingInput, TaxInfoMissingInput.residence);
      expect(s.canSubmit, isFalse);
      final ready = s.copyWith(residenceCountry: 'CI');
      expect(ready.firstMissingInput, isNull);
      expect(ready.canSubmit, isTrue);
    });

    test('France + pièce complète : seul le numéro fiscal', () {
      final s = TaxInfoState(
        load: TaxInfoLoadStatus.ready,
        info: kFranceDiditNifMissing,
        taxCountry: 'FR',
      );
      expect(s.isTargeted, isTrue);
      expect(s.asksResidence, isFalse);
      expect(s.asksName, isFalse);
      expect(s.asksBirthDate, isFalse);
      expect(s.asksAddress, isFalse);
      expect(s.asksTaxNumber, isTrue);
      expect(s.offersNoTaxNumber, isTrue);
      expect(s.showsTaxNumberFields, isTrue);
      expect(s.asksBirthPlace, isFalse);
      expect(s.hasPrefilledFromId, isTrue);
      expect(s.showsSummary, isFalse);
    });

    test('« Ce n\'est plus mon adresse » : l\'adresse est demandée', () {
      final s = TaxInfoState(
        load: TaxInfoLoadStatus.ready,
        info: kFranceDiditNifMissing,
        replacingAddress: true,
      );
      expect(s.asksAddress, isTrue);
    });

    test('tout manque : nom, date, adresse, numéro', () {
      const s = TaxInfoState(load: TaxInfoLoadStatus.ready, info: kAllMissing);
      expect(s.asksName, isTrue);
      expect(s.asksBirthDate, isTrue);
      expect(s.asksAddress, isTrue);
      expect(s.asksTaxNumber, isTrue);
      expect(s.hasPrefilledFromId, isFalse);
      expect(s.firstMissingInput, TaxInfoMissingInput.name);
    });

    test('identité du profil sans champ en lecture seule : pas de « déjà '
        'repris »', () {
      final s = TaxInfoState(
        load: TaxInfoLoadStatus.ready,
        info: kProfileAddressMissing,
      );
      expect(s.hasPrefilledFromId, isFalse);
      expect(s.asksAddress, isTrue);
      expect(s.asksTaxNumber, isFalse);
    });

    test('source Didit sans liste en lecture seule : « déjà repris »', () {
      const s = TaxInfoState(
        load: TaxInfoLoadStatus.ready,
        info: kDiditAddressOnlySource,
      );
      expect(s.hasPrefilledFromId, isTrue);
    });

    test('COMPLETE : fiche ; « Modifier » : seulement le numéro', () {
      const s = TaxInfoState(load: TaxInfoLoadStatus.ready, info: kComplete);
      expect(s.showsSummary, isTrue);
      expect(s.asksTaxNumber, isFalse);
      final editing = s.copyWith(editing: true);
      expect(editing.showsSummary, isFalse);
      expect(editing.asksTaxNumber, isTrue);
      expect(editing.offersNoTaxNumber, isFalse);
      expect(editing.asksAddress, isFalse);
    });

    test('ancien contrat : jamais de règle française ni d\'identité', () {
      const s = TaxInfoState(
        load: TaxInfoLoadStatus.ready,
        info: kLegacyAsk,
        taxCountry: 'FR',
        taxNumber: '123456789012',
      );
      expect(s.isTargeted, isFalse);
      expect(s.usesFrenchTaxNumberRule, isFalse);
      expect(s.isTaxNumberValid, isTrue);
      expect(s.asksName, isFalse);
      expect(s.offersNoTaxNumber, isFalse);
      expect(s.canSubmit, isTrue);
    });
  });

  group('état : validation', () {
    TaxInfoState fr(String n, {String country = 'FR'}) => TaxInfoState(
      load: TaxInfoLoadStatus.ready,
      info: kFranceDiditNifMissing,
      taxCountry: country,
      taxNumber: n,
    );

    test('numéro français : 13 chiffres exacts, espaces ignorés', () {
      expect(fr('1234567890123').isTaxNumberValid, isTrue);
      expect(fr('1 23 456 789 0123').isTaxNumberValid, isTrue);
      expect(fr('123456789012').isTaxNumberValid, isFalse);
      expect(fr('123456789012').isTaxNumberInvalid, isTrue);
      expect(fr('12345678901234').isTaxNumberValid, isFalse);
      expect(fr('123456789012A').isTaxNumberValid, isFalse);
      expect(fr('').isTaxNumberInvalid, isFalse);
      expect(fr('123456789012').usesFrenchTaxNumberRule, isTrue);
      expect(fr('123456789012').canSubmit, isFalse);
      expect(fr('1234567890123').canSubmit, isTrue);
    });

    test('autre pays : règle générale (non vide, 4 à 40)', () {
      expect(fr('AB12', country: 'BE').isTaxNumberValid, isTrue);
      expect(fr('123456789012', country: 'BE').isTaxNumberValid, isTrue);
      expect(fr('A', country: 'BE').isTaxNumberValid, isFalse);
    });

    test('nom, date, adresse, lieu de naissance', () {
      const base = TaxInfoState(
        load: TaxInfoLoadStatus.ready,
        info: kAllMissing,
      );
      expect(base.isNameValid, isFalse);
      expect(base.copyWith(firstName: 'A', lastName: ' ').isNameValid, isFalse);
      expect(base.copyWith(firstName: 'A', lastName: 'B').isNameValid, isTrue);
      expect(
        base.copyWith(firstName: 'A' * 101, lastName: 'B').isNameValid,
        isFalse,
      );
      expect(base.isBirthDateValid, isFalse);
      expect(
        base.copyWith(birthDate: DateTime(1899, 12, 31)).isBirthDateValid,
        isFalse,
      );
      expect(
        base
            .copyWith(birthDate: DateTime.now().add(const Duration(days: 2)))
            .isBirthDateValid,
        isFalse,
      );
      expect(
        base.copyWith(birthDate: DateTime(1990, 4, 12)).isBirthDateValid,
        isTrue,
      );
      final address = base.copyWith(
        street: '1 rue',
        postalCode: '69001',
        city: 'Lyon',
      );
      expect(base.isAddressValid, isFalse);
      expect(address.isAddressValid, isTrue);
      expect(address.copyWith(line2: 'x' * 101).isAddressValid, isFalse);
      expect(base.isBirthPlaceValid, isFalse);
      expect(base.copyWith(birthPlace: 'Dakar').isBirthPlaceValid, isTrue);
      expect(base.copyWith(birthPlace: 'x' * 121).isBirthPlaceValid, isFalse);
    });

    test('lieu de naissance déjà enregistré : champ vide accepté', () {
      final s = TaxInfoState(
        load: TaxInfoLoadStatus.ready,
        info: kBirthPlaceSaved,
        noTaxNumber: true,
      );
      expect(s.asksBirthPlace, isTrue);
      expect(s.isBirthPlaceValid, isTrue);
      // Rien d'autre à envoyer : pas d'envoi vide.
      expect(s.firstMissingInput, isNull);
      expect(s.update.isEmpty, isTrue);
      expect(s.canSubmit, isFalse);
    });

    test('ordre des manques : nom, date, adresse, numéro, TVA, pays, lieu', () {
      var s = const TaxInfoState(
        load: TaxInfoLoadStatus.ready,
        info: kAllMissing,
      );
      expect(s.firstMissingInput, TaxInfoMissingInput.name);
      s = s.copyWith(firstName: 'A', lastName: 'B');
      expect(s.firstMissingInput, TaxInfoMissingInput.birthDate);
      s = s.copyWith(birthDate: DateTime(1990));
      expect(s.firstMissingInput, TaxInfoMissingInput.address);
      s = s.copyWith(street: 'r', postalCode: 'p', city: 'c');
      expect(s.firstMissingInput, TaxInfoMissingInput.taxNumber);
      s = s.copyWith(taxNumber: 'AB1234', vatNumber: '!');
      expect(s.firstMissingInput, TaxInfoMissingInput.vat);
      s = s.copyWith(vatNumber: '');
      expect(s.firstMissingInput, TaxInfoMissingInput.taxCountry);
      s = s.copyWith(taxCountry: 'BE');
      expect(s.firstMissingInput, isNull);
      expect(s.canSubmit, isTrue);
      s = s.copyWith(noTaxNumber: true);
      expect(s.firstMissingInput, TaxInfoMissingInput.birthPlace);
    });

    test('corps du PUT : seulement les champs demandés', () {
      final s =
          const TaxInfoState(
            load: TaxInfoLoadStatus.ready,
            info: kAllMissing,
          ).copyWith(
            firstName: 'Jeanne',
            lastName: 'Martin',
            birthDate: DateTime(1988, 7, 14),
            street: '12 rue des Lilas',
            line2: '',
            postalCode: '13001',
            city: 'Marseille',
            taxNumber: '1234567890123',
            taxCountry: 'FR',
          );
      expect(s.update.toJson(), {
        'taxIdentificationNumber': '1234567890123',
        'taxCountry': 'FR',
        'firstName': 'Jeanne',
        'lastName': 'Martin',
        'birthDate': '1988-07-14',
        'address': {
          'street': '12 rue des Lilas',
          'postalCode': '13001',
          'city': 'Marseille',
        },
      });
      final noNif = s.copyWith(noTaxNumber: true, birthPlace: ' Dakar ');
      final json = noNif.update.toJson();
      expect(json.containsKey('taxIdentificationNumber'), isFalse);
      expect(json['birthPlace'], 'Dakar');
    });

    test('erreurs du serveur sous les champs visibles seulement', () {
      TaxInfoState err(String? field, {TaxInfo info = kAllMissing}) =>
          TaxInfoState(
            load: TaxInfoLoadStatus.ready,
            info: info,
            errorCode: kTaxInfoInvalidCode,
            errorField: field,
          );
      expect(err(kTaxFieldFirstName).hasInlineError, isTrue);
      expect(err(kTaxFieldBirthDate).hasInlineError, isTrue);
      expect(err(kTaxFieldCity).hasInlineError, isTrue);
      expect(err(kTaxFieldNumber).hasInlineError, isTrue);
      expect(err(null).hasInlineError, isTrue);
      expect(err(kTaxFieldBirthPlace).hasInlineError, isFalse);
      expect(err('inconnu').hasInlineError, isFalse);
      expect(
        err(kTaxFieldFirstName, info: kFranceDiditNifMissing).hasInlineError,
        isFalse,
      );
      expect(err(kTaxFieldCountry).serverRejectedTaxNumber, isTrue);
      expect(err(kTaxFieldCity).serverRejectedTaxNumber, isFalse);
      expect(
        const TaxInfoState(errorCode: kTaxInfoReadOnlyCode).hasInlineError,
        isFalse,
      );
    });
  });

  group('cubit : chargement', () {
    test('chaque statut', () async {
      expect((await loaded(kResidence)).state.load, TaxInfoLoadStatus.ready);
      expect(
        (await loaded(kFranceDiditNifMissing)).state.load,
        TaxInfoLoadStatus.ready,
      );
      expect((await loaded(kComplete)).state.load, TaxInfoLoadStatus.ready);
      final out = await loaded(kOutOfScope);
      expect(out.state.load, TaxInfoLoadStatus.unavailable);
      expect(out.state.collection, TaxInfoCollectionStatus.nePasSolliciter);
    });

    test('pays d\'émission proposé d\'après la résidence', () async {
      final cubit = await loaded(kFranceDiditNifMissing);
      expect(cubit.state.taxCountry, 'FR');
    });

    test('lieu de naissance déjà donné : « pas de numéro » coché', () async {
      final cubit = await loaded(kBirthPlaceSaved);
      expect(cubit.state.noTaxNumber, isTrue);
    });

    test('ouverture tracée avec le statut et la portée', () async {
      when(() => repo.fetch()).thenAnswer((_) async => kResidence);
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load(scope: 'residence');
      await cubit.load();
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.taxInfoOpened,
          properties: {
            'solicitation': 'NE_PAS_SOLLICITER',
            'provided': false,
            'collection_status': 'RESIDENCE_INCONNUE',
            'scope': 'residence',
          },
        ),
      ).called(1);
    });
  });

  group('cubit : saisie', () {
    test('modifier un champ refusé efface son erreur', () async {
      final cubit = await loaded(kAllMissing);
      cubit.updateForm(
        firstName: 'A',
        lastName: 'B',
        birthDate: DateTime(1990),
        street: 'r',
        postalCode: 'p',
        city: 'c',
        taxNumber: 'AB1234',
        taxCountry: 'BE',
      );
      final fields = <String, void Function()>{
        kTaxFieldFirstName: () => cubit.updateForm(firstName: 'a'),
        kTaxFieldLastName: () => cubit.updateForm(lastName: 'a'),
        kTaxFieldBirthDate: () => cubit.updateForm(birthDate: DateTime(1991)),
        kTaxFieldStreet: () => cubit.updateForm(street: 'a'),
        kTaxFieldLine2: () => cubit.updateForm(line2: 'a'),
        kTaxFieldPostalCode: () => cubit.updateForm(postalCode: 'a'),
        kTaxFieldCity: () => cubit.updateForm(city: 'a'),
        kTaxFieldBirthPlace: () => cubit.updateForm(birthPlace: 'a'),
        kTaxFieldCountry: () => cubit.updateForm(taxCountry: 'DE'),
      };
      for (final entry in fields.entries) {
        when(
          () => repo.update(any()),
        ).thenThrow(TaxInfoException(kTaxInfoInvalidCode, field: entry.key));
        await cubit.submit();
        expect(cubit.state.errorField, entry.key);
        // Un autre champ ne l'efface pas.
        cubit.updateForm(residenceCountry: 'FR');
        expect(cubit.state.errorField, entry.key);
        entry.value();
        expect(cubit.state.errorCode, isNull, reason: entry.key);
      }
    });

    test('« Ce n\'est plus mon adresse » puis « Garder »', () async {
      final cubit = await loaded(kFranceDiditNifMissing);
      cubit.replaceAddress();
      expect(cubit.state.asksAddress, isTrue);
      cubit.updateForm(street: 'x', city: 'y', postalCode: 'z', line2: 'w');
      cubit.keepAddress();
      expect(cubit.state.asksAddress, isFalse);
      expect(cubit.state.street, '');
      expect(cubit.state.city, '');
    });

    test('« Je n\'ai pas de numéro fiscal »', () async {
      final cubit = await loaded(kFranceDiditNifMissing);
      cubit.setNoTaxNumber(true);
      expect(cubit.state.asksBirthPlace, isTrue);
      expect(cubit.state.showsTaxNumberFields, isFalse);
      final before = cubit.state;
      cubit.setNoTaxNumber(true);
      expect(cubit.state, same(before));
      cubit.setNoTaxNumber(false);
      expect(cubit.state.showsTaxNumberFields, isTrue);
    });

    test('rien pendant l\'envoi ni après fermeture', () async {
      final cubit = await loaded(kFranceDiditNifMissing);
      final gate = Completer<TaxInfo>();
      when(() => repo.update(any())).thenAnswer((_) => gate.future);
      cubit.updateForm(taxNumber: '1234567890123');
      final pending = cubit.submit();
      expect(cubit.state.submitting, isTrue);
      final before = cubit.state;
      cubit
        ..replaceAddress()
        ..keepAddress()
        ..setNoTaxNumber(true);
      expect(cubit.state, same(before));
      gate.complete(kComplete);
      await pending;
      await cubit.close();
      cubit
        ..replaceAddress()
        ..keepAddress()
        ..setNoTaxNumber(true);
    });
  });

  group('cubit : enregistrement ciblé', () {
    test('n\'envoie que les champs manquants, puis enregistré', () async {
      final cubit = await loaded(kFranceDiditNifMissing);
      when(() => repo.update(any())).thenAnswer((_) async => kComplete);
      final changes = taxInfoChanged.value;
      cubit.updateForm(taxNumber: '1234567890123');
      await cubit.submit();
      final sent =
          verify(() => repo.update(captureAny())).captured.single
              as TaxInfoUpdate;
      expect(sent.toJson(), {
        'taxIdentificationNumber': '1234567890123',
        'taxCountry': 'FR',
      });
      verifyNever(
        () => repo.save(
          taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
          taxCountry: any(named: 'taxCountry'),
          vatNumber: any(named: 'vatNumber'),
        ),
      );
      expect(cubit.state.saved, isTrue);
      expect(cubit.state.taxNumber, '');
      expect(taxInfoChanged.value, changes + 1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.taxInfoSaved,
          properties: {
            'edit': false,
            'scope': 'tax_info',
            'fields': 'TAX_IDENTIFICATION_NUMBER,VAT_NUMBER',
            'collection_status': 'COMPLETE',
          },
        ),
      ).called(1);
    });

    test('numéro français à 12 chiffres : rien n\'est envoyé', () async {
      final cubit = await loaded(kFranceDiditNifMissing);
      cubit.updateForm(taxNumber: '123456789012');
      await cubit.submit();
      verifyNever(() => repo.update(any()));
    });

    test('422 sur la ville : erreur gardée, saisie gardée', () async {
      final cubit = await loaded(kProfileAddressMissing);
      when(() => repo.update(any())).thenThrow(
        const TaxInfoException(kTaxInfoInvalidCode, field: kTaxFieldCity),
      );
      cubit.updateForm(street: 'r', postalCode: 'p', city: 'c');
      await cubit.submit();
      expect(cubit.state.serverRejected(kTaxFieldCity), isTrue);
      expect(cubit.state.hasInlineError, isTrue);
      expect(cubit.state.city, 'c');
      expect(cubit.state.submitting, isFalse);
    });
  });

  group('cubit : pays de résidence', () {
    TaxInfoUpdate sent() =>
        verify(() => repo.update(captureAny())).captured.single
            as TaxInfoUpdate;

    test(
      'résident de l\'Union : PUT fiscal, il reste des informations',
      () async {
        final cubit = await loaded(kResidence);
        when(
          () => repo.update(any()),
        ).thenAnswer((_) async => kFranceDiditNifMissing);
        cubit.updateForm(residenceCountry: 'SE');
        final pending = cubit.submit();
        expect(cubit.state.submitting, isTrue);
        await pending;
        expect(sent().toJson(), {'residenceCountry': 'SE'});
        expect(cubit.state.residenceSaves, 1);
        expect(cubit.state.asksResidence, isFalse);
        expect(cubit.state.collection, TaxInfoCollectionStatus.infoRequired);
        expect(cubit.state.taxCountry, 'FR');
        expect(cubit.state.load, TaxInfoLoadStatus.ready);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.taxInfoSaved,
            properties: {
              'edit': false,
              'scope': 'residence',
              'collection_status': 'INFO_REQUIRED',
            },
          ),
        ).called(1);
      },
    );

    test('hors Union : plus rien à demander', () async {
      final cubit = await loaded(kResidence);
      when(() => repo.update(any())).thenAnswer((_) async => kOutOfScope);
      cubit.updateForm(residenceCountry: 'CI');
      await cubit.submit();
      expect(cubit.state.residenceSaves, 1);
      expect(cubit.state.collection, TaxInfoCollectionStatus.nePasSolliciter);
    });

    test(
      'pays refusé : erreur sous le pays, effacée au nouveau choix',
      () async {
        final cubit = await loaded(kResidence);
        when(() => repo.update(any())).thenThrow(
          const TaxInfoException(
            kTaxInfoInvalidCode,
            field: kTaxFieldResidence,
          ),
        );
        cubit.updateForm(residenceCountry: 'FR');
        await cubit.submit();
        expect(cubit.state.serverRejected(kTaxFieldResidence), isTrue);
        expect(cubit.state.hasInlineError, isTrue);
        expect(cubit.state.residenceCountry, 'FR');
        expect(cubit.state.residenceSaves, 0);
        cubit.updateForm(residenceCountry: 'BE');
        expect(cubit.state.errorCode, isNull);
      },
    );

    test('fonction absente, puis erreur inconnue', () async {
      var cubit = await loaded(kResidence);
      when(
        () => repo.update(any()),
      ).thenThrow(const TaxInfoUnavailableException(status: 404));
      cubit.updateForm(residenceCountry: 'FR');
      await cubit.submit();
      expect(cubit.state.load, TaxInfoLoadStatus.unavailable);
      expect(cubit.state.errorCode, 'dac7-disabled');

      cubit = await loaded(kResidence);
      when(() => repo.update(any())).thenThrow(StateError('x'));
      cubit.updateForm(residenceCountry: 'FR');
      await cubit.submit();
      expect(cubit.state.errorCode, 'unknown');
    });

    test('sans pays choisi : rien n\'est envoyé', () async {
      final cubit = await loaded(kResidence);
      await cubit.submit();
      verifyNever(() => repo.update(any()));
    });

    test('cubit fermé pendant l\'envoi : aucune émission', () async {
      final cubit = await loaded(kResidence);
      final gate = Completer<TaxInfo>();
      when(() => repo.update(any())).thenAnswer((_) => gate.future);
      cubit.updateForm(residenceCountry: 'FR');
      final pending = cubit.submit();
      await cubit.close();
      gate.complete(kFranceDiditNifMissing);
      await pending;
      expect(cubit.isClosed, isTrue);
    });
  });

  group('état : nouveau contrat (relecture du back)', () {
    test('professionnel avec NIF : rien à saisir, l\'équipe complète', () {
      const s = TaxInfoState(
        load: TaxInfoLoadStatus.ready,
        info: kBusinessWithNif,
      );
      expect(s.showsSummary, isFalse);
      expect(s.hasEnterableInput, isFalse);
      expect(s.asksTaxNumber, isFalse);
      expect(s.info!.needsTeamFollowUp, isTrue);
    });

    test('professionnel sans NIF : numéro, jamais « pas de numéro »', () {
      const s = TaxInfoState(
        load: TaxInfoLoadStatus.ready,
        info: kBusinessNoNif,
      );
      expect(s.hasEnterableInput, isTrue);
      expect(s.asksTaxNumber, isTrue);
      expect(s.offersNoTaxNumber, isFalse);
      expect(s.copyWith(noTaxNumber: true).asksBirthPlace, isFalse);
    });

    test('pièce non relue à temps : rien de « déjà repris », champs à '
        'saisir', () {
      const s = TaxInfoState(
        load: TaxInfoLoadStatus.ready,
        info: kIdentityUnavailable,
      );
      expect(s.hasPrefilledFromId, isFalse);
      expect(s.asksName, isTrue);
      expect(s.asksAddress, isTrue);
    });

    test('Profil : professionnel sans action, ligne sans « À compléter »', () {
      const s = TaxInfoPromptState(info: kBusinessWithNif);
      expect(s.showBanner, isFalse);
      expect(s.showRow, isTrue);
      expect(s.rowNeedsAction, isFalse);
    });

    test('Profil : demande faite mais rien de saisissable, pas de '
        'bannière', () {
      final s = TaxInfoPromptState(
        info: TaxInfo(
          provided: true,
          solicitation: TaxInfoSolicitation.solliciter,
          collectionStatus: TaxInfoCollectionStatus.infoRequired,
          missingFields: const [TaxInfoField.identityReview],
          requestedAt: DateTime.utc(2026, 11, 11),
        ),
      );
      expect(s.showBanner, isFalse);
      expect(s.rowNeedsAction, isFalse);
    });
  });

  group('Profil : bannière et ligne (collecte ciblée)', () {
    test('INFO_REQUIRED demandé : bannière ; « Plus tard » : ligne à '
        'compléter', () {
      final s = TaxInfoPromptState(info: kFranceDiditNifMissing);
      expect(s.showBanner, isTrue);
      expect(s.showRow, isFalse);
      final later = TaxInfoPromptState(
        info: kFranceDiditNifMissing,
        dismissed: true,
      );
      expect(later.showBanner, isFalse);
      expect(later.showRow, isTrue);
      expect(later.rowNeedsAction, isTrue);
    });

    test('INFO_REQUIRED jamais demandé : ligne seulement', () {
      const s = TaxInfoPromptState(info: kAllMissing);
      expect(s.showBanner, isFalse);
      expect(s.showRow, isTrue);
    });

    test('COMPLETE : ligne « Voir ou modifier »', () {
      const s = TaxInfoPromptState(info: kComplete);
      expect(s.showBanner, isFalse);
      expect(s.showRow, isTrue);
      expect(s.rowNeedsAction, isFalse);
    });

    test('hors périmètre ou pays inconnu : rien', () {
      for (final info in [kOutOfScope, kResidence]) {
        final s = TaxInfoPromptState(info: info);
        expect(s.showBanner, isFalse);
        expect(s.showRow, isFalse);
      }
      expect(const TaxInfoPromptState().showRow, isFalse);
      expect(const TaxInfoPromptState().showBanner, isFalse);
    });

    test('ancien contrat inchangé', () {
      expect(const TaxInfoPromptState(info: kLegacyAsk).showBanner, isTrue);
      expect(
        const TaxInfoPromptState(info: kLegacyAsk).rowNeedsAction,
        isFalse,
      );
    });
  });
}
