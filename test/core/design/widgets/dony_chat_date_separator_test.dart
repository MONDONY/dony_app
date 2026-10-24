import 'package:dony/core/design/widgets/dony_chat_date_separator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  testWidgets('aujourd\'hui', (tester) async {
    await tester.pumpWidget(
      localizedApp(DonyChatDateSeparator(date: DateTime.now())),
    );
    expect(find.text("Aujourd'hui"), findsOneWidget);
  });

  testWidgets('hier', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      localizedApp(
        DonyChatDateSeparator(
          date: DateTime(now.year, now.month, now.day - 1, 12),
        ),
      ),
    );
    expect(find.text('Hier'), findsOneWidget);
  });

  testWidgets('une date plus ancienne : jour complet', (tester) async {
    await tester.pumpWidget(
      localizedApp(DonyChatDateSeparator(date: DateTime(2025, 3, 7, 12))),
    );
    expect(find.text('7 mars 2025'), findsOneWidget);
  });
}
