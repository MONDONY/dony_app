import 'package:dony/features/profile/presentation/widgets/pending_deletion_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final deletionDate = DateTime(2026, 5, 6, 10);

  testWidgets('shows deletion date (J+30)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PendingDeletionBanner(
          deletionRequestedAt: deletionDate,
          onReactivate: () {},
        ),
      ),
    );

    // J+30 of 2026-05-06 = 2026-06-05
    expect(find.textContaining('05/06/2026'), findsOneWidget);
  });

  testWidgets('shows cancel button', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PendingDeletionBanner(
          deletionRequestedAt: deletionDate,
          onReactivate: () {},
        ),
      ),
    );

    expect(find.text('Annuler la suppression'), findsOneWidget);
  });

  testWidgets('calls onReactivate when cancel button tapped', (tester) async {
    var called = false;
    await tester.pumpWidget(
      _wrap(
        PendingDeletionBanner(
          deletionRequestedAt: deletionDate,
          onReactivate: () => called = true,
        ),
      ),
    );

    await tester.tap(find.text('Annuler la suppression'));
    await tester.pump();

    expect(called, isTrue);
  });
}
