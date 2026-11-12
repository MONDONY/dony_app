// Les poids de colis affichés passent tous par `formatWeightKg` : milliers
// groupés (« 1 200 kg »), décimale à la langue (« 2,5 kg » / « 2.5 kg »), et
// les entiers courants d'avion inchangés (« 23 kg »).
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_negotiation_parcel_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_direct_request_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcel_rows.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid(double? kg) => BidModel(
  id: 'bid-00000001',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  senderName: 'Moussa Traoré',
  weightKg: kg,
  contentCategory: 'Vêtements',
  status: 'ACCEPTED',
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('tripRequestDetails', () {
    test('2,5 kg, 1 200 kg et 23 kg (fr)', () {
      expect(tripRequestDetails(fr, _bid(2.5)), endsWith(' · 2,5 kg'));
      expect(tripRequestDetails(fr, _bid(1200)), endsWith(' · 1 200 kg'));
      expect(tripRequestDetails(fr, _bid(23)), endsWith(' · 23 kg'));
    });

    test('2.5 kg et 1,200 kg (en)', () {
      expect(tripRequestDetails(en, _bid(2.5)), endsWith(' · 2.5 kg'));
      expect(tripRequestDetails(en, _bid(1200)), endsWith(' · 1,200 kg'));
    });

    test('poids inconnu : le contenu seul', () {
      expect(tripRequestDetails(fr, _bid(null)), isNot(contains('kg')));
    });
  });

  test('negotiationParcelWeightLabel : fr et en', () {
    expect(negotiationParcelWeightLabel(fr, 2.5), '2,5 kg');
    expect(negotiationParcelWeightLabel(fr, 1200), '1 200 kg');
    expect(negotiationParcelWeightLabel(en, 2.5), '2.5 kg');
    expect(negotiationParcelWeightLabel(en, 1200), '1,200 kg');
    expect(negotiationParcelWeightLabel(fr, 23), '23 kg');
  });

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    testWidgets(
      'ligne d\'un colis du trajet : 1 200 kg (${locale.languageCode})',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripParcelRow(bid: _bid(1200), onTap: () {}),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.textContaining(locale == AppL10n.fr ? '1 200 kg' : '1,200 kg'),
          findsOneWidget,
        );
      },
    );
  }
}
