import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/similar_announcement.dart';
import 'package:dony/features/matching/presentation/widgets/similar_trips_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

SimilarAnnouncement _similar(String id) => SimilarAnnouncement(
  announcement: AnnouncementModel(
    id: id,
    travelerId: 't-$id',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2026, 11, 3),
    availableKg: 10,
    totalKg: 20,
    pricePerKg: 7,
    status: 'ACTIVE',
    createdAt: DateTime(2026, 10),
    updatedAt: DateTime(2026, 10),
  ),
  unmet: const [UnmetCriterion(code: 'DATE')],
);

Widget _host(Widget sliver) =>
    localizedApp(Scaffold(body: CustomScrollView(slivers: [sliver])));

Widget _card(SimilarAnnouncement s, int i) =>
    SizedBox(key: Key('card-${s.announcement.id}-$i'), height: 40);

/// Les animations d'entrée (flutter_animate) laissent des minuteurs en
/// attente : on avance l'horloge par paliers plutôt qu'un seul pump.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  group('SimilarTripsSection', () {
    testWidgets('renders_title_subtitle_and_one_card_per_item', (tester) async {
      await tester.pumpWidget(
        _host(
          SimilarTripsSection(
            items: [_similar('a'), _similar('b')],
            cardBuilder: _card,
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Autres annonces sur ce trajet'), findsOneWidget);
      expect(
        find.text(
          'Ces trajets ne correspondent pas exactement à vos critères.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('card-a-0')), findsOneWidget);
      expect(find.byKey(const Key('card-b-1')), findsOneWidget);
      // Le titre est annoncé comme un en-tête par les lecteurs d'écran.
      expect(
        tester.getSemantics(find.text('Autres annonces sur ce trajet')),
        matchesSemantics(
          label: 'Autres annonces sur ce trajet',
          isHeader: true,
        ),
      );
    });

    testWidgets('empty_items_render_nothing', (tester) async {
      await tester.pumpWidget(
        _host(
          const SimilarTripsSection(
            items: [],
            cardBuilder: _card,
            showNoExactMatch: true,
          ),
        ),
      );
      await _settle(tester);

      expect(find.byKey(const Key('similar-trips-section')), findsNothing);
      expect(find.text('Autres annonces sur ce trajet'), findsNothing);
      expect(
        find.text('Aucun trajet ne correspond exactement à votre recherche.'),
        findsNothing,
      );
    });

    testWidgets('no_exact_match_line_shown_only_when_flagged', (tester) async {
      const line = 'Aucun trajet ne correspond exactement à votre recherche.';
      await tester.pumpWidget(
        _host(SimilarTripsSection(items: [_similar('a')], cardBuilder: _card)),
      );
      await _settle(tester);
      expect(find.text(line), findsNothing);

      await tester.pumpWidget(
        _host(
          SimilarTripsSection(
            items: [_similar('a')],
            cardBuilder: _card,
            showNoExactMatch: true,
          ),
        ),
      );
      await _settle(tester);
      expect(find.text(line), findsOneWidget);
      // La ligne précède le titre du bloc.
      expect(
        tester.getTopLeft(find.text(line)).dy,
        lessThan(
          tester.getTopLeft(find.text('Autres annonces sur ce trajet')).dy,
        ),
      );
    });

    testWidgets('textes traduits en anglais', (tester) async {
      enableEnglish();
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: CustomScrollView(
              slivers: [
                SimilarTripsSection(
                  items: [_similar('a')],
                  cardBuilder: _card,
                  showNoExactMatch: true,
                ),
              ],
            ),
          ),
          locale: const Locale('en'),
        ),
      );
      await _settle(tester);
      expect(find.text('Other listings on this route'), findsOneWidget);
      expect(find.text('No trip exactly matches your search.'), findsOneWidget);
    });
  });
}
