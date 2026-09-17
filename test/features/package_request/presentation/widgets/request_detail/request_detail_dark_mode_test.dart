import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/compatible_traveler_card.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_detail_skeleton.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_offer_card.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_state_banner.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_status_pill.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_ticket_card.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_travelers_section.dart';
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

  testWidgets('RequestStateBanner (info) : couleurs du thème sombre', (tester) async {
    final darkCs = AppTheme.dark().colorScheme;
    await tester.pumpWidget(wrapDark(const RequestStateBanner(
      tone: RequestBannerTone.info, icon: 'info', title: 'Titre', message: 'Message.')));

    final bg = tester
        .widget<Container>(find.descendant(of: find.byType(RequestStateBanner), matching: find.byType(Container)).first)
        .decoration as BoxDecoration;
    final title = tester.widget<Text>(find.text('Titre'));

    expect(bg.color, darkCs.primaryContainer);
    expect(title.style?.color, darkCs.primary);
    expect(bg.color, isNot(DonyColors.primarySoft));
    expect(title.style?.color, isNot(DonyColors.blue700));
  });

  testWidgets('RequestOfferCard : ton et bordure surlignée du thème sombre', (tester) async {
    final darkCs = AppTheme.dark().colorScheme;
    final thread = NegotiationThread(
      id: 't', packageRequestId: 'pr', travelerId: 'tr', travelerTravelDate: DateTime(2026, 9, 26),
      travelerAvailableKg: 8, status: NegotiationThreadStatus.open, currentPriceEur: 25, roundsCount: 1,
      lastActivityAt: DateTime(2026, 9, 17), createdAt: DateTime(2026, 9, 17), messages: const [],
      travelerName: 'Awa K.', isMyTurn: true, grossPriceEur: 28,
    );
    await tester.pumpWidget(wrapDark(RequestOfferCard(thread: thread, firmPrice: false, highlighted: true)));

    final tagLabel = tester.widget<Text>(find.text('À toi de répondre'));
    final card = tester.widget<Container>(find.byWidgetPredicate(
      (w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).border != null,
    ));
    final border = (card.decoration! as BoxDecoration).border! as Border;

    expect(tagLabel.style?.color, darkCs.primary);
    expect(tagLabel.style?.color, isNot(DonyColors.blue700));
    expect(border.top.color, darkCs.primary.withValues(alpha: 0.30));
    expect(border.top.color, isNot(DonyColors.blue200));
  });

  testWidgets('CompatibleTravelerCard : bouton Inviter en couleurs du thème sombre', (tester) async {
    final darkCs = AppTheme.dark().colorScheme;
    final trip = AnnouncementModel(
      id: 'a-1', travelerId: 'tr', departureCity: 'Divo', arrivalCity: 'Annemasse',
      departureDate: DateTime(2026, 9, 26), availableKg: 8, totalKg: 10, pricePerKg: 7,
      status: 'ACTIVE', createdAt: DateTime(2026, 9), updatedAt: DateTime(2026, 9),
    );
    await tester.pumpWidget(wrapDark(CompatibleTravelerCard(
      trip: trip, requestWeightKg: 2, inviteState: TravelerInviteState.idle, onInvite: () {})));

    final button = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Inviter'));
    final style = button.style!;
    expect(style.backgroundColor?.resolve({}), darkCs.primaryContainer);
    expect(style.foregroundColor?.resolve({}), darkCs.primary);
    expect(style.backgroundColor?.resolve({}), isNot(DonyColors.primarySoft));
  });

  testWidgets('RequestNoTravelersEmpty : fond communautaire du thème sombre', (tester) async {
    final darkCs = AppTheme.dark().colorScheme;
    await tester.pumpWidget(wrapDark(RequestNoTravelersEmpty(
      corridor: 'Divo → Annemasse', onCreateAlert: () {}, onWidenDates: () {})));

    final action = tester
        .widget<Material>(find.ancestor(of: find.text('Être alerté des nouveaux trajets'), matching: find.byType(Material)).first);

    expect(action.color, darkCs.surfaceWarm);
    expect(action.color, isNot(DonyColors.sand100));
  });

  testWidgets('RequestDetailSkeleton : blocs en couleurs du thème sombre', (tester) async {
    final darkCs = AppTheme.dark().colorScheme;
    await tester.pumpWidget(wrapDark(const RequestDetailSkeleton()));

    final block = tester
        .widget<Container>(find.descendant(of: find.byType(RequestDetailSkeleton), matching: find.byType(Container)).first);
    final deco = block.decoration as BoxDecoration;

    expect(deco.color, darkCs.surfaceContainerHighest);
    expect(deco.color, isNot(DonyColors.neutral100));
  });
}
