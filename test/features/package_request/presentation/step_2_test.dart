// Step 2 widget test — catégories multiples (chips multi + input libre + ajout).
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_2_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockPackageRepo extends Mock implements PackageRequestRepository {}

void main() {
  late _MockPackageRepo packageRepo;

  setUp(() {
    packageRepo = _MockPackageRepo();
  });

  Widget wrap(Widget child) => MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => PackageRequestFormBloc(
            packageRepo,
            analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
          ),
        ),
        BlocProvider(
          create: (_) => PackageRequestPhotosCubit(
            packageRepo,
            makeDisabledAnalytics(MockAnalyticsBackend()),
          ),
        ),
      ],
      child: Scaffold(body: child),
    ),
  );

  group('Step2Details — catégories multiples', () {
    testWidgets('input catégorie + bouton « + » toujours visibles', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const Step2Details()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('custom-category-input')), findsOneWidget);
      expect(find.byKey(const Key('add-category-btn')), findsOneWidget);
    });

    testWidgets('chips prédéfinies en multi-sélection', (tester) async {
      await tester.pumpWidget(wrap(const Step2Details()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Vêtements'));
      await tester.tap(find.text('Vêtements'));
      await tester.pump();
      await tester.ensureVisible(find.text('Documents'));
      await tester.tap(find.text('Documents'));
      await tester.pump();
      // Les deux restent affichées (pas d'exclusivité).
      expect(find.text('Vêtements'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
    });

    testWidgets(
      'ajouter une catégorie libre via « + » crée une chip supprimable',
      (tester) async {
        await tester.pumpWidget(wrap(const Step2Details()));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('custom-category-input')),
          'Textile brodé',
        );
        await tester.ensureVisible(find.byKey(const Key('add-category-btn')));
        await tester.tap(find.byKey(const Key('add-category-btn')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('remove-cat-Textile brodé')),
          findsOneWidget,
        );
        expect(find.text('Textile brodé'), findsOneWidget);
      },
    );

    testWidgets('retirer une catégorie libre', (tester) async {
      await tester.pumpWidget(wrap(const Step2Details()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('custom-category-input')),
        'Fragile',
      );
      await tester.ensureVisible(find.byKey(const Key('add-category-btn')));
      await tester.tap(find.byKey(const Key('add-category-btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remove-cat-Fragile')), findsOneWidget);
      await tester.tap(find.byKey(const Key('remove-cat-Fragile')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remove-cat-Fragile')), findsNothing);
    });
  });
}
