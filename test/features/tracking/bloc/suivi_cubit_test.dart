import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/bloc/suivi_cubit.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidRepo extends Mock implements BidRepository {}

class _MockTrackingRepo extends Mock implements TrackingRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

BidModel _bid(
  String id,
  String status, {
  String announcementId = 'trip-a',
  String? from,
  String? to,
  String? instructions,
}) => BidModel(
  id: id,
  announcementId: announcementId,
  senderId: 's',
  status: status,
  departureCity: from,
  arrivalCity: to,
  arrivalInstructions: instructions,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

AnnouncementModel _trip(
  String id, {
  String from = 'Paris',
  String to = 'Dakar',
}) => AnnouncementModel(
  id: id,
  travelerId: 't',
  status: 'IN_PROGRESS',
  departureDate: DateTime(2026, 9, 26),
  departureCity: from,
  arrivalCity: to,
  availableKg: 10,
  totalKg: 20,
  pricePerKg: 5,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ScanHubLoaded _hub({
  Map<String, List<BidModel>>? bidsByTrip,
  String selected = 'trip-a',
}) => ScanHubLoaded(
  trips: [
    _trip('trip-a'),
    _trip('trip-b', from: 'Lyon', to: 'Abidjan'),
  ],
  selectedTripId: selected,
  bidsByTrip:
      bidsByTrip ??
      {
        'trip-a': [
          _bid('own-accepted', 'ACCEPTED'),
          _bid('own-done', 'COMPLETED'),
          _bid('own-pending', 'PENDING'),
        ],
        'trip-b': [_bid('other', 'IN_TRANSIT', announcementId: 'trip-b')],
      },
  scanHistory: const [],
);

void main() {
  late _MockBidRepo bidRepo;
  late _MockTrackingRepo trackingRepo;
  late _MockAnalytics analytics;
  late DateTime now;

  setUp(() {
    bidRepo = _MockBidRepo();
    trackingRepo = _MockTrackingRepo();
    analytics = _MockAnalytics();
    now = DateTime(2026, 9, 28, 12);
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => bidRepo.getMyBids()).thenAnswer(
      (_) async => [
        _bid('ship-1', 'IN_TRANSIT', from: 'Paris', to: 'Dakar'),
        _bid('ship-old', 'COMPLETED'),
        _bid('ship-wait', 'PENDING'),
      ],
    );
  });

  SuiviCubit build() =>
      SuiviCubit(bidRepo, trackingRepo, analytics, now: () => now);

  test('suiviModeFromQuery', () {
    expect(suiviModeFromQuery('valider'), SuiviMode.valider);
    expect(suiviModeFromQuery('suivre'), SuiviMode.suivre);
    expect(suiviModeFromQuery('autre'), isNull);
    expect(suiviModeFromQuery(null), isNull);
  });

  group('start', () {
    blocTest<SuiviCubit, SuiviState>(
      'non voyageur : Suivre, envois en cours chargés (filtre kEnvoisEnCours)',
      build: build,
      act: (c) => c.start(canValidate: false),
      expect: () => [
        isA<SuiviState>()
            .having((s) => s.mode, 'mode', SuiviMode.suivre)
            .having((s) => s.canValidate, 'canValidate', false),
        isA<SuiviState>().having(
          (s) => s.shipmentsStatus,
          'status',
          SuiviLoadStatus.loading,
        ),
        isA<SuiviState>()
            .having((s) => s.shipmentsStatus, 'status', SuiviLoadStatus.loaded)
            .having((s) => s.shipments.map((b) => b.id), 'ids', ['ship-1']),
      ],
    );

    blocTest<SuiviCubit, SuiviState>(
      'voyageur sans mode demandé : le mode attend ses trajets',
      build: build,
      act: (c) => c.start(canValidate: true),
      expect: () => [
        isA<SuiviState>()
            .having((s) => s.mode, 'mode', isNull)
            .having((s) => s.canValidate, 'canValidate', true),
      ],
      verify: (_) => verifyNever(() => bidRepo.getMyBids()),
    );

    blocTest<SuiviCubit, SuiviState>(
      'voyageur avec ?mode=suivre : Suivre tout de suite',
      build: build,
      act: (c) => c.start(canValidate: true, requested: SuiviMode.suivre),
      verify: (c) {
        expect(c.state.mode, SuiviMode.suivre);
        verify(() => bidRepo.getMyBids()).called(1);
      },
    );

    blocTest<SuiviCubit, SuiviState>(
      'échec du chargement des envois → erreur, puis Réessayer',
      build: () {
        when(() => bidRepo.getMyBids()).thenThrow(Exception('offline'));
        return build();
      },
      act: (c) async {
        c.start(canValidate: false);
        await Future<void>.delayed(Duration.zero);
        when(() => bidRepo.getMyBids()).thenAnswer((_) async => []);
        await c.loadShipments();
      },
      verify: (c) {
        expect(c.state.shipmentsStatus, SuiviLoadStatus.loaded);
        expect(c.state.shipments, isEmpty);
      },
    );
  });

  group('resolveDefaultMode', () {
    SuiviCubit traveler() => build()..start(canValidate: true);

    test('colis à valider → Valider', () {
      final c = traveler()..resolveDefaultMode(_hub());
      expect(c.state.mode, SuiviMode.valider);
    });

    test('rien à valider → Suivre', () {
      final c = traveler()
        ..resolveDefaultMode(
          _hub(
            bidsByTrip: {
              'trip-a': [_bid('done', 'COMPLETED')],
            },
          ),
        );
      expect(c.state.mode, SuiviMode.suivre);
    });

    test('aucun trajet → Suivre ; erreur → Valider ; chargement → rien', () {
      expect(
        (traveler()..resolveDefaultMode(const ScanHubEmpty())).state.mode,
        SuiviMode.suivre,
      );
      expect(
        (traveler()..resolveDefaultMode(
              ScanHubError(unwrapDioError(Exception('offline'))),
            ))
            .state
            .mode,
        SuiviMode.valider,
      );
      expect(
        (traveler()..resolveDefaultMode(const ScanHubLoading())).state.mode,
        isNull,
      );
    });

    test('mode déjà fixé ou non voyageur : sans effet', () {
      final c = build()
        ..start(canValidate: true, requested: SuiviMode.suivre)
        ..resolveDefaultMode(_hub());
      expect(c.state.mode, SuiviMode.suivre);

      final sender = build()
        ..start(canValidate: false)
        ..resolveDefaultMode(_hub());
      expect(sender.state.mode, SuiviMode.suivre);
    });
  });

  group('selectMode / applyRequestedMode', () {
    test('selectMode trace suivi_mode_changed', () {
      final c = build()
        ..start(canValidate: true, requested: SuiviMode.valider)
        ..selectMode(SuiviMode.suivre);
      expect(c.state.mode, SuiviMode.suivre);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.suiviModeChanged,
          properties: {'mode': 'suivre'},
        ),
      ).called(1);
      // Même mode : rien de plus.
      c.selectMode(SuiviMode.suivre);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.suiviModeChanged,
          properties: {'mode': 'valider'},
        ),
      );
    });

    test('selectMode sans effet pour un non-voyageur', () {
      final c = build()
        ..start(canValidate: false)
        ..selectMode(SuiviMode.valider);
      expect(c.state.mode, SuiviMode.suivre);
    });

    test('applyRequestedMode bascule sans tracer', () {
      final c = build()
        ..start(canValidate: true, requested: SuiviMode.suivre)
        ..applyRequestedMode(SuiviMode.valider)
        ..applyRequestedMode(null);
      expect(c.state.mode, SuiviMode.valider);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.suiviModeChanged,
          properties: any(named: 'properties'),
        ),
      );
    });
  });

  group('onQrScanned en mode Valider', () {
    SuiviCubit validating() =>
        build()..start(canValidate: true, requested: SuiviMode.valider);

    void expectQrLogged(String outcome) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.suiviQrScanned,
        properties: {'mode': 'valider', 'outcome': outcome},
      ),
    ).called(1);

    test('colis du trajet affiché → étape suivante', () {
      final c = validating()..onQrScanned('own-accepted', _hub());
      final effect = c.state.effect;
      expect(effect, isA<SuiviValidateStep>());
      expect((effect! as SuiviValidateStep).step, 'DEPART');
      expect(c.state.busy, isTrue);
      expectQrLogged('own_trip');
    });

    test('colis du trajet déjà livré → toutes les étapes faites', () {
      final c = validating()..onQrScanned('own-done', _hub());
      expect(c.state.effect, isA<SuiviStepsAllDone>());
      expectQrLogged('own_trip');
    });

    test('colis sur un autre trajet chargé', () {
      final c = validating()..onQrScanned('other', _hub());
      final effect = c.state.effect! as SuiviParcelOnOtherTrip;
      expect(effect.trip.id, 'trip-b');
      expect(effect.bid.id, 'other');
      expectQrLogged('other_trip');
    });

    test('colis inconnu (ou non confirmé) → suivre seulement', () {
      final c = validating()..onQrScanned('own-pending', _hub());
      expect(c.state.effect, isA<SuiviParcelUnknown>());
      expectQrLogged('unknown');
    });

    test('anti-rafale : ignoré pendant un traitement', () {
      final c = validating()..onQrScanned('own-accepted', _hub());
      final id = c.state.effectId;
      c.onQrScanned('other', _hub());
      expect(c.state.effectId, id);
    });

    test('même colis juste après la fermeture : ignoré, puis accepté', () {
      final c = validating()
        ..onQrScanned('own-accepted', _hub())
        ..releaseScan();
      expect(c.state.busy, isFalse);
      final id = c.state.effectId;

      c.onQrScanned('own-accepted', _hub());
      expect(c.state.effectId, id);

      // Un autre colis passe tout de suite.
      c.onQrScanned('own-done', _hub());
      expect(c.state.effectId, id + 1);
      c.releaseScan();

      now = now.add(SuiviCubit.rescanCooldown);
      c.onQrScanned('own-done', _hub());
      expect(c.state.effectId, id + 2);
    });
  });

  group('suivre un colis', () {
    test('QR en mode Suivre → parcours en lecture seule', () async {
      final c = build()..start(canValidate: false);
      await Future<void>.delayed(Duration.zero);
      c.onQrScanned('ship-1', null);
      final effect = c.state.effect! as SuiviShowTimeline;
      expect(effect.bidId, 'ship-1');
      expect(effect.corridor, 'Paris → Dakar');
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.suiviQrScanned,
          properties: {'mode': 'suivre', 'outcome': 'unknown'},
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.suiviTrackSubmitted,
          properties: {'source': 'qr'},
        ),
      ).called(1);
    });

    test('QR d\'un colis du voyageur en mode Suivre : corridor du trajet', () {
      final c = build()
        ..start(canValidate: true, requested: SuiviMode.suivre)
        ..onQrScanned('other', _hub());
      final effect = c.state.effect! as SuiviShowTimeline;
      expect(effect.corridor, 'Lyon → Abidjan');
    });

    test('QR inconnu : corridor vide', () {
      final c = build()
        ..start(canValidate: true, requested: SuiviMode.suivre)
        ..onQrScanned('nowhere', _hub());
      expect((c.state.effect! as SuiviShowTimeline).corridor, isEmpty);
    });

    test('followParcel bascule en Suivre et ouvre le parcours', () {
      final c = build()
        ..start(canValidate: true, requested: SuiviMode.valider)
        ..onQrScanned('nowhere', _hub())
        ..followParcel('nowhere');
      expect(c.state.mode, SuiviMode.suivre);
      expect(c.state.effect, isA<SuiviShowTimeline>());
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.suiviModeChanged,
          properties: {'mode': 'suivre'},
        ),
      ).called(1);
    });

    test('trackShipment → parcours, source my_shipments', () async {
      final c = build()..start(canValidate: false);
      await Future<void>.delayed(Duration.zero);
      c.trackShipment(c.state.shipments.single);
      expect((c.state.effect! as SuiviShowTimeline).bidId, 'ship-1');
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.suiviTrackSubmitted,
          properties: {'source': 'my_shipments'},
        ),
      ).called(1);
      // Occupé : un second tap est ignoré.
      final id = c.state.effectId;
      c.trackShipment(c.state.shipments.single);
      expect(c.state.effectId, id);
    });

    test('trackNumber trouve le colis et ouvre son parcours', () async {
      when(() => trackingRepo.searchByTrackingNumber('DON-ABC123')).thenAnswer(
        (_) async => const TrackingSearchModel(
          trackingNumber: 'DON-ABC123',
          bidId: 'bid-9',
          departureCity: 'Marseille',
          arrivalCity: 'Bamako',
          currentStep: 'IN_TRANSIT',
          stepLabel: 'En transit',
          paymentStatus: 'ESCROWED',
          arrivalInstructions: 'Gare routière',
        ),
      );
      final c = build()..start(canValidate: false);
      await c.trackNumber('  don-abc123 ');
      final effect = c.state.effect! as SuiviShowTimeline;
      expect(effect.bidId, 'bid-9');
      expect(effect.corridor, 'Marseille → Bamako');
      expect(effect.arrivalInstructions, 'Gare routière');
      expect(c.state.searchStatus, SuiviLoadStatus.idle);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.suiviTrackSubmitted,
          properties: {'source': 'number'},
        ),
      ).called(1);
    });

    test('trackNumber : numéro introuvable → erreur, vide → rien', () async {
      when(
        () => trackingRepo.searchByTrackingNumber(any()),
      ).thenThrow(Exception('404'));
      final c = build()..start(canValidate: false);
      await c.trackNumber('   ');
      verifyNever(() => trackingRepo.searchByTrackingNumber(any()));

      await c.trackNumber('DON-NOPE');
      expect(c.state.searchStatus, SuiviLoadStatus.error);
      expect(c.state.searchError, isNotNull);
      expect(c.state.busy, isFalse);
    });

    test('holdScans met les scans en pause jusqu\'à releaseScan', () {
      final c = build()
        ..start(canValidate: true, requested: SuiviMode.valider)
        ..holdScans();
      expect(c.state.busy, isTrue);
      c.onQrScanned('own-accepted', _hub());
      expect(c.state.effect, isNull);
      c.releaseScan();
      expect(c.state.busy, isFalse);
    });
  });
}
