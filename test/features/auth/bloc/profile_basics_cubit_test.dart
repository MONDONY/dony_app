import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/profile_basics_cubit.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockBusinessPrefsRepository extends Mock
    implements BusinessPrefsRepository {}

class _MockBox extends Mock implements Box<dynamic> {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _FakeUserBusinessPrefsDto extends Fake implements UserBusinessPrefsDto {}

class _FakeUserModel extends Fake implements UserModel {}

const _prefs = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'XOF',
  defaultPackageWeightKg: 23,
  minBidPriceEur: 0,
);

void main() {
  late _MockAuthRepository auth;
  late _MockBusinessPrefsRepository businessPrefs;
  late _MockBox box;
  late _MockAnalyticsService analytics;

  ProfileBasicsCubit build() =>
      ProfileBasicsCubit(auth, businessPrefs, box, analytics);

  void stubUpdateProfile() => when(
    () => auth.updateProfile(
      firstName: any(named: 'firstName'),
      lastName: any(named: 'lastName'),
    ),
  ).thenAnswer((_) async => _FakeUserModel());

  setUpAll(() => registerFallbackValue(_FakeUserBusinessPrefsDto()));

  setUp(() {
    auth = _MockAuthRepository();
    businessPrefs = _MockBusinessPrefsRepository();
    box = _MockBox();
    analytics = _MockAnalyticsService();
    stubUpdateProfile();
    when(() => businessPrefs.fetchPrefs()).thenAnswer((_) async => _prefs);
    when(
      () => businessPrefs.updatePrefs(any()),
    ).thenAnswer((_) async => _prefs);
    when(() => box.put(any(), any())).thenAnswer((_) async {});
    when(() => analytics.logEvent(any())).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  group('submit', () {
    blocTest<ProfileBasicsCubit, ProfileBasicsState>(
      'un prénom seul écrit le nom et pas le pays',
      build: build,
      act: (cubit) => cubit.submit(firstName: '  Awa  '),
      expect: () => const [
        ProfileBasicsSaving(),
        ProfileBasicsSuccess(refreshProfile: true),
      ],
      verify: (_) {
        verify(() => auth.updateProfile(firstName: 'Awa')).called(1);
        verifyZeroInteractions(businessPrefs);
        verifyZeroInteractions(box);
      },
    );

    blocTest<ProfileBasicsCubit, ProfileBasicsState>(
      'des espaces seuls ne déclenchent aucun appel',
      build: build,
      act: (cubit) => cubit.submit(firstName: '   ', lastName: ' '),
      expect: () => const [ProfileBasicsSuccess(refreshProfile: false)],
      verify: (_) {
        verifyZeroInteractions(auth);
        verifyZeroInteractions(businessPrefs);
        verifyZeroInteractions(box);
      },
    );

    blocTest<ProfileBasicsCubit, ProfileBasicsState>(
      'un pays écrit le pays dans l\'ordre serveur puis Hive, sans nom',
      build: build,
      act: (cubit) => cubit.submit(countryCode: 'SN'),
      expect: () => const [
        ProfileBasicsSaving(),
        ProfileBasicsSuccess(refreshProfile: true),
      ],
      verify: (_) {
        verifyZeroInteractions(auth);
        verifyInOrder([
          () => businessPrefs.fetchPrefs(),
          () => businessPrefs.updatePrefs(
            any(
              that: isA<UserBusinessPrefsDto>().having(
                (dto) => dto.country,
                'country',
                'SN',
              ),
            ),
          ),
          () => box.put(HiveService.kCountryCode, 'SN'),
          () => box.put(HiveService.kCurrencyCode, 'XOF'),
          () => box.put(HiveService.kTravelerCountryUnsupported, false),
        ]);
      },
    );

    blocTest<ProfileBasicsCubit, ProfileBasicsState>(
      'nom et pays : le nom part d\'abord, puis le pays',
      build: build,
      act: (cubit) =>
          cubit.submit(firstName: 'Awa', lastName: 'Diallo', countryCode: 'SN'),
      expect: () => const [
        ProfileBasicsSaving(),
        ProfileBasicsSuccess(refreshProfile: true),
      ],
      verify: (_) {
        verifyInOrder([
          () => auth.updateProfile(firstName: 'Awa', lastName: 'Diallo'),
          () => businessPrefs.updatePrefs(any()),
        ]);
      },
    );

    blocTest<ProfileBasicsCubit, ProfileBasicsState>(
      'un échec réseau du nom rend Error sans toucher au pays',
      build: build,
      setUp: () => when(
        () => auth.updateProfile(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
        ),
      ).thenThrow(const NetworkException('offline', code: 'OFFLINE')),
      act: (cubit) => cubit.submit(firstName: 'Awa', countryCode: 'SN'),
      expect: () => const [ProfileBasicsSaving(), ProfileBasicsError()],
      verify: (_) {
        verifyZeroInteractions(businessPrefs);
        verifyZeroInteractions(box);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.profileBasicsFailed,
            properties: {'step': 'name', 'error_code': 'OFFLINE'},
          ),
        ).called(1);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.profileBasicsCompleted,
            properties: any(named: 'properties'),
          ),
        );
      },
    );

    blocTest<ProfileBasicsCubit, ProfileBasicsState>(
      'un échec du pays rend Error ; passer ensuite rafraîchit le profil, le '
      'nom ayant été écrit',
      build: build,
      setUp: () => when(
        () => businessPrefs.updatePrefs(any()),
      ).thenThrow(Exception('422')),
      act: (cubit) async {
        await cubit.submit(firstName: 'Awa', countryCode: 'SN');
        await cubit.skip();
      },
      expect: () => const [
        ProfileBasicsSaving(),
        ProfileBasicsError(),
        ProfileBasicsSuccess(refreshProfile: true),
      ],
      verify: (_) {
        verifyNever(() => box.put(any(), any()));
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.profileBasicsFailed,
            properties: {'step': 'country', 'error_code': 'unknown'},
          ),
        ).called(1);
      },
    );

    blocTest<ProfileBasicsCubit, ProfileBasicsState>(
      'completed porte has_name et has_country, sans PII',
      build: build,
      act: (cubit) => cubit.submit(lastName: 'Diallo', countryCode: 'SN'),
      verify: (_) {
        final captured = verify(
          () => analytics.logEvent(
            AnalyticsEvents.profileBasicsCompleted,
            properties: captureAny(named: 'properties'),
          ),
        ).captured;
        expect(captured.single, {'has_name': true, 'has_country': true});
      },
    );

    blocTest<ProfileBasicsCubit, ProfileBasicsState>(
      'completed sans rien saisi : has_name et has_country à faux',
      build: build,
      act: (cubit) => cubit.submit(),
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.profileBasicsCompleted,
          properties: {'has_name': false, 'has_country': false},
        ),
      ).called(1),
    );
  });

  group('skip', () {
    blocTest<ProfileBasicsCubit, ProfileBasicsState>(
      'n\'appelle aucun repository et ne rend jamais Error',
      build: build,
      act: (cubit) => cubit.skip(),
      expect: () => const [ProfileBasicsSuccess(refreshProfile: false)],
      verify: (_) {
        verifyZeroInteractions(auth);
        verifyZeroInteractions(businessPrefs);
        verifyZeroInteractions(box);
        verify(
          () => analytics.logEvent(AnalyticsEvents.profileBasicsSkipped),
        ).called(1);
      },
    );
  });

  test('trackViewed émet profile_basics_viewed sans propriété', () {
    build().trackViewed();
    verify(
      () => analytics.logEvent(AnalyticsEvents.profileBasicsViewed),
    ).called(1);
  });

  test('les noms d\'événements sont en snake_case', () {
    expect(AnalyticsEvents.profileBasicsViewed, 'profile_basics_viewed');
    expect(AnalyticsEvents.profileBasicsCompleted, 'profile_basics_completed');
    expect(AnalyticsEvents.profileBasicsSkipped, 'profile_basics_skipped');
    expect(AnalyticsEvents.profileBasicsFailed, 'profile_basics_failed');
  });
}
