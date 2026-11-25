import 'package:dony/features/video_modal/data/datasources/video_modal_remote_datasource.dart';
import 'package:dony/features/video_modal/data/models/parcel_role.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video_modal_test_data.dart';

void main() {
  group('modals d\'étape de colis', () {
    test('les 5 déclencheurs PARCEL_* sont lus, ce sont des moments', () {
      const wires = {
        'PARCEL_ACCEPTED': VideoModalTrigger.parcelAccepted,
        'PARCEL_HANDED_OVER': VideoModalTrigger.parcelHandedOver,
        'PARCEL_IN_TRANSIT': VideoModalTrigger.parcelInTransit,
        'PARCEL_ARRIVED': VideoModalTrigger.parcelArrived,
        'PARCEL_DELIVERED': VideoModalTrigger.parcelDelivered,
      };
      wires.forEach((wire, trigger) {
        final c = VideoModalCampaign.tryParse(
          campaignJson(triggers: [wire]),
        )!;
        expect(c.triggers, {trigger});
        expect(trigger.isParcelStep, isTrue);
        expect(trigger.isMoment, isTrue);
        expect(trigger.usesCorridors, isFalse);
      });
      expect(VideoModalTrigger.deliveryConfirmed.isParcelStep, isFalse);
      expect(VideoModalTrigger.searchTab.isParcelStep, isFalse);
    });

    test('campaign_parsesParcelRoles', () {
      final c = VideoModalCampaign.tryParse(
        campaignJson(
          triggers: ['PARCEL_ACCEPTED'],
          extra: {
            'parcelRoles': ['SENDER', 'RECIPIENT'],
          },
        ),
      )!;
      expect(c.parcelRoles, {ParcelRole.sender, ParcelRole.recipient});
    });

    test('parcelRoles absent, null ou vide : ensemble vide (tous)', () {
      for (final extra in <Map<String, Object?>>[
        {},
        {'parcelRoles': null},
        {'parcelRoles': <String>[]},
        {'parcelRoles': 'SENDER'},
      ]) {
        final c = VideoModalCampaign.tryParse(
          campaignJson(triggers: ['PARCEL_ARRIVED'], extra: extra),
        )!;
        expect(c.parcelRoles, isEmpty);
      }
    });

    test('un rôle inconnu est ignoré, les autres restent', () {
      final c = VideoModalCampaign.tryParse(
        campaignJson(
          triggers: ['PARCEL_ARRIVED'],
          extra: {
            'parcelRoles': ['TRAVELER', 'COURIER', 42, null],
          },
        ),
      )!;
      expect(c.parcelRoles, {ParcelRole.traveler});
    });

    test('ParcelRole.fromWire', () {
      expect(ParcelRole.fromWire('SENDER'), ParcelRole.sender);
      expect(ParcelRole.fromWire('TRAVELER'), ParcelRole.traveler);
      expect(ParcelRole.fromWire('RECIPIENT'), ParcelRole.recipient);
      expect(ParcelRole.fromWire('ADMIN'), isNull);
      expect(ParcelRole.fromWire(null), isNull);
      expect(ParcelRole.sender.wire, 'SENDER');
    });

    test('campaign_unknownTriggerIgnoredNotThrown', () {
      // Seul déclencheur inconnu : campagne ignorée, sans exception.
      expect(
        VideoModalCampaign.tryParse(
          campaignJson(triggers: ['PARCEL_TELEPORTED']),
        ),
        isNull,
      );
      // Mêlé à un connu : seul l'inconnu tombe.
      final c = VideoModalCampaign.tryParse(
        campaignJson(triggers: ['PARCEL_TELEPORTED', 'PARCEL_DELIVERED']),
      )!;
      expect(c.triggers, {VideoModalTrigger.parcelDelivered});
    });

    test('campaign_oncePerParcelParsed', () {
      final c = VideoModalCampaign.tryParse(
        campaignJson(
          triggers: ['PARCEL_ACCEPTED'],
          extra: {'frequency': 'ONCE_PER_PARCEL'},
        ),
      )!;
      expect(c.frequency, VideoModalFrequency.oncePerParcel);
      expect(VideoModalFrequency.oncePerParcel.wire, 'ONCE_PER_PARCEL');
      // Pas de plafond local : le back compte par colis.
      expect(c.displayCap, isNull);
      expect(c.underDisplayCap, isTrue);
    });

    test('fréquence inconnue : campagne ignorée sans exception', () {
      expect(
        VideoModalCampaign.tryParse(
          campaignJson(extra: {'frequency': 'ONCE_PER_GALAXY'}),
        ),
        isNull,
      );
    });

    test('les 4 écrans de colis sont lus, avec contexte colis requis', () {
      const wires = {
        'PARCEL_DETAIL': InfoScreen.parcelDetail,
        'PARCEL_QR': InfoScreen.parcelQr,
        'PARCEL_SEND_CODE': InfoScreen.parcelSendCode,
        'PARCEL_TRACKING': InfoScreen.parcelTracking,
      };
      wires.forEach((wire, screen) {
        final c = VideoModalCampaign.tryParse(
          infoJson(
            triggers: ['PARCEL_ACCEPTED'],
            primaryAction: {'kind': 'SCREEN', 'screen': wire},
          ),
        )!;
        expect(c.primaryAction, VideoModalAction.openScreen(screen));
        expect(screen.needsParcelContext, isTrue);
        expect(screen.isShellTab, isFalse);
      });
      expect(InfoScreen.myMoney.needsParcelContext, isFalse);
    });

    test('campaign_unknownInfoScreenIgnored', () {
      expect(
        VideoModalCampaign.tryParse(
          infoJson(
            primaryAction: {'kind': 'SCREEN', 'screen': 'PARCEL_HOLOGRAM'},
          ),
        ),
        isNull,
      );
      expect(
        VideoModalAction.tryParse({'kind': 'SCREEN', 'screen': 'NOPE'}),
        isNull,
      );
    });

    test('caps_containsParcel', () {
      expect(VideoModalRemoteDatasource.caps, contains('parcel'));
      expect(
        VideoModalRemoteDatasource.caps,
        'layout,targeting,moments,everytime,parcel',
      );
    });
  });
}
