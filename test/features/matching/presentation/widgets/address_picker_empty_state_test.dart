import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/address_picker_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Sentry FLUTTER-1B : avec le clavier ouvert, le corps du picker ne laisse
  // qu'une centaine de pixels. Un débordement est un FlutterError, le test
  // échoue seul.
  testWidgets('tient dans 100 px de haut sans déborder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            height: 100,
            child: AddressPickerEmptyState(
              icon: 'map-pin-off',
              color: Colors.grey,
              title: 'Aucun résultat',
              subtitle: 'Essayez « Utiliser ma position actuelle ».',
              action: SizedBox(height: 56, child: Text('GPS')),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(find.text('GPS'), findsOneWidget);
  });

  testWidgets('sans action ni contrainte, reste centré', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AddressPickerEmptyState(
            icon: 'wifi-off',
            color: Colors.orange,
            title: 'Connexion requise',
            subtitle: 'Vérifiez votre connexion.',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Center), findsWidgets);
    expect(find.text('Connexion requise'), findsOneWidget);
  });
}
