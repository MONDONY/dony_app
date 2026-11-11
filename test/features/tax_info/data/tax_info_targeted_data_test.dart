import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:dony/features/tax_info/data/datasources/tax_info_remote_datasource.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/models/tax_info_update.dart';
import 'package:dony/features/tax_info/data/repositories/tax_info_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

class _MockDatasource extends Mock implements TaxInfoRemoteDatasource {}

class _MockPrefs extends Mock implements BusinessPrefsRepository {}

const _path = '/travelers/me/tax-info';

/// Réponse du contrat d'API de yadony-back #730 (rapport tâche 1).
const _infoRequiredJson = <String, dynamic>{
  'provided': false,
  'vatNumberProvided': false,
  'residenceCountry': 'FR',
  'dac7Status': 'DECLARABLE',
  'solicitation': 'NE_PAS_SOLLICITER',
  'collectionStatus': 'INFO_REQUIRED',
  'missingFields': ['TAX_IDENTIFICATION_NUMBER'],
  'readOnlyFields': ['NAME', 'BIRTH_DATE', 'ADDRESS'],
  'actionRequired': true,
  'requestedAt': '2026-11-11T10:00:00Z',
  'identity': {
    'firstName': 'Awa',
    'lastName': 'Diallo',
    'nameSource': 'DIDIT',
    'birthDate': '1990-04-12',
    'birthDateSource': 'DIDIT',
    'address': {
      'street': '1 rue de la République',
      'postalCode': '69001',
      'city': 'Lyon',
      'country': 'FR',
    },
    'addressSource': 'DIDIT',
    'addressReplaceable': true,
    'birthPlaceProvided': false,
  },
};

const _prefs = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'EUR',
  defaultPackageWeightKg: 23,
  minBidPriceEur: 0,
);

