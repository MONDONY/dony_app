import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/presentation/widgets/unverified_contact_warning_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ouvre la sheet et expose le résultat retourné par `show`, pour vérifier ce
/// que l'appelant reçoit réellement (c'est lui qui décide d'appliquer ou non).
Future<bool?> _openSheet(WidgetTester tester) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await UnverifiedContactWarningSheet.show(context);
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('UnverifiedContactWarningSheet', () {
    testWidgets('annonce les trois conséquences et le non-recommandé',
        (tester) async {
      await _openSheet(tester);

      expect(find.text('Accepter les profils non vérifiés ?'), findsOneWidget);
      expect(
        find.text("Cette option n'est pas recommandée par Yadony."),
        findsOneWidget,
      );
      expect(
        find.textContaining("Tous les utilisateurs pourront t'envoyer"),
        findsOneWidget,
      );
      expect(
        find.textContaining("Yadony ne peut pas confirmer l'identité"),
        findsOneWidget,
      );
      expect(
        find.textContaining("Yadony n'est pas responsable"),
        findsOneWidget,
      );
    });

    testWidgets('le bouton reste inactif tant que le risque n\'est pas accepté',
        (tester) async {
      await _openSheet(tester);

      final button = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('cocher la case active le bouton', (tester) async {
      await _openSheet(tester);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final button = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('confirmer renvoie true à l\'appelant', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await UnverifiedContactWarningSheet.show(context);
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accepter quand même'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    /// Fermer la sheet sans confirmer ne doit pas valoir acceptation : l'appelant
    /// ne doit appliquer le changement que sur un `true` franc.
    testWidgets('fermer sans confirmer ne renvoie pas true', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await UnverifiedContactWarningSheet.show(context);
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      // Tap hors de la sheet : fermeture par l'utilisateur.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(result, isNot(isTrue));
    });
  });
}
