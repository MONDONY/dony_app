import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/residence_country_writer.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class _MockBusinessPrefsRepository extends Mock
    implements BusinessPrefsRepository {}

class _MockBox extends Mock implements Box<dynamic> {}

class _FakeUserBusinessPrefsDto extends Fake implements UserBusinessPrefsDto {}

const _current = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'EUR',
  defaultPackageWeightKg: 23,
  minBidPriceEur: 0,
);

const _saved = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'XOF',
  defaultPackageWeightKg: 23,
  minBidPriceEur: 0,
  country: 'SN',
);

void main() {
  late _MockBusinessPrefsRepository repository;
  late _MockBox prefs;

  setUpAll(() => registerFallbackValue(_FakeUserBusinessPrefsDto()));

  setUp(() {
    residenceRetryDelay = Duration.zero;
    repository = _MockBusinessPrefsRepository();
    prefs = _MockBox();
    when(() => repository.fetchPrefs()).thenAnswer((_) async => _current);
    when(() => repository.updatePrefs(any())).thenAnswer((_) async => _saved);
    when(() => prefs.put(any(), any())).thenAnswer((_) async {});
  });

  test(
    'écrit le pays au serveur, puis Hive avec la devise du serveur',
    () async {
      await writeResidenceCountry(repository, prefs, 'SN');

      verifyInOrder([
        () => repository.fetchPrefs(),
        () => repository.updatePrefs(
          any(
            that: isA<UserBusinessPrefsDto>()
                .having((dto) => dto.country, 'country', 'SN')
                .having((dto) => dto.weightUnit, 'weightUnit', 'kg'),
          ),
        ),
        () => prefs.put(HiveService.kCountryCode, 'SN'),
        () => prefs.put(HiveService.kCurrencyCode, 'XOF'),
        () => prefs.put(HiveService.kTravelerCountryUnsupported, false),
      ]);
    },
  );

  test('un refus du serveur ne touche pas Hive et remonte l\'erreur', () async {
    when(() => repository.updatePrefs(any())).thenThrow(Exception('422'));

    await expectLater(
      writeResidenceCountry(repository, prefs, 'SN'),
      throwsException,
    );
    verifyNever(() => prefs.put(any(), any()));
  });

  test(
    'GET en échec réseau puis succès au 2e essai : pays enregistré',
    () async {
      var gets = 0;
      when(() => repository.fetchPrefs()).thenAnswer((_) async {
        if (++gets == 1) throw const NetworkException('offline');
        return _current;
      });

      await writeResidenceCountry(repository, prefs, 'FR');

      expect(gets, 2);
      verify(() => repository.updatePrefs(any())).called(1);
      verify(() => prefs.put(HiveService.kCountryCode, 'FR')).called(1);
      verify(() => prefs.put(HiveService.kCurrencyCode, 'XOF')).called(1);
    },
  );

  test('PUT en 503 puis succès : une reprise, Hive écrit une fois', () async {
    var puts = 0;
    when(() => repository.updatePrefs(any())).thenAnswer((_) async {
      if (++puts == 1) throw const ServiceUnavailableException();
      return _saved;
    });

    await writeResidenceCountry(repository, prefs, 'SN');

    expect(puts, 2);
    verify(() => prefs.put(HiveService.kCountryCode, 'SN')).called(1);
  });

  test(
    'DioException portant une AppException transitoire est reprise',
    () async {
      var gets = 0;
      when(() => repository.fetchPrefs()).thenAnswer((_) async {
        if (++gets == 1) {
          throw DioException(
            requestOptions: RequestOptions(path: '/x'),
            error: const TimeoutException(),
          );
        }
        return _current;
      });

      await writeResidenceCountry(repository, prefs, 'FR');

      expect(gets, 2);
    },
  );

  test(
    'échec définitif : 3 tentatives, erreur remontée, Hive intact',
    () async {
      when(
        () => repository.fetchPrefs(),
      ).thenThrow(const NetworkException('offline'));

      await expectLater(
        writeResidenceCountry(repository, prefs, 'FR'),
        throwsA(isA<NetworkException>()),
      );

      verify(() => repository.fetchPrefs()).called(3);
      verifyNever(() => repository.updatePrefs(any()));
      verifyNever(() => prefs.put(any(), any()));
    },
  );

  test('refus métier (422) : aucune reprise', () async {
    when(
      () => repository.updatePrefs(any()),
    ).thenThrow(const ValidationException('refusé'));

    await expectLater(
      writeResidenceCountry(repository, prefs, 'FR'),
      throwsA(isA<ValidationException>()),
    );

    verify(() => repository.updatePrefs(any())).called(1);
    verifyNever(() => prefs.put(any(), any()));
  });
}
