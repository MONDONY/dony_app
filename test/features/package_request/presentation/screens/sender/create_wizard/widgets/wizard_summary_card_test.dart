import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../../../helpers/l10n_test_helpers.dart';

PackageRequestFormState _state() => PackageRequestFormState(
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 10, 6),
  dateToleranceDays: 2,
  transportMode: TransportMode.plane,
  weightKg: 5,
  categories: const ['Vêtements & tissus'],
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('rendu français inchangé', (tester) async {
    await tester.pumpWidget(_wrap(WizardSummaryCard(state: _state())));

    expect(find.text('Trajet'), findsOneWidget);
    expect(find.text('Paris → Dakar'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    // Motif fixe conservé tel quel pour le français — le double point après
    // « oct. » (abréviation du mois + point du motif) est le rendu
    // pré-existant, inchangé par cette migration.
    expect(find.text('6 oct.. 2026 ±2j'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Avion'), findsOneWidget);
    expect(find.text('Colis'), findsOneWidget);
    expect(find.text('5 kg'), findsOneWidget);
    expect(find.text('Contenu'), findsOneWidget);
    expect(find.text('Vêtements & tissus'), findsOneWidget);
  });

  testWidgets('anglais : libellés et date traduits, tolérance sans « j »', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(_wrap(WizardSummaryCard(state: _state())));

    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Oct 6, 2026 ±2d'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Plane'), findsOneWidget);
    expect(find.text('Parcel'), findsOneWidget);
    expect(find.text('5 kg'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
    expect(find.text('Clothing & fabrics'), findsOneWidget);
    expect(find.textContaining('±2j'), findsNothing);
    expect(find.text('Vêtements & tissus'), findsNothing);
  });
}
