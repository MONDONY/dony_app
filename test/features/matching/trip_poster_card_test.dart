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
  String pricingMode = 'KG',
  List<Map<String, dynamic>> gridItems = const [],
  String capacityUnit = 'SUITCASE_23KG',
  String? pickupLabel,
  String? deliveryLabel,
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
  'pricingMode': pricingMode,
  'priceGridItems': gridItems,
  'capacityUnit': capacityUnit,
  if (pickupLabel != null)
    'pickupAddress': {'label': pickupLabel, 'lat': 48.88, 'lng': 2.35},
  if (deliveryLabel != null)
    'deliveryAddress': {'label': deliveryLabel, 'lat': 14.69, 'lng': -17.44},
  'status': 'ACTIVE',
  'createdAt': DateTime(2026, 8).toIso8601String(),
  'updatedAt': DateTime(2026, 8).toIso8601String(),
});

Map<String, dynamic> _gridItem(String label, double display) => {
  'id': 'g-$label',
  'label': label,
  'unitPriceNet': display / 1.05,
  'unitPriceDisplay': display,
};

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

  /// En mode MIXED le prix au kilo est facultatif, mais la colonne backend est
  /// NOT NULL et le formulaire y écrit 0.0. `pricePerKgDisplay` vaut donc 0.00
  /// et non null : un test de nullité laissait passer « 0 € le kilo » sur une
  /// affiche destinée à Facebook.
  testWidgets('annonce la grille et jamais 0 le kilo en mode article', (
    tester,
  ) async {
    await _pump(
      tester,
      _announcement(
        pricingMode: 'MIXED',
        pricePerKg: 0,
        pricePerKgDisplay: 0,
        gridItems: [_gridItem('Carton', 25), _gridItem('Valise', 40)],
      ),
    );

    expect(find.text('dès ${formatPriceIn(25, 'EUR')}'), findsOneWidget);
    expect(find.text("l'article"), findsOneWidget);
    expect(find.text('le kilo'), findsNothing);
    expect(find.textContaining('0 €'), findsNothing);
  });

  testWidgets('affiche les deux tarifs quand le voyageur a rempli les deux', (
    tester,
  ) async {
    await _pump(
      tester,
      _announcement(
        pricingMode: 'MIXED',
        pricePerKg: 6,
        pricePerKgDisplay: 8,
        gridItems: [_gridItem('Carton', 25)],
      ),
    );

    expect(find.text('dès ${formatPriceIn(25, 'EUR')}'), findsOneWidget);
    expect(find.text('${formatPriceIn(8, 'EUR')} le kilo'), findsOneWidget);
  });

  /// KG_FREE veut dire « pas de plafond déclaré » : availableKg n'est alors
  /// qu'une valeur de forme, et l'imprimer comme une limite tromperait
  /// l'expéditeur.
  testWidgets('dit Kg libre au lieu d\'un plafond inventé', (tester) async {
    await _pump(tester, _announcement(capacityUnit: 'KG_FREE'));

    expect(find.text('Kg libre'), findsOneWidget);
    expect(find.text('12 kg'), findsNothing);
  });

  testWidgets('imprime les lieux de remise et de récupération', (tester) async {
    await _pump(
      tester,
      _announcement(
        pickupLabel: '12 rue de Tombouctou, 75018 Paris',
        deliveryLabel: 'Sacré-Cœur 3, Dakar',
      ),
    );

    expect(find.text('Remise'), findsOneWidget);
    expect(find.text('12 rue de Tombouctou, 75018 Paris'), findsOneWidget);
    expect(find.text('Récupération'), findsOneWidget);
    expect(find.text('Sacré-Cœur 3, Dakar'), findsOneWidget);
  });

  testWidgets('omet les lieux quand le DTO ne les porte pas', (tester) async {
    await _pump(tester, _announcement());

    expect(find.text('Remise'), findsNothing);
    expect(find.text('Récupération'), findsNothing);
  });

  /// L'affiche a une hauteur fixe : une adresse à rallonge ne doit pas faire
  /// déborder la colonne, sinon la capture PNG sort barrée de jaune et noir.
  testWidgets('encaisse des adresses très longues sans déborder', (
    tester,
  ) async {
    await _pump(
      tester,
      _announcement(
        handoverDeadline: DateTime(2026, 8, 19, 19).toIso8601String(),
        pickupLabel:
            'Domicile, 148 bis boulevard de la Chapelle, bâtiment C, '
            'escalier 4, 75018 Paris, France',
        deliveryLabel:
            'Chez ma tante, Cité Sotrac Mermoz villa 1245, '
            'près de la station Total, Dakar, Sénégal',
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
