import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tax_info/bloc/tax_info_cubit.dart';
import 'package:dony/features/tax_info/bloc/tax_info_signal.dart';
import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/repositories/tax_info_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements TaxInfoRepository {}

class MockAnalytics extends Mock implements AnalyticsService {}

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
  maskedVatNumber: '****89',
);
const _none = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.nePasSolliciter,
);

void main() {
  late MockRepo repo;
  late MockAnalytics analytics;

  setUp(() {
    repo = MockRepo();
    analytics = MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  TaxInfoCubit build() => TaxInfoCubit(repo, analytics);

  void stubFetch(TaxInfo info) =>
      when(() => repo.fetch()).thenAnswer((_) async => info);

  void stubSave(Future<TaxInfo> Function() answer) => when(
    () => repo.save(
      taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
      taxCountry: any(named: 'taxCountry'),
      vatNumber: any(named: 'vatNumber'),
    ),
  ).thenAnswer((_) => answer());

  /// Les propriétés envoyées à l'analytique ne contiennent jamais la saisie.
  void expectNoSecretLogged(String number, String vat) {
    final calls = verify(
      () => analytics.logEvent(
        any(),
        properties: captureAny(named: 'properties'),
      ),
    ).captured;
    for (final props in calls) {
      final text = '$props';
      expect(text, isNot(contains(number)));
      expect(text, isNot(contains(vat)));
      for (final v in (props as Map).values) {
        expect(v is int, isFalse, reason: 'aucune longueur');
      }
    }
  }

  group('état', () {
    test('validation du numéro fiscal', () {
      TaxInfoState s(String n) => TaxInfoState(taxNumber: n);
      expect(s('').isTaxNumberValid, isFalse);
      expect(s('').isTaxNumberInvalid, isFalse);
      expect(s('123').isTaxNumberValid, isFalse);
      expect(s('123').isTaxNumberInvalid, isTrue);
      expect(s('1234').isTaxNumberValid, isTrue);
      expect(s(' 12 34 ').isTaxNumberValid, isTrue);
      expect(s('FR-12.34/56').isTaxNumberValid, isTrue);
      expect(s('Éa1 23').isTaxNumberValid, isFalse);
      expect(s('ab1 23').isTaxNumberValid, isTrue);
      // Séparateur en bord : refusé comme par le back.
      expect(s('-1234').isTaxNumberValid, isFalse);
      expect(s('1234.').isTaxNumberValid, isFalse);
      expect(s('12 34 ').isTaxNumberValid, isTrue); // rogné avant contrôle
      expect(s('1234/').isTaxNumberValid, isFalse);
      expect(s('1' * 40).isTaxNumberValid, isTrue);
      expect(s('1' * 41).isTaxNumberValid, isFalse);
      expect(s('12_34').isTaxNumberValid, isFalse);
      expect(s('12@34').isTaxNumberInvalid, isTrue);
      expect(s('12–34').isTaxNumberValid, isFalse);
    });

    test(
      'validation de la TVA : vide permise, sinon même règle que le back',
      () {
        TaxInfoState v(String n) => TaxInfoState(vatNumber: n);
        expect(v('').isVatValid, isTrue);
        expect(v('   ').isVatValid, isTrue);
        expect(v('FR12').isVatValid, isTrue);
        expect(v('FR 12 345 678 901').isVatValid, isTrue);
        expect(v('FR1').isVatValid, isFalse);
        expect(v('FR1').isVatInvalid, isTrue);
        expect(v('FR12_3').isVatInvalid, isTrue);
        expect(v('-FR12').isVatInvalid, isTrue);
        expect(v('FR12.').isVatInvalid, isTrue);
        expect(v('F' * 41).isVatInvalid, isTrue);
        const ready = TaxInfoState(
          load: TaxInfoLoadStatus.ready,
          taxNumber: '12345',
          taxCountry: 'FR',
        );
        expect(ready.copyWith(vatNumber: 'X').canSubmit, isFalse);
        expect(ready.copyWith(vatNumber: 'FR12').canSubmit, isTrue);
      },
    );

    test('toString ne recopie ni le numéro fiscal ni la TVA', () {
      const s = TaxInfoState(taxNumber: 'SECRET-1234', vatNumber: 'FRVAT-9999');
      expect('$s', isNot(contains('SECRET')));
      expect('$s', isNot(contains('FRVAT')));
      expect(s.toString(), 'TaxInfoState');
    });

    test('erreur 422 : rattachée au bon champ', () {
      const nif = TaxInfoState(errorCode: kTaxInfoInvalidCode);
      expect(nif.serverRejectedTaxNumber, isTrue);
      expect(nif.serverRejectedVat, isFalse);
      const nif2 = TaxInfoState(
        errorCode: kTaxInfoInvalidCode,
        errorField: kTaxFieldNumber,
      );
      expect(nif2.serverRejectedTaxNumber, isTrue);
      const vat = TaxInfoState(
        errorCode: kTaxInfoInvalidCode,
        errorField: kTaxFieldVat,
      );
      expect(vat.serverRejectedVat, isTrue);
      expect(vat.serverRejectedTaxNumber, isFalse);
      expect(
        const TaxInfoState(errorCode: 'network').serverRejectedVat,
        isFalse,
      );
      expect(
        const TaxInfoState(errorCode: 'network').serverRejectedTaxNumber,
        isFalse,
      );
    });

    test('canSubmit demande chargement prêt, numéro, pays, pas d\'envoi', () {
      const ready = TaxInfoState(
        load: TaxInfoLoadStatus.ready,
        taxNumber: '12345',
        taxCountry: 'FR',
      );
      expect(ready.canSubmit, isTrue);
      expect(ready.copyWith(submitting: true).canSubmit, isFalse);
      expect(
        const TaxInfoState(taxNumber: '12345', taxCountry: 'FR').canSubmit,
        isFalse,
      );
      expect(
        const TaxInfoState(
          load: TaxInfoLoadStatus.ready,
          taxNumber: '12345',
        ).canSubmit,
        isFalse,
      );
    });

    test('showsSummary : fourni et pas en modification', () {
      expect(const TaxInfoState(info: _done).showsSummary, isTrue);
      expect(
        const TaxInfoState(info: _done, editing: true).showsSummary,
        isFalse,
      );
      expect(const TaxInfoState(info: _ask).showsSummary, isFalse);
      expect(const TaxInfoState().showsSummary, isFalse);
    });

    test('copyWith conserve ce qui n\'est pas changé', () {
      const base = TaxInfoState(
        info: _done,
        taxCountry: 'SN',
        errorCode: 'network',
      );
      expect(base.copyWith().errorCode, 'network');
      expect(base.copyWith(clearError: true).errorCode, isNull);
    });
  });

  group('chargement', () {
    test('SOLLICITER : formulaire prêt, pays proposé = résidence', () async {
      stubFetch(_ask);
      final cubit = build();
      await cubit.load();
      expect(cubit.state.load, TaxInfoLoadStatus.ready);
      expect(cubit.state.info, _ask);
      expect(cubit.state.taxCountry, 'FR');
      expect(cubit.state.showsSummary, isFalse);
      await cubit.close();
    });

    test('DEJA_FOURNI : fiche prête, pays du numéro conservé', () async {
      stubFetch(_done);
      final cubit = build();
      await cubit.load();
      expect(cubit.state.load, TaxInfoLoadStatus.ready);
      expect(cubit.state.showsSummary, isTrue);
      expect(cubit.state.taxCountry, 'SN');
      await cubit.close();
    });

    test('NE_PAS_SOLLICITER et rien fourni : rien à montrer', () async {
      stubFetch(_none);
      final cubit = build();
      await cubit.load();
      expect(cubit.state.load, TaxInfoLoadStatus.unavailable);
      await cubit.close();
    });

    test('404 (dac7-disabled), 403, 401 : fonction absente', () async {
      when(() => repo.fetch()).thenThrow(const TaxInfoUnavailableException());
      final cubit = build();
      await cubit.load();
      expect(cubit.state.load, TaxInfoLoadStatus.unavailable);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.taxInfoOpened,
          properties: any(named: 'properties'),
        ),
      );
      await cubit.close();
    });

    test('réseau : échec avec reprise possible', () async {
      when(() => repo.fetch()).thenThrow(const TaxInfoException('network'));
      final cubit = build();
      await cubit.load();
      expect(cubit.state.load, TaxInfoLoadStatus.failure);
      stubFetch(_ask);
      await cubit.load();
      expect(cubit.state.load, TaxInfoLoadStatus.ready);
      await cubit.close();
    });

    test('erreur inattendue : échec, aucun crash', () async {
      when(() => repo.fetch()).thenThrow(StateError('x'));
      final cubit = build();
      await cubit.load();
      expect(cubit.state.load, TaxInfoLoadStatus.failure);
      await cubit.close();
    });

    test('ouverture tracée une fois, sans valeur saisie', () async {
      stubFetch(_ask);
      final cubit = build();
      await cubit.load();
      await cubit.load();
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.taxInfoOpened,
          properties: {
            'solicitation': 'SOLLICITER',
            'provided': false,
            'collection_status': 'legacy',
          },
        ),
      ).called(1);
      await cubit.close();
    });

    test('lectures coalescées : un seul rejeu', () async {
      final gate = Completer<TaxInfo>();
      var calls = 0;
      when(() => repo.fetch()).thenAnswer((_) {
        calls++;
        return calls == 1 ? gate.future : Future.value(_ask);
      });
      final cubit = build();
      final first = cubit.load();
      unawaited(cubit.load());
      unawaited(cubit.load());
      unawaited(cubit.load());
      gate.complete(_ask);
      await first;
      expect(calls, 2);
      await cubit.close();
    });

    test('cubit fermé pendant la lecture : aucune émission', () async {
      final gate = Completer<TaxInfo>();
      when(() => repo.fetch()).thenAnswer((_) => gate.future);
      final cubit = build();
      final pending = cubit.load();
      await cubit.close();
      gate.complete(_ask);
      await pending;
      expect(cubit.state.load, TaxInfoLoadStatus.loading);
    });

    test('load sur un cubit fermé : sans effet', () async {
      final cubit = build();
      await cubit.close();
      await cubit.load();
      verifyNever(() => repo.fetch());
    });
  });

  group('saisie', () {
    test('updateForm met à jour numéro, TVA et pays', () async {
      stubFetch(_ask);
      final cubit = build();
      await cubit.load();
      cubit.updateForm(taxNumber: '12345', vatNumber: 'FR99', taxCountry: 'SN');
      expect(cubit.state.taxNumber, '12345');
      expect(cubit.state.vatNumber, 'FR99');
      expect(cubit.state.taxCountry, 'SN');
      expect(cubit.state.canSubmit, isTrue);
      await cubit.close();
    });

    test('modifier le numéro efface l\'erreur « numéro refusé »', () async {
      stubFetch(_ask);
      stubSave(() async => throw const TaxInfoException('tax-info-invalid'));
      final cubit = build();
      await cubit.load();
      cubit.updateForm(taxNumber: '12345');
      await cubit.submit();
      expect(cubit.state.errorCode, kTaxInfoInvalidCode);
      cubit.updateForm(vatNumber: 'x');
      expect(cubit.state.errorCode, kTaxInfoInvalidCode);
      cubit.updateForm(taxNumber: '123456');
      expect(cubit.state.errorCode, isNull);
      await cubit.close();
    });

    test(
      'startEditing ouvre un formulaire vide, cancelEditing revient',
      () async {
        stubFetch(_done);
        final cubit = build();
        await cubit.load();
        cubit.startEditing();
        expect(cubit.state.editing, isTrue);
        expect(cubit.state.showsSummary, isFalse);
        expect(cubit.state.taxNumber, isEmpty);
        cubit.updateForm(taxNumber: '9999');
        cubit.cancelEditing();
        expect(cubit.state.editing, isFalse);
        expect(cubit.state.taxNumber, isEmpty);
        expect(cubit.state.showsSummary, isTrue);
        await cubit.close();
      },
    );

    test('sur un cubit fermé : sans effet', () async {
      final cubit = build();
      await cubit.close();
      cubit.updateForm(taxNumber: '12345');
      cubit.startEditing();
      cubit.cancelEditing();
      cubit.later();
      await cubit.submit();
      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
    });
  });

  group('envoi', () {
    late int signals;
    void onSignal() => signals++;

    setUp(() {
      signals = 0;
      taxInfoChanged.addListener(onSignal);
      addTearDown(() => taxInfoChanged.removeListener(onSignal));
    });

    test('invalide : aucun appel', () async {
      stubFetch(_ask);
      final cubit = build();
      await cubit.load();
      cubit.updateForm(taxNumber: '12');
      await cubit.submit();
      verifyNever(
        () => repo.save(
          taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
          taxCountry: any(named: 'taxCountry'),
          vatNumber: any(named: 'vatNumber'),
        ),
      );
      await cubit.close();
    });

    test(
      'réussi : forme masquée, saisie effacée, signal, analytique',
      () async {
        stubFetch(_ask);
        stubSave(() async => _done);
        final cubit = build();
        await cubit.load();
        cubit.updateForm(
          taxNumber: ' 98761234 ',
          vatNumber: 'FRVAT889',
          taxCountry: 'SN',
        );
        await cubit.submit();

        verify(
          () => repo.save(
            taxIdentificationNumber: ' 98761234 ',
            taxCountry: 'SN',
            vatNumber: 'FRVAT889',
          ),
        ).called(1);
        expect(cubit.state.saved, isTrue);
        expect(cubit.state.submitting, isFalse);
        expect(cubit.state.info, _done);
        expect(cubit.state.taxNumber, isEmpty);
        expect(cubit.state.vatNumber, isEmpty);
        expect(cubit.state.showsSummary, isTrue);
        expect(signals, 1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.taxInfoSaved,
            properties: {'edit': false},
          ),
        ).called(1);
        expectNoSecretLogged('98761234', 'FRVAT889');
        await cubit.close();
      },
    );

    test('modification d\'informations déjà fournies : edit = true', () async {
      stubFetch(_done);
      stubSave(() async => _done);
      final cubit = build();
      await cubit.load();
      cubit.startEditing();
      cubit.updateForm(taxNumber: '55556666');
      await cubit.submit();
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.taxInfoSaved,
          properties: {'edit': true},
        ),
      ).called(1);
      expect(cubit.state.editing, isFalse);
      await cubit.close();
    });

    test('double appui : un seul envoi', () async {
      stubFetch(_ask);
      final gate = Completer<TaxInfo>();
      stubSave(() => gate.future);
      final cubit = build();
      await cubit.load();
      cubit.updateForm(taxNumber: '12345678');
      final first = cubit.submit();
      expect(cubit.state.submitting, isTrue);
      expect(cubit.state.canSubmit, isFalse);
      await cubit.submit();
      await cubit.submit();
      gate.complete(_done);
      await first;
      verify(
        () => repo.save(
          taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
          taxCountry: any(named: 'taxCountry'),
          vatNumber: any(named: 'vatNumber'),
        ),
      ).called(1);
      expect(signals, 1);
      await cubit.close();
    });

    test('pendant l\'envoi, la saisie est figée', () async {
      stubFetch(_ask);
      final gate = Completer<TaxInfo>();
      stubSave(() => gate.future);
      final cubit = build();
      await cubit.load();
      cubit.updateForm(taxNumber: '12345678');
      final pending = cubit.submit();
      cubit.updateForm(taxNumber: 'autre');
      expect(cubit.state.taxNumber, '12345678');
      gate.complete(_done);
      await pending;
      await cubit.close();
    });

    test(
      '422 tax-info-invalid : erreur sans la valeur, formulaire gardé',
      () async {
        stubFetch(_ask);
        stubSave(
          () async =>
              throw const TaxInfoException('tax-info-invalid', status: 422),
        );
        final cubit = build();
        await cubit.load();
        cubit.updateForm(taxNumber: '12345678');
        await cubit.submit();
        expect(cubit.state.errorCode, kTaxInfoInvalidCode);
        expect(cubit.state.submitting, isFalse);
        expect(cubit.state.saved, isFalse);
        expect(cubit.state.load, TaxInfoLoadStatus.ready);
        expect(cubit.state.taxNumber, '12345678');
        expect(signals, 0);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.taxInfoSaveFailed,
            properties: {'error_code': 'tax-info-invalid'},
          ),
        ).called(1);
        expectNoSecretLogged('12345678', 'zzz');
        await cubit.close();
      },
    );

    test('404 dac7-disabled : fonction absente', () async {
      stubFetch(_ask);
      stubSave(
        () async => throw const TaxInfoUnavailableException(status: 404),
      );
      final cubit = build();
      await cubit.load();
      cubit.updateForm(taxNumber: '12345678', vatNumber: 'FR9999');
      await cubit.submit();
      expect(cubit.state.load, TaxInfoLoadStatus.unavailable);
      expect(cubit.state.errorCode, 'dac7-disabled');
      expect(cubit.state.submitting, isFalse);
      // Plus de formulaire à rejouer : la saisie ne reste pas en mémoire.
      expect(cubit.state.taxNumber, isEmpty);
      expect(cubit.state.vatNumber, isEmpty);
      await cubit.close();
    });

    test('réseau puis nouvelle tentative réussie', () async {
      stubFetch(_ask);
      stubSave(() async => throw const TaxInfoException('network'));
      final cubit = build();
      await cubit.load();
      cubit.updateForm(taxNumber: '12345678');
      await cubit.submit();
      expect(cubit.state.errorCode, 'network');
      stubSave(() async => _done);
      await cubit.submit();
      expect(cubit.state.saved, isTrue);
      expect(cubit.state.errorCode, isNull);
      await cubit.close();
    });

    test('erreur inattendue : unknown', () async {
      stubFetch(_ask);
      stubSave(() async => throw StateError('x'));
      final cubit = build();
      await cubit.load();
      cubit.updateForm(taxNumber: '12345678');
      await cubit.submit();
      expect(cubit.state.errorCode, 'unknown');
      await cubit.close();
    });

    test(
      'cubit fermé pendant l\'envoi : aucune émission, signal émis',
      () async {
        stubFetch(_ask);
        final gate = Completer<TaxInfo>();
        stubSave(() => gate.future);
        final cubit = build();
        await cubit.load();
        cubit.updateForm(taxNumber: '12345678');
        final pending = cubit.submit();
        await cubit.close();
        gate.complete(_done);
        await pending;
        // L'enregistrement a eu lieu côté serveur : le Profil doit se relire.
        expect(signals, 1);
      },
    );

    test('cubit fermé pendant un envoi en échec : pas d\'émission', () async {
      stubFetch(_ask);
      final gate = Completer<TaxInfo>();
      stubSave(() => gate.future);
      final cubit = build();
      await cubit.load();
      cubit.updateForm(taxNumber: '12345678');
      final pending = cubit.submit();
      await cubit.close();
      gate.completeError(const TaxInfoException('network'));
      await pending;
      // Aucune émission après la fermeture : l'état reste celui d'avant l'échec
      // (un `emit` sur un cubit fermé lèverait une exception).
      expect(cubit.isClosed, isTrue);
      expect(cubit.state.submitting, isTrue);
      expect(cubit.state.errorCode, isNull);
    });
  });

  group('« Plus tard »', () {
    test('trace l\'événement, sans rien enregistrer', () async {
      stubFetch(_ask);
      final cubit = build();
      await cubit.load();
      cubit.updateForm(taxNumber: '12345678');
      cubit.later();
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.taxInfoLater,
          properties: {'source': 'screen'},
        ),
      ).called(1);
      verifyNever(
        () => repo.save(
          taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
          taxCountry: any(named: 'taxCountry'),
          vatNumber: any(named: 'vatNumber'),
        ),
      );
      await cubit.close();
    });
  });
}
