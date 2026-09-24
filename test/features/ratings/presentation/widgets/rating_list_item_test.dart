import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  final item = RatingItem(
    stars: 4,
    comment: 'Super voyageur !',
    createdAt: DateTime(2026, 10, 6, 14, 5),
    excluded: false,
  );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('date au format français (non-régression)', (tester) async {
    await tester.pumpWidget(wrap(RatingListItem(item: item)));

    expect(find.text('6 oct. 2026'), findsOneWidget);
    expect(find.text('Super voyageur !'), findsOneWidget);
  });

  testWidgets('date au format anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(wrap(RatingListItem(item: item)));

    expect(find.text('Oct 6, 2026'), findsOneWidget);
  });
}
