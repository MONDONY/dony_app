import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/parcel_status_pill.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helpers.dart';

void main() {
  final cs = ThemeData.light().colorScheme;

  group('parcelStatusBadge (FLUTTER-EZ)', () {
    test('libellés FR et couleurs sémantiques par statut', () {
      final l = AppL10n.current;
      final cases = <String, (String, Color)>{
        'PENDING': (l.shipmentBadgeWaiting, cs.warning),
        'AWAITING_PAYMENT': (l.shipmentBadgeWaiting, cs.warning),
        'PAYMENT_ESCROWED': (l.shipmentBadgeWaiting, cs.warning),
        'ACCEPTED': (l.shipmentBadgeToHandOver, cs.warning),
        'HANDED_OVER': (l.shipmentBadgeHandedOver, cs.info),
        'IN_TRANSIT': (l.shipmentBadgeInTransit, cs.info),
        'ARRIVED': (l.shipmentBadgeArrived, cs.info),
        'COMPLETED': (l.shipmentBadgeDelivered, cs.success),
        'CANCELLED': (l.shipmentBadgeCancelled, cs.onSurfaceVariant),
        'REJECTED': (l.shipmentBadgeRejected, cs.onSurfaceVariant),
        'NO_SHOW': (l.shipmentBadgeNoShow, cs.onSurfaceVariant),
        'EXPIRED': (l.shipmentBadgeExpired, cs.onSurfaceVariant),
        'PARCEL_REFUSED': (l.shipmentBadgeParcelRefused, cs.onSurfaceVariant),
      };
      cases.forEach((status, expected) {
        final badge = parcelStatusBadge(cs, l, status)!;
        expect(badge.label, expected.$1, reason: status);
        expect(badge.fg, expected.$2, reason: status);
      });
      expect(l.shipmentBadgeInTransit, 'EN TRANSIT');
    });

    test('retour en cours : prime sur le statut, en avertissement', () {
      final l = AppL10n.current;
      final badge = parcelStatusBadge(cs, l, 'CANCELLED', returnPending: true)!;
      expect(badge.label, 'RETOUR EN COURS');
      expect(badge.fg, cs.warning);
      expect(badge.bg, cs.warningLight);
    });

    test('négociation, statut inconnu ou absent : pas de badge', () {
      final l = AppL10n.current;
      expect(parcelStatusBadge(cs, l, 'NEGOTIATING'), isNull);
      expect(parcelStatusBadge(cs, l, 'NEGOTIATION_CLOSED'), isNull);
      expect(parcelStatusBadge(cs, l, 'FUTURE_STATUS'), isNull);
      expect(parcelStatusBadge(cs, l, null), isNull);
    });

    test('anglais', () {
      useEnglish();
      final l = AppL10n.current;
      expect(parcelStatusBadge(cs, l, 'IN_TRANSIT')!.label, 'IN TRANSIT');
      expect(
        parcelStatusBadge(cs, l, 'CANCELLED', returnPending: true)!.label,
        'RETURN PENDING',
      );
    });
  });

  testWidgets('ParcelStatusPill : libellé et variante compacte', (
    tester,
  ) async {
    final badge = (bg: cs.infoLight, fg: cs.info, label: 'EN TRANSIT');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ParcelStatusPill(badge: badge),
              ParcelStatusPill(
                key: const Key('compact'),
                badge: badge,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('EN TRANSIT'), findsNWidgets(2));
    final regular = tester.getSize(find.byType(ParcelStatusPill).first);
    final compact = tester.getSize(find.byKey(const Key('compact')));
    expect(compact.height, lessThan(regular.height));
  });
}
