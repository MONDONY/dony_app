import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/tracking/presentation/screens/reception_confirm_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../helpers/l10n_test_helpers.dart';

GoRouter _buildRouter({
  String bidId = 'bid-001',
  String travelerName = 'Ibrahima',
}) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            ReceptionConfirmScreen(bidId: bidId, travelerName: travelerName),
      ),
      GoRoute(
        path: '/bids/:bidId',
        builder: (_, _) => const Scaffold(body: Text('bid detail')),
      ),
      GoRoute(
        path: '/disputes',
        builder: (_, _) => const Scaffold(body: Text('disputes screen')),
      ),
    ],
  );
}

/// Parcourt tous les `Text.rich` de l'arbre et retourne le premier `TextSpan`
/// dont le texte exact vaut [text] — y compris un span imbriqué (`children`).
/// Permet de vérifier le style/`recognizer` du segment mis en valeur par
/// `emphasizedSpans`, pas seulement sa présence textuelle.
TextSpan? _findSpan(WidgetTester tester, String text) {
  TextSpan? found;
  void visit(InlineSpan span) {
    if (found != null) return;
    if (span is TextSpan) {
      if (span.text == text) {
        found = span;
        return;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child);
      }
    }
  }

  for (final element in find.byType(Text).evaluate()) {
    final textSpan = (element.widget as Text).textSpan;
    if (textSpan != null) visit(textSpan);
  }
  return found;
}

Future<void> _pump(
  WidgetTester tester, {
  String travelerName = 'Ibrahima',
}) async {
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: _buildRouter(travelerName: travelerName),
    ),
  );
  await tester.pump(
    const Duration(milliseconds: 900),
  ); // drain mascotte confiant animation
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
        find.descendant(
          of: find.byType(DonyButton),
          matching: find.byType(InkWell),
        ),
      );
      expect(filledBtn.onTap, isNull);
    });

    testWidgets('CTA is enabled after entering 6-digit code', (tester) async {
      await _pump(tester);

      final pinput = find.byType(Pinput);
      await tester.enterText(pinput, '472135');
      await tester.pump();

      final filledBtn = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(DonyButton),
          matching: find.byType(InkWell),
        ),
      );
      expect(filledBtn.onTap, isNotNull);
    });

    testWidgets('CTA remains disabled with fewer than 6 digits', (
      tester,
    ) async {
      await _pump(tester);

      await tester.enterText(find.byType(Pinput), '4721');
      await tester.pump();

      final filledBtn = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(DonyButton),
          matching: find.byType(InkWell),
        ),
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
      await _pump(tester);
      expect(find.textContaining('Ibrahima'), findsWidgets);
    });

    testWidgets('title and tabs are translated in English', (tester) async {
      useEnglish();
      await _pump(tester);
      expect(find.text('Confirmation'), findsOneWidget);
      expect(find.text('Confirm receipt'), findsWidgets);
      expect(find.text('Scan QR'), findsOneWidget);
      expect(find.text('Enter code'), findsOneWidget);
      expect(find.textContaining('contest first'), findsWidgets);
    });

    group('mise en forme du minuteur (emphasizedSpans)', () {
      testWidgets('le minuteur reste en gras — fr', (tester) async {
        await _pump(tester);

        final span = _findSpan(tester, '15:00');
        expect(span, isNotNull, reason: 'le span du minuteur doit exister');
        expect(span!.style?.fontWeight, FontWeight.w700);
      });

      testWidgets('le minuteur reste en gras — en', (tester) async {
        useEnglish();
        await _pump(tester);

        final span = _findSpan(tester, '15:00');
        expect(span, isNotNull, reason: 'le span du minuteur doit exister');
        expect(span!.style?.fontWeight, FontWeight.w700);
      });
    });

    group('lien « contestez d\'abord » (emphasizedSpans)', () {
      testWidgets('porte un recognizer et navigue vers /disputes — fr', (
        tester,
      ) async {
        await _pump(tester);

        final span = _findSpan(tester, 'contestez d\'abord');
        expect(span, isNotNull, reason: 'le span du lien doit exister');
        expect(span!.style?.decoration, TextDecoration.underline);
        expect(span.recognizer, isA<TapGestureRecognizer>());

        (span.recognizer as TapGestureRecognizer).onTap!();
        await tester.pumpAndSettle();

        expect(find.text('disputes screen'), findsOneWidget);
      });

      testWidgets('porte un recognizer et navigue vers /disputes — en', (
        tester,
      ) async {
        useEnglish();
        await _pump(tester);

        final span = _findSpan(tester, 'contest first');
        expect(span, isNotNull, reason: 'le span du lien doit exister');
        expect(span!.style?.decoration, TextDecoration.underline);
        expect(span.recognizer, isA<TapGestureRecognizer>());

        (span.recognizer as TapGestureRecognizer).onTap!();
        await tester.pumpAndSettle();

        expect(find.text('disputes screen'), findsOneWidget);
      });
    });
  });
}
