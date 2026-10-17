import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:flutter_test/flutter_test.dart';

GpProStatus parse(Map<String, dynamic> json) => GpProStatus.fromJson(json);

void main() {
  group('GpProStatus.fromJson', () {
    test('lit chaque état wire', () {
      const wires = {
        'NONE': GpProState.none,
        'AWAITING_KYC': GpProState.awaitingKyc,
        'PENDING': GpProState.pending,
        'ACTIVE': GpProState.active,
        'REJECTED': GpProState.rejected,
        'REVOKED': GpProState.revoked,
      };
      wires.forEach((wire, state) {
        final status = parse({'state': wire});
        expect(status.state, state);
        expect(state.wire, wire);
      });
    });

    test('état inconnu ou absent vaut none', () {
      expect(parse({'state': 'FUTUR'}).state, GpProState.none);
      expect(parse(const {}).state, GpProState.none);
      expect(GpProState.fromWire(null), GpProState.none);
    });

    test('documents vaut null quand la clé manque', () {
      final status = parse({'state': 'PENDING'});
      expect(status.documents, isNull);
      expect(status.documentCount, 0);
    });

    test('lit la liste de documents', () {
      final status = parse({
        'state': 'AWAITING_KYC',
        'documentCount': 1,
        'documents': [
          {'id': 'd1', 'type': 'TRAVEL_PROOF'},
        ],
      });
      expect(status.documents, [
        const GpProDocument(id: 'd1', type: GpProDocType.travelProof),
      ]);
      expect(status.documentCount, 1);
    });

    test('lit fréquence, nom, motif et date en heure locale', () {
      final status = parse({
        'state': 'REJECTED',
        'travelFrequency': 'TWICE_A_MONTH',
        'commercialName': 'Awa Express',
        'reason': 'Pièces illisibles',
        'decidedAt': '2026-10-17T10:00:00Z',
      });
      expect(status.travelFrequency, GpProFrequency.twiceAMonth);
      expect(status.commercialName, 'Awa Express');
      expect(status.reason, 'Pièces illisibles');
      expect(status.decidedAt, DateTime.utc(2026, 10, 17, 10).toLocal());
      expect(status.decidedAt!.isUtc, isFalse);
    });

    test('isOpen vrai pour AWAITING_KYC et PENDING seulement', () {
      for (final state in GpProState.values) {
        final open =
            state == GpProState.awaitingKyc || state == GpProState.pending;
        expect(parse({'state': state.wire}).isOpen, open);
      }
    });
  });

  group('enums wire', () {
    test('fréquences', () {
      expect(GpProFrequency.fromWire('WEEKLY'), GpProFrequency.weekly);
      expect(GpProFrequency.fromWire('MONTHLY'), GpProFrequency.monthly);
      expect(GpProFrequency.fromWire('LESS_OFTEN'), GpProFrequency.lessOften);
      expect(GpProFrequency.fromWire('x'), isNull);
      expect(GpProFrequency.fromWire(null), isNull);
    });

    test('types de document et source', () {
      expect(GpProDocType.fromWire('OTHER'), GpProDocType.other);
      expect(
        GpProDocType.fromWire('BUSINESS_REGISTRATION'),
        GpProDocType.businessRegistration,
      );
      expect(GpProDocType.fromWire('x'), GpProDocType.other);
      expect(GpProSource.signup.wire, 'SIGNUP');
      expect(GpProSource.profile.wire, 'PROFILE');
    });
  });
}
