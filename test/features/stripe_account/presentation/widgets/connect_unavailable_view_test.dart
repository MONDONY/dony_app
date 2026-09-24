import 'package:dony/features/stripe_account/presentation/widgets/connect_unavailable_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  Widget buildWidget() => const MaterialApp(
    home: ConnectUnavailableView(title: 'Recevoir mes paiements'),
  );

  testWidgets('affiche le titre passé par l\'appelant et le message', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Recevoir mes paiements'), findsOneWidget);
    expect(find.text('Pas encore disponible\ndans votre pays'), findsOneWidget);

    // Draine les timers flutter_animate de la mascotte avant la fin du test.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('en anglais : le corps est traduit', (tester) async {
    useEnglish();
    await tester.pumpWidget(buildWidget());
    // Le titre reste celui passé par l'appelant, jamais traduit ici.
    expect(find.text('Recevoir mes paiements'), findsOneWidget);
    expect(find.text('Not available yet\nin your country'), findsOneWidget);

    // Draine les timers flutter_animate de la mascotte avant la fin du test.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
