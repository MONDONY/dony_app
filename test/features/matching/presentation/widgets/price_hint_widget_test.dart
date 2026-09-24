import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/presentation/widgets/price_hint_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('prix trop bas : avertissement en français', (tester) async {
    await tester.pumpWidget(
      _wrap(const PriceHintWidget(warning: PriceWarning.tooLow)),
    );

    expect(
      find.text('Prix bas : risque de méfiance de l\'expéditeur'),
      findsOneWidget,
    );
  });

  testWidgets('prix trop élevé : avertissement en français', (tester) async {
    await tester.pumpWidget(
      _wrap(const PriceHintWidget(warning: PriceWarning.tooHigh)),
    );

    expect(find.text('Prix élevé : peu de demandes attendues'), findsOneWidget);
  });

  testWidgets('prix médian de marché avec corridor, en français', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const PriceHintWidget(
          marketMedianPrice: 8,
          corridor: 'Paris → Dakar',
          currency: SupportedCurrency.eur,
        ),
      ),
    );

    expect(
      find.textContaining('Marché Paris → Dakar : ', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Votre prix est compétitif.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('en anglais : les trois messages sont traduits', (tester) async {
    useEnglish();

    await tester.pumpWidget(
      _wrap(const PriceHintWidget(warning: PriceWarning.tooLow)),
    );
    expect(
      find.text('Low price: risk of distrust from the sender'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _wrap(const PriceHintWidget(warning: PriceWarning.tooHigh)),
    );
    expect(find.text('High price: few requests expected'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        const PriceHintWidget(
          marketMedianPrice: 8,
          corridor: 'Paris → Dakar',
          currency: SupportedCurrency.eur,
        ),
      ),
    );
    expect(
      find.textContaining('Market Paris → Dakar: ', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Your price is competitive.', findRichText: true),
      findsOneWidget,
    );
  });
}
