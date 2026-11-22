import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/contact_picker_service.dart';
import 'package:dony/features/recipients/bloc/invite_recipient_cubit.dart';
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

const _found = UsernameLookup(username: 'awa.diallo', initial: 'A');

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.usernameChannelUnsupported).thenReturn(false);
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  InviteRecipientCubit build() =>
      InviteRecipientCubit(repo, analytics)
        ..selectChannel(InvitationChannel.username);

  test('la frappe ne lance jamais la recherche', () async {
    final c = build()
      ..inputChanged('a')
      ..inputChanged('awa')
      ..inputChanged('awa.diallo');
    expect(c.state.lookup, UsernameLookupStatus.idle);
    verifyNever(() => repo.lookupUsername(any()));
    await c.close();
  });

  test('validation : recherche normalisée (minuscules, sans @)', () async {
    when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
    final c = build()..inputChanged('@Awa.Diallo');
    await c.usernameCommitted();
    verify(() => repo.lookupUsername('awa.diallo')).called(1);
    expect(c.state.lookup, UsernameLookupStatus.found);
    expect(c.state.foundInitial, 'A');
    expect(c.state.isValid, isTrue);
    await c.close();
  });

  test('format invalide : aucune requête', () async {
    final c = build();
    for (final v in ['ab', '.awa', 'awa..x', 'awa-x', 'a' * 21, '']) {
      c.inputChanged(v);
      await c.usernameCommitted();
    }
    verifyNever(() => repo.lookupUsername(any()));
    expect(c.state.lookup, UsernameLookupStatus.idle);
    expect(c.state.isValid, isFalse);
    await c.close();
  });

  test(
    'une modification remet l\'aperçu à zéro et désactive l\'envoi',
    () async {
      when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
      final c = build()..inputChanged('awa.diallo');
      await c.usernameCommitted();
      expect(c.state.isValid, isTrue);
      c.inputChanged('awa.diallo2');
      expect(c.state.lookup, UsernameLookupStatus.idle);
      expect(c.state.isValid, isFalse);
      await c.close();
    },
  );

  test('revalider la même saisie ne relance pas la recherche', () async {
    when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
    final c = build()..inputChanged('awa.diallo');
    await c.usernameCommitted();
    await c.usernameCommitted();
    verify(() => repo.lookupUsername(any())).called(1);
    await c.close();
  });

  test('réponse périmée ignorée après une modification', () async {
    when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
    final c = build()..inputChanged('awa.diallo');
    final pending = c.usernameCommitted();
    c.inputChanged('awa.dial');
    await pending;
    expect(c.state.lookup, UsernameLookupStatus.idle);
    expect(c.state.isValid, isFalse);
    await c.close();
  });

  group('verdicts du serveur', () {
    Future<InviteRecipientCubit> commit(Object error) async {
      when(() => repo.lookupUsername(any())).thenThrow(error);
      final c = build()..inputChanged('awa.diallo');
      await c.usernameCommitted();
      return c;
    }

    test('404 user-not-found : introuvable', () async {
      final c = await commit(
        _dio(
          const NotFoundException(
            apiCode: 'user-not-found',
            extensions: {'type': 'https://yadony.com/problems/user-not-found'},
          ),
        ),
      );
      expect(c.state.lookup, UsernameLookupStatus.notFound);
      expect(c.state.usernameUnsupported, isFalse);
      expect(c.state.isValid, isFalse);
      await c.close();
    });

    test('422 recipient-invitation-self : c\'est soi-même', () async {
      final c = await commit(
        _dio(
          const ValidationException(
            'x',
            code: 'recipient-invitation-self',
            extensions: {'type': 'recipient-invitation-self'},
          ),
        ),
      );
      expect(c.state.lookup, UsernameLookupStatus.self);
      await c.close();
    });

    test('429 : quota de recherche', () async {
      final c = await commit(
        _dio(const RateLimitException('x', 'recipient-lookup-quota')),
      );
      expect(c.state.lookup, UsernameLookupStatus.quota);
      await c.close();
    });

    test(
      '404 sans type user-not-found : route absente, onglet retiré',
      () async {
        final c = await commit(_dio(const NotFoundException()));
        expect(c.state.lookup, UsernameLookupStatus.unsupported);
        expect(c.state.usernameUnsupported, isTrue);
        // Le canal ne peut plus être choisi.
        c.selectChannel(InvitationChannel.phone);
        c.selectChannel(InvitationChannel.username);
        expect(c.state.channel, InvitationChannel.phone);
        expect(c.state.usernameUnsupported, isTrue);
        await c.close();
      },
    );

    test(
      '405 (prod : GET lookup mappé sur /{id}) : route absente, onglet retiré',
      () async {
        final c = await commit(
          _dio(const NetworkException('Method Not Allowed', code: '405')),
        );
        expect(c.state.lookup, UsernameLookupStatus.unsupported);
        expect(c.state.usernameUnsupported, isTrue);
        // Le verdict est mémorisé pour la session, sur le dépôt singleton.
        verify(() => repo.usernameChannelUnsupported = true).called(1);
        await c.close();
      },
    );

    test('un autre NetworkException reste un échec réessayable', () async {
      final c = await commit(_dio(const NetworkException('x', code: '500')));
      expect(c.state.lookup, UsernameLookupStatus.failed);
      verifyNever(() => repo.usernameChannelUnsupported = true);
      await c.close();
    });

    test('un cubit ouvert après un verdict unsupported n\'a pas d\'onglet', () {
      when(() => repo.usernameChannelUnsupported).thenReturn(true);
      final c = InviteRecipientCubit(repo, analytics);
      expect(c.state.usernameUnsupported, isTrue);
      c.selectChannel(InvitationChannel.username);
      expect(c.state.channel, InvitationChannel.phone);
      c.close();
    });

    test(
      '404 user-not-found : le drapeau de session n\'est pas posé',
      () async {
        final c = await commit(
          _dio(const NotFoundException(apiCode: 'user-not-found')),
        );
        expect(c.state.usernameUnsupported, isFalse);
        verifyNever(() => repo.usernameChannelUnsupported = true);
        await c.close();
      },
    );

    test(
      '404 sans type user-not-found : le drapeau de session est posé',
      () async {
        final c = await commit(_dio(const NotFoundException()));
        verify(() => repo.usernameChannelUnsupported = true).called(1);
        await c.close();
      },
    );

    test('autre échec : réessayable à la validation suivante', () async {
      final c = await commit(Exception('boom'));
      expect(c.state.lookup, UsernameLookupStatus.failed);
      when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
      await c.usernameCommitted();
      expect(c.state.lookup, UsernameLookupStatus.found);
      await c.close();
    });
  });

  group('envoi', () {
    test('POST avec l\'identifiant et le nom, événement sans PII', () async {
      when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
      when(
        () => repo.sendToUsername(any(), name: any(named: 'name')),
      ).thenAnswer((_) async {});
      final c = build()
        ..nameChanged(' Awa ')
        ..inputChanged('Awa.Diallo');
      await c.usernameCommitted();
      await c.submit();
      verify(() => repo.sendToUsername('awa.diallo', name: 'Awa')).called(1);
      expect(c.state.status, InviteRecipientStatus.sent);
      verify(
        () => analytics.logEvent(any(), properties: {'channel': 'username'}),
      ).called(1);
      await c.close();
    });

    test('sans aperçu trouvé, rien n\'est envoyé', () async {
      final c = build()..inputChanged('awa.diallo');
      await c.submit();
      verifyNever(() => repo.sendToUsername(any(), name: any(named: 'name')));
      await c.close();
    });

    test('404 user-not-found à l\'envoi : retour à introuvable', () async {
      when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
      when(
        () => repo.sendToUsername(any(), name: any(named: 'name')),
      ).thenThrow(_dio(const NotFoundException(apiCode: 'user-not-found')));
      final c = build()..inputChanged('awa.diallo');
      await c.usernameCommitted();
      await c.submit();
      expect(c.state.lookup, UsernameLookupStatus.notFound);
      expect(c.state.status, InviteRecipientStatus.editing);
      await c.close();
    });

    test(
      '405 à l\'envoi (champ username) : onglet retiré et mémorisé',
      () async {
        when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
        when(
          () => repo.sendToUsername(any(), name: any(named: 'name')),
        ).thenThrow(_dio(const NetworkException('x', code: '405')));
        final c = build()..inputChanged('awa.diallo');
        await c.usernameCommitted();
        await c.submit();
        expect(c.state.lookup, UsernameLookupStatus.unsupported);
        expect(c.state.usernameUnsupported, isTrue);
        expect(c.state.status, InviteRecipientStatus.editing);
        verify(() => repo.usernameChannelUnsupported = true).called(1);
        await c.close();
      },
    );

    test('404 user-not-found à l\'envoi : pas de drapeau de session', () async {
      when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
      when(
        () => repo.sendToUsername(any(), name: any(named: 'name')),
      ).thenThrow(_dio(const NotFoundException(apiCode: 'user-not-found')));
      final c = build()..inputChanged('awa.diallo');
      await c.usernameCommitted();
      await c.submit();
      verifyNever(() => repo.usernameChannelUnsupported = true);
      await c.close();
    });

    test('404 sans type à l\'envoi : drapeau de session posé', () async {
      when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
      when(
        () => repo.sendToUsername(any(), name: any(named: 'name')),
      ).thenThrow(_dio(const NotFoundException()));
      final c = build()..inputChanged('awa.diallo');
      await c.usernameCommitted();
      await c.submit();
      verify(() => repo.usernameChannelUnsupported = true).called(1);
      await c.close();
    });

    test('429 du quota quotidien : quota d\'envoi, pas de recherche', () async {
      when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
      when(
        () => repo.sendToUsername(any(), name: any(named: 'name')),
      ).thenThrow(
        _dio(const RateLimitException('x', 'recipient-invitation-quota')),
      );
      final c = build()..inputChanged('awa.diallo');
      await c.usernameCommitted();
      await c.submit();
      expect(c.state.status, InviteRecipientStatus.failed);
      expect(c.state.isQuotaExceeded, isTrue);
      expect(c.state.lookup, UsernameLookupStatus.found);
      await c.close();
    });

    test('429 de recherche à l\'envoi : quota de recherche', () async {
      when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
      when(
        () => repo.sendToUsername(any(), name: any(named: 'name')),
      ).thenThrow(
        _dio(const RateLimitException('x', 'recipient-lookup-quota')),
      );
      final c = build()..inputChanged('awa.diallo');
      await c.usernameCommitted();
      await c.submit();
      expect(c.state.lookup, UsernameLookupStatus.quota);
      expect(c.state.status, InviteRecipientStatus.editing);
      expect(c.state.isQuotaExceeded, isFalse);
      expect(c.state.error, isNull);
      await c.close();
    });
  });

  test('validation après close : ni requête ni exception', () async {
    final c = build()..inputChanged('awa.diallo');
    await c.close();
    await c.usernameCommitted();
    verifyNever(() => repo.lookupUsername(any()));
  });

  test(
    'contact choisi : une recherche en vol n\'écrit pas sur le numéro',
    () async {
      when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
      final c = build()..inputChanged('awa.diallo');
      final pending = c.usernameCommitted();
      c.contactPicked(
        const PickedContact(fullName: 'Awa', phone: '+221771234567'),
      );
      await pending;
      expect(c.state.channel, InvitationChannel.phone);
      expect(c.state.lookup, UsernameLookupStatus.idle);
      await c.close();
    },
  );

  test('contact sans téléphone : la recherche en vol aboutit', () async {
    when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
    final c = build()..inputChanged('awa.diallo');
    final pending = c.usernameCommitted();
    c.contactPicked(const PickedContact(fullName: 'Awa'));
    expect(c.state.name, 'Awa');
    expect(c.state.lookup, UsernameLookupStatus.searching);
    await pending;
    expect(c.state.channel, InvitationChannel.username);
    expect(c.state.lookup, UsernameLookupStatus.found);
    await c.close();
  });

  test('le nom survit au changement d\'onglet', () {
    final c = build()
      ..nameChanged('Awa')
      ..selectChannel(InvitationChannel.phone);
    expect(c.state.name, 'Awa');
    expect(c.state.channel, InvitationChannel.phone);
  });
}
