import 'package:dony/core/widgets/sender_reliability_label.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helpers.dart';

void main() {
  Widget host(int? count, {Locale locale = AppL10n.fr}) => localizedApp(
    Scaffold(body: SenderReliabilityLabel(count: count)),
    locale: locale,
  );

  testWidgets('rien à zéro ni sur un back antérieur (champ absent)', (
    tester,
  ) async {
    for (final count in [null, 0]) {
      await tester.pumpWidget(host(count));
      expect(find.byKey(const Key('sender-reliability-label')), findsNothing);
    }
  });

  testWidgets('une annulation : singulier, en français', (tester) async {
    await tester.pumpWidget(host(1));
    expect(find.byKey(const Key('sender-reliability-label')), findsOneWidget);
    expect(find.text('1 annulation ou absence'), findsOneWidget);
  });

  testWidgets('plusieurs incidents : pluriel et infobulle explicative', (
    tester,
  ) async {
    await tester.pumpWidget(host(3));
    expect(find.text('3 annulations ou absences'), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('rendez-vous de remise'));
  });

  testWidgets('anglais', (tester) async {
    enableEnglish();
    await tester.pumpWidget(host(2, locale: AppL10n.en));
    expect(find.text('2 cancellations or no-shows'), findsOneWidget);
  });

  test('isVisible', () {
    expect(SenderReliabilityLabel.isVisible(null), isFalse);
    expect(SenderReliabilityLabel.isVisible(0), isFalse);
    expect(SenderReliabilityLabel.isVisible(1), isTrue);
  });
}
