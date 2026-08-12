import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/matching_request.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

MatchingRequestModel _match() => MatchingRequestModel(
  id: 'r1',
  tripId: 't1',
  tripCorridor: 'Paris → Bamako',
  tripDepartureDate: DateTime(2026, 7, 10),
  tripAvailableKg: 12,
  senderId: 's1',
  senderName: 'Awa Diallo',
  senderInitials: 'AD',
  senderRating: 4.8,
  senderTotalSent: 7,
  weightKg: 3,
  contentType: 'Documents',
  budgetPerKg: 9.5,
  matchScore: 92,
  requestedAt: DateTime(2026, 6, 19),
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr', null);
  });

  testWidgets('renders score, weight, corridor, sender, budget', (t) async {
    await t.pumpWidget(_wrap(MatchingRequestCard(match: _match(), index: 0)));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('92'), findsWidgets); // score badge
    expect(find.textContaining('3'), findsWidgets); // weight kg
    expect(find.textContaining('Paris → Bamako'), findsOneWidget);
    expect(find.text('Awa Diallo'), findsOneWidget);
    expect(find.textContaining('9'), findsWidgets); // budget/kg
  });

  testWidgets('tap fires onTap', (t) async {
    var tapped = false;
    await t.pumpWidget(
      _wrap(
        MatchingRequestCard(
          match: _match(),
          index: 0,
          onTap: () => tapped = true,
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.text('Awa Diallo'), warnIfMissed: false);
    await t.pump();
    expect(tapped, isTrue);
  });
}
