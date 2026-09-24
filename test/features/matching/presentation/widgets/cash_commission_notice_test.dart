import 'package:dony/features/matching/presentation/widgets/cash_commission_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

Widget _wrap() =>
    const MaterialApp(home: Scaffold(body: CashCommissionNotice()));

void main() {
  testWidgets('en français : identique à l\'ancien texte concaténé', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());

    expect(
      find.textContaining(
        'Vous ne pourrez accepter un colis en espèces que si la commission '
        'Yadony peut être prélevée ',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'sur votre portefeuille en priorité',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '. À défaut, il faudra le recharger ou enregistrer une carte '
        'valide au moment d’accepter.',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('en anglais : les trois segments sont traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(_wrap());

    expect(
      find.textContaining(
        "You'll only be able to accept a cash package if the Yadony "
        'service fee can be collected ',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('from your wallet first', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        ". Otherwise, you'll need to top it up or add a valid card when "
        'accepting.',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });
}
