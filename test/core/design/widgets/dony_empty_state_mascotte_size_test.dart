import 'package:dony/core/design/widgets/dony_empty_state.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

Future<double> _mascotteHeight(
  WidgetTester tester,
  DonyMascotteSize? size,
) async {
  await tester.pumpWidget(
    localizedApp(
      Scaffold(
        body: DonyEmptyState(
          title: 'Titre',
          mascotte: DonyMascotteType.aucunResultat,
          mascotteSize: size ?? DonyMascotteSize.lg,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  return tester.getSize(find.byType(DonyMascotteAnimated)).height;
}

void main() {
  testWidgets('la mascotte suit la taille demandée', (tester) async {
    final large = await _mascotteHeight(tester, null);
    final medium = await _mascotteHeight(tester, DonyMascotteSize.md);
    expect(medium, lessThan(large));
    expect(medium, DonyMascotteSize.md.dimension);
  });
}
