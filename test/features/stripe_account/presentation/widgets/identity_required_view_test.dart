import 'package:dony/features/stripe_account/presentation/widgets/identity_required_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  Widget buildWidget() => const MaterialApp(
    home: IdentityRequiredView(title: 'Recevoir mes paiements'),
  );

  testWidgets('affiche le titre passé par l\'appelant et le CTA', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Recevoir mes paiements'), findsOneWidget);
    expect(find.text('Vérifiez votre identité\nd\'abord'), findsOneWidget);
    expect(find.text('Vérifier mon identité'), findsOneWidget);
  });

  testWidgets('en anglais : le corps et le CTA sont traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(buildWidget());
    // Le titre reste celui passé par l'appelant, jamais traduit ici.
    expect(find.text('Recevoir mes paiements'), findsOneWidget);
    expect(find.text('Verify your identity\nfirst'), findsOneWidget);
    expect(find.text('Verify my identity'), findsOneWidget);
  });
}
