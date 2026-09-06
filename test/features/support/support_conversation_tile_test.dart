import 'package:dony/features/support/presentation/widgets/support_conversation_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('affiche la ligne meme sans aucun ticket, avec une invitation', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const SupportConversationTile(unreadCount: 0, preview: '')),
    );

    expect(find.text('Support Yadony'), findsOneWidget);
    expect(find.textContaining('Une question'), findsOneWidget);
  });

  testWidgets('affiche l aperçu du dernier message quand il y en a un', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SupportConversationTile(
          unreadCount: 0,
          preview: 'Nous regardons votre dossier',
        ),
      ),
    );

    expect(find.text('Nous regardons votre dossier'), findsOneWidget);
  });

  testWidgets('affiche la pastille quand il y a des non-lus', (tester) async {
    await tester.pumpWidget(
      wrap(const SupportConversationTile(unreadCount: 2, preview: 'Bonjour')),
    );

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('n affiche aucune pastille a zero non-lu', (tester) async {
    await tester.pumpWidget(
      wrap(const SupportConversationTile(unreadCount: 0, preview: 'Bonjour')),
    );

    expect(find.text('0'), findsNothing);
  });
}
