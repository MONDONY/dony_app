import 'package:dony/core/phone/phone_country.dart';
import 'package:dony/features/auth/presentation/widgets/dial_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<PhoneCountry?> pump(
    WidgetTester tester, {
    String selected = 'FR',
  }) async {
    PhoneCountry? choisi;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialCodePicker(
            selectedCode: selected,
            onSelected: (c) => choisi = c,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return choisi;
  }

  Finder search() => find.byKey(const Key('dial_code_search'));

  group('DialCodePicker', () {
    testWidgets('la recherche trouve un pays malgré les accents', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(search(), 'senegal');
      await tester.pumpAndSettle();
      expect(find.text('Sénégal (+221)'), findsOneWidget);
      expect(find.text('France (+33)'), findsNothing);
    });

    testWidgets('la recherche accepte un indicatif', (tester) async {
      await pump(tester);
      await tester.enterText(search(), '+225');
      await tester.pumpAndSettle();
      expect(find.text('Côte d\'Ivoire (+225)'), findsOneWidget);
    });

    testWidgets('la recherche accepte un code ISO', (tester) async {
      await pump(tester);
      await tester.enterText(search(), 'be');
      await tester.pumpAndSettle();
      expect(find.text('Belgique (+32)'), findsOneWidget);
    });

    testWidgets('une recherche sans résultat le dit', (tester) async {
      await pump(tester);
      await tester.enterText(search(), 'zzzzz');
      await tester.pumpAndSettle();
      expect(find.text('Aucun pays ne correspond'), findsOneWidget);
    });

    testWidgets('taper un pays le remonte à l\'appelant', (tester) async {
      PhoneCountry? choisi;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DialCodePicker(
              selectedCode: 'FR',
              onSelected: (c) => choisi = c,
            ),
          ),
        ),
      );
      await tester.enterText(search(), 'Ivoire');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Côte d\'Ivoire (+225)'));
      await tester.pumpAndSettle();
      expect(choisi?.code, 'CI');
      expect(choisi?.stripsLeadingZero, isFalse);
    });

    testWidgets('seul le pays retenu est coché, même à indicatif partagé', (
      tester,
    ) async {
      // Le Canada et les États-Unis sont tous deux en +1 : cocher sur
      // l'indicatif marquerait les deux lignes.
      await pump(tester, selected: 'CA');
      await tester.enterText(search(), '+1');
      await tester.pumpAndSettle();
      expect(find.text('Canada (+1)'), findsOneWidget);
      expect(find.text('États-Unis (+1)'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));
    });
  });
}
