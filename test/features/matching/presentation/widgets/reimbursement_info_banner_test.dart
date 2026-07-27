import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/presentation/widgets/reimbursement_info_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => setDonyReimbursementCap(kDonyReimbursementCapDefault));

  testWidgets('shows configured reimbursement cap and conditions link',
      (tester) async {
    setDonyReimbursementCap(50);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ReimbursementInfoBanner()),
    ));

    expect(find.textContaining('50'), findsWidgets);
    expect(find.textContaining('rembourse'), findsOneWidget);
    expect(find.text('Voir conditions'), findsOneWidget);
  });

  testWidgets('reflects a changed cap value', (tester) async {
    setDonyReimbursementCap(75);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ReimbursementInfoBanner()),
    ));

    expect(find.textContaining('75'), findsWidgets);
  });

  testWidgets('onSeeConditions override is invoked on tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReimbursementInfoBanner(onSeeConditions: () => tapped = true),
      ),
    ));

    await tester.tap(find.text('Voir conditions'));
    expect(tapped, isTrue);
  });
}
