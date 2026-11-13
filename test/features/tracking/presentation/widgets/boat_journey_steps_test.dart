import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:dony/features/tracking/data/models/trip_milestones.dart';
import 'package:dony/features/tracking/presentation/widgets/journey_timeline.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

TrackingEventModel _event(String type, DateTime at) => TrackingEventModel(
  id: 'evt-$type',
  bidId: 'bid-1',
  eventType: type,
  scannedAt: at,
  createdAt: at,
  scanMethod: ScanMethod.qr,
);

/// Trajet Le Havre → Abidjan : départ le 2 déc., arrivée estimée du 11 au
/// 18 janv. ; « maintenant » le 20 nov., avant le départ.
final _now = DateTime(2026, 11, 20, 10);
final _milestones = TripMilestones(
  departureDate: DateTime(2026, 12, 2),
  departureAt: DateTime(2026, 12, 2, 18),
  arrivalDate: DateTime(2027, 1, 11),
  arrivalDateMax: DateTime(2027, 1, 18),
);
final _deposit = _event('DEPART', DateTime(2026, 11, 26, 14, 10));

final _delay = TripDelayInfo(
  reason: 'PORT_CONGESTION',
  arrivalDate: DateTime(2027, 1, 16),
  arrivalDateMax: DateTime(2027, 1, 23),
  message: 'Attente au port de Tanger Med',
  announcedAt: DateTime(2026, 12, 20),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  List<(JourneyStepState, String, String?)> rows(List<JourneyStep> steps) => [
    for (final s in steps) (s.state, s.title, s.detail),
  ];

  List<JourneyStep> boat(
    List<TrackingEventModel> events, {
    String? status,
    TripMilestones? milestones,
    DateTime? now,
    String arrival = 'Abidjan',
  }) => boatJourneySteps(
    fr,
    events,
    bidStatus: status,
    milestones: milestones ?? _milestones,
    departureCity: 'Le Havre',
    arrivalCity: arrival,
    now: now ?? _now,
  );

  group('boatTimeline_labels', () {
    test('pas encore déposé : dépôt en cours, jalons du trajet à venir', () {
      expect(rows(boat(const [], status: 'ACCEPTED')), [
        (JourneyStepState.current, "Dépôt à l'entrepôt", 'Le Havre'),
        (JourneyStepState.upcoming, 'Départ du bateau', 'Prévu le 2 déc.'),
        (
          JourneyStepState.upcoming,
          "Arrivé au port d'Abidjan",
          'Estimé du 11 janv. 2027 au 18 janv. 2027',
        ),
        (JourneyStepState.upcoming, 'Remise au destinataire', null),
      ]);
      final progress = boatJourneyProgress(
        const [],
        bidStatus: 'ACCEPTED',
        milestones: _milestones,
        now: _now,
      );
      expect(
        boatJourneyHeadline(fr, progress, 'Abidjan'),
        "En attente du dépôt à l'entrepôt",
      );
    });

    test('déposé, bateau pas parti : le départ devient l\'étape en cours', () {
      final steps = boat([_deposit], status: 'HANDED_OVER');
      expect(rows(steps).take(2), [
        (JourneyStepState.done, "Déposé à l'entrepôt", null),
        (JourneyStepState.current, 'Départ du bateau', 'Prévu le 2 déc.'),
      ]);
      expect(steps.first.event, same(_deposit));
      final progress = boatJourneyProgress(
        [_deposit],
        bidStatus: 'HANDED_OVER',
        milestones: _milestones,
        now: _now,
      );
      expect(
        boatJourneyHeadline(fr, progress, 'Abidjan'),
        "Déposé à l'entrepôt",
      );
    });

    test(
      'bateau parti (date passée) : jalon fait, en mer, arrivée estimée',
      () {
        final steps = boat(
          [_deposit],
          status: 'HANDED_OVER',
          now: DateTime(2026, 12, 10),
        );
        expect(rows(steps), [
          (JourneyStepState.done, "Déposé à l'entrepôt", null),
          (JourneyStepState.done, 'Bateau parti', 'Le Havre'),
          (JourneyStepState.current, 'En mer', null),
          (
            JourneyStepState.upcoming,
            "Arrivé au port d'Abidjan",
            'Estimé du 11 janv. 2027 au 18 janv. 2027',
          ),
          (JourneyStepState.upcoming, 'Remise au destinataire', null),
        ]);
        // Jalon du trajet : le jour du départ prévu, sans heure.
        expect(steps[1].at, DateTime(2026, 12, 2));
        expect(steps[1].dateOnly, isTrue);
        final progress = boatJourneyProgress(
          [_deposit],
          bidStatus: 'HANDED_OVER',
          milestones: _milestones,
          now: DateTime(2026, 12, 10),
        );
        expect(
          boatJourneyHeadline(fr, progress, 'Abidjan'),
          'En mer vers Abidjan',
        );
        expect(boatJourneyHeadline(fr, progress, null), 'En mer');
      },
    );

    test('retard annoncé : texte du retard en mer, nouvelle fourchette', () {
      final steps = boat(
        [_deposit],
        status: 'HANDED_OVER',
        milestones: TripMilestones(
          departureDate: DateTime(2026, 12, 2),
          arrivalDate: DateTime(2027, 1, 11),
          arrivalDateMax: DateTime(2027, 1, 18),
          latestDelay: _delay,
        ),
      );
      final atSea = steps.firstWhere((s) => s.title == 'En mer');
      expect(atSea.state, JourneyStepState.current);
      expect(atSea.detail, 'Retard annoncé : Attente au port de Tanger Med');
      final port = steps.firstWhere(
        (s) => s.title == "Arrivé au port d'Abidjan",
      );
      expect(port.detail, 'Estimé du 16 janv. 2027 au 23 janv. 2027');
    });

    test('retard sans message : son motif', () {
      final steps = boat(
        [_deposit],
        milestones: TripMilestones(
          latestDelay: TripDelayInfo(
            reason: 'WEATHER',
            arrivalDate: DateTime(2027, 1, 16),
            arrivalDateMax: DateTime(2027, 1, 16),
            announcedAt: DateTime(2026, 12, 20),
          ),
        ),
      );
      expect(
        steps.firstWhere((s) => s.title == 'En mer').detail,
        'Retard annoncé : Météo',
      );
      expect(
        steps.firstWhere((s) => s.title.startsWith('Arrivé au port')).detail,
        'Estimé le 16 janv. 2027',
      );
    });

    test('transit scanné : après le départ du bateau, sans date passée', () {
      final transit = _event('TRANSIT', DateTime(2026, 11, 28, 9));
      final steps = boat([transit, _deposit], status: 'IN_TRANSIT');
      expect(steps.map((s) => s.title).take(4), [
        "Déposé à l'entrepôt",
        'Bateau parti',
        'Transit',
        'En mer',
      ]);
    });

    test(
      'trajet marqué arrivé : port fait (sans élision), remise en cours',
      () {
        final steps = boat([_deposit], status: 'ARRIVED', arrival: 'Dakar');
        expect(rows(steps).skip(2), [
          (JourneyStepState.done, 'Arrivé au port de Dakar', null),
          (JourneyStepState.current, 'Remise au destinataire', null),
        ]);
        expect(steps.any((s) => s.title == 'En mer'), isFalse);
        final progress = boatJourneyProgress(
          [_deposit],
          bidStatus: 'ARRIVED',
          now: _now,
        );
        expect(
          boatJourneyHeadline(fr, progress, 'Dakar'),
          'Arrivé au port de Dakar',
        );
      },
    );

    test('remis au destinataire : toutes les étapes faites', () {
      final delivered = _event('ARRIVEE', DateTime(2027, 1, 20, 11));
      final steps = boat([delivered, _deposit], status: 'COMPLETED');
      expect(steps.every((s) => s.state == JourneyStepState.done), isTrue);
      expect(steps.last.title, 'Remis au destinataire');
      final progress = boatJourneyProgress([delivered, _deposit], now: _now);
      expect(
        boatJourneyHeadline(fr, progress, 'Abidjan'),
        'Colis remis au destinataire',
      );
    });

    test('sans jalons (colis lu par QR) : ni date ni estimation', () {
      final steps = boatJourneySteps(fr, const [], now: _now);
      expect(rows(steps), [
        (JourneyStepState.current, "Dépôt à l'entrepôt", null),
        (JourneyStepState.upcoming, 'Départ du bateau', null),
        (JourneyStepState.upcoming, 'Arrivé au port', null),
        (JourneyStepState.upcoming, 'Remise au destinataire', null),
      ]);
    });

    test('en anglais', () {
      final steps = boatJourneySteps(
        en,
        [_deposit],
        milestones: TripMilestones(
          departureDate: DateTime(2026, 12, 2),
          latestDelay: _delay,
        ),
        departureCity: 'Le Havre',
        arrivalCity: 'Abidjan',
        now: _now,
      );
      expect(steps.map((s) => s.title), [
        'Dropped off at the warehouse',
        'Ship departed',
        'At sea',
        'Arrived at the port of Abidjan',
        'Handover to the recipient',
      ]);
      expect(steps[2].detail, 'Delay announced: Attente au port de Tanger Med');
      expect(steps[3].detail, 'Estimated Jan 16, 2027 to Jan 23, 2027');
      final progress = boatJourneyProgress(
        [_deposit],
        milestones: TripMilestones(latestDelay: _delay),
        now: _now,
      );
      expect(
        boatJourneyHeadline(en, progress, 'Abidjan'),
        'At sea, bound for Abidjan',
      );
    });

    test('aucun mot d\'avion, ni « voyageur » pour le dépôt', () {
      final all = [
        ...boat(const []),
        ...boat([_deposit], now: DateTime(2026, 12, 10)),
        ...boat([_deposit], status: 'ARRIVED'),
      ];
      for (final s in all) {
        final text = '${s.title} ${s.detail ?? ''}'.toLowerCase();
        for (final word in [
          'vol',
          'aéroport',
          'escale',
          'valise',
          'voyageur',
        ]) {
          expect(text, isNot(contains(word)), reason: s.title);
        }
      }
    });
  });

  group('compactJourneySteps selon le mode', () {
    final tracking = TravelerTrackingModel(
      status: TravelerTrackingStatus.arrived,
      history: [
        TravelerTrackingPoint(city: 'Tanger', at: DateTime(2026, 12, 5)),
      ],
    );

    test('bateau : dépôt et arrivée au port', () {
      final steps = compactJourneySteps(
        fr,
        [_deposit],
        tracking: tracking,
        now: _now,
        arrived: true,
        mode: TransportMode.boat,
        arrivalCity: 'Abidjan',
      );
      expect(steps.first.title, "Déposé à l'entrepôt");
      expect(steps.last.title, "Arrivé au port d'Abidjan");
    });

    test('bateau : jamais les villes du téléphone du transporteur', () {
      final steps = compactJourneySteps(
        fr,
        [_deposit],
        tracking: tracking,
        now: _now,
        mode: TransportMode.boat,
        arrivalCity: 'Abidjan',
      );
      expect(steps.where((s) => s.state == JourneyStepState.position), isEmpty);
    });

    test('route : les villes approximatives restent dans la frise', () {
      final steps = compactJourneySteps(
        fr,
        [_deposit],
        tracking: tracking,
        now: _now,
        mode: TransportMode.car,
        arrivalCity: 'Dakar',
      );
      expect(
        steps.where((s) => s.state == JourneyStepState.position),
        hasLength(1),
      );
    });

    test('route : libellés neutres inchangés', () {
      final steps = compactJourneySteps(
        fr,
        [_deposit],
        tracking: tracking,
        now: _now,
        arrived: true,
        mode: TransportMode.car,
        arrivalCity: 'Dakar',
      );
      expect(steps.first.title, 'Remis au voyageur');
      expect(steps.last.title, 'Arrivé à destination');
    });
  });
}