DioException _http(int status, [Object? body]) => DioException(
  requestOptions: RequestOptions(path: _path),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: _path),
    statusCode: status,
    data: body,
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const TaxInfoUpdate());
    registerFallbackValue(_prefs);
  });

  group('TaxInfo.fromJson : collecte ciblée', () {
    test('lit statut, champs, demande et identité', () {
      final info = TaxInfo.fromJson(_infoRequiredJson);
      expect(info.usesCollectionContract, isTrue);
      expect(info.collectionStatus, TaxInfoCollectionStatus.infoRequired);
      expect(info.missingFields, [TaxInfoField.taxIdentificationNumber]);
      expect(info.readOnlyFields, [
        TaxInfoField.name,
        TaxInfoField.birthDate,
        TaxInfoField.address,
      ]);
      expect(info.isMissing(TaxInfoField.address), isFalse);
      expect(info.actionRequired, isTrue);
      expect(info.requestedAt, DateTime.utc(2026, 11, 11, 10));
      final id = info.identity!;
      expect(id.fullName, 'Awa Diallo');
      expect(id.nameSource, TaxInfoSource.didit);
      expect(id.birthDate, DateTime(1990, 4, 12));
      expect(id.birthDateSource, TaxInfoSource.didit);
      expect(id.address!.street, '1 rue de la République');
      expect(id.address!.line2, isNull);
      expect(id.address!.postalCode, '69001');
      expect(id.address!.city, 'Lyon');
      expect(id.address!.country, 'FR');
      expect(id.addressSource, TaxInfoSource.didit);
      expect(id.addressReplaceable, isTrue);
      expect(id.birthPlaceProvided, isFalse);
      expect(id.identityCheckUnavailable, isFalse);
    });

    test('chaque statut connu', () {
      for (final s in TaxInfoCollectionStatus.values) {
        expect(
          TaxInfo.fromJson({'collectionStatus': s.wire}).collectionStatus,
          s,
        );
      }
    });

    test('ancien back : aucun champ, ancien comportement', () {
      final info = TaxInfo.fromJson(const {
        'provided': false,
        'solicitation': 'SOLLICITER',
      });
      expect(info.usesCollectionContract, isFalse);
      expect(info.collectionStatus, isNull);
      expect(info.missingFields, isEmpty);
      expect(info.readOnlyFields, isEmpty);
      expect(info.actionRequired, isFalse);
      expect(info.requestedAt, isNull);
      expect(info.identity, isNull);
    });

    test('statut ou champ inconnus : ignorés, sans doublon', () {
      final info = TaxInfo.fromJson(const {
        'collectionStatus': 'CLOSURE_PENDING',
        'missingFields': ['ADDRESS', 'AUTRE', 'ADDRESS', 3, 'NAME'],
        'readOnlyFields': 'NAME',
        'identity': 'illisible',
      });
      expect(info.collectionStatus, isNull);
      expect(info.missingFields, [TaxInfoField.address, TaxInfoField.name]);
      expect(info.readOnlyFields, isEmpty);
      expect(info.identity, isNull);
    });

    test('identité partielle : nom incomplet, adresse vide, source '
        'inconnue', () {
      final info = TaxInfo.fromJson(const {
        'collectionStatus': 'INFO_REQUIRED',
        'identity': {
          'firstName': 'Awa',
          'nameSource': 'AUTRE',
          'birthDate': 'pas une date',
          'address': {'street': ' '},
          'birthPlaceProvided': true,
          'identityCheckUnavailable': true,
        },
      });
      final id = info.identity!;
      expect(id.fullName, isNull);
      expect(id.nameSource, isNull);
      expect(id.birthDate, isNull);
      expect(id.address, isNull);
      expect(id.birthPlaceProvided, isTrue);
      expect(id.identityCheckUnavailable, isTrue);
    });

    test('adresse avec complément et sans pays', () {
      final address = TaxInfoAddress.fromJson(const {
        'street': '12 rue des Lilas',
        'line2': 'Bât. B',
        'city': 'Marseille',
      })!;
      expect(address.line2, 'Bât. B');
      expect(address.postalCode, '');
      expect(address.country, isNull);
      expect(TaxInfoAddress.fromJson('x'), isNull);
    });

    test('aucune donnée d\'identité dans un toString', () {
      final info = TaxInfo.fromJson(_infoRequiredJson);
      expect('${info.identity}', isNot(contains('Awa')));
      expect('${info.identity!.address}', isNot(contains('Lyon')));
    });

    test('égalité de valeur', () {
      expect(
        TaxInfo.fromJson(_infoRequiredJson),
        TaxInfo.fromJson(_infoRequiredJson),
      );
    });
  });

  group('TaxInfoUpdate', () {
    test('n\'envoie que les champs présents, rognés', () {
      final update = TaxInfoUpdate(
        firstName: ' Jeanne ',
        lastName: ' Martin ',
        birthDate: DateTime(1988, 7, 4),
        address: const TaxInfoAddressInput(
          street: ' 12 rue des Lilas ',
          line2: ' Bât. B ',
          postalCode: ' 13001 ',
          city: ' Marseille ',
        ),
      );
      expect(update.toJson(), {
        'firstName': 'Jeanne',
        'lastName': 'Martin',
        'birthDate': '1988-07-04',
        'address': {
          'street': '12 rue des Lilas',
          'line2': 'Bât. B',
          'postalCode': '13001',
          'city': 'Marseille',
        },
      });
      expect(update.isEmpty, isFalse);
      expect(update.fieldCodes, ['NAME', 'BIRTH_DATE', 'ADDRESS']);
    });

    test('numéro avec pays ; TVA vide absente (effacée par le back)', () {
      const update = TaxInfoUpdate(
        taxIdentificationNumber: ' 1234567890123 ',
        taxCountry: 'FR',
        vatNumber: ' ',
      );
      expect(update.toJson(), {
        'taxIdentificationNumber': '1234567890123',
        'taxCountry': 'FR',
      });
      expect(update.fieldCodes, ['TAX_IDENTIFICATION_NUMBER', 'VAT_NUMBER']);
    });

    test('numéro avec TVA renseignée', () {
      const update = TaxInfoUpdate(
        taxIdentificationNumber: 'X1',
        taxCountry: 'BE',
        vatNumber: ' BE0123 ',
      );
      expect(update.toJson()['vatNumber'], 'BE0123');
    });

    test('TVA seule : envoyée, vide l\'efface', () {
      expect(const TaxInfoUpdate(vatNumber: '').toJson(), {'vatNumber': ''});
    });

    test('lieu de naissance ; complément d\'adresse vide absent', () {
      const update = TaxInfoUpdate(
        birthPlace: ' Saint-Louis, Sénégal ',
        address: TaxInfoAddressInput(
          street: 'a',
          line2: ' ',
          postalCode: 'b',
          city: 'c',
        ),
      );
      final json = update.toJson();
      expect(json['birthPlace'], 'Saint-Louis, Sénégal');
      expect((json['address'] as Map).containsKey('line2'), isFalse);
      expect(update.fieldCodes, ['BIRTH_PLACE', 'ADDRESS']);
    });

    test('vide', () {
      expect(const TaxInfoUpdate().isEmpty, isTrue);
      expect(const TaxInfoUpdate().toJson(), isEmpty);
    });

    test('année sur quatre chiffres', () {
      expect(TaxInfoUpdate.formatBirthDate(DateTime(905, 1, 2)), '0905-01-02');
    });

    test('toString : les noms des champs, jamais les valeurs', () {
      const update = TaxInfoUpdate(
        taxIdentificationNumber: '1234567890123',
        taxCountry: 'FR',
        birthPlace: 'Dakar',
        address: TaxInfoAddressInput(
          street: 'rue secrète',
          postalCode: '75001',
          city: 'Paris',
        ),
      );
      final text = '$update ${update.address}';
      for (final secret in ['1234567890123', 'Dakar', 'secrète', 'Paris']) {
        expect(text, isNot(contains(secret)));
      }
    });
  });

  group('TaxInfoRemoteDatasource.update', () {
    late _MockApiClient api;
    late _MockDio dio;

    setUp(() {
      api = _MockApiClient();
      dio = _MockDio();
      when(() => api.dio).thenReturn(dio);
    });

    test('PUT partiel puis lecture de la réponse', () async {
      when(() => dio.put(_path, data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          data: _infoRequiredJson,
          statusCode: 200,
          requestOptions: RequestOptions(path: _path),
        ),
      );
      final info = await TaxInfoRemoteDatasource(
        api,
      ).update(const TaxInfoUpdate(birthPlace: 'Dakar'));
      expect(info.collectionStatus, TaxInfoCollectionStatus.infoRequired);
      verify(() => dio.put(_path, data: {'birthPlace': 'Dakar'})).called(1);
    });
  });

  group('TaxInfoRepository : collecte ciblée', () {
    late _MockDatasource ds;
    late _MockPrefs prefs;
    late TaxInfoRepository repo;
    final complete = TaxInfo.fromJson(const {'collectionStatus': 'COMPLETE'});

    setUp(() {
      ds = _MockDatasource();
      prefs = _MockPrefs();
      repo = TaxInfoRepository(ds, prefs);
    });

    test('update transmet le succès et traduit les 422', () async {
      when(() => ds.update(any())).thenAnswer((_) async => complete);
      expect(await repo.update(const TaxInfoUpdate(birthPlace: 'x')), complete);
      when(() => ds.update(any())).thenThrow(
        _http(422, const {
          'type': 'https://yadony.com/problems/tax-info-read-only',
          'field': 'birthDate',
        }),
      );
      await expectLater(
        repo.update(const TaxInfoUpdate(birthPlace: 'x')),
        throwsA(
          isA<TaxInfoException>()
              .having((e) => e.code, 'code', 'tax-info-read-only')
              .having((e) => e.field, 'field', 'birthDate'),
        ),
      );
    });

    test('pays : PUT des préférences avec le pays, puis relecture', () async {
      when(() => prefs.fetchPrefs()).thenAnswer((_) async => _prefs);
      when(() => prefs.updatePrefs(any())).thenAnswer((_) async => _prefs);
      when(() => ds.fetch()).thenAnswer((_) async => complete);
      expect(await repo.saveResidenceCountry('FR'), complete);
      final sent =
          verify(() => prefs.updatePrefs(captureAny())).captured.single
              as UserBusinessPrefsDto;
      expect(sent.country, 'FR');
      expect(sent.weightUnit, 'kg');
      verify(() => ds.fetch()).called(1);
    });

    test('pays déjà enregistré : aucun PUT, relecture seule', () async {
      when(
        () => prefs.fetchPrefs(),
      ).thenAnswer((_) async => _prefs.copyWith(country: 'SN'));
      when(() => ds.fetch()).thenAnswer((_) async => complete);
      await repo.saveResidenceCountry('SN');
      verifyNever(() => prefs.updatePrefs(any()));
    });

    test('pays verrouillé : refus sans envoi', () async {
      when(
        () => prefs.fetchPrefs(),
      ).thenAnswer((_) async => _prefs.copyWith(countryLocked: true));
      await expectLater(
        repo.saveResidenceCountry('FR'),
        throwsA(
          isA<TaxInfoException>().having(
            (e) => e.code,
            'code',
            kTaxResidenceLockedCode,
          ),
        ),
      );
      verifyNever(() => prefs.updatePrefs(any()));
    });

    test('activation des paiements en cours : Réglages, pas ici', () async {
      when(() => prefs.fetchPrefs()).thenAnswer(
        (_) async => _prefs.copyWith(countryChangeResetsPayoutSetup: true),
      );
      await expectLater(
        repo.saveResidenceCountry('FR'),
        throwsA(
          isA<TaxInfoException>().having(
            (e) => e.code,
            'code',
            kTaxResidenceResetsPayoutCode,
          ),
        ),
      );
      verifyNever(() => prefs.updatePrefs(any()));
    });

    test('422 country-locked du serveur : code conservé', () async {
      when(() => prefs.fetchPrefs()).thenAnswer((_) async => _prefs);
      when(() => prefs.updatePrefs(any())).thenThrow(
        _http(422, const {
          'type': 'https://yadony.com/problems/country-locked',
        }),
      );
      await expectLater(
        repo.saveResidenceCountry('FR'),
        throwsA(
          isA<TaxInfoException>().having(
            (e) => e.code,
            'code',
            'country-locked',
          ),
        ),
      );
    });

    test('sans dépôt des préférences : fonction absente', () async {
      await expectLater(
        TaxInfoRepository(ds).saveResidenceCountry('FR'),
        throwsA(isA<TaxInfoUnavailableException>()),
      );
    });
  });
}
