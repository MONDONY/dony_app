import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/recipients/bloc/designate_yadony_user_cubit.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements RecipientInvitationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

DioException _dio(AppException e) => DioException(
  requestOptions: RequestOptions(path: '/recipient-invitations/lookup'),
  error: e,
);

const _found = UsernameLookup(
  username: 'awa.diallo',
  initial: 'A',
  parcelDesignation: true,
);

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.usernameChannelUnsupported).thenReturn(false);
    when(() => repo.parcelDesignationUnavailable).thenReturn(false);
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  DesignateYadonyUserCubit build() => DesignateYadonyUserCubit(repo, analytics);

  test('la frappe ne lance jamais la recherche', () async {
    final c = build()
      ..inputChanged('a')
      ..inputChanged('awa.diallo');
    expect(c.state.lookup, DesignateLookup.idle);
    verifyNever(() => repo.lookupUsername(any()));
    await c.close();
  });

  test('validation : recherche normalisée puis compte trouvé', () async {
    when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
    final c = build()..inputChanged('@Awa.Diallo');
    await c.committed();
    verify(() => repo.lookupUsername('awa.diallo')).called(1);
    expect(c.state.lookup, DesignateLookup.found);
    expect(c.state.foundInitial, 'A');
    expect(c.state.canChoose, isTrue);
    await c.close();
  });

  test('format invalide : aucune requête', () async {
    final c = build();
    for (final v in ['ab', '.awa', 'awa..x', '']) {
      c.inputChanged(v);
      await c.committed();
    }
    verifyNever(() => repo.lookupUsername(any()));
    expect(c.state.canChoose, isFalse);
    await c.close();
  });

  test('un seul appel par saisie', () async {
    when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
    final c = build()..inputChanged('awa.diallo');
    await c.committed();
    await c.committed();
    verify(() => repo.lookupUsername('awa.diallo')).called(1);
    await c.close();
  });

  test('back sans la désignation de colis : pas de sélection', () async {
    when(() => repo.lookupUsername(any())).thenAnswer(
      (_) async => const UsernameLookup(username: 'awa.diallo', initial: 'A'),
    );
    final c = build()..inputChanged('awa.diallo');
    await c.committed();
    expect(c.state.lookup, DesignateLookup.unavailable);
    expect(c.state.canChoose, isFalse);
    expect(c.choose(), isNull);
    verify(() => repo.parcelDesignationUnavailable = true).called(1);
    await c.close();
  });

  test('introuvable, soi-même, quota', () async {
    final cases = <AppException, DesignateLookup>{
      const NotFoundException(apiCode: 'user-not-found'):
          DesignateLookup.notFound,
      const ValidationException(
        'x',
        code: 'recipient-invitation-self',
        extensions: {'type': 'recipient-invitation-self'},
      ): DesignateLookup.self,
      const RateLimitException('x', 'recipient-lookup-quota'):
          DesignateLookup.quota,
    };
    for (final e in cases.entries) {
      when(() => repo.lookupUsername(any())).thenThrow(_dio(e.key));
      final c = build()..inputChanged('awa.diallo');
      await c.committed();
      expect(c.state.lookup, e.value, reason: '${e.key}');
      expect(c.state.canChoose, isFalse);
      await c.close();
    }
  });

  test('route absente (405) : drapeau de session posé', () async {
    when(
      () => repo.lookupUsername(any()),
    ).thenThrow(_dio(const NetworkException('x', code: '405')));
    final c = build()..inputChanged('awa.diallo');
    await c.committed();
    expect(c.state.lookup, DesignateLookup.unsupported);
    verify(() => repo.usernameChannelUnsupported = true).called(1);
    await c.close();
  });

  test('choose rend l\'identifiant et trace sans l\'identifiant', () async {
    when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
    final c = build()..inputChanged('awa.diallo');
    await c.committed();
    final chosen = c.choose();
    expect(chosen?.username, 'awa.diallo');
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.recipientDesignatedByUsername,
        properties: any(named: 'properties'),
      ),
    ).called(1);
    await c.close();
  });

  test(
    'échec de recherche : événement avec error_code, sans identifiant',
    () async {
      when(() => repo.lookupUsername(any())).thenThrow(
        _dio(const RateLimitException('x', 'recipient-lookup-quota')),
      );
      final c = build()..inputChanged('awa.diallo');
      await c.committed();
      final captured =
          verify(
                () => analytics.logEvent(
                  AnalyticsEvents.recipientDesignationByUsernameFailed,
                  properties: captureAny(named: 'properties'),
                ),
              ).captured.single
              as Map<String, Object?>;
      expect(captured['error_code'], isNotNull);
      expect(captured.values.join(), isNot(contains('awa')));
      await c.close();
    },
  );
}
