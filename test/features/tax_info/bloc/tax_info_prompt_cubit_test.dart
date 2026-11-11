import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tax_info/bloc/tax_info_prompt_cubit.dart';
import 'package:dony/features/tax_info/bloc/tax_info_session.dart';
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
);
const _done = TaxInfo(
  provided: true,
  solicitation: TaxInfoSolicitation.dejaFourni,
  maskedTaxIdentificationNumber: '****1234',
);
const _none = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.nePasSolliciter,
);

void main() {
  late MockRepo repo;
  late MockAnalytics analytics;
  late TaxInfoSession session;

  setUp(() {
    repo = MockRepo();
    analytics = MockAnalytics();
    session = TaxInfoSession();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  TaxInfoPromptCubit build({String userId = 'u1'}) =>
      TaxInfoPromptCubit(repo, analytics, session, userId);

  void stubFetch(TaxInfo info) =>
      when(() => repo.fetch()).thenAnswer((_) async => info);

  test('rien lu : ni bannière ni ligne', () async {
    final cubit = build();
    expect(cubit.state.showBanner, isFalse);
    expect(cubit.state.showRow, isFalse);
    await cubit.close();
  });

  test('SOLLICITER : bannière, pas de ligne', () async {
    stubFetch(_ask);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.showBanner, isTrue);
    expect(cubit.state.showRow, isFalse);
    await cubit.close();
  });

  test('DEJA_FOURNI : ligne discrète, pas de bannière', () async {
    stubFetch(_done);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.showBanner, isFalse);
    expect(cubit.state.showRow, isTrue);
    await cubit.close();
  });

  test('NE_PAS_SOLLICITER : rien du tout', () async {
    stubFetch(_none);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.showBanner, isFalse);
    expect(cubit.state.showRow, isFalse);
    await cubit.close();
  });

  for (final status in [404, 403, 401]) {
    test(
      '$status : fonction absente, rien d\'affiché, rien de lancé',
      () async {
        when(
          () => repo.fetch(),
        ).thenThrow(TaxInfoUnavailableException(status: status));
        final cubit = build();
        await cubit.load();
        expect(cubit.state.info, isNull);
        expect(cubit.state.showBanner, isFalse);
        expect(cubit.state.showRow, isFalse);
        await cubit.close();
      },
    );
  }

  test('une fonction qui disparaît efface la lecture précédente', () async {
    stubFetch(_ask);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.showBanner, isTrue);
    when(() => repo.fetch()).thenThrow(const TaxInfoUnavailableException());
    await cubit.load();
    expect(cubit.state.showBanner, isFalse);
    await cubit.close();
  });

  test('réseau : la dernière lecture reste, sans bruit', () async {
    stubFetch(_ask);
    final cubit = build();
    await cubit.load();
    when(() => repo.fetch()).thenThrow(const TaxInfoException('network'));
    await cubit.load();
    expect(cubit.state.showBanner, isTrue);
    when(() => repo.fetch()).thenThrow(StateError('x'));
    await cubit.load();
    expect(cubit.state.showBanner, isTrue);
    await cubit.close();
  });

  test('lectures coalescées : jamais en rafale', () async {
    final gate = Completer<TaxInfo>();
    var calls = 0;
    when(() => repo.fetch()).thenAnswer((_) {
      calls++;
      return calls == 1 ? gate.future : Future.value(_ask);
    });
    final cubit = build();
    final first = cubit.load();
    for (var i = 0; i < 10; i++) {
      unawaited(cubit.load());
    }
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
    expect(cubit.state.info, isNull);
    await cubit.load();
    verify(() => repo.fetch()).called(1);
  });

  test('cubit fermé pendant une lecture en échec : aucune émission', () async {
    final gate = Completer<TaxInfo>();
    when(() => repo.fetch()).thenAnswer((_) => gate.future);
    final cubit = build();
    final pending = cubit.load();
    await cubit.close();
    gate.completeError(const TaxInfoUnavailableException());
    await pending;
  });

  group('« Plus tard »', () {
    test('masque la bannière pour la session, sans rien enregistrer', () async {
      stubFetch(_ask);
      final cubit = build();
      await cubit.load();
      cubit.dismiss();
      expect(cubit.state.dismissed, isTrue);
      expect(cubit.state.showBanner, isFalse);
      verifyNever(
        () => repo.save(
          taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
          taxCountry: any(named: 'taxCountry'),
          vatNumber: any(named: 'vatNumber'),
        ),
      );
      // Une relecture ne la fait pas revenir.
      await cubit.load();
      expect(cubit.state.showBanner, isFalse);
      // Second appel : sans effet, un seul événement.
      cubit.dismiss();
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.taxInfoLater,
          properties: {'source': 'banner'},
        ),
      ).called(1);
      await cubit.close();
    });

    test('survit au cubit (session), par compte', () async {
      stubFetch(_ask);
      final first = build();
      await first.load();
      first.dismiss();
      await first.close();

      final again = build();
      expect(again.state.dismissed, isTrue);
      await again.load();
      expect(again.state.showBanner, isFalse);
      await again.close();

      final other = build(userId: 'u2');
      await other.load();
      expect(other.state.showBanner, isTrue);
      await other.close();
    });

    test(
      'la ligne « déjà fourni » n\'est pas masquée par « Plus tard »',
      () async {
        stubFetch(_done);
        final cubit = build();
        await cubit.load();
        cubit.dismiss();
        expect(cubit.state.showRow, isTrue);
        await cubit.close();
      },
    );

    test('sur un cubit fermé : sans effet', () async {
      final cubit = build();
      await cubit.close();
      cubit.dismiss();
      expect(session.isDismissed('u1'), isFalse);
    });
  });

  test('trackTapped trace la variante, rien d\'autre', () async {
    final cubit = build();
    cubit.trackTapped('banner');
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.profileTaxInfoTapped,
        properties: {'variant': 'banner'},
      ),
    ).called(1);
    await cubit.close();
  });

  test('état : égalité et props', () {
    expect(
      const TaxInfoPromptState(info: _ask),
      const TaxInfoPromptState(info: _ask),
    );
    expect(
      const TaxInfoPromptState(info: _ask),
      isNot(const TaxInfoPromptState(info: _ask, dismissed: true)),
    );
  });
}
