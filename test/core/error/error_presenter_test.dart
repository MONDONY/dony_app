import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helpers.dart';

Widget _trigger(Locale locale) => localizedApp(
  Builder(
    builder: (c) => TextButton(
      onPressed: () => ErrorPresenter.show(
        c,
        const NetworkException('x', code: 'deletion-impossible'),
        actionLabel: 'Go',
        onAction: () {},
      ),
      child: const Text('trigger'),
    ),
  ),
  locale: locale,
);

void main() {
  testWidgets('erreur critique : bouton Fermer en français', (tester) async {
    await tester.pumpWidget(_trigger(AppL10n.fr));
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    expect(find.text('Fermer'), findsOneWidget);
  });

  testWidgets('erreur critique : bouton Close en anglais', (tester) async {
    await tester.pumpWidget(_trigger(AppL10n.en));
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsOneWidget);
    expect(find.text("Can't delete"), findsOneWidget);
  });

  test('resolve : l10n anglais explicite → titre anglais', () {
    final p = ErrorPresenter.resolve(
      const ConflictException('x', code: 'currency-mismatch'),
      l10n: lookupAppLocalizations(AppL10n.en),
    );
    expect(p.title, 'Different currency');
  });
}
