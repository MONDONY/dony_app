import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/plane_icon_expectations.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('iconAsset : icône SVG avant le libellé', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const DonyInfoRow(
          label: 'Départ',
          value: '4 oct.',
          iconAsset: 'map-pin',
        ),
      ),
    );

    expect(findDonyIcon('map-pin'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(find.text('Départ'), findsOneWidget);
  });

  testWidgets('icon Material : inchangé', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const DonyInfoRow(
          label: 'Poids',
          value: '4 kg',
          icon: Icons.scale_rounded,
        ),
      ),
    );

    expect(find.byIcon(Icons.scale_rounded), findsOneWidget);
    expect(findDonyIcon('map-pin'), findsNothing);
  });

  testWidgets('sans icône : aucune icône', (tester) async {
    await tester.pumpWidget(
      _wrap(const DonyInfoRow(label: 'Poids', value: '4 kg')),
    );

    expect(find.byType(Icon), findsNothing);
  });
}
