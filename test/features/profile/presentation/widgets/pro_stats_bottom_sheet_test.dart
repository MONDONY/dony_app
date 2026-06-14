import 'package:dony/features/profile/data/models/pro_stats_model.dart';
import 'package:dony/features/profile/presentation/widgets/pro_stats_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _kStats = ProStatsModel(
  monthlyRevenue: 1250.50,
  totalRevenue: 8400.0,
  monthlyTrips: 3,
  monthlyParcelsDelivered: 12,
  acceptanceRate: 0.92,
  averageRating: 4.7,
  topDestinations: [
    DestinationStatModel(from: 'Paris', to: 'Dakar', count: 2),
    DestinationStatModel(from: 'Lyon', to: 'Abidjan', count: 1),
  ],
);

const _kNoDestinations = ProStatsModel(
  monthlyRevenue: 0.0,
  totalRevenue: 0.0,
  monthlyTrips: 0,
  monthlyParcelsDelivered: 0,
  acceptanceRate: 0.0,
  averageRating: 0.0,
  topDestinations: [],
);

Widget _buildSheet(ProStatsModel stats) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: ProStatsBottomSheet(stats: stats)),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  group('ProStatsBottomSheet', () {
    testWidgets('affiche les revenus mensuels formatés', (tester) async {
      await tester.pumpWidget(_buildSheet(_kStats));
      await tester.pumpAndSettle();

      // L'espace dans le formatage fr_FR peut être un espace insécable — on cherche "250"
      expect(find.textContaining('250'), findsWidgets);
    });

    testWidgets('affiche le nombre de trajets et colis', (tester) async {
      await tester.pumpWidget(_buildSheet(_kStats));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Trajets'), findsOneWidget);
      expect(find.text('Colis livrés'), findsOneWidget);
    });

    testWidgets('affiche les revenus total', (tester) async {
      await tester.pumpWidget(_buildSheet(_kStats));
      await tester.pumpAndSettle();

      // L'espace dans "8 400" peut être insécable selon le locale fr_FR
      expect(find.textContaining('400'), findsOneWidget);
      expect(find.text('Revenus total (depuis le début)'), findsOneWidget);
    });

    testWidgets('affiche la section PERFORMANCE', (tester) async {
      await tester.pumpWidget(_buildSheet(_kStats));
      await tester.pumpAndSettle();

      expect(find.text('PERFORMANCE'), findsOneWidget);
      expect(find.text("Taux d'acceptation"), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('Note moyenne'), findsOneWidget);
      expect(find.text('4.7 / 5.0 ★'), findsOneWidget);
    });

    testWidgets('affiche la section TOP DESTINATIONS', (tester) async {
      await tester.pumpWidget(_buildSheet(_kStats));
      await tester.pumpAndSettle();

      expect(find.text('TOP DESTINATIONS'), findsOneWidget);
      expect(find.textContaining('Paris → Dakar'), findsOneWidget);
      expect(find.textContaining('Lyon → Abidjan'), findsOneWidget);
      // DonyBadge applique toUpperCase() sur le label
      expect(find.text('2 TRAJETS'), findsOneWidget);
      expect(find.text('1 TRAJET'), findsOneWidget);
    });

    testWidgets('cache la section TOP DESTINATIONS si vide', (tester) async {
      await tester.pumpWidget(_buildSheet(_kNoDestinations));
      await tester.pumpAndSettle();

      expect(find.text('TOP DESTINATIONS'), findsNothing);
    });

    testWidgets('affiche — pour rating à zéro', (tester) async {
      await tester.pumpWidget(_buildSheet(_kNoDestinations));
      await tester.pumpAndSettle();

      expect(find.text('— / 5.0'), findsOneWidget);
    });

    testWidgets('affiche les barres de progression', (tester) async {
      await tester.pumpWidget(_buildSheet(_kStats));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });
  });

  group('ProStatsModel.fromJson', () {
    test('désérialise correctement', () {
      final json = {
        'monthlyRevenue': 1250.50,
        'totalRevenue': 8400.0,
        'monthlyTrips': 3,
        'monthlyParcelsDelivered': 12,
        'acceptanceRate': 0.92,
        'averageRating': 4.7,
        'topDestinations': [
          {'from': 'Paris', 'to': 'Dakar', 'count': 2},
        ],
      };
      final model = ProStatsModel.fromJson(json);
      expect(model.monthlyRevenue, 1250.50);
      expect(model.monthlyTrips, 3);
      expect(model.topDestinations, hasLength(1));
      expect(model.topDestinations.first.from, 'Paris');
    });

    test('tolère des revenus entiers dans le JSON', () {
      final json = {
        'monthlyRevenue': 1000,
        'totalRevenue': 5000,
        'monthlyTrips': 1,
        'monthlyParcelsDelivered': 5,
        'acceptanceRate': 1,
        'averageRating': 5,
        'topDestinations': <dynamic>[],
      };
      final model = ProStatsModel.fromJson(json);
      expect(model.monthlyRevenue, 1000.0);
      expect(model.acceptanceRate, 1.0);
    });
  });
}
