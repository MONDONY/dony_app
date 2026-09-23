import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_detail_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

void main() {
  testWidgets('se construit et s annonce comme chargement', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: RequestDetailSkeleton()),
      ),
    );
    expect(find.bySemanticsLabel('Chargement de ta demande'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('écran traduit en anglais : libellé d\'accessibilité', (
    tester,
  ) async {
    useEnglish();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: RequestDetailSkeleton()),
      ),
    );
    expect(find.bySemanticsLabel('Loading your request'), findsOneWidget);
    semantics.dispose();
  });
}
