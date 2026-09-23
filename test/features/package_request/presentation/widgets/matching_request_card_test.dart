import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/matching_request.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/l10n_test_helpers.dart';

MatchingRequestModel _match({int senderTotalSent = 7, String? contentType}) =>
    MatchingRequestModel(
      id: 'r1',
      tripId: 't1',
      tripCorridor: 'Paris → Bamako',
      tripDepartureDate: DateTime(2026, 7, 10),
      tripAvailableKg: 12,
      senderId: 's1',
      senderName: 'Awa Diallo',
      senderInitials: 'AD',
      senderRating: 4.8,
      senderTotalSent: senderTotalSent,
      weightKg: 3,
      contentType: contentType ?? 'Documents',
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
    await initializeDateFormatting('fr');
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

  // Le nombre d'envois de l'expéditeur accordait toujours au pluriel avant
  // la migration i18n (« 1 envois ») : le nouveau message ICU corrige cette
  // faute d'accord — décision du contrôleur, signalée dans la PR.
  testWidgets('accord du nombre d\'envois : singulier à 1, pluriel à 3', (
    t,
  ) async {
    await t.pumpWidget(
      _wrap(MatchingRequestCard(match: _match(senderTotalSent: 1), index: 0)),
    );
    await t.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('1 envoi'), findsOneWidget);
    expect(find.textContaining('1 envois'), findsNothing);

    await t.pumpWidget(
      _wrap(MatchingRequestCard(match: _match(senderTotalSent: 3), index: 0)),
    );
    await t.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('3 envois'), findsOneWidget);
  });

  testWidgets('en anglais : nombre d\'envois traduit', (t) async {
    useEnglish();
    await t.pumpWidget(
      _wrap(MatchingRequestCard(match: _match(senderTotalSent: 3), index: 0)),
    );
    await t.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('3 shipments'), findsOneWidget);
    expect(find.textContaining('3 envois'), findsNothing);
  });

  testWidgets(
    'en anglais : catégorie « Vêtements & tissus » devient « Clothing & fabrics »',
    (t) async {
      useEnglish();
      await t.pumpWidget(
        _wrap(
          MatchingRequestCard(
            match: _match(contentType: 'Vêtements & tissus'),
            index: 0,
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('Clothing & fabrics'), findsOneWidget);
      expect(find.textContaining('Vêtements'), findsNothing);
    },
  );
}
