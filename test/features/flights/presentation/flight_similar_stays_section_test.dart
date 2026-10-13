import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/flights/bloc/flight_link_cubit.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/presentation/widgets/flight_similar_stays_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../bloc/flights_test_doubles.dart';

class _MockLauncher extends Mock implements ExternalUrlLauncher {}

FlightOffer _offer(String path, {String? back}) => FlightOffer.fromJson({
  'originCode': 'PAR',
  'destinationCode': 'ABJ',
  'departureAt': '2026-11-20T11:45:00+01:00',
  'returnAt': ?back,
  'price': 612,
  'currency': 'EUR',
  'offerPath': path,
});

Widget _host(
  FlightSimilarStaysSection section, {
  ThemeData? theme,
  Locale locale = AppL10n.fr,
}) => MaterialApp(
  theme: theme,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider(
    create: (_) => FlightLinkCubit(
      MockFlightsRepository(),
      silentAnalytics(),
      _MockLauncher(),
    ),
    child: Scaffold(body: SingleChildScrollView(child: section)),
  ),
);

void main() {
  testWidgets('sans plage connue : titre générique, pas de pastille', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(FlightSimilarStaysSection(offers: [_offer('a')], range: null)),
    );
    expect(find.text('Séjours de durée proche'), findsOneWidget);
    expect(find.byKey(const Key('flight-offer-stay')), findsNothing);
  });

  testWidgets('une seule durée : « Séjours de 28 jours », clair et sombre', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await tester.pumpWidget(
        _host(
          FlightSimilarStaysSection(
            offers: [_offer('a', back: '2026-12-18T20:10:00+00:00')],
            range: (min: 28, max: 28),
          ),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Séjours de 28 jours'), findsOneWidget);
      expect(find.text('28 j'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Séjour de 28 jours')),
        findsOneWidget,
      );
      final tag = tester.widget<Container>(
        find.byKey(const Key('flight-offer-stay')),
      );
      expect(
        (tag.decoration! as BoxDecoration).color,
        theme.colorScheme.secondaryContainer,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('en anglais : un jour au singulier', (tester) async {
    enableEnglish();
    await tester.pumpWidget(
      _host(
        FlightSimilarStaysSection(
          offers: [_offer('a', back: '2026-11-21T20:10:00+00:00')],
          range: (min: 1, max: 1),
        ),
        locale: const Locale('en'),
      ),
    );
    expect(find.text('1 day trip'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
  });
}
