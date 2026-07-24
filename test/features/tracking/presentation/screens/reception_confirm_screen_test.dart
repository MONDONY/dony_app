import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/tracking/presentation/screens/reception_confirm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

GoRouter _buildRouter({String bidId = 'bid-001', String travelerName = 'Ibrahima'}) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ReceptionConfirmScreen(
          bidId: bidId,
          travelerName: travelerName,
        ),
      ),
      GoRoute(
        path: '/bids/:bidId',
        builder: (_, __) => const Scaffold(body: Text('bid detail')),
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, {String travelerName = 'Ibrahima'}) async {
  await tester.pumpWidget(MaterialApp.router(
    theme: AppTheme.light,
    routerConfig: _buildRouter(travelerName: travelerName),
  ));
  await tester.pump(const Duration(milliseconds: 900)); // drain mascotte confiant animation
}

void main() {
  group('ReceptionConfirmScreen', () {
    testWidgets('shows Confirmer la réception title', (tester) async {
      await _pump(tester);
      // Both the Caveat title and the CTA button share this text
      expect(find.text('Confirmer la réception'), findsWidgets);
    });

    testWidgets('shows traveler name in subtitle', (tester) async {
      await _pump(tester, travelerName: 'Fatou');
      expect(find.textContaining('Fatou'), findsWidgets);
    });

    testWidgets('shows both tab options', (tester) async {
      await _pump(tester);
      expect(find.text('Lire le QR'), findsOneWidget);
      expect(find.text('Taper le code'), findsOneWidget);
    });

    testWidgets('defaults to code tab showing OPTION 2 · CODE', (tester) async {
      await _pump(tester);
      expect(find.text('OPTION 2 · CODE'), findsOneWidget);
    });

    testWidgets('CTA is disabled when code is empty', (tester) async {
      await _pump(tester);
      final filledBtn = tester.widget<InkWell>(
        find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)),
      );
      expect(filledBtn.onTap, isNull);
    });

    testWidgets('CTA is enabled after entering 6-digit code', (tester) async {
      await _pump(tester);

      final pinput = find.byType(Pinput);
      await tester.enterText(pinput, '472135');
      await tester.pump();

      final filledBtn = tester.widget<InkWell>(
        find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)),
      );
      expect(filledBtn.onTap, isNotNull);
    });

    testWidgets('CTA remains disabled with fewer than 6 digits', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(Pinput), '4721');
      await tester.pump();

      final filledBtn = tester.widget<InkWell>(
        find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)),
      );
      expect(filledBtn.onTap, isNull);
    });

    testWidgets('timer shows initial countdown', (tester) async {
      await _pump(tester);
      // "15:00" is the initial display matching _kInitialSeconds = 900 (15 min)
      expect(find.textContaining('15:00'), findsOneWidget);
    });

    testWidgets('timer decrements after 1 second', (tester) async {
      await _pump(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('14:59'), findsOneWidget);
    });

    testWidgets('switching to QR tab hides code input', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Lire le QR'));
      await tester.pump();
      expect(find.text('OPTION 2 · CODE'), findsNothing);
      expect(find.text('Lire le QR code'), findsOneWidget);
    });

    testWidgets('legal note mentions traveler name', (tester) async {
      await _pump(tester, travelerName: 'Ibrahima');
      expect(find.textContaining('Ibrahima'), findsWidgets);
    });
  });
}
