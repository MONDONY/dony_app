import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/trip_poster_screen.dart';
import 'package:dony/features/matching/presentation/widgets/poster/trip_poster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _announcement() => AnnouncementModel.fromJson({
  'id': 'a1',
  'travelerId': 't1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': DateTime(2026, 8, 20).toIso8601String(),
  'availableKg': 12.0,
  'totalKg': 23.0,
  'pricePerKg': 6.0,
  'pricePerKgDisplay': 8.0,
  'handoverDeadline': DateTime(2026, 8, 19, 19).toIso8601String(),
  'currency': 'EUR',
  'status': 'ACTIVE',
  'createdAt': DateTime(2026, 8).toIso8601String(),
  'updatedAt': DateTime(2026, 8).toIso8601String(),
});

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(
    home: TripPosterScreen(
      announcement: _announcement(),
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

    expect(copied, [
      'https://api.yadony.test/api/v1/public/annonce/a1',
    ]);
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
      contains('https://api.yadony.test/api/v1/public/annonce/a1'),
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
    expect(caption, contains('8€'));
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
}
