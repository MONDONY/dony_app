import 'package:dony/features/profile/presentation/widgets/pending_deletion_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import '../../../../helpers/l10n_test_helpers.dart';

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

  testWidgets(
    'prévient que les remboursements déjà lancés ne sont pas annulés',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          PendingDeletionBanner(
            deletionRequestedAt: deletionDate,
            onReactivate: () {},
          ),
        ),
      );

      expect(
        find.text('Les remboursements déjà lancés ne sont pas annulés.'),
        findsOneWidget,
      );
    },
  );

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

  test(
    'DateFormat.yMd(fr) rend le même texte que l\'ancien padLeft(2, "0")',
    () {
      // Ancien rendu : '${d.padLeft(2,'0')}/${m.padLeft(2,'0')}/$y'.
      const oldRender = '05/06/2026';
      final newRender = DateFormat.yMd('fr').format(DateTime(2026, 6, 5));
      expect(newRender, oldRender);
    },
  );

  testWidgets('date et bouton en anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        PendingDeletionBanner(
          deletionRequestedAt: deletionDate,
          onReactivate: () {},
        ),
      ),
    );

    // DateFormat.yMd('en') pour le 2026-06-05 : 6/5/2026.
    expect(find.textContaining('6/5/2026'), findsOneWidget);
    expect(find.text('Cancel deletion'), findsOneWidget);
  });
}
