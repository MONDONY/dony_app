import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_active_currency_cubit.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrefsRepository extends Mock implements BusinessPrefsRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

const _eurPrefs = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'EUR',
  pickupRadiusKm: 12,
  defaultPackageWeightKg: 23,
  minBidPriceEur: 5,
  country: 'FR',
  displayCurrencyCode: 'USD',
);

void main() {
  late _MockPrefsRepository repo;
  late _MockAnalytics analytics;
  late WalletActiveCurrencyCubit cubit;

  setUpAll(() => registerFallbackValue(_eurPrefs));

  setUp(() {
    repo = _MockPrefsRepository();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    cubit = WalletActiveCurrencyCubit(repo, analytics);
  });

  tearDown(() => cubit.close());

  test('état initial au repos', () {
    expect(cubit.state.isSwitching, isFalse);
    expect(cubit.state.switchCount, 0);
    expect(cubit.state.error, isNull);
  });

  test(
    'relit les préférences serveur et ne change que la devise active',
    () async {
      when(() => repo.fetchPrefs()).thenAnswer((_) async => _eurPrefs);
      when(() => repo.updatePrefs(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as UserBusinessPrefsDto,
      );

      final states = <WalletActiveCurrencyState>[];
      final sub = cubit.stream.listen(states.add);
      await cubit.switchTo('cad');
      await sub.cancel();

      expect(states.first.pendingCurrency, 'CAD');
      expect(cubit.state.isSwitching, isFalse);
      expect(cubit.state.switchedTo, 'CAD');
      expect(cubit.state.switchCount, 1);

      final sent =
          verify(() => repo.updatePrefs(captureAny())).captured.single
              as UserBusinessPrefsDto;
      expect(sent.currencyCode, 'CAD');
      // Le reste vient du serveur, pas d'un état local périmé.
      expect(sent.pickupRadiusKm, 12);
      expect(sent.minBidPriceEur, 5);
      expect(sent.country, 'FR');
      expect(sent.displayCurrencyCode, 'USD');
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.walletActiveCurrencySwitched,
          properties: {'from': 'EUR', 'to': 'CAD'},
        ),
      ).called(1);
    },
  );

  test('même devise que le serveur : aucun PUT, succès quand même', () async {
    when(() => repo.fetchPrefs()).thenAnswer((_) async => _eurPrefs);

    await cubit.switchTo('EUR');

    verifyNever(() => repo.updatePrefs(any()));
    verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    );
    expect(cubit.state.switchedTo, 'EUR');
    expect(cubit.state.switchCount, 1);
  });

  test(
    'erreur serveur (ancien contrat, 422 currency-locked) exposée',
    () async {
      when(() => repo.fetchPrefs()).thenAnswer((_) async => _eurPrefs);
      when(
        () => repo.updatePrefs(any()),
      ).thenThrow(const NetworkException('locked', code: 'currency-locked'));

      await cubit.switchTo('XOF');

      expect(cubit.state.isSwitching, isFalse);
      expect(cubit.state.error?.code, 'currency-locked');
      expect(cubit.state.switchCount, 0);
    },
  );

  test('ignore un second changement pendant le premier', () async {
    when(() => repo.fetchPrefs()).thenAnswer((_) async => _eurPrefs);
    when(() => repo.updatePrefs(any())).thenAnswer(
      (inv) async => inv.positionalArguments.first as UserBusinessPrefsDto,
    );

    final first = cubit.switchTo('CAD');
    await cubit.switchTo('XOF');
    await first;

    verify(() => repo.fetchPrefs()).called(1);
    expect(cubit.state.switchedTo, 'CAD');
  });

  test('cubit fermé pendant l’appel : aucune émission', () async {
    when(() => repo.fetchPrefs()).thenAnswer((_) async {
      await cubit.close();
      return _eurPrefs;
    });

    await cubit.switchTo('CAD');

    verifyNever(() => repo.updatePrefs(any()));
  });
}
