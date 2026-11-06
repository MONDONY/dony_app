import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une photo de profil est un visage : masquée dans le replay. Les initiales
/// n'ont rien de personnel au-delà du nom déjà visible.
void main() {
  Widget host(DonyAvatar avatar) => MaterialApp(
    home: Scaffold(body: Center(child: avatar)),
  );

  testWidgets('photo de profil : masquée dans le replay', (tester) async {
    await tester.pumpWidget(
      host(
        const DonyAvatar(name: 'Awa Diop', imageUrl: 'https://x.test/a.jpg'),
      ),
    );

    expect(find.byType(DonyReplayMask), findsOneWidget);
  });

  testWidgets('initiales seules : rien à masquer', (tester) async {
    await tester.pumpWidget(host(const DonyAvatar(name: 'Awa Diop')));

    expect(find.byType(DonyReplayMask), findsNothing);
    expect(find.text('AD'), findsOneWidget);
  });
}
