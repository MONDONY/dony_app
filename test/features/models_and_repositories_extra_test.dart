import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/features/app_update/data/datasources/app_update_remote_config_datasource.dart';
import 'package:dony/features/cancellation/data/datasources/cancellation_remote_datasource.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/incident_report/data/datasources/incident_report_remote_datasource.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/matching/data/datasources/announcement_remote_datasource.dart';
import 'package:dony/features/matching/data/models/address_suggestion.dart';
import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_info.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/data/models/price_estimate.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/recording_dio.dart';

class _MockRemoteConfig extends Mock implements FirebaseRemoteConfig {}

void main() {
  group('modèles', () {
    test('TripRescheduleInfo : aller-retour JSON', () {
      final info = TripRescheduleInfo.fromJson(const {
        'id': 'rs-1',
        'reason': 'FLIGHT_CANCELLED',
        'note': 'Vol annulé',
        'previousDepartureDate': '2026-06-01T00:00:00.000Z',
        'previousDepartureTime': '10:00:00',
        'newDepartureDate': '2026-06-03T00:00:00.000Z',
        'newDepartureTime': '12:00',
        'rescheduledAt': '2026-05-30T08:00:00.000Z',
        'decisionPending': true,
        'decisionDeadline': '2026-06-02T18:00:00.000Z',
      });
      final json = info.toJson();
      expect(json['id'], 'rs-1');
      expect(json['reason'], 'FLIGHT_CANCELLED');
      expect(json['note'], 'Vol annulé');
      expect(json['previousDepartureDate'], '2026-06-01T00:00:00.000Z');
      expect(json['previousDepartureTime'], '10:00:00');
      expect(json['newDepartureDate'], '2026-06-03T00:00:00.000Z');
      expect(json['newDepartureTime'], '12:00');
      expect(json['rescheduledAt'], '2026-05-30T08:00:00.000Z');
      expect(json['decisionPending'], isTrue);
      expect(json['decisionDeadline'], '2026-06-02T18:00:00.000Z');
    });

    test('TripRescheduleInfo : dates absentes sérialisées à null', () {
      final json = const TripRescheduleInfo(id: 'x', reason: 'OTHER').toJson();
      expect(json['decisionPending'], isFalse);
      expect(json['newDepartureDate'], isNull);
      expect(json['decisionDeadline'], isNull);
    });

    test('BidPhoto : égalité sur id et url', () {
      const a = BidPhoto(id: 'p1', url: 'https://u/1');
      expect(a, const BidPhoto(id: 'p1', url: 'https://u/1'));
      expect(a.hashCode, const BidPhoto(id: 'p1', url: 'https://u/1').hashCode);
      expect(a, isNot(const BidPhoto(id: 'p1', url: 'https://u/2')));
    });

    test('ContentCategory : égalité, hashCode et toString', () {
      final a = ContentCategory.fromJson(const {
        'code': 'CLOTHING',
        'label': 'Vêtements',
        'emoji': '👕',
      });
      const b = ContentCategory(
        code: 'CLOTHING',
        label: 'Vêtements',
        emoji: '👕',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), 'ContentCategory(CLOTHING, Vêtements, 👕)');
      expect(
        a,
        isNot(
          const ContentCategory(code: 'FOOD', label: 'Vêtements', emoji: '👕'),
        ),
      );
    });

    test('AddressSuggestion : toJson et libellé complet', () {
      final s = AddressSuggestion.fromJson(const {
        'placeId': 'pl1',
        'mainText': '1 rue de Paris',
        'secondaryText': 'Lyon, France',
      });
      expect(s.toJson(), {
        'placeId': 'pl1',
        'mainText': '1 rue de Paris',
        'secondaryText': 'Lyon, France',
      });
      expect(s.fullLabel, '1 rue de Paris, Lyon, France');
    });

    test('PriceEstimate : lecture, devise par défaut et égalité', () {
      final e = PriceEstimate.fromJson(const {
        'lowEur': 30,
        'highEur': 45.5,
        'confidence': 'MEDIUM',
        'sampleSize': 12,
      });
      expect(e.lowEur, 30.0);
      expect(e.confidence, PriceEstimateConfidence.medium);
      expect(e.currency, 'EUR');
      expect(
        e,
        const PriceEstimate(
          lowEur: 30,
          highEur: 45.5,
          confidence: PriceEstimateConfidence.medium,
          sampleSize: 12,
        ),
      );
    });
  });

  group('dépôts', () {
    late RecordingApi api;

    setUp(() => api = RecordingApi());

    test('IncidentReportRepository : photo puis signalement', () async {
      final dir = Directory.systemTemp.createTempSync('incident');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/capture.png')..writeAsBytesSync([1]);
      api.on('POST', '/reports/photos', {'key': 'reports/k.png'});
      api.on('POST', '/reports', {'id': 'rep-1'});
      final repo = IncidentReportRepository(
        IncidentReportRemoteDatasource(api.client),
      );

      expect(await repo.uploadPhoto(file.path), 'reports/k.png');
      final form = api.last.data as FormData;
      expect(form.files.single.value.filename, 'capture.png');

      final id = await repo.submit(
        targetType: IncidentTargetType.message,
        targetId: 'conv-1',
        reason: 'HARASSMENT',
        description: 'Messages insultants',
        photoKeys: const ['reports/k.png'],
        messageId: 'msg-9',
      );
      expect(id, 'rep-1');
      expect(api.last.data, {
        'targetType': 'MESSAGE',
        'targetId': 'conv-1',
        'reason': 'HARASSMENT',
        'description': 'Messages insultants',
        'photoKeys': ['reports/k.png'],
        'messageId': 'msg-9',
      });
    });

    test(
      'CancellationRepository délègue no-show et décision de report',
      () async {
        final repo = CancellationRepository(
          CancellationRemoteDatasource(api.client),
        );
        await repo.reportTravelerNoShow('b1');
        await repo.decideReschedule('b1', keep: false);
        expect(api.requests.map((r) => r.path), [
          '/cancellations/bids/b1/report-traveler-noshow',
          '/cancellations/bids/b1/reschedule-decision',
        ]);
        expect(api.last.data, {'decision': 'WITHDRAW'});
      },
    );

    group('AnnouncementRepository', () {
      late AnnouncementRepository repo;

      setUp(() {
        repo = AnnouncementRepository(AnnouncementRemoteDatasource(api.client));
      });

      test('getTripsSummary transmet la période', () async {
        api.on('GET', '/travelers/me/trips-summary', {
          'activeTrips': 1,
          'kgSold': 4,
          'revenue': 32,
        });
        final s = await repo.getTripsSummary(period: '7d');
        expect(s.revenue, 32.0);
        expect(api.last.queryParameters, {'period': '7d'});
      });

      test('searchAnnouncementsPage transmet tri et page', () async {
        api.on('GET', '/announcements', {
          'content': <dynamic>[],
          'totalElements': 7,
        });
        final page = await repo.searchAnnouncementsPage(
          departureCity: 'Paris',
          sortBy: 'price',
          sortDir: 'desc',
          page: 2,
        );
        expect(page.totalElements, 7);
        expect(page.page, 2);
        final q = api.last.queryParameters;
        expect(q['departureCity'], 'Paris');
        expect(q['sortBy'], 'price');
        expect(q['sortDir'], 'desc');
        expect(q['page'], 2);
      });

      test('rescheduleTrip délègue au datasource', () async {
        api.on('POST', '/announcements/a1/reschedule', {'rescheduleId': 'r'});
        final r = await repo.rescheduleTrip(
          announcementId: 'a1',
          departureDate: DateTime(2026, 6, 3),
          departureTime: '09:00',
          handoverDeadline: DateTime.utc(2026, 6, 2),
          reason: TripRescheduleReason.postponed,
        );
        expect(r.rescheduleId, 'r');
        expect((api.last.data as Map)['reason'], 'POSTPONED');
      });
    });
  });

  test('FirebaseAppUpdateRemoteConfigClient délègue à Remote Config', () async {
    final remoteConfig = _MockRemoteConfig();
    final settings = RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 5),
      minimumFetchInterval: const Duration(hours: 1),
    );
    when(remoteConfig.fetchAndActivate).thenAnswer((_) async => true);
    when(() => remoteConfig.getInt('min_supported_build')).thenReturn(42);
    when(
      () => remoteConfig.setConfigSettings(settings),
    ).thenAnswer((_) async {});

    final client = FirebaseAppUpdateRemoteConfigClient(remoteConfig);

    expect(await client.fetchAndActivate(), isTrue);
    expect(client.getInt('min_supported_build'), 42);
    await client.setConfigSettings(settings);
    verify(() => remoteConfig.setConfigSettings(settings)).called(1);
  });
}
