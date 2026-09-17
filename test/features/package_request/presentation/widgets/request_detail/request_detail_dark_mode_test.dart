import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_status_pill.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_ticket_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Vérifie que la pastille de statut et le billet sans photo lisent leurs
/// couleurs dans le thème (ColorScheme) plutôt que des primitives figées :
/// sous `AppTheme.dark()`, elles doivent afficher les couleurs SOMBRES du
/// design system, distinctes des primitives claires historiquement en dur.
void main() {
  setUpAll(() {
    // Comme test/core/design/theme/app_theme_test.dart : AppTheme.X() charge
    // des polices via google_fonts, à appeler uniquement depuis un
    // testWidgets (zone d'erreurs gérée), jamais depuis setUpAll lui-même.
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    initializeDateFormatting('fr');
  });

  Widget wrapDark(Widget child) =>
      MaterialApp(theme: AppTheme.dark(), home: Scaffold(body: Center(child: child)));

  testWidgets('RequestStatusPill (succès) : couleurs du thème sombre', (tester) async {
    final darkCs = AppTheme.dark().colorScheme;
    await tester.pumpWidget(wrapDark(
      const RequestStatusPill(screenCase: RequestScreenCase.accepted),
    ));

    final bg = tester
        .widget<Container>(find.descendant(of: find.byType(RequestStatusPill), matching: find.byType(Container)).first)
        .decoration as BoxDecoration;
    final label = tester.widget<Text>(find.descendant(of: find.byType(RequestStatusPill), matching: find.byType(Text)).first);

    expect(bg.color, darkCs.successLight);
    expect(label.style?.color, darkCs.success);
    // Preuve que ce ne sont plus les primitives claires figées.
    expect(bg.color, isNot(DonyColors.success50));
    expect(label.style?.color, isNot(DonyColors.success500));
  });

  testWidgets('RequestStatusPill (attente commission) : ton warning du thème sombre', (tester) async {
    final darkCs = AppTheme.dark().colorScheme;
    await tester.pumpWidget(wrapDark(
      const RequestStatusPill(screenCase: RequestScreenCase.cashCommissionPending),
    ));

    final bg = tester
        .widget<Container>(find.descendant(of: find.byType(RequestStatusPill), matching: find.byType(Container)).first)
        .decoration as BoxDecoration;

    expect(bg.color, darkCs.warningLight);
    expect(bg.color, isNot(DonyColors.warning50));
  });

  testWidgets('Billet sans photo : vignette placeholder en couleurs du thème sombre', (tester) async {
    final darkCs = AppTheme.dark().colorScheme;
    await tester.pumpWidget(wrapDark(RequestTicketCard(
      request: PackageRequest(
        id: 'pr-1', senderId: 's', departureCity: 'Divo', arrivalCity: 'Annemasse',
        desiredDate: DateTime(2026, 9, 27), dateToleranceDays: 0, weightKg: 2,
        parcelSize: ParcelSize.small, transportMode: TransportMode.plane,
        status: PackageRequestStatus.open, createdAt: DateTime.utc(2026, 9, 17)),
      statusPill: const SizedBox(), metaLabel: '',
    )));

    final placeholder = find.byKey(const Key('request-ticket-photo-placeholder'));
    final deco = tester.widget<Container>(placeholder).decoration as BoxDecoration;
    final icon = tester.widget<DonyIcon>(find.descendant(of: placeholder, matching: find.byType(DonyIcon)));

    expect(deco.color, darkCs.surfaceContainerHighest);
    expect(icon.color, darkCs.onSurfaceVariant);
    expect(deco.color, isNot(DonyColors.sand200));
    expect(icon.color, isNot(DonyColors.terra700));
  });
}
