import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/compatible_traveler_card.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_travelers_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

AnnouncementModel _trip(String id) => AnnouncementModel(
  id: id,
  travelerId: 'tr-$id',
  departureCity: 'Divo',
  arrivalCity: 'Annemasse',
  departureDate: DateTime(2026, 9, 26),
  availableKg: 8,
  totalKg: 10,
  pricePerKg: 7,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 9),
  updatedAt: DateTime(2026, 9),
);

Widget _wrap(Widget w) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: SingleChildScrollView(child: w)),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('liste : titre avec compteur, une carte par trajet', (
    tester,
  ) async {
    final invited = <String>[];
    await tester.pumpWidget(
      _wrap(
        RequestTravelersList(
          trips: [_trip('a'), _trip('b')],
          requestWeightKg: 2,
          inviteStateFor: (_) => TravelerInviteState.idle,
          onInvite: invited.add,
          onOpenTrip: (_) {},
        ),
      ),
    );
    expect(find.text('Voyageurs sur ton axe'), findsOneWidget);
    expect(find.byType(CompatibleTravelerCard), findsNWidgets(2));
    await tester.tap(find.text('Inviter').first);
    expect(invited, ['a']);
  });

  testWidgets('ligne repliée', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        RequestTravelersFold(
          trips: [_trip('a'), _trip('b')],
          label: '2 voyageurs sur ton axe',
          onTap: () => taps++,
        ),
      ),
    );
    await tester.tap(find.text('2 voyageurs sur ton axe'));
    expect(taps, 1);
  });

  testWidgets('ligne repliée sans onTap : non interactive, pas de chevron', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        RequestTravelersFold(
          trips: [_trip('a'), _trip('b')],
          label: '2 voyageurs la verront',
        ),
      ),
    );
    expect(find.byType(InkWell), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'chevron-right'),
      findsNothing,
    );
    // Le contenu (avatars + libellé) reste bien affiché malgré l'absence de geste.
    expect(find.text('2 voyageurs la verront'), findsOneWidget);
  });

  testWidgets('état vide : alerte et dates', (tester) async {
    var alert = 0, widen = 0;
    await tester.pumpWidget(
      _wrap(
        RequestNoTravelersEmpty(
          corridor: 'Divo → Annemasse',
          onCreateAlert: () => alert++,
          onWidenDates: () => widen++,
        ),
      ),
    );
    expect(
      find.text('Aucun voyageur sur Divo → Annemasse pour l\'instant'),
      findsOneWidget,
    );
    await tester.tap(find.text('Être alerté des nouveaux trajets'));
    await tester.tap(find.text('Élargir mes dates'));
    expect((alert, widen), (1, 1));
  });

  testWidgets('écran traduit en anglais : titre et état vide', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        RequestTravelersList(
          trips: [_trip('a')],
          requestWeightKg: 2,
          inviteStateFor: (_) => TravelerInviteState.idle,
          onInvite: (_) {},
          onOpenTrip: (_) {},
        ),
      ),
    );
    expect(find.text('Travelers on your route'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
  });

  testWidgets('état vide en anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        RequestNoTravelersEmpty(
          corridor: 'Divo → Annemasse',
          onCreateAlert: () {},
          onWidenDates: () {},
        ),
      ),
    );
    expect(find.text('No traveler on Divo → Annemasse yet'), findsOneWidget);
    expect(find.text('Get alerted about new trips'), findsOneWidget);
    expect(find.text('Widen my dates'), findsOneWidget);
  });
}
