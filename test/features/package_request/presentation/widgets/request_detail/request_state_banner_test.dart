import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_state_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('titre et message', (tester) async {
    for (final tone in RequestBannerTone.values) {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: Scaffold(body: RequestStateBanner(
        tone: tone, icon: 'info', title: 'Pas encore visible', message: 'Publie ta demande.'))));
      expect(find.text('Pas encore visible'), findsOneWidget);
      expect(find.text('Publie ta demande.'), findsOneWidget);
    }
  });
}
