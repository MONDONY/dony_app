import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/presentation/widgets/flight_loading_view.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

Widget _host({
  bool reduceMotion = false,
  Locale locale = AppL10n.fr,
  VoidCallback? onBack,
}) => localizedApp(
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Scaffold(
        body: FlightLoadingView(
          routeChip: 'PAR ↔ ABJ · 12 déc. – 3 janv. · 1 pers.',
          destinationName: 'Abidjan',
          onBack: onBack ?? () {},
        ),
      ),
    ),
  ),
  locale: locale,
);

void main() {
  testWidgets(
    'rappel du trajet, titre, étapes qui avancent pendant l\'attente',
    (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump();

      expect(
        find.text('PAR ↔ ABJ · 12 déc. – 3 janv. · 1 pers.'),
        findsOneWidget,
      );
      expect(find.text('Recherche de vols vers Abidjan'), findsOneWidget);
      expect(
        find.text('On compare les prix des compagnies pour vous'),
        findsOneWidget,
      );
      expect(find.text('Bon à savoir'), findsOneWidget);
      expect(
        find.byKey(const Key('flights-loading-step-0-now')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('flights-loading-step-2-wait')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        find.byKey(const Key('flights-loading-step-0-done')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('flights-loading-step-1-now')),
        findsOneWidget,
      );

      await tester.pump(FlightLoadingView.stepsDuration);
      expect(
        find.byKey(const Key('flights-loading-step-1-done')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('flights-loading-step-2-now')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // L'anneau tourne en boucle : on démonte l'écran pour l'arrêter.
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('réduction des animations : l\'anneau ne tourne pas', (
    tester,
  ) async {
    await tester.pumpWidget(_host(reduceMotion: true));
    // Sans boucle, l'écran se pose.
    await tester.pumpAndSettle();
    final rotation = tester.widget<RotationTransition>(
      find.descendant(
        of: find.byType(FlightLoadingView),
        matching: find.byType(RotationTransition),
      ),
    );
    expect(rotation.turns.value, 0);
  });

  testWidgets('en-tête Yadony au-dessus de la scène : « Billets » centré, '
      'scarabée, le chevron abandonne la recherche', (tester) async {
    var back = 0;
    await tester.pumpWidget(_host(reduceMotion: true, onBack: () => back++));
    await tester.pumpAndSettle();

    expect(find.byType(DonyAppBar), findsOneWidget);
    expect(find.text('Billets'), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isTrue);
    expect(find.byType(DonyFeedbackButton), findsOneWidget);
    // La scène de nuit commence sous l'en-tête.
    expect(
      tester.getTopLeft(find.byKey(const Key('flights-loading'))).dy,
      tester.getBottomLeft(find.byType(AppBar)).dy,
    );

    await tester.tap(find.byType(DonyAppBarBackButton));
    expect(back, 1);
  });

  testWidgets('en anglais', (tester) async {
    enableEnglish();
    await tester.pumpWidget(_host(locale: const Locale('en')));
    await tester.pump();
    expect(find.text('Searching flights to Abidjan'), findsOneWidget);
    expect(find.text('Direct flights'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
