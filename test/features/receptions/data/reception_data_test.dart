import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/receptions/data/datasources/reception_remote_datasource.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/receptions/data/repositories/reception_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

const _bidId = 'b1b2c3d4-e5f6-7890-abcd-ef1234567890';

Map<String, dynamic> _confirmedJson() => {
  'bidId': _bidId,
  'linkStatus': 'CONFIRMED',
  'bidStatus': 'IN_TRANSIT',
  'senderFirstName': 'Awa',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2026-10-04',
  'arrivalDate': '2026-10-05',
  'recipientName': 'Moussa Diop',
  'trackingNumber': 'DON-AB12CD',
  'travelerFirstName': 'Ibrahima',
  'travelerId': 'trav-1',
  'travelerAvatarUrl': 'https://cdn.test/a.jpg',
  'senderId': 'send-1',
  'senderAvatarUrl': 'https://cdn.test/s.jpg',
  'arrivalInstructions': 'Sortie B, parking P2.',
  'weightKg': 4,
  'confirmationCode': '482913',
  'updatedAt': '2026-10-04T08:30:00Z',
};

Response<dynamic> _response(dynamic data, {int status = 200}) => Response(
  data: data,
  statusCode: status,
  requestOptions: RequestOptions(path: '/receptions'),
);

void main() {
  group('Reception.fromJson', () {
    test('lien confirmé : tous les champs', () {
      final r = Reception.fromJson(_confirmedJson());

      expect(r.bidId, _bidId);
      expect(r.isConfirmed, isTrue);
      expect(r.isPending, isFalse);
      expect(r.bidStatus, 'IN_TRANSIT');
      expect(r.senderFirstName, 'Awa');
      expect(r.departureDate, DateTime(2026, 10, 4));
      expect(r.arrivalDate, DateTime(2026, 10, 5));
      expect(r.recipientName, 'Moussa Diop');
      expect(r.trackingNumber, 'DON-AB12CD');
      expect(r.travelerFirstName, 'Ibrahima');
      expect(r.travelerId, 'trav-1');
      expect(r.travelerAvatarUrl, 'https://cdn.test/a.jpg');
      expect(r.senderId, 'send-1');
      expect(r.senderAvatarUrl, 'https://cdn.test/s.jpg');
      expect(r.arrivalInstructions, 'Sortie B, parking P2.');
      expect(r.weightKg, 4.0);
      expect(r.confirmationCode, '482913');
      expect(r.updatedAt, DateTime.utc(2026, 10, 4, 8, 30));
    });

    test('champs absents : tout est nul, le lien reste à confirmer', () {
      final r = Reception.fromJson({'bidId': _bidId});

      expect(r.isPending, isTrue);
      expect(r.bidStatus, '');
      expect(r.senderFirstName, isNull);
      expect(r.departureCity, isNull);
      expect(r.arrivalCity, isNull);
      expect(r.departureDate, isNull);
      expect(r.arrivalDate, isNull);
      expect(r.recipientName, isNull);
      expect(r.trackingNumber, isNull);
      expect(r.travelerFirstName, isNull);
      expect(r.travelerId, isNull);
      // Back antérieur au contrat FLUTTER-7P : pas d'expéditeur cliquable.
      expect(r.senderId, isNull);
      expect(r.senderAvatarUrl, isNull);
      expect(r.arrivalInstructions, isNull);
      expect(r.weightKg, isNull);
      expect(r.confirmationCode, isNull);
      expect(r.updatedAt, isNull);
    });

    test('textes vides et dates illisibles valent null', () {
      final r = Reception.fromJson({
        'bidId': _bidId,
        'linkStatus': 'PENDING',
        'senderFirstName': '  ',
        'arrivalInstructions': '',
        'departureDate': 'pas une date',
        'weightKg': null,
      });

      expect(r.senderFirstName, isNull);
      expect(r.arrivalInstructions, isNull);
      expect(r.departureDate, isNull);
    });
  });

  group('Reception.fromJson — note du voyageur (FLUTTER-CA)', () {
    test('canRate et myRating lus', () {
      final r = Reception.fromJson({
        ..._confirmedJson(),
        'bidStatus': 'COMPLETED',
        'canRate': false,
        'myRating': 4,
      });
      expect(r.canRate, isFalse);
      expect(r.myRating, 4);

      final rateable = Reception.fromJson({
        ..._confirmedJson(),
        'canRate': true,
        'myRating': null,
      });
      expect(rateable.canRate, isTrue);
      expect(rateable.myRating, isNull);
    });

    test('back antérieur ou valeurs inattendues : ni notation ni note', () {
      final old = Reception.fromJson(_confirmedJson());
      expect(old.canRate, isFalse);
      expect(old.myRating, isNull);

      final odd = Reception.fromJson({
        ..._confirmedJson(),
        'canRate': 'true',
        'myRating': 9,
      });
      expect(odd.canRate, isFalse);
      expect(odd.myRating, isNull);
    });
  });

  group('ReceptionRemoteDatasource', () {
    late MockApiClient apiClient;
    late MockDio dio;
    late ReceptionRepository repository;

    setUp(() {
      apiClient = MockApiClient();
      dio = MockDio();
      when(() => apiClient.dio).thenReturn(dio);
      repository = ReceptionRepository(ReceptionRemoteDatasource(apiClient));
    });

    test('GET /receptions : liste', () async {
      when(() => dio.get('/receptions')).thenAnswer(
        (_) async => _response([
          _confirmedJson(),
          {'bidId': 'other', 'linkStatus': 'PENDING', 'bidStatus': 'ACCEPTED'},
        ]),
      );

      final list = await repository.getReceptions();

      expect(list, hasLength(2));
      expect(list.first.confirmationCode, '482913');
      expect(list.last.isPending, isTrue);
    });

    test('GET /receptions : réponse inattendue, liste vide', () async {
      when(
        () => dio.get('/receptions'),
      ).thenAnswer((_) async => _response({'content': []}));

      expect(await repository.getReceptions(), isEmpty);
    });

    test('GET /receptions/{bidId}', () async {
      when(
        () => dio.get('/receptions/$_bidId'),
      ).thenAnswer((_) async => _response(_confirmedJson()));

      final r = await repository.getReception(_bidId);

      expect(r.trackingNumber, 'DON-AB12CD');
    });

    test('POST /receptions/{bidId}/confirm rend le colis à jour', () async {
      when(
        () => dio.post('/receptions/$_bidId/confirm'),
      ).thenAnswer((_) async => _response(_confirmedJson()));

      final r = await repository.confirm(_bidId);

      expect(r.isConfirmed, isTrue);
    });

    test('POST /receptions/{bidId}/rating : étoiles et commentaire', () async {
      when(
        () => dio.post<dynamic>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => _response({'id': 'r1'}, status: 201));

      await repository.rateTraveler(_bidId, stars: 5, comment: 'Parfait');

      verify(
        () => dio.post<dynamic>(
          '/receptions/$_bidId/rating',
          data: {'stars': 5, 'comment': 'Parfait'},
        ),
      ).called(1);
    });

    test('POST /receptions/{bidId}/rating sans commentaire', () async {
      when(
        () => dio.post<dynamic>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => _response({'id': 'r1'}, status: 201));

      await repository.rateTraveler(_bidId, stars: 3);

      verify(
        () =>
            dio.post<dynamic>('/receptions/$_bidId/rating', data: {'stars': 3}),
      ).called(1);
    });

    test('POST /receptions/{bidId}/decline', () async {
      when(
        () => dio.post('/receptions/$_bidId/decline'),
      ).thenAnswer((_) async => _response(null, status: 204));

      await repository.decline(_bidId);

      verify(() => dio.post('/receptions/$_bidId/decline')).called(1);
    });
  });

  group('Reception.canMessageTraveler (lot 3C)', () {
    Reception reception(String link, String bid) =>
        Reception(bidId: 'b', linkStatus: link, bidStatus: bid);

    test('lien confirmé et colis en cours', () {
      for (final status in Reception.activeBidStatuses) {
        expect(reception('CONFIRMED', status).canMessageTraveler, isTrue);
      }
    });

    test('colis terminé ou lien à confirmer : non', () {
      expect(reception('CONFIRMED', 'COMPLETED').canMessageTraveler, isFalse);
      expect(reception('CONFIRMED', '').canMessageTraveler, isFalse);
      expect(reception('PENDING', 'IN_TRANSIT').canMessageTraveler, isFalse);
    });
  });

  group('Reception.canShowParcelQr (FLUTTER-7Y)', () {
    Reception reception(String link, String bid) =>
        Reception(bidId: 'b', linkStatus: link, bidStatus: bid);

    test('lien confirmé et colis pas encore remis', () {
      for (final status in Reception.activeBidStatuses) {
        expect(reception('CONFIRMED', status).canShowParcelQr, isTrue);
      }
    });

    test('colis remis ou lien à confirmer : non', () {
      expect(reception('CONFIRMED', 'COMPLETED').canShowParcelQr, isFalse);
      expect(reception('PENDING', 'ACCEPTED').canShowParcelQr, isFalse);
    });
  });
}
