import 'dart:io';

import 'package:dony/app/router.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/country_onboarding_cubit.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements BusinessPrefsRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _FakeDto extends Fake implements UserBusinessPrefsDto {}

void main() {
  group('isCountryEmpty', () {
    final cases = <(String?, String?, bool)>[
      (null, null, true),
      ('', '', true),
      ('  ', '\t', true),
      ('FR', null, false),
      ('FR', '', false),
      // Réinstallation : Hive vide, le serveur connaît le pays.
      (null, 'FR', false),
      ('', ' SN ', false),
      ('FR', 'SN', false),
    ];
    for (final (hive, synced, empty) in cases) {
      test('Hive "$hive" + serveur "$synced" -> $empty', () {
        expect(isCountryEmpty(hiveCountry: hive, syncedCountry: synced), empty);
      });
    }
  });

  const next = '/auth/country-selection?next=%2Ftrips%2Fcreate';

  group('resolveCountryGuardRedirect', () {
    test('pays vide redirige vers la sélection avec next', () {
      expect(
        resolveCountryGuardRedirect(
          path: '/trips/create',
          countryEmpty: true,
          travelerCountryUnsupported: false,
        ),
        next,
      );
    });

    test('pays renseigné laisse passer', () {
      expect(
        resolveCountryGuardRedirect(
          path: '/trips/create',
          countryEmpty: false,
          travelerCountryUnsupported: false,
        ),
        isNull,
      );
    });

    test('kTravelerCountryUnsupported garde son comportement, avec next', () {
      expect(
        resolveCountryGuardRedirect(
          path: '/trips/create',
          countryEmpty: false,
          travelerCountryUnsupported: true,
        ),
        next,
      );
    });

    test('une autre route n\'est pas gardée', () {
      expect(
        resolveCountryGuardRedirect(
          path: '/home',
          countryEmpty: true,
          travelerCountryUnsupported: true,
        ),
        isNull,
      );
    });
  });

  // Recette (premier « Publier un trajet », compte neuf) : après « France »,
  // la garde de /trips/create ne doit plus renvoyer vers la sélection.
  group('choisir un pays puis rouvrir /trips/create', () {
    late Directory dir;
    late Box<dynamic> box;
    late _MockRepo repo;

    setUpAll(() => registerFallbackValue(_FakeDto()));

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('country_guard');
      Hive.init(dir.path);
      box = await Hive.openBox<dynamic>('user_prefs_guard');
      repo = _MockRepo();
      const prefs = UserBusinessPrefsDto(
        weightUnit: 'kg',
        currencyCode: 'EUR',
        defaultPackageWeightKg: 23,
        minBidPriceEur: 0,
      );
      when(() => repo.fetchPrefs()).thenAnswer((_) async => prefs);
      when(
        () => repo.updatePrefs(any()),
      ).thenAnswer((_) async => prefs.copyWith(country: 'FR'));
    });

    tearDown(() async {
      await Hive.close();
      dir.deleteSync(recursive: true);
    });

    for (final unsupportedBefore in [false, true]) {
      test('France choisie (drapeau « pays non desservi » '
          '$unsupportedBefore avant) : la garde laisse passer', () async {
        if (unsupportedBefore) {
          await box.put(HiveService.kTravelerCountryUnsupported, true);
        }
        final analytics = _MockAnalytics();
        when(() => analytics.logEvent(any())).thenAnswer((_) async {});
        when(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        ).thenAnswer((_) async {});
        final cubit = CountryOnboardingCubit(repo, box, analytics);

        await cubit.select('FR');

        expect(cubit.state, isA<CountryOnboardingSuccess>());
        final hive = box.get(HiveService.kCountryCode);
        final redirect = resolveCountryGuardRedirect(
          path: '/trips/create',
          countryEmpty: isCountryEmpty(
            hiveCountry: hive is String ? hive : null,
          ),
          travelerCountryUnsupported:
              box.get(HiveService.kTravelerCountryUnsupported) == true,
        );
        expect(redirect, isNull);
        await cubit.close();
      });
    }

    test('enregistrement refusé : le cache reste vide, la garde renvoie '
        'encore à la sélection (le pays n\'est pas enregistré)', () async {
      when(() => repo.updatePrefs(any())).thenThrow(Exception('timeout'));
      final analytics = _MockAnalytics();
      final cubit = CountryOnboardingCubit(repo, box, analytics);

      await cubit.select('FR');

      expect(cubit.state, isA<CountryOnboardingError>());
      expect(box.get(HiveService.kCountryCode), isNull);
      await cubit.close();
    });
  });
}
