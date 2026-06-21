import 'package:dony/features/profile/presentation/widgets/activity_hub_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('affiche titre, sous-titre et compteur, et déclenche onTap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        ProfileActivityHubCard(
          iconAsset: 'plane',
          title: 'Mes trajets et colis',
          subtitle: 'Gère tes trajets et colis embarqués',
          countLabel: '2 à venir',
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Mes trajets et colis'), findsOneWidget);
    expect(find.text('Gère tes trajets et colis embarqués'), findsOneWidget);
    expect(find.text('2 à venir'), findsOneWidget);

    await tester.tap(find.byType(ProfileActivityHubCard));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('masque le compteur quand countLabel est null', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ProfileActivityHubCard(
          iconAsset: 'package',
          title: 'Mes colis',
          subtitle: 'Suis tes colis et demandes en cours',
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Mes colis'), findsOneWidget);
    expect(find.text('2 à venir'), findsNothing);
  });
}
