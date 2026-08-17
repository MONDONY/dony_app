import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/trip_poster_screen.dart';
import 'package:dony/features/matching/presentation/widgets/poster/trip_poster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _announcement({
  double pricePerKg = 6.0,
  double? pricePerKgDisplay = 8.0,
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
  'handoverDeadline': DateTime(2026, 8, 19, 19).toIso8601String(),
  'currency': 'EUR',
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

Future<void> _pump(WidgetTester tester, {AnnouncementModel? announcement}) =>
    tester.pumpWidget(
      MaterialApp(
        home: TripPosterScreen(
          announcement: announcement ?? _announcement(),
          shareBaseUrl: 'https://api.yadony.test/api/v1',
        ),
      ),
    );

/// Les actions vivent sous la ligne de flottaison du viewport de test : sans
/// defilement prealable, le tap tombe hors de la zone testable et n'atteint
/// jamais le bouton.
Future<void> _tapAction(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('fr'));

  late List<String> copied;

  setUp(() {
    copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('montre l\'aperçu de l\'affiche', (tester) async {
    await _pump(tester);

    expect(find.byType(TripPosterCard), findsOneWidget);
  });

  testWidgets('propose les quatre actions de publication', (tester) async {
    await _pump(tester);

    expect(find.text('Partager l\'affiche'), findsOneWidget);
    expect(find.text('Copier la légende'), findsOneWidget);
    expect(find.text('Copier le lien'), findsOneWidget);
    expect(find.text('Enregistrer dans la galerie'), findsOneWidget);
  });

  testWidgets('copie l\'URL publique construite depuis la base fournie', (
    tester,
  ) async {
    await _pump(tester);

    await _tapAction(tester, 'Copier le lien');

    // Le canal voyage dans l'URL dès la première affiche publiée : une affiche
    // postée est irrécupérable, un lien sans dimension ne sera jamais
    // attribuable rétroactivement.
    expect(copied, ['https://api.yadony.test/api/v1/public/annonce/a1?c=lien']);
  });

  /// Sur Facebook, une URL écrite dans l'image n'est pas cliquable : la légende
  /// est le seul endroit où le lien devient actionnable. Elle doit donc le
  /// contenir, sinon la moitié de la valeur de l'affiche est perdue.
  testWidgets('la légende contient le lien cliquable', (tester) async {
    await _pump(tester);

    await _tapAction(tester, 'Copier la légende');

    expect(copied, hasLength(1));
    expect(
      copied.single,
      contains('https://api.yadony.test/api/v1/public/annonce/a1?c=post'),
    );
  });

  testWidgets('la légende reprend corridor, dépôt et prix expéditeur', (
    tester,
  ) async {
    await _pump(tester);

    await _tapAction(tester, 'Copier la légende');

    final caption = copied.single;
    expect(caption, contains('Paris vers Dakar'));
    expect(caption, contains('Dernier dépôt'));
    expect(caption, contains(formatPriceIn(8, 'EUR')));
    expect(caption, contains('12 kg'));
  });

  /// Le canal de contact est l'application, jamais le portable du voyageur.
  testWidgets('la légende ne contient aucun numéro de téléphone', (
    tester,
  ) async {
    await _pump(tester);

    await _tapAction(tester, 'Copier la légende');

    expect(RegExp(r'\+\d{6,}').hasMatch(copied.single), isFalse);
  });

  /// L'image et le texte du post doivent annoncer la même chose : une légende
  /// qui promet « 0 € le kilo » sous une affiche vendant à l'article ferait
  /// fuir l'expéditeur avant même le clic.
  testWidgets('la légende annonce la grille et jamais 0 le kilo', (
    tester,
  ) async {
    await _pump(
      tester,
      announcement: _announcement(
        pricingMode: 'MIXED',
        pricePerKg: 0,
        pricePerKgDisplay: 0,
        gridItems: [_gridItem('Carton', 25), _gridItem('Valise', 40)],
      ),
    );

    await _tapAction(tester, 'Copier la légende');

    final caption = copied.single;
    expect(caption, contains("dès ${formatPriceIn(25, 'EUR')} l'article"));
    expect(caption, isNot(contains('le kilo')));
  });

  testWidgets('la légende porte les lieux de remise et de récupération', (
    tester,
  ) async {
    await _pump(
      tester,
      announcement: _announcement(
        pickupLabel: '12 rue de Tombouctou, 75018 Paris',
        deliveryLabel: 'Sacré-Cœur 3, Dakar',
      ),
    );

    await _tapAction(tester, 'Copier la légende');

    final caption = copied.single;
    expect(caption, contains('Remise : 12 rue de Tombouctou, 75018 Paris'));
    expect(caption, contains('Récupération : Sacré-Cœur 3, Dakar'));
  });

  testWidgets('la légende dit Kg libre quand la capacité est non bornée', (
    tester,
  ) async {
    await _pump(tester, announcement: _announcement(capacityUnit: 'KG_FREE'));

    await _tapAction(tester, 'Copier la légende');

    expect(copied.single, contains('Kg libre'));
    expect(copied.single, isNot(contains('12 kg')));
  });
}
