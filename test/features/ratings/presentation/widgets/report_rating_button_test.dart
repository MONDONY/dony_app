import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/presentation/widgets/report_rating_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

RatingItem _item({String? id = 'rating-1', String? comment = 'Très mauvais'}) =>
    RatingItem(
      id: id,
      stars: 1,
      comment: comment,
      createdAt: DateTime(2026, 10, 2),
      excluded: false,
    );

void main() {
  Map<String, dynamic>? pushedExtra;

  Widget app(RatingItem item) => MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Center(child: ReportRatingButton(item: item)),
          ),
        ),
        GoRoute(
          path: '/settings/report-incident',
          builder: (_, state) {
            pushedExtra = state.extra as Map<String, dynamic>?;
            return const Scaffold(body: Text('Écran de signalement'));
          },
        ),
      ],
    ),
  );

  setUp(() => pushedExtra = null);

  group('ReportRatingButton', () {
    testWidgets('ouvre le signalement avec la cible RATING', (tester) async {
      await tester.pumpWidget(app(_item()));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Signaler cet avis'), findsOneWidget);
      await tester.tap(find.byTooltip('Signaler cet avis'));
      await tester.pumpAndSettle();

      expect(find.text('Écran de signalement'), findsOneWidget);
      expect(pushedExtra?['targetType'], IncidentTargetType.rating);
      expect(pushedExtra?['targetId'], 'rating-1');
    });

    testWidgets('zone tactile d\'au moins 44 pt', (tester) async {
      await tester.pumpWidget(app(_item()));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('masqué sans identifiant (back antérieur)', (tester) async {
      await tester.pumpWidget(app(_item(id: null)));
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('masqué pour un avis sans commentaire', (tester) async {
      await tester.pumpWidget(app(_item(comment: '  ')));
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsNothing);
    });
  });
}
