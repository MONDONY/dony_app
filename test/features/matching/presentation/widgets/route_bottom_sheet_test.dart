import 'package:dony/core/constants/cities.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/route_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _ann(String dep, String arr, {String id = 'a1'}) =>
    AnnouncementModel(
      id: id,
      travelerId: 't1',
      departureCity: dep,
      arrivalCity: arr,
      departureDate: DateTime(2026, 6, 15),
      availableKg: 8,
      pricePerKg: 12,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      traveler: TravelerProfile(id: 't1', displayName: 'Sékou Ba', kiloPro: false),
    );

final _paris = CityConstants.findById('paris')!;
final _dakar = CityConstants.findById('dakar')!;
final _abidjan = CityConstants.findById('abidjan')!;

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
      GoRoute(path: '/search/:id', builder: (_, __) => const Scaffold()),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('RouteBottomSheet', () {
    final announcements = [
      _ann('Paris', 'Dakar', id: 'a1'),
      _ann('Paris', 'Dakar', id: 'a2'),
      _ann('Paris', 'Abidjan', id: 'a3'),
      _ann('Lyon', 'Dakar', id: 'a4'),
    ];

    testWidgets('ExactRouteFilter shows only Paris→Dakar trips', (tester) async {
      await tester.pumpWidget(_wrap(RouteBottomSheet(
        announcements: announcements,
        filter: ExactRouteFilter(_paris, _dakar),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a1')), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a2')), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a4')), findsNothing);
    });

    testWidgets('DepartureCityFilter shows trips from Paris only', (tester) async {
      await tester.pumpWidget(_wrap(RouteBottomSheet(
        announcements: announcements,
        filter: DepartureCityFilter(_paris),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Départs depuis Paris'), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a1')), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a3')), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a4')), findsNothing);
    });

    testWidgets('ArrivalCityFilter shows trips to Dakar only', (tester) async {
      await tester.pumpWidget(_wrap(RouteBottomSheet(
        announcements: announcements,
        filter: ArrivalCityFilter(_dakar),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Arrivées à Dakar'), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a1')), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a4')), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a3')), findsNothing);
    });

    testWidgets('ExactRouteFilter Paris→Abidjan shows a3 only', (tester) async {
      await tester.pumpWidget(_wrap(RouteBottomSheet(
        announcements: announcements,
        filter: ExactRouteFilter(_paris, _abidjan),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('traveler-card-a3')), findsOneWidget);
    });

    testWidgets('shows empty message when filter matches nothing', (tester) async {
      await tester.pumpWidget(_wrap(RouteBottomSheet(
        announcements: const [],
        filter: ExactRouteFilter(_paris, _dakar),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Aucun trajet disponible sur cette route'), findsOneWidget);
    });
  });
}
