import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/form_draft_store.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/data/payer_phone_memory.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/form_draft_test_doubles.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class _Invalid extends ValidationException {
  const _Invalid()
    : super('numéro invalide', code: 'mobile-money-invalid-phone');
}

/// Trousseau dont la lecture attend [gate].
class _SlowStorage implements FormDraftStorage {
  _SlowStorage(this._inner, this.gate);

  final FormDraftStorage _inner;
  final Future<void> gate;

  @override
  Future<String?> read(String key) async {
    await gate;
    return _inner.read(key);
  }

  @override
  Future<void> write(String key, String value) => _inner.write(key, value);

  @override
  Future<void> delete(String key) => _inner.delete(key);
}

void main() {
  const orange = MobileMoneyOperator(
    code: 'ORANGE_CIV',
    label: 'Orange Money',
    brand: 'ORANGE',
  );
  const mtn = MobileMoneyOperator(
    code: 'MTN_MOMO_CIV',
    label: 'MTN MoMo',
    brand: 'MTN',
  );
  const wave = MobileMoneyOperator(
    code: 'WAVE_CIV',
    label: 'Wave',
    brand: 'WAVE',
  );
  const ci = MobileMoneyCountry(
    country: 'CI',
    currency: 'XOF',
    operators: [orange, mtn, wave],
  );
  const sn = MobileMoneyCountry(
    country: 'SN',
    currency: 'XOF',
    operators: [
      MobileMoneyOperator(code: 'WAVE_SEN', label: 'Wave', brand: 'WAVE'),
    ],
  );
  const countries = MobileMoneyCountries(available: [ci, sn], upcoming: ['ML']);

  const e164 = '+2250748840856';

  MobileMoneyProviderCatalog catalogDetecting(String? code) =>
      MobileMoneyProviderCatalog(
        country: 'CI',
        currency: 'XOF',
        detected: code,
      );

  late MockWalletRepository repo;
  late MockAnalyticsService analytics;
  late InMemoryFormDraftStorage storage;
  late PayerPhoneMemory memory;
  late PayerAccountCubit cubit;

  PayerAccountCubit build() =>
      PayerAccountCubit(repo, memory, analytics, flow: 'topup');

  setUp(() {
    repo = MockWalletRepository();
    analytics = MockAnalyticsService();
    storage = InMemoryFormDraftStorage();
    memory = PayerPhoneMemory(storage: storage, currentUid: () => 'uid-1');
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => repo.mobileMoneyCountries()).thenAnswer((_) async => countries);
    when(
      () => repo.topupProviders(any()),
    ).thenAnswer((_) async => catalogDetecting('ORANGE_CIV'));
    cubit = build();
  });

  tearDown(() => cubit.close());

  /// Charge le catalogue puis choisit CI + Orange.
  Future<void> readyOnOrange() async {
    await cubit.load();
    cubit.selectCountry('CI');
    cubit.selectOperator('ORANGE_CIV');
  }

  void verifyLogged(String event, Map<String, Object> properties) {
    verify(() => analytics.logEvent(event, properties: properties)).called(1);
  }

  group('load', () {
    test('load_withoutCatalog_emitsLegacy', () async {
      when(() => repo.mobileMoneyCountries()).thenAnswer((_) async => null);

      await cubit.load();

      expect(cubit.state.status, PayerAccountStatus.legacy);
      expect(cubit.state.countries, isNull);
    });

    test('load_networkError_emitsError', () async {
      when(() => repo.mobileMoneyCountries()).thenThrow(Exception('réseau'));

      await cubit.load();

      expect(cubit.state.status, PayerAccountStatus.error);
    });

    test('load_withoutMemory_isReadyWithNothingSelected', () async {
      await cubit.load();

      expect(cubit.state.status, PayerAccountStatus.ready);
      expect(cubit.state.countries, countries);
      expect(cubit.state.country, isNull);
      expect(cubit.state.operator, isNull);
      verifyNever(() => repo.topupProviders(any()));
    });

    test('load_prefillsFromMemory_whenCountryStillOpen', () async {
      await memory.save(
        const RememberedPayer(
          country: 'CI',
          operatorCode: 'ORANGE_CIV',
          e164: e164,
        ),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.country, ci);
      expect(cubit.state.operator, orange);
      expect(cubit.state.e164, e164);
      expect(cubit.state.localNumber, '0748840856');
      expect(cubit.state.recognition, RecognitionStatus.recognized);
      verify(() => repo.topupProviders(e164)).called(1);
    });

    test('load_ignoresMemory_whenCountryClosed', () async {
      await memory.save(
        const RememberedPayer(
          country: 'BF',
          operatorCode: 'ORANGE_BFA',
          e164: '+22670123456',
        ),
      );

      await cubit.load();

      expect(cubit.state.status, PayerAccountStatus.ready);
      expect(cubit.state.country, isNull);
      expect(cubit.state.e164, isNull);
      verifyNever(() => repo.topupProviders(any()));
    });

    test('load_memoryReadPending_isNotReadyYet_thenPrefills', () async {
      await memory.save(
        const RememberedPayer(
          country: 'CI',
          operatorCode: 'ORANGE_CIV',
          e164: e164,
        ),
      );
      final gate = Completer<void>();
      final slow = _SlowStorage(storage, gate.future);
      cubit = PayerAccountCubit(
        repo,
        PayerPhoneMemory(storage: slow, currentUid: () => 'uid-1'),
        analytics,
        flow: 'topup',
      );

      final loading = cubit.load();
      await Future<void>.delayed(Duration.zero);
      // Tant que la mémoire se lit, le catalogue n'est pas exposé : aucun
      // choix de l'utilisateur ne peut être écrasé par le préremplissage.
      expect(cubit.state.status, PayerAccountStatus.loading);
      cubit.selectCountry('SN');
      expect(cubit.state.country, isNull);

      gate.complete();
      await loading;

      expect(cubit.state.status, PayerAccountStatus.ready);
      expect(cubit.state.country, ci);
      expect(cubit.state.operator, orange);
    });

    test('load_calledAgain_dropsOlderLoad', () async {
      final gate = Completer<MobileMoneyCountries?>();
      var calls = 0;
      when(() => repo.mobileMoneyCountries()).thenAnswer((_) {
        return ++calls == 1 ? gate.future : Future.value(countries);
      });

      final first = cubit.load();
      await cubit.load();
      gate.complete(null);
      await first;

      expect(cubit.state.status, PayerAccountStatus.ready);
    });

    test('load_ignoresMemory_whenOperatorGone', () async {
      await memory.save(
        const RememberedPayer(
          country: 'CI',
          operatorCode: 'MOOV_CIV',
          e164: e164,
        ),
      );

      await cubit.load();

      expect(cubit.state.country, isNull);
      expect(cubit.state.operator, isNull);
    });
  });

  group('selectCountry / clearCountry', () {
    test('selectCountry_open_setsCountry_andLogsEvent', () async {
      await cubit.load();

      cubit.selectCountry('ci');

      expect(cubit.state.country, ci);
      expect(cubit.state.unavailableCountry, isNull);
      verifyLogged(AnalyticsEvents.mobileMoneyCountrySelected, {
        'country': 'CI',
        'available': true,
        'flow': 'topup',
      });
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.mobileMoneyCountryUnavailableViewed,
          properties: any(named: 'properties'),
        ),
      );
    });

    test('selectCountry_upcoming_setsUnavailable_andLogsEvent', () async {
      await cubit.load();

      cubit.selectCountry('ML');

      expect(cubit.state.country, isNull);
      expect(cubit.state.unavailableCountry, 'ML');
      expect(cubit.state.operator, isNull);
      expect(cubit.state.canProceed, isFalse);
      verifyLogged(AnalyticsEvents.mobileMoneyCountrySelected, {
        'country': 'ML',
        'available': false,
        'flow': 'topup',
      });
      verifyLogged(AnalyticsEvents.mobileMoneyCountryUnavailableViewed, {
        'country': 'ML',
        'flow': 'topup',
      });
    });

    test('selectCountry_unknown_isIgnored', () async {
      await cubit.load();
      final before = cubit.state;

      cubit.selectCountry('ZZ');

      expect(cubit.state, before);
      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
    });

    test('selectCountry_beforeLoad_isIgnored', () {
      cubit.selectCountry('CI');
      expect(cubit.state.country, isNull);
    });

    test('selectCountry_upcomingThenOpen_clearsUnavailable', () async {
      await cubit.load();
      cubit.selectCountry('ML');

      cubit.selectCountry('SN');

      expect(cubit.state.country, sn);
      expect(cubit.state.unavailableCountry, isNull);
    });

    test(
      'selectCountry_afterOperatorAndNumber_resetsBoth_noRecognitionCall',
      () {
        fakeAsync((async) {
          cubit.load();
          async.flushMicrotasks();
          cubit.selectCountry('CI');
          cubit.selectOperator('ORANGE_CIV');
          cubit.phoneChanged('07 48 84 08 56');
          // Le changement de pays arrive avant la fin du debounce.
          async.elapse(const Duration(milliseconds: 200));

          cubit.selectCountry('SN');
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();

          expect(cubit.state.country, sn);
          expect(cubit.state.operator, isNull);
          expect(cubit.state.localNumber, isEmpty);
          expect(cubit.state.e164, isNull);
          expect(cubit.state.recognition, RecognitionStatus.idle);
          verifyNever(() => repo.topupProviders(any()));
        });
      },
    );

    test('clearCountry_resetsEverything', () async {
      await readyOnOrange();
      cubit.phoneChanged('0748840856');

      cubit.clearCountry();

      expect(cubit.state.country, isNull);
      expect(cubit.state.operator, isNull);
      expect(cubit.state.e164, isNull);
      expect(cubit.state.localNumber, isEmpty);
      expect(cubit.state.status, PayerAccountStatus.ready);
    });
  });

  group('selectOperator', () {
    test('selectOperator_keepsNumber_andRecognizesWithoutDebounce', () {
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.phoneChanged('0748840856');
        async.elapse(const Duration(seconds: 1));
        verifyNever(() => repo.topupProviders(any()));

        cubit.selectOperator('ORANGE_CIV');
        async.flushMicrotasks();

        expect(cubit.state.e164, e164);
        expect(cubit.state.recognition, RecognitionStatus.recognized);
        verify(() => repo.topupProviders(e164)).called(1);
      });
    });

    test('selectOperator_sameCode_isNoop', () {
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');
        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);
        async.flushMicrotasks();
        final before = cubit.state;

        cubit.selectOperator('ORANGE_CIV');
        async.flushMicrotasks();

        expect(cubit.state, before);
        verify(() => repo.topupProviders(e164)).called(1);
      });
    });

    test('selectOperator_afterAutoSwitch_respectsManualChoice', () {
      when(
        () => repo.topupProviders(any()),
      ).thenAnswer((_) async => catalogDetecting('MTN_MOMO_CIV'));
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');
        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);
        async.flushMicrotasks();
        expect(cubit.state.recognition, RecognitionStatus.autoSwitched);

        cubit.selectOperator('ORANGE_CIV');
        async.flushMicrotasks();

        expect(cubit.state.operator, orange);
        expect(cubit.state.recognition, RecognitionStatus.overridden);
        expect(cubit.state.switchedFrom, isNull);
        expect(cubit.state.canProceed, isTrue);

        cubit.selectOperator('WAVE_CIV');
        expect(cubit.state.operator, wave);
        expect(cubit.state.recognition, RecognitionStatus.overridden);

        cubit.selectOperator('MTN_MOMO_CIV');
        expect(cubit.state.operator, mtn);
        expect(cubit.state.recognition, RecognitionStatus.recognized);

        // Aucun nouvel appel, ni second basculement.
        verify(() => repo.topupProviders(e164)).called(1);
        verifyLogged(AnalyticsEvents.mobileMoneyOperatorAutoSwitched, {
          'from': 'ORANGE_CIV',
          'to': 'MTN_MOMO_CIV',
          'flow': 'topup',
        });
      });
    });

    test('selectOperator_afterNumberEdit_recognizesAgain', () {
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');
        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);
        async.flushMicrotasks();

        // Un nouveau numéro efface la détection : le choix suivant interroge.
        cubit.phoneChanged('0101010101');
        cubit.selectOperator('WAVE_CIV');
        async.flushMicrotasks();

        verify(() => repo.topupProviders('+2250101010101')).called(1);
      });
    });

    test('selectOperator_notInCountry_isIgnored', () async {
      await cubit.load();
      cubit.selectCountry('CI');

      cubit.selectOperator('WAVE_SEN');

      expect(cubit.state.operator, isNull);
    });
  });

  group('phoneChanged', () {
    test('phoneChanged_pastedWithDialCode_normalizesToSingleDialCode', () {
      for (final raw in [
        '+225 07 48 84 08 56',
        '00225 0748840856',
        '07 48 84 08 56',
        '225 0748840856',
      ]) {
        fakeAsync((async) {
          final c = build();
          c.load();
          async.flushMicrotasks();
          c.selectCountry('CI');
          c.selectOperator('ORANGE_CIV');

          c.phoneChanged(raw);

          expect(c.state.e164, e164, reason: raw);
          expect(c.state.localNumber, '0748840856', reason: raw);
          c.close();
        });
      }
    });

    test('phoneChanged_withoutCountry_keepsNoE164', () async {
      await cubit.load();

      cubit.phoneChanged('0748840856');

      expect(cubit.state.e164, isNull);
      expect(cubit.state.recognition, RecognitionStatus.idle);
    });

    test('phoneChanged_empty_clearsNumber', () async {
      await readyOnOrange();
      cubit.phoneChanged('0748840856');

      cubit.phoneChanged('  ');

      expect(cubit.state.e164, isNull);
      expect(cubit.state.localNumber, isEmpty);
    });

    test('phoneChanged_incomplete_doesNotRecognize', () {
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');

        cubit.phoneChanged('07 48 84');
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(cubit.state.recognition, RecognitionStatus.idle);
        verifyNever(() => repo.topupProviders(any()));
      });
    });

    test('phoneChanged_debounces500ms_thenRecognizes', () {
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');

        cubit.phoneChanged('0748840856');
        async.elapse(const Duration(milliseconds: 499));
        verifyNever(() => repo.topupProviders(any()));

        async.elapse(const Duration(milliseconds: 1));

        expect(cubit.state.recognition, RecognitionStatus.recognized);
        expect(cubit.state.canProceed, isTrue);
        verify(() => repo.topupProviders(e164)).called(1);
      });
    });

    test('phoneChanged_detectedOtherOperator_autoSwitches', () {
      when(
        () => repo.topupProviders(any()),
      ).thenAnswer((_) async => catalogDetecting('MTN_MOMO_CIV'));
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');

        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);
        async.flushMicrotasks();

        expect(cubit.state.operator?.code, 'MTN_MOMO_CIV');
        expect(cubit.state.recognition, RecognitionStatus.autoSwitched);
        expect(cubit.state.switchedFrom, 'ORANGE_CIV');
        expect(cubit.state.canProceed, isTrue);
        verifyLogged(AnalyticsEvents.mobileMoneyOperatorAutoSwitched, {
          'from': 'ORANGE_CIV',
          'to': 'MTN_MOMO_CIV',
          'flow': 'topup',
        });
      });
    });

    test('phoneChanged_detectedSameOperator_recognized', () {
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');

        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);
        async.flushMicrotasks();

        expect(cubit.state.operator, orange);
        expect(cubit.state.recognition, RecognitionStatus.recognized);
        expect(cubit.state.switchedFrom, isNull);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyOperatorAutoSwitched,
            properties: any(named: 'properties'),
          ),
        );
      });
    });

    test('phoneChanged_invalidNumber_unrecognized', () {
      when(() => repo.topupProviders(any())).thenThrow(const _Invalid());
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');

        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);
        async.flushMicrotasks();

        expect(cubit.state.recognition, RecognitionStatus.unrecognized);
        expect(cubit.state.canProceed, isFalse);
        verifyLogged(AnalyticsEvents.mobileMoneyNumberUnrecognized, {
          'flow': 'topup',
        });
      });
    });

    test('phoneChanged_detectedOperatorOutsideCountry_unrecognized', () {
      when(
        () => repo.topupProviders(any()),
      ).thenAnswer((_) async => catalogDetecting('WAVE_SEN'));
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');

        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);
        async.flushMicrotasks();

        expect(cubit.state.recognition, RecognitionStatus.unrecognized);
        expect(cubit.state.operator, orange);
      });
    });

    test('phoneChanged_networkError_failed', () {
      when(() => repo.topupProviders(any())).thenThrow(Exception('réseau'));
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');

        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);
        async.flushMicrotasks();

        expect(cubit.state.recognition, RecognitionStatus.failed);
        expect(cubit.state.canProceed, isFalse);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyNumberUnrecognized,
            properties: any(named: 'properties'),
          ),
        );
      });
    });

    test('retryRecognition_afterFailure_recognizes', () {
      var calls = 0;
      when(() => repo.topupProviders(any())).thenAnswer((_) async {
        if (++calls == 1) throw Exception('réseau');
        return catalogDetecting('ORANGE_CIV');
      });
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');
        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);
        async.flushMicrotasks();
        expect(cubit.state.recognition, RecognitionStatus.failed);

        cubit.retryRecognition();
        async.flushMicrotasks();

        expect(cubit.state.recognition, RecognitionStatus.recognized);
        expect(cubit.state.canProceed, isTrue);
        verify(() => repo.topupProviders(e164)).called(2);
      });
    });

    test('retryRecognition_withoutCompleteNumber_doesNothing', () async {
      await readyOnOrange();

      await cubit.retryRecognition();

      verifyNever(() => repo.topupProviders(any()));
      expect(cubit.state.recognition, RecognitionStatus.idle);
    });

    test('phoneChanged_predictedOperatorClosed_unrecognized', () {
      when(
        () => repo.topupProviders(any()),
      ).thenAnswer((_) async => catalogDetecting(null));
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');

        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);
        async.flushMicrotasks();

        expect(cubit.state.recognition, RecognitionStatus.unrecognized);
        expect(cubit.state.canProceed, isFalse);
        verifyLogged(AnalyticsEvents.mobileMoneyNumberUnrecognized, {
          'flow': 'topup',
        });
      });
    });

    test('phoneChanged_foreignDialCode_unrecognizedWithoutCall', () {
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');

        cubit.phoneChanged('+221 77 123 45 67');
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(cubit.state.recognition, RecognitionStatus.unrecognized);
        expect(cubit.state.e164, '+221771234567');
        expect(cubit.state.localNumber, '771234567');
        verifyNever(() => repo.topupProviders(any()));
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyNumberUnrecognized,
            properties: any(named: 'properties'),
          ),
        );
      });
    });

    test('phoneChanged_partialDialCode_staysIdle', () {
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');

        // Indicatif +225 en cours de frappe : rien n'est encore faux.
        for (final raw in ['+', '+2', '+22']) {
          cubit.phoneChanged(raw);
          expect(cubit.state.recognition, RecognitionStatus.idle, reason: raw);
          expect(cubit.state.e164, isNull, reason: raw);
        }
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(cubit.state.recognition, RecognitionStatus.idle);
        verifyNever(() => repo.topupProviders(any()));
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyNumberUnrecognized,
            properties: any(named: 'properties'),
          ),
        );
      });
    });

    test('phoneChanged_staleResponseIgnored', () {
      fakeAsync((async) {
        // Créés dans la zone factice, sinon leurs continuations lui échappent.
        final first = Completer<MobileMoneyProviderCatalog>();
        final second = Completer<MobileMoneyProviderCatalog>();
        when(
          () => repo.topupProviders('+2250748840856'),
        ).thenAnswer((_) => first.future);
        when(
          () => repo.topupProviders('+2250101010101'),
        ).thenAnswer((_) => second.future);
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');

        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);
        cubit.phoneChanged('0101010101');
        async.elapse(PayerAccountCubit.debounce);

        // La première réponse arrive en retard : elle bascule sur MTN, mais
        // la saisie courante est la seconde.
        first.complete(catalogDetecting('MTN_MOMO_CIV'));
        async.flushMicrotasks();
        expect(cubit.state.operator, orange);
        expect(cubit.state.recognition, RecognitionStatus.checking);

        second.complete(catalogDetecting('ORANGE_CIV'));
        async.flushMicrotasks();
        expect(cubit.state.e164, '+2250101010101');
        expect(cubit.state.operator, orange);
        expect(cubit.state.recognition, RecognitionStatus.recognized);
      });
    });

    test('phoneChanged_editedWhileChecking_dropsResponse', () {
      fakeAsync((async) {
        final pending = Completer<MobileMoneyProviderCatalog>();
        when(
          () => repo.topupProviders(any()),
        ).thenAnswer((_) => pending.future);
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');
        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);

        cubit.phoneChanged('07488');
        pending.complete(catalogDetecting('MTN_MOMO_CIV'));
        async.flushMicrotasks();

        expect(cubit.state.recognition, RecognitionStatus.idle);
        expect(cubit.state.operator, orange);
      });
    });

    test('close_cancelsPendingDebounce', () {
      fakeAsync((async) {
        final c = build();
        c.load();
        async.flushMicrotasks();
        c.selectCountry('CI');
        c.selectOperator('ORANGE_CIV');
        c.phoneChanged('0748840856');

        c.close();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verifyNever(() => repo.topupProviders(any()));
      });
    });
  });

  group('rememberSuccess / switchToCardTapped', () {
    test('rememberSuccess_savesCountryOperatorAndNumber', () {
      when(
        () => repo.topupProviders(any()),
      ).thenAnswer((_) async => catalogDetecting('MTN_MOMO_CIV'));
      fakeAsync((async) {
        cubit.load();
        async.flushMicrotasks();
        cubit.selectCountry('CI');
        cubit.selectOperator('ORANGE_CIV');
        cubit.phoneChanged('0748840856');
        async.elapse(PayerAccountCubit.debounce);
        async.flushMicrotasks();

        cubit.rememberSuccess();
        async.flushMicrotasks();

        final saved = storage.values['mm_last_payer_uid-1'];
        expect(saved, contains('"country":"CI"'));
        expect(saved, contains('"operatorCode":"MTN_MOMO_CIV"'));
        expect(saved, contains(e164));
      });
    });

    test('rememberSuccess_withoutNumber_savesNothing', () async {
      await readyOnOrange();

      await cubit.rememberSuccess();

      expect(storage.values, isEmpty);
    });

    test('switchToCardTapped_logsEventWithUpcomingCountry', () async {
      await cubit.load();
      cubit.selectCountry('ML');

      cubit.switchToCardTapped();

      verifyLogged(AnalyticsEvents.mobileMoneySwitchToCardTapped, {
        'country': 'ML',
        'flow': 'topup',
      });
    });
  });
}
