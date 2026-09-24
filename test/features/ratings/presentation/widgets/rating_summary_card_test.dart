import 'package:dony/features/ratings/presentation/widgets/rating_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  const distribution = {1: 0, 2: 0, 3: 0, 4: 1, 5: 2};

  testWidgets('nombre d\'avis en français', (tester) async {
    await tester.pumpWidget(
      wrap(
        const RatingSummaryCard(
          averageRating: 4.5,
          ratingCount: 3,
          distribution: distribution,
        ),
      ),
    );

    expect(find.text('3 avis'), findsOneWidget);
  });

  testWidgets('nombre d\'avis traduit en anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      wrap(
        const RatingSummaryCard(
          averageRating: 4.5,
          ratingCount: 3,
          distribution: distribution,
        ),
      ),
    );

    expect(find.text('3 reviews'), findsOneWidget);
  });

  testWidgets('singulier anglais à 1 avis', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      wrap(
        const RatingSummaryCard(
          averageRating: 5,
          ratingCount: 1,
          distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 1},
        ),
      ),
    );

    expect(find.text('1 review'), findsOneWidget);
  });
}
