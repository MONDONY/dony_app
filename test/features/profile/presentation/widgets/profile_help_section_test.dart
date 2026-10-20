import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/store_review_service.dart';
import 'package:dony/features/profile/presentation/widgets/profile_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockStoreReview extends Mock implements StoreReviewService {}

Widget _app() => localizedApp(
  const Scaffold(body: SingleChildScrollView(child: ProfileHelpSection())),
);

void main() {
  late _MockStoreReview storeReview;

  setUp(() {
    storeReview = _MockStoreReview();
    when(
      () => storeReview.openStoreListing(source: any(named: 'source')),
    ).thenAnswer((_) async => true);
    getIt.registerSingleton<StoreReviewService>(storeReview);
  });

  tearDown(() => getIt.unregister<StoreReviewService>());

  testWidgets('la tuile « Noter Yadony » ouvre la fiche du Store', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('Noter Yadony'), findsOneWidget);
    expect(
      find.text("Votre avis aide d'autres personnes à nous trouver"),
      findsOneWidget,
    );

    await tester.tap(find.text('Noter Yadony'));
    await tester.pump();

    verify(() => storeReview.openStoreListing(source: 'profile')).called(1);
  });

  testWidgets('sans service enregistré, la tuile ne plante pas', (
    tester,
  ) async {
    getIt.unregister<StoreReviewService>();
    addTearDown(() => getIt.registerSingleton<StoreReviewService>(storeReview));

    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.text('Noter Yadony'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
