import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_owner_menu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

void main() {
  testWidgets('liste les actions avec leur conséquence et rend le choix', (
    tester,
  ) async {
    RequestMenuAction? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async => picked = await RequestOwnerMenuSheet.show(
                ctx,
                items: const [
                  RequestMenuAction.unpublish,
                  RequestMenuAction.duplicate,
                  RequestMenuAction.cancel,
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Dépublier'), findsOneWidget);
    expect(
      find.text('Redevient un brouillon, invisible des voyageurs'),
      findsOneWidget,
    );
    expect(find.text('Dupliquer la demande'), findsOneWidget);
    expect(find.text('Irréversible'), findsOneWidget);
    await tester.tap(find.text('Annuler la demande'));
    await tester.pumpAndSettle();
    expect(picked, RequestMenuAction.cancel);
  });

  testWidgets('écran traduit en anglais : libellés et conséquences', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => RequestOwnerMenuSheet.show(
                ctx,
                items: const [
                  RequestMenuAction.unpublish,
                  RequestMenuAction.cancel,
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Unpublish'), findsOneWidget);
    expect(
      find.text('Becomes a draft again, hidden from travelers'),
      findsOneWidget,
    );
    expect(find.text('Cancel the request'), findsOneWidget);
    expect(find.text('Irreversible'), findsOneWidget);
    expect(find.text('Dépublier'), findsNothing);
  });
}
