import 'package:dony/features/matching/bloc/trip_filter_cubit.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('HeaderPill affiche label + icône et répond au tap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        HeaderPill(
          label: 'Envoyer',
          icon: Icons.inventory_2_rounded,
          style: HeaderPillStyle.warm,
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.tap(find.text('Envoyer'));
    expect(tapped, isTrue);
  });

  testWidgets('TripsStatsStrip affiche les 3 tuiles', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TripsStatsStrip(
          summary: TripsSummaryModel(
            activeTrips: 3,
            kgSold: 19,
            revenue: 152.46,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('3'), findsOneWidget);
    expect(find.text('19 kg'), findsOneWidget);
    expect(find.text('152 €'), findsOneWidget);
    expect(find.text('Trajets actifs'), findsOneWidget);
  });

  testWidgets('StatusChipsRow : chip active mise en avant, tap change', (
    tester,
  ) async {
    TripStatusFilter? selected;
    await tester.pumpWidget(
      _wrap(
        StatusChipsRow<TripStatusFilter>(
          chips: const [
            StatusChipData(
              label: 'Tous',
              value: TripStatusFilter.all,
              count: 34,
            ),
            StatusChipData(
              label: 'Actifs',
              value: TripStatusFilter.active,
              count: 3,
              dotColor: Colors.green,
            ),
          ],
          selected: TripStatusFilter.all,
          onSelected: (v) => selected = v,
        ),
      ),
    );

    expect(find.text('Tous · 34'), findsOneWidget);
    await tester.tap(find.text('Actifs · 3'));
    expect(selected, TripStatusFilter.active);
  });

  testWidgets('StatusChipsRow avec equals (Set) compare correctement', (
    tester,
  ) async {
    Set<String>? selected;
    await tester.pumpWidget(
      _wrap(
        StatusChipsRow<Set<String>>(
          chips: const [
            StatusChipData(label: 'Tous', value: <String>{}),
            StatusChipData(label: 'Livrés', value: {'COMPLETED'}),
          ],
          selected: const <String>{},
          equals: setEquals,
          onSelected: (v) => selected = v,
        ),
      ),
    );

    await tester.tap(find.text('Livrés'));
    expect(selected, {'COMPLETED'});
  });

  testWidgets('ActivitySearchField émet onChanged', (tester) async {
    String? typed;
    await tester.pumpWidget(
      _wrap(
        ActivitySearchField(hint: 'Rechercher…', onChanged: (v) => typed = v),
      ),
    );
    await tester.enterText(find.byType(TextField), 'dakar');
    expect(typed, 'dakar');
  });
}
