import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_info_sheet.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/compatible_traveler_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

AnnouncementModel _trip({bool gpPro = false}) => AnnouncementModel(
  id: 'a-1',
  travelerId: 'tr',
  departureCity: 'Divo',
  arrivalCity: 'Annemasse',
  departureDate: DateTime(2026, 9, 26),
  availableKg: 8,
  totalKg: 10,
  pricePerKg: 7,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 9),
  updatedAt: DateTime(2026, 9),
  traveler: TravelerProfile(
    id: 'tr',
    displayName: 'Awa K.',
    averageRating: 4.9,
    gpPro: gpPro,
  ),
);

Future<void> _pump(
  WidgetTester tester,
  TravelerInviteState state, {
  VoidCallback? onInvite,
  VoidCallback? onTap,
  bool gpPro = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: CompatibleTravelerCard(
        trip: _trip(gpPro: gpPro),
        requestWeightKg: 2,
        inviteState: state,
        onInvite: onInvite,
        onTap: onTap,
      ),
    ),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('jauge et bouton Inviter', (tester) async {
    var invites = 0;
    await _pump(tester, TravelerInviteState.idle, onInvite: () => invites++);
    expect(find.text('Awa K.'), findsOneWidget);
    expect(find.text('26 sept. · Divo → Annemasse'), findsOneWidget);
    expect(find.text('8 kg libres'), findsOneWidget);
    expect(find.text('votre colis : 2 kg'), findsOneWidget);
    await tester.tap(find.text('Inviter'));
    expect(invites, 1);
  });

  testWidgets('badge GP Pro seulement si le voyageur est GP Pro', (
    tester,
  ) async {
    await _pump(tester, TravelerInviteState.idle, gpPro: true);
    expect(find.byType(GpProBadge), findsOneWidget);
    await _pump(tester, TravelerInviteState.idle);
    expect(find.byType(GpProBadge), findsNothing);
  });

  testWidgets('tap sur le badge : déclenche le onTap de la carte', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      TravelerInviteState.idle,
      gpPro: true,
      onTap: () => taps++,
    );
    await tester.tap(find.byType(GpProBadge));
    expect(taps, 1);
    expect(find.byType(GpProInfoSheet), findsNothing);
  });

  testWidgets('états Invité, envoi en cours, masqué', (tester) async {
    await _pump(tester, TravelerInviteState.invited);
    expect(find.text('Invité'), findsOneWidget);
    await _pump(tester, TravelerInviteState.sending);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _pump(tester, TravelerInviteState.hidden);
    expect(find.text('Inviter'), findsNothing);
  });

  testWidgets('écran traduit en anglais : jauge et bouton Invite', (
    tester,
  ) async {
    useEnglish();
    var invites = 0;
    await _pump(tester, TravelerInviteState.idle, onInvite: () => invites++);
    expect(find.text('8 kg available'), findsOneWidget);
    expect(find.text('your parcel: 2 kg'), findsOneWidget);
    await tester.tap(find.text('Invite'));
    expect(invites, 1);
  });
}
