import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/poster/trip_poster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _announcement({
  double pricePerKg = 5,
  double? pricePerKgDisplay = 7,
  String? handoverDeadline,
  String currency = 'EUR',
}) => AnnouncementModel.fromJson({
  'id': 'a1',
  'travelerId': 't1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': DateTime(2026, 8, 20).toIso8601String(),
  'availableKg': 12.0,
  'totalKg': 23.0,
  'pricePerKg': pricePerKg,
  'pricePerKgDisplay': pricePerKgDisplay,
  'handoverDeadline': handoverDeadline,
  'currency': currency,
  'status': 'ACTIVE',
  'createdAt': DateTime(2026, 8).toIso8601String(),
  'updatedAt': DateTime(2026, 8).toIso8601String(),
});

Future<void> _pump(WidgetTester tester, AnnouncementModel a) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripPosterCard(
            announcement: a,
            shareUrl: 'https://api.yadony.test/api/v1/public/annonce/a1',
          ),
        ),
      ),
    );

void main() {
  setUpAll(() async => initializeDateFormatting('fr'));

  testWidgets('affiche le corridor en capitales', (tester) async {
    await _pump(tester, _announcement());

    expect(find.text('PARIS'), findsOneWidget);
    expect(find.text('DAKAR'), findsOneWidget);
  });

  /// L'affiche s'adresse aux expéditeurs. `pricePerKg` est le net voyageur :
  /// l'afficher annoncerait un prix que personne ne paie réellement.
  testWidgets('affiche le prix expéditeur, pas le net voyageur', (
    tester,
  ) async {
    await _pump(tester, _announcement(pricePerKg: 6, pricePerKgDisplay: 8));

    expect(find.text(formatPriceIn(8, 'EUR')), findsOneWidget);
    expect(find.text(formatPriceIn(6, 'EUR')), findsNothing);
  });

  /// Sans `pricePerKgDisplay`, il faut appliquer la commission au net, pas
  /// afficher le net tel quel : ce serait le tarif voyageur, pas celui payé.
  testWidgets('applique la commission quand le prix affiché est absent', (
    tester,
  ) async {
    await _pump(tester, _announcement(pricePerKg: 6, pricePerKgDisplay: null));

    expect(
      find.text(formatPriceIn(netToSenderPrice(6), 'EUR')),
      findsOneWidget,
    );
    expect(find.text(formatPriceIn(6, 'EUR')), findsNothing);
  });

  testWidgets('affiche la date limite de dépôt quand elle existe', (
    tester,
  ) async {
    await _pump(
      tester,
      _announcement(
        handoverDeadline: DateTime(2026, 8, 19, 19).toIso8601String(),
      ),
    );

    expect(find.text('Dernier dépôt'), findsOneWidget);
  });

  testWidgets('omet la ligne de dépôt quand la date limite est absente', (
    tester,
  ) async {
    await _pump(tester, _announcement());

    expect(find.text('Dernier dépôt'), findsNothing);
  });

  testWidgets('imprime le lien de partage', (tester) async {
    await _pump(tester, _announcement());

    expect(
      find.text('https://api.yadony.test/api/v1/public/annonce/a1'),
      findsOneWidget,
    );
  });

  /// Toutes les affiches concurrentes placardent deux à quatre numéros. Celle
  /// de Yadony n'en porte aucun : le canal de contact est l'application.
  testWidgets('ne contient aucun numéro de téléphone', (tester) async {
    await _pump(tester, _announcement());

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(RegExp(r'\+\d{6,}').hasMatch(texts), isFalse);
    expect(RegExp(r'\b0\d[\s.]?(\d{2}[\s.]?){4}\b').hasMatch(texts), isFalse);
  });

  /// XOF et XAF sont les devises des corridors principaux. Une table de
  /// symboles écrite à la main les laissait tomber dans son cas par défaut et
  /// imprimait le code ISO brut sur l'affiche.
  testWidgets('gère une devise hors euro', (tester) async {
    await _pump(
      tester,
      _announcement(currency: 'XOF', pricePerKgDisplay: 6000),
    );

    expect(find.text(formatPriceIn(6000, 'XOF')), findsOneWidget);
    expect(find.textContaining('XOF'), findsNothing);
  });

  testWidgets('gère le franc CFA d\'Afrique centrale', (tester) async {
    await _pump(
      tester,
      _announcement(currency: 'XAF', pricePerKgDisplay: 6000),
    );

    expect(find.text(formatPriceIn(6000, 'XAF')), findsOneWidget);
    expect(find.textContaining('XAF'), findsNothing);
  });
}
