import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/recipients/data/datasources/recipient_invitation_datasource.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _response(dynamic data, {int status = 200}) => Response(
  data: data,
  statusCode: status,
  requestOptions: RequestOptions(path: '/recipient-invitations'),
);

DioException _dioError(AppException error) => DioException(
  requestOptions: RequestOptions(path: '/recipient-invitations'),
  error: error,
);

void main() {
  late MockDio dio;
  late RecipientInvitationRepository repository;

  setUp(() {
    dio = MockDio();
    final api = MockApiClient();
    when(() => api.dio).thenReturn(dio);
    repository = RecipientInvitationRepository(
      RecipientInvitationDatasource(api),
    );
  });

  group('envoi', () {
    test('numéro : POST avec le seul champ phone, 202 suffit', () async {
      when(
        () => dio.post<dynamic>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => _response({'status': 'SENT'}, status: 202));

      await repository.sendToPhone('+221771234567');

      verify(
        () => dio.post<dynamic>(
          '/recipient-invitations',
          data: {'phone': '+221771234567'},
        ),
      ).called(1);
    });

    test('email : POST avec le seul champ email', () async {
      when(
        () => dio.post<dynamic>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => _response({'status': 'SENT'}, status: 202));

      await repository.sendToEmail('awa@example.com');

      verify(
        () => dio.post<dynamic>(
          '/recipient-invitations',
          data: {'email': 'awa@example.com'},
        ),
      ).called(1);
    });

    test('429 : le quota remonte en RateLimitException', () async {
      when(
        () => dio.post<dynamic>(any(), data: any(named: 'data')),
      ).thenThrow(_dioError(const RateLimitException()));

      await expectLater(
        repository.sendToPhone('+221771234567'),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<RateLimitException>(),
          ),
        ),
      );
    });
  });

  group('listes', () {
    test('envoyées : cible masquée et statut', () async {
      when(() => dio.get<dynamic>('/recipient-invitations/sent')).thenAnswer(
        (_) async => _response([
          {
            'id': 'i1',
            'channel': 'PHONE',
            'maskedTarget': '+221 •• •• •• 12',
            'status': 'PENDING',
            'createdAt': '2026-10-01T10:00:00Z',
          },
          {
            'id': 'i2',
            'channel': 'EMAIL',
            'maskedTarget': 'a••••@gmail.com',
            'status': 'ACCEPTED',
          },
          'ignoré',
        ]),
      );

      final sent = await repository.getSent();

      expect(sent, hasLength(2));
      expect(sent[0].maskedTarget, '+221 •• •• •• 12');
      expect(sent[0].isAccepted, isFalse);
      expect(sent[0].isEmail, isFalse);
      expect(sent[0].createdAt, DateTime.utc(2026, 10, 1, 10));
      expect(sent[1].isAccepted, isTrue);
      expect(sent[1].isEmail, isTrue);
      expect(sent[1].createdAt, isNull);
    });

    test('envoyées : réponse inattendue → liste vide', () async {
      when(
        () => dio.get<dynamic>('/recipient-invitations/sent'),
      ).thenAnswer((_) async => _response({'oops': true}));
      expect(await repository.getSent(), isEmpty);
    });

    test('reçues : prénom et statut, champs absents tolérés', () async {
      when(
        () => dio.get<dynamic>('/recipient-invitations/incoming'),
      ).thenAnswer(
        (_) async => _response([
          {
            'id': 'i1',
            'inviterFirstName': 'Awa',
            'status': 'PENDING',
            'createdAt': '2026-10-01T10:00:00Z',
          },
          {'id': 'i2', 'status': 'ACCEPTED'},
        ]),
      );

      final incoming = await repository.getIncoming();

      expect(incoming[0].inviterFirstName, 'Awa');
      expect(incoming[0].isPending, isTrue);
      expect(incoming[1].inviterFirstName, '');
      expect(incoming[1].isAccepted, isTrue);
      expect(incoming[1].copyWith().status, 'ACCEPTED');
      expect(incoming[0].copyWith(status: 'ACCEPTED').isAccepted, isTrue);
    });

    test('reçues : réponse inattendue → liste vide', () async {
      when(
        () => dio.get<dynamic>('/recipient-invitations/incoming'),
      ).thenAnswer((_) async => _response(null));
      expect(await repository.getIncoming(), isEmpty);
    });

    test('ancien back : 404 remonte', () async {
      when(
        () => dio.get<dynamic>('/recipient-invitations/sent'),
      ).thenThrow(_dioError(const NotFoundException()));
      await expectLater(repository.getSent(), throwsA(isA<DioException>()));
    });

    test('modèles : valeurs par défaut', () {
      final sent = SentRecipientInvitation.fromJson({'id': 'x'});
      expect(sent.channel, 'PHONE');
      expect(sent.status, 'PENDING');
      expect(sent.maskedTarget, '');
      final incoming = IncomingRecipientInvitation.fromJson({'id': 'y'});
      expect(incoming.status, 'PENDING');
    });
  });

  group('réponses', () {
    test('accepter, refuser, retirer : bonnes routes', () async {
      when(
        () => dio.post<dynamic>(any()),
      ).thenAnswer((_) async => _response(null));
      when(
        () => dio.delete<dynamic>(any()),
      ).thenAnswer((_) async => _response(null, status: 204));

      await repository.accept('i1');
      await repository.decline('i2');
      await repository.revoke('i3');

      verify(
        () => dio.post<dynamic>('/recipient-invitations/i1/accept'),
      ).called(1);
      verify(
        () => dio.post<dynamic>('/recipient-invitations/i2/decline'),
      ).called(1);
      verify(() => dio.delete<dynamic>('/recipient-invitations/i3')).called(1);
    });

    test('409 sans téléphone : code conservé', () async {
      when(() => dio.post<dynamic>(any())).thenThrow(
        _dioError(
          const ConflictException(
            'phone',
            code: 'recipient-invitation-phone-required',
          ),
        ),
      );
      await expectLater(
        repository.accept('i1'),
        throwsA(
          isA<DioException>().having(
            (e) => (e.error! as AppException).code,
            'code',
            'recipient-invitation-phone-required',
          ),
        ),
      );
    });
  });

  group('Recipient.linkedOnYadony', () {
    const base = {
      'id': 'r1',
      'fullName': 'Awa Diop',
      'phoneE164': '+221771234567',
      'country': 'SN',
    };

    test('absent (ancien back) → false', () {
      expect(Recipient.fromJson(base).linkedOnYadony, isFalse);
    });

    test('présent → lu, et conservé par copyWith', () {
      final r = Recipient.fromJson({...base, 'linkedOnYadony': true});
      expect(r.linkedOnYadony, isTrue);
      expect(r.copyWith(isDefault: true).linkedOnYadony, isTrue);
    });
  });
}
