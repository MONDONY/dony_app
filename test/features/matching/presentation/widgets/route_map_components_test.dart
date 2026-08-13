import 'package:dony/features/matching/presentation/widgets/route_map_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData.light(useMaterial3: true),
  home: Scaffold(body: child),
);

void main() {
  group('RouteMapCard', () {
    testWidgets('renders departure and arrival city codes', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RouteMapCard(
            departureCode: 'CDG',
            arrivalCode: 'DSS',
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
          ),
        ),
      );

      expect(find.textContaining('Paris'), findsOneWidget);
      expect(find.textContaining('CDG'), findsOneWidget);
      expect(find.textContaining('Dakar'), findsOneWidget);
      expect(find.textContaining('DSS'), findsOneWidget);
    });

    testWidgets('renders CustomPaint for the dashed route line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RouteMapCard(
            departureCode: 'LYS',
            arrivalCode: 'ABJ',
            departureCity: 'Lyon',
            arrivalCity: 'Abidjan',
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('CityChip', () {
    testWidgets('displays cityCode · airportCode text', (tester) async {
      await tester.pumpWidget(
        _wrap(const CityChip(cityCode: 'MRS', airportCode: 'MRS')),
      );

      expect(find.text('MRS · MRS'), findsOneWidget);
    });
  });
}
