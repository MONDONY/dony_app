import 'package:dony/features/matching/presentation/widgets/activity_tile.dart';
import 'package:dony/features/matching/presentation/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

ActivityTile _tile({
  int value = 6,
  bool isLoading = false,
  bool hasError = false,
  bool showNotificationDot = false,
  VoidCallback? onTap,
}) => ActivityTile(
  iconName: 'plane',
  iconColor: Colors.blue,
  value: value,
  label: 'Trajets actifs',
  isLoading: isLoading,
  hasError: hasError,
  showNotificationDot: showNotificationDot,
  onTap: onTap ?? () {},
);

void main() {
  group('ActivityTile', () {
    testWidgets('affiche la valeur et le libellé', (tester) async {
      await tester.pumpWidget(_wrap(_tile()));

      expect(find.text('6'), findsOneWidget);
      expect(find.text('Trajets actifs'), findsOneWidget);
    });

    testWidgets('déclenche onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(_tile(onTap: () => tapped = true)));

      await tester.tap(find.text('Trajets actifs'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('en chargement, masque la valeur mais garde le libellé', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_tile(isLoading: true)));

      expect(find.text('6'), findsNothing);
      expect(find.text('Trajets actifs'), findsOneWidget);
    });

    testWidgets('en erreur, affiche un tiret et reste cliquable', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(_tile(hasError: true, onTap: () => tapped = true)),
      );

      expect(find.text('—'), findsOneWidget);
      // Une erreur de compteur ne doit pas bloquer l'accès à l'écran cible :
      // c'est lui qui gère son propre état d'erreur.
      await tester.tap(find.text('Trajets actifs'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('zéro reste affiché et cliquable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(_tile(value: 0, onTap: () => tapped = true)),
      );

      expect(find.text('0'), findsOneWidget);
      await tester.tap(find.text('Trajets actifs'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('StatTile', () {
    testWidgets('affiche le libellé et la valeur formatée', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatTile(
            iconName: 'euro',
            label: 'Revenus',
            value: '152 €',
            color: Colors.blue,
          ),
        ),
      );

      expect(find.text('Revenus'), findsOneWidget);
      expect(find.text('152 €'), findsOneWidget);
    });

    testWidgets('en chargement, masque la valeur', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatTile(
            iconName: 'euro',
            label: 'Revenus',
            value: '152 €',
            color: Colors.blue,
            isLoading: true,
          ),
        ),
      );

      expect(find.text('152 €'), findsNothing);
      expect(find.text('Revenus'), findsOneWidget);
    });
  });
}
