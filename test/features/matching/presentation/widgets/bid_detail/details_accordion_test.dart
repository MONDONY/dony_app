// Tests ciblés sur les dates de DetailsAccordion (K3) : la date de départ du
// trajet (motif fixe branché par langue, details_accordion.dart:64-73 —
// corrigé en K3 : la locale 'fr_FR' codée en dur devient `locale`) et la date
// limite de dépôt (squelette yMd, déjà correcte, non-régression).
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/details_accordion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

BidModel _bid({DateTime? handoverDeadline, DateTime? departureDate}) =>
    BidModel(
      id: 'bid-001',
      announcementId: 'ann-001',
      senderId: 'sender-001',
      status: 'ACCEPTED',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      handoverDeadline: handoverDeadline,
      departureDate: departureDate,
    );

Widget _host(BidModel bid) => MaterialApp(
  home: Scaffold(body: DetailsAccordion(bid: bid)),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  // Le corps de l'accordéon n'est rendu qu'une fois ouvert.
  Future<void> ouvrir(WidgetTester tester) async {
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'date de départ du trajet fr non-régression (motif EEE dd MMM yyyy '
    'inchangé, locale explicite au lieu de fr_FR)',
    (tester) async {
      final departure = DateTime(2026, 10, 6, 14, 5);
      await tester.pumpWidget(_host(_bid(departureDate: departure)));
      await ouvrir(tester);

      expect(
        find.textContaining(
          DateFormat('EEE dd MMM yyyy', 'fr').format(departure),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('date de départ du trajet en anglais (squelette yMMMEd)', (
    tester,
  ) async {
    useEnglish();
    final departure = DateTime(2026, 10, 6, 14, 5);
    await tester.pumpWidget(_host(_bid(departureDate: departure)));
    await ouvrir(tester);

    expect(
      find.textContaining(DateFormat.yMMMEd('en').format(departure)),
      findsOneWidget,
    );
  });

  testWidgets(
    'date limite de dépôt fr non-régression (squelette yMd inchangé)',
    (tester) async {
      final deadline = DateTime(2026, 10, 6, 14, 5);
      await tester.pumpWidget(_host(_bid(handoverDeadline: deadline)));
      await ouvrir(tester);

      expect(
        find.textContaining(DateFormat.yMd('fr').format(deadline)),
        findsOneWidget,
      );
    },
  );

  testWidgets('date limite de dépôt en anglais (squelette yMd)', (
    tester,
  ) async {
    useEnglish();
    final deadline = DateTime(2026, 10, 6, 14, 5);
    await tester.pumpWidget(_host(_bid(handoverDeadline: deadline)));
    await ouvrir(tester);

    expect(
      find.textContaining(DateFormat.yMd('en').format(deadline)),
      findsOneWidget,
    );
  });
}
