import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/presentation/widgets/airline_logo.dart';
import 'package:dony/features/flights/presentation/widgets/flight_price_ticket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('FlightTicketBorder', () {
    const border = FlightTicketBorder();
    const rect = Rect.fromLTWH(0, 0, 120, 40);

    test('encoches en demi-cercle au milieu des deux côtés', () {
      final path = border.getOuterPath(rect);
      // Le milieu des bords est creusé, le reste du billet est plein.
      expect(path.contains(const Offset(1, 20)), isFalse);
      expect(path.contains(const Offset(119, 20)), isFalse);
      expect(path.contains(const Offset(60, 20)), isTrue);
      expect(path.contains(const Offset(10, 6)), isTrue);
      // Coins arrondis.
      expect(path.contains(const Offset(0.5, 0.5)), isFalse);
      expect(border.getInnerPath(rect).getBounds(), path.getBounds());
    });

    test('dimensions, mise à l\'échelle et égalité', () {
      expect(border.dimensions, EdgeInsets.zero);
      final scaled = border.scale(2) as FlightTicketBorder;
      expect(scaled.radius, 18);
      expect(scaled.notchRadius, 8);
      expect(border, const FlightTicketBorder());
      expect(border.hashCode, const FlightTicketBorder().hashCode);
      expect(border == scaled, isFalse);
      // Rien à peindre : la forme sert de découpe à la décoration.
      border.paint(Canvas(PictureRecorder()), rect);
    });
  });

  testWidgets('trois tons : vert, gris, bleu ; clair et sombre', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final cs = theme.colorScheme;
      for (final (tone, background) in [
        (FlightPriceTicketTone.hit, cs.successLight),
        (FlightPriceTicketTone.neutral, cs.surfaceContainerHighest),
        (FlightPriceTicketTone.create, cs.primaryContainer),
      ]) {
        await tester.pumpWidget(
          _wrap(
            FlightPriceTicket(
              tone: tone,
              label: '389 €',
              caption: tone == FlightPriceTicketTone.create ? null : 'x',
            ),
            theme: theme,
          ),
        );
        // Le changement de thème est animé par MaterialApp.
        await tester.pumpAndSettle();
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(FlightPriceTicket),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = box.decoration as ShapeDecoration;
        expect(decoration.color, background);
        expect(decoration.shape, const FlightTicketBorder());
        expect(
          find.text('x'),
          findsNWidgets(tone == FlightPriceTicketTone.create ? 0 : 1),
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('pile de logos : trois au plus, rien sans code', (tester) async {
    await tester.pumpWidget(
      _wrap(const AirlineLogoStack(codes: ['AT', 'SS', 'AF', 'TK'])),
    );
    expect(find.byType(AirlineLogo), findsNWidgets(3));
    expect(
      tester.getSize(find.byKey(const Key('airline-logo-stack'))).width,
      48,
    );

    await tester.pumpWidget(_wrap(const AirlineLogoStack(codes: [])));
    expect(find.byType(AirlineLogo), findsNothing);
  });

  testWidgets('logo miniature : code réduit à la pastille', (tester) async {
    await tester.pumpWidget(_wrap(const AirlineLogo(code: 'AT', size: 16)));
    final small = tester.widget<Text>(find.text('AT'));
    expect(small.style?.fontSize, closeTo(6.4, 0.01));

    await tester.pumpWidget(_wrap(const AirlineLogo(code: 'AT', size: 24)));
    final regular = tester.widget<Text>(find.text('AT'));
    expect(regular.style?.fontSize, isNot(closeTo(9.6, 0.01)));
  });
}
