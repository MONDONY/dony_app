import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/recipient_change/recipient_change_cubit.dart';
import 'package:dony/features/matching/data/datasources/bid_negotiation_remote_datasource.dart';
import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

class _MockClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

class _MockBidRepo extends Mock implements BidRepository {}

class _MockNegoRepo extends Mock implements BidNegotiationRepository {}

class _MockConfig extends Mock implements IConfigRepository {}

Response<dynamic> _ok(dynamic data, String path) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

final _bidJson = <String, dynamic>{
  'id': 'bid-1',
  'announcementId': 'ann-1',
  'senderId': 's-1',
  'status': 'PENDING',
  'createdAt': '2026-11-22T10:00:00Z',
  'updatedAt': '2026-11-22T10:00:00Z',
};

final _threadJson = <String, dynamic>{
  'bidId': 'bid-1',
  'announcementId': 'ann-1',
  'status': 'NEGOTIATING',
  'round': 1,
  'maxRounds': 6,
  'myTurn': false,
  'canCounter': true,
  'currency': 'EUR',
  'proposedGrossEur': 48.5,
};

BidModel _bid() => BidModel.fromJson(_bidJson);

void main() {
  late _MockClient client;
  late _MockDio dio;

  setUpAll(() => registerFallbackValue(BidPaymentMethod.stripe));

  setUp(() {
    client = _MockClient();
    dio = _MockDio();
    when(() => client.dio).thenReturn(dio);
  });

  group('modèles', () {
    test('BidModel : champs de désignation présents', () {
      final bid = BidModel.fromJson({
        ..._bidJson,
        'recipientDesignatedByUsername': true,
        'recipientUsername': 'awa.n',
      });
      expect(bid.recipientDesignatedByUsername, isTrue);
      expect(bid.recipientUsername, 'awa.n');
    });

    test('BidModel : champs absents (ancien back) -> false et null', () {
      final bid = BidModel.fromJson(_bidJson);
      expect(bid.recipientDesignatedByUsername, isFalse);
      expect(bid.recipientUsername, isNull);
    });

    test('UsernameLookup : parcelDesignation présent', () {
      final l = UsernameLookup.fromJson({
        'username': 'awa',
        'initial': 'A',
        'parcelDesignation': true,
      });
      expect(l.parcelDesignation, isTrue);
    });

    test('UsernameLookup : parcelDesignation absent -> false', () {
      final l = UsernameLookup.fromJson({'username': 'awa', 'initial': 'A'});
      expect(l.parcelDesignation, isFalse);
    });
  });

  group('BidRemoteDatasource : corps JSON', () {
    late BidRemoteDatasource ds;
    setUp(() => ds = BidRemoteDatasource(client));

    Map<String, dynamic> body(Invocation i) =>
        i.namedArguments[const Symbol('data')] as Map<String, dynamic>;

    test('checkoutBid avec identifiant : ni nom ni numéro', () async {
      Map<String, dynamic>? sent;
      when(() => dio.post('/bids/checkout', data: any(named: 'data')))
          .thenAnswer((i) async {
            sent = body(i);
            return _ok({
              'bidId': 'b',
              'clientSecret': 's',
              'publishableKey': 'pk',
              'expiresAt': '2030-01-01T00:00:00',
            }, '/bids/checkout');
          });
      await ds.checkoutBid(
        announcementId: 'ann-1',
        weightKg: 2,
        description: 'd',
        contentCategory: 'c',
        recipientUsername: 'awa.n',
      );
      expect(sent!['recipientUsername'], 'awa.n');
      expect(sent!.containsKey('recipientName'), isFalse);
      expect(sent!.containsKey('recipientPhone'), isFalse);
    });

    test('checkoutBid sans identifiant : corps inchangé', () async {
      Map<String, dynamic>? sent;
      when(() => dio.post('/bids/checkout', data: any(named: 'data')))
          .thenAnswer((i) async {
            sent = body(i);
            return _ok({
              'bidId': 'b',
              'clientSecret': 's',
              'publishableKey': 'pk',
              'expiresAt': '2030-01-01T00:00:00',
            }, '/bids/checkout');
          });
      await ds.checkoutBid(
        announcementId: 'ann-1',
        weightKg: 2,
        description: 'd',
        contentCategory: 'c',
        recipientName: 'Fatou',
        recipientPhone: '+221770000000',
      );
      expect(sent!['recipientName'], 'Fatou');
      expect(sent!['recipientPhone'], '+221770000000');
      expect(sent!.containsKey('recipientUsername'), isFalse);
    });

    test('createBid avec / sans identifiant', () async {
      final sent = <Map<String, dynamic>>[];
      when(
        () => dio.post('/announcements/ann-1/bids', data: any(named: 'data')),
      ).thenAnswer((i) async {
        sent.add(body(i));
        return _ok(_bidJson, '/announcements/ann-1/bids');
      });
      await ds.createBid(
        announcementId: 'ann-1',
        weightKg: 2,
        description: 'd',
        contentCategory: 'c',
        recipientUsername: 'awa.n',
      );
      await ds.createBid(
        announcementId: 'ann-1',
        weightKg: 2,
        description: 'd',
        contentCategory: 'c',
        recipientName: 'Fatou',
        recipientPhone: '+221770000000',
      );
      expect(sent[0]['recipientUsername'], 'awa.n');
      expect(sent[0].containsKey('recipientName'), isFalse);
      expect(sent[0].containsKey('recipientPhone'), isFalse);
      expect(sent[1].containsKey('recipientUsername'), isFalse);
      expect(sent[1]['recipientName'], 'Fatou');
    });

    test('changeRecipient avec / sans identifiant', () async {
      final sent = <Map<String, dynamic>>[];
      when(() => dio.put('/bids/bid-1/recipient', data: any(named: 'data')))
          .thenAnswer((i) async {
            sent.add(body(i));
            return _ok(_bidJson, '/bids/bid-1/recipient');
          });
      await ds.changeRecipient('bid-1', recipientUsername: 'awa.n');
      await ds.changeRecipient(
        'bid-1',
        recipientName: 'Awa',
        recipientPhone: '+221781112233',
      );
      expect(sent[0], {'recipientUsername': 'awa.n'});
      expect(sent[1], {
        'recipientName': 'Awa',
        'recipientPhone': '+221781112233',
      });
    });
  });

  group('BidNegotiationRemoteDatasource : corps JSON', () {
    late BidNegotiationRemoteDatasource ds;
    setUp(() => ds = BidNegotiationRemoteDatasource(client));

    Future<Map<String, dynamic>> propose({
      String? name,
      String? phone,
      String? username,
    }) async {
      Map<String, dynamic>? sent;
      when(
        () => dio.post(
          '/announcements/ann-1/bids/negotiation',
          data: any(named: 'data'),
        ),
      ).thenAnswer((i) async {
        sent = i.namedArguments[const Symbol('data')] as Map<String, dynamic>;
        return _ok(_threadJson, '/announcements/ann-1/bids/negotiation');
      });
      await ds.propose(
        announcementId: 'ann-1',
        weightKg: 2,
        description: 'd',
        contentCategory: 'c',
        recipientName: name,
        recipientPhone: phone,
        recipientUsername: username,
        proposedTotalEur: 40,
      );
      return sent!;
    }

    test('avec identifiant : ni nom ni numéro', () async {
      final sent = await propose(username: 'awa.n');
      expect(sent['recipientUsername'], 'awa.n');
      expect(sent.containsKey('recipientName'), isFalse);
      expect(sent.containsKey('recipientPhone'), isFalse);
    });

    test('sans identifiant : corps inchangé', () async {
      final sent = await propose(name: 'Fatou', phone: '+221770000000');
      expect(sent['recipientName'], 'Fatou');
      expect(sent['recipientPhone'], '+221770000000');
      expect(sent.containsKey('recipientUsername'), isFalse);
    });
  });

  group('événements', () {
    test('BidCheckoutRequested / BidCreateRequested : compat et identifiant', () {
      final a = BidCheckoutRequested(
        announcementId: 'a',
        weightKg: 1,
        description: 'd',
        contentCategory: 'c',
        recipientName: 'n',
        recipientPhone: 'p',
      );
      expect(a.recipientName, 'n');
      expect(a.recipientUsername, isNull);
      final b = BidCreateRequested(
        announcementId: 'a',
        weightKg: 1,
        description: 'd',
        contentCategory: 'c',
        recipientUsername: 'awa',
      );
      expect(b.recipientUsername, 'awa');
      expect(b.recipientName, isNull);
    });

    test('BidNegotiationProposeRequested : props contient l\'identifiant', () {
      const a = BidNegotiationProposeRequested(
        announcementId: 'a',
        weightKg: 1,
        description: 'd',
        contentCategory: 'c',
        recipientUsername: 'awa',
        proposedTotalEur: 10,
      );
      const b = BidNegotiationProposeRequested(
        announcementId: 'a',
        weightKg: 1,
        description: 'd',
        contentCategory: 'c',
        recipientUsername: 'bob',
        proposedTotalEur: 10,
      );
      expect(a.recipientUsername, 'awa');
      expect(a == b, isFalse);
    });
  });

  group('BidBloc', () {
    late _MockBidRepo repo;
    setUp(() => repo = _MockBidRepo());

    BidBloc build() =>
        BidBloc(repo, makeDisabledAnalytics(MockAnalyticsBackend()));

    blocTest<BidBloc, dynamic>(
      'checkout transmet l\'identifiant',
      build: () {
        when(
          () => repo.checkoutBid(
            announcementId: any(named: 'announcementId'),
            weightKg: any(named: 'weightKg'),
            description: any(named: 'description'),
            contentCategory: any(named: 'contentCategory'),
            recipientName: any(named: 'recipientName'),
            recipientPhone: any(named: 'recipientPhone'),
            recipientUsername: any(named: 'recipientUsername'),
            photoKeys: any(named: 'photoKeys'),
            gridItems: any(named: 'gridItems'),
          ),
        ).thenAnswer(
          (_) async => BidCheckoutResponseModel(
            bidId: 'b',
            clientSecret: 's',
            publishableKey: 'pk',
            expiresAt: DateTime(2030),
          ),
        );
        return build();
      },
      act: (b) => b.add(
        BidCheckoutRequested(
          announcementId: 'a',
          weightKg: 1,
          description: 'd',
          contentCategory: 'c',
          recipientUsername: 'awa.n',
        ),
      ),
      verify: (_) {
        final c = verify(
          () => repo.checkoutBid(
            announcementId: any(named: 'announcementId'),
            weightKg: any(named: 'weightKg'),
            description: any(named: 'description'),
            contentCategory: any(named: 'contentCategory'),
            recipientName: captureAny(named: 'recipientName'),
            recipientPhone: captureAny(named: 'recipientPhone'),
            recipientUsername: captureAny(named: 'recipientUsername'),
            photoKeys: any(named: 'photoKeys'),
            gridItems: any(named: 'gridItems'),
          ),
        ).captured;
        expect(c, [null, null, 'awa.n']);
      },
    );

    blocTest<BidBloc, dynamic>(
      'création transmet l\'identifiant',
      build: () {
        when(
          () => repo.createBid(
            announcementId: any(named: 'announcementId'),
            weightKg: any(named: 'weightKg'),
            description: any(named: 'description'),
            contentCategory: any(named: 'contentCategory'),
            recipientName: any(named: 'recipientName'),
            recipientPhone: any(named: 'recipientPhone'),
            recipientUsername: any(named: 'recipientUsername'),
            paymentMethod: any(named: 'paymentMethod'),
            countryCode: any(named: 'countryCode'),
            promoCode: any(named: 'promoCode'),
            photoKeys: any(named: 'photoKeys'),
            gridItems: any(named: 'gridItems'),
          ),
        ).thenAnswer((_) async => _bid());
        return build();
      },
      act: (b) => b.add(
        BidCreateRequested(
          announcementId: 'a',
          weightKg: 1,
          description: 'd',
          contentCategory: 'c',
          recipientUsername: 'awa.n',
        ),
      ),
      verify: (_) {
        verify(
          () => repo.createBid(
            announcementId: any(named: 'announcementId'),
            weightKg: any(named: 'weightKg'),
            description: any(named: 'description'),
            contentCategory: any(named: 'contentCategory'),
            recipientName: any(named: 'recipientName'),
            recipientPhone: any(named: 'recipientPhone'),
            recipientUsername: 'awa.n',
            paymentMethod: any(named: 'paymentMethod'),
            countryCode: any(named: 'countryCode'),
            promoCode: any(named: 'promoCode'),
            photoKeys: any(named: 'photoKeys'),
            gridItems: any(named: 'gridItems'),
          ),
        ).called(1);
      },
    );
  });

  group('BidNegotiationBloc', () {
    blocTest<BidNegotiationBloc, dynamic>(
      'proposition transmet l\'identifiant',
      build: () {
        final repo = _MockNegoRepo();
        when(
          () => repo.propose(
            announcementId: any(named: 'announcementId'),
            weightKg: any(named: 'weightKg'),
            description: any(named: 'description'),
            contentCategory: any(named: 'contentCategory'),
            recipientName: any(named: 'recipientName'),
            recipientPhone: any(named: 'recipientPhone'),
            recipientUsername: any(named: 'recipientUsername'),
            proposedTotalEur: any(named: 'proposedTotalEur'),
            paymentMethod: any(named: 'paymentMethod'),
            countryCode: any(named: 'countryCode'),
            photoKeys: any(named: 'photoKeys'),
            customItems: any(named: 'customItems'),
            gridItems: any(named: 'gridItems'),
          ),
        ).thenAnswer((_) async => BidNegotiation.fromJson(_threadJson));
        _negoRepo = repo;
        final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
        return BidNegotiationBloc(repo, analytics, _MockConfig());
      },
      act: (b) => b.add(
        const BidNegotiationProposeRequested(
          announcementId: 'a',
          weightKg: 1,
          description: 'd',
          contentCategory: 'c',
          recipientUsername: 'awa.n',
          proposedTotalEur: 10,
        ),
      ),
      verify: (_) {
        verify(
          () => _negoRepo.propose(
            announcementId: any(named: 'announcementId'),
            weightKg: any(named: 'weightKg'),
            description: any(named: 'description'),
            contentCategory: any(named: 'contentCategory'),
            recipientName: any(named: 'recipientName'),
            recipientPhone: any(named: 'recipientPhone'),
            recipientUsername: 'awa.n',
            proposedTotalEur: any(named: 'proposedTotalEur'),
            paymentMethod: any(named: 'paymentMethod'),
            countryCode: any(named: 'countryCode'),
            photoKeys: any(named: 'photoKeys'),
            customItems: any(named: 'customItems'),
            gridItems: any(named: 'gridItems'),
          ),
        ).called(1);
      },
    );
  });

  group('RecipientChangeCubit', () {
    test('submit avec identifiant : transmis, sans nom ni numéro', () async {
      final repo = _MockBidRepo();
      when(
        () => repo.changeRecipient(
          any(),
          recipientName: any(named: 'recipientName'),
          recipientPhone: any(named: 'recipientPhone'),
          recipientUsername: any(named: 'recipientUsername'),
        ),
      ).thenAnswer((_) async => _bid());
      final cubit = RecipientChangeCubit(
        repo,
        makeDisabledAnalytics(MockAnalyticsBackend()),
      );
      await cubit.submit(_bid(), username: 'awa.n');
      verify(
        () => repo.changeRecipient(
          'bid-1',
          recipientUsername: 'awa.n',
        ),
      ).called(1);
      await cubit.close();
    });
  });
}

late _MockNegoRepo _negoRepo;
