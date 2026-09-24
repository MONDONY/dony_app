import 'package:dony/features/matching/presentation/widgets/near_me_radius_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  testWidgets('default radius shows 25 km', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => NearMeRadiusSheet.show(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('25 km'), findsOneWidget);
  });

  testWidgets('initialRadiusKm reflected in display', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => NearMeRadiusSheet.show(ctx, initialRadiusKm: 60),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('60 km'), findsOneWidget);
  });

  testWidgets('Activer button returns the slider value via Navigator.pop', (
    tester,
  ) async {
    double? returned;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                returned = await NearMeRadiusSheet.show(
                  ctx,
                  initialRadiusKm: 40,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activer le filtre'));
    await tester.pumpAndSettle();
    expect(returned, 40);
  });

  testWidgets('français : titre, explication et bouton par défaut', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => NearMeRadiusSheet.show(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Près de moi'), findsOneWidget);
    expect(
      find.text(
        'On garde uniquement les annonces dont le point de remise est dans ce rayon autour de toi.',
      ),
      findsOneWidget,
    );
    expect(find.text('Activer le filtre'), findsOneWidget);
  });

  testWidgets('anglais : titre, explication et bouton par défaut', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => NearMeRadiusSheet.show(ctx),
              child: const Text('open'),
            ),
          ),
        ),
        locale: AppL10n.en,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Near me'), findsOneWidget);
    expect(
      find.text(
        'We only keep listings whose drop-off point is within this radius of you.',
      ),
      findsOneWidget,
    );
    expect(find.text('Turn on the filter'), findsOneWidget);
  });

  testWidgets('anglais : un libellé fourni remplace le libellé par défaut', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  NearMeRadiusSheet.show(ctx, confirmLabel: 'Apply'),
              child: const Text('open'),
            ),
          ),
        ),
        locale: AppL10n.en,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('Turn on the filter'), findsNothing);
  });
}
