import 'package:dony/core/design/design_system.dart';
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
  String departureCity = 'Paris',
  String arrivalCity = 'Dakar',
}) => AnnouncementModel.fromJson({
  'id': 'a1',
  'travelerId': 't1',
  'departureCity': departureCity,
  'arrivalCity': arrivalCity,
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
        home: Scaffold(body: TripPosterCard(announcement: a)),
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

  /// Une URL ecrite dans une image n'est cliquable sur aucune plateforme, et
  /// personne ne recopie a la main 80 caracteres portant un UUID. Le lien vit
  /// dans la legende, pas sur l'image.
  testWidgets('n\'imprime aucune URL', (tester) async {
    await _pump(tester, _announcement());

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(texts.contains('http'), isFalse);
    expect(texts.contains('annonce/'), isFalse);
  });

  /// L'affiche circule hors de l'application : elle est la seule representation
  /// de la marque que verront des gens qui ne la connaissent pas encore.
  testWidgets('porte le mot-logo officiel, pas un texte style', (tester) async {
    await _pump(tester, _announcement());

    expect(find.byType(DonyLogo), findsOneWidget);
    expect(find.text('Yadony'), findsNothing);
  });

  /// Sans URL sur l'image, les badges sont le seul indice de « ou trouver
  /// l'application » pour qui recoit une capture d'ecran sans la legende.
  testWidgets('porte les badges des deux stores', (tester) async {
    await _pump(tester, _announcement());

    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<AssetImage>()
        .map((a) => a.assetName)
        .toSet();

    expect(assets, contains(TripPosterCard.appStoreBadgeAsset));
    expect(assets, contains(TripPosterCard.googlePlayBadgeAsset));
  });

  /// Le corridor se lit d'un coup d'oeil, depart puis arrivee sur une ligne.
  /// Empiles, rien n'indiquait lequel des deux etait le depart.
  testWidgets('affiche le corridor sur une seule ligne', (tester) async {
    await _pump(tester, _announcement());

    final depart = tester.getRect(find.text('PARIS'));
    final arrivee = tester.getRect(find.text('DAKAR'));

    expect(arrivee.left, greaterThan(depart.right));
    expect((arrivee.top - depart.top).abs(), lessThan(1));
  });

  /// « MARSEILLE ✈ OUAGADOUGOU » est deux fois plus large que « PARIS ✈ DAKAR ».
  /// Le forcer sur une ligne le reduirait sous la taille des libelles qui le
  /// suivent, inversant la hierarchie de lecture : on repasse sur deux lignes.
  testWidgets('empile un corridor trop long au lieu de le rapetisser', (
    tester,
  ) async {
    await _pump(
      tester,
      _announcement(departureCity: 'Marseille', arrivalCity: 'Ouagadougou'),
    );

    expect(tester.takeException(), isNull);

    final depart = tester.getRect(find.text('MARSEILLE'));
    final arrivee = tester.getRect(find.text('OUAGADOUGOU'));

    expect(arrivee.top, greaterThan(depart.top));
    expect(arrivee.right, lessThanOrEqualTo(TripPosterCard.logicalWidth));
  });

  /// Aucune disposition ne doit amputer un nom de ville : une affiche annoncant
  /// « OUAGAD… » est inutilisable.
  testWidgets('ne tronque jamais un nom de ville', (tester) async {
    for (final pair in [
      ('Paris', 'Dakar'),
      ('Marseille', 'Ouagadougou'),
      ('Charleville-Mezieres', 'Bobo-Dioulasso'),
    ]) {
      await _pump(
        tester,
        _announcement(departureCity: pair.$1, arrivalCity: pair.$2),
      );

      expect(tester.takeException(), isNull, reason: '${pair.$1} ${pair.$2}');
      expect(find.text(pair.$1.toUpperCase()), findsOneWidget);
      expect(find.text(pair.$2.toUpperCase()), findsOneWidget);
    }
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
