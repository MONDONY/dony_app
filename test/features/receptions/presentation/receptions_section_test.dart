import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/receptions/bloc/receptions_cubit.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/receptions/presentation/widgets/receptions_section.dart';
import 'package:dony/features/tracking/presentation/widgets/route_label.dart';
import 'package:dony/features/tracking/presentation/widgets/shipment_progress_bar.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/plane_icon_expectations.dart';

class _MockReceptionsCubit extends MockCubit<ReceptionsState>
    implements ReceptionsCubit {}

const _pending = Reception(
  bidId: 'p1',
  linkStatus: 'PENDING',
  bidStatus: 'ACCEPTED',
  senderFirstName: 'Awa',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
);

const _confirmed = Reception(
  bidId: 'c1',
  linkStatus: 'CONFIRMED',
  bidStatus: 'IN_TRANSIT',
  trackingNumber: 'DON-AB12CD',
);

void main() {
  late _MockReceptionsCubit cubit;

  setUp(() {
    cubit = _MockReceptionsCubit();
    when(() => cubit.load()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, ReceptionsState state) async {
    when(() => cubit.state).thenReturn(state);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: BlocProvider<ReceptionsCubit>.value(
              value: cubit,
              child: const SingleChildScrollView(child: ReceptionsSection()),
            ),
          ),
        ),
        GoRoute(
          path: '/receptions/:bidId',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(true),
              child: Text('page ${state.pathParameters['bidId']}'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (label, state) in [
    ('chargement initial', const ReceptionsLoading()),
    ('erreur (ancien back)', const ReceptionsError(NotFoundException())),
    ('liste vide', const ReceptionsLoaded([])),
  ]) {
    testWidgets('$label : section invisible', (tester) async {
      await pump(tester, state);
      expect(find.byKey(const Key('receptions-section')), findsNothing);
      expect(
        find.textContaining('Colis à recevoir', findRichText: true),
        findsNothing,
      );
    });
  }

  testWidgets('colis à confirmer et colis confirmé', (tester) async {
    await pump(tester, const ReceptionsLoaded([_pending, _confirmed]));

    expect(find.byKey(const Key('receptions-section')), findsOneWidget);
    expect(
      find.textContaining('Colis à recevoir', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('À confirmer'), findsOneWidget);
    expect(find.text('De Awa'), findsOneWidget);
    // Sans trajet connu, le numéro de suivi sert de titre.
    expect(find.text('DON-AB12CD'), findsOneWidget);
    expect(find.text('En route'), findsOneWidget);
    // Barre de progression seulement pour un colis confirmé.
    expect(find.byType(ShipmentProgressBar), findsOneWidget);
  });

  testWidgets('le corridor porte le mode de la réception, neutre sans mode', (
    tester,
  ) async {
    const boat = Reception(
      bidId: 'b1',
      linkStatus: 'CONFIRMED',
      bidStatus: 'IN_TRANSIT',
      departureCity: 'Marseille',
      arrivalCity: 'Dakar',
      transportMode: TransportMode.boat,
    );
    const unknown = Reception(
      bidId: 'u1',
      linkStatus: 'CONFIRMED',
      bidStatus: 'IN_TRANSIT',
      departureCity: 'Paris',
      arrivalCity: 'Abidjan',
    );
    await pump(tester, const ReceptionsLoaded([boat, unknown]));

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RouteLabel &&
            w.from == 'Marseille' &&
            w.transportMode == TransportMode.boat,
      ),
      findsOneWidget,
    );
    expect(findDonyIcon('ship'), findsOneWidget);
    expect(findDonyIcon('route'), findsOneWidget);
    expectNoPlaneIcon(tester);
  });

  testWidgets('colis bateau : étape courte du bateau, autre mode inchangé', (
    tester,
  ) async {
    const boat = Reception(
      bidId: 'b1',
      linkStatus: 'CONFIRMED',
      bidStatus: 'IN_TRANSIT',
      departureCity: 'Marseille',
      arrivalCity: 'Dakar',
      transportMode: TransportMode.boat,
    );
    const toDrop = Reception(
      bidId: 'b2',
      linkStatus: 'CONFIRMED',
      bidStatus: 'ACCEPTED',
      departureCity: 'Marseille',
      arrivalCity: 'Dakar',
      transportMode: TransportMode.boat,
    );
    const road = Reception(
      bidId: 'r1',
      linkStatus: 'CONFIRMED',
      bidStatus: 'IN_TRANSIT',
      departureCity: 'Paris',
      arrivalCity: 'Lyon',
      transportMode: TransportMode.car,
    );
    await pump(tester, const ReceptionsLoaded([boat, toDrop, road]));

    expect(find.text('En mer'), findsOneWidget);
    expect(find.text('À déposer'), findsOneWidget);
    expect(find.text('En route'), findsOneWidget);
    expectNoPlaneIcon(tester);
  });

  testWidgets('tap : ouvre le colis puis recharge la liste au retour', (
    tester,
  ) async {
    await pump(tester, const ReceptionsLoaded([_pending]));

    await tester.tap(find.byKey(const Key('reception-row-p1')));
    await tester.pumpAndSettle();
    expect(find.text('page p1'), findsOneWidget);

    await tester.tap(find.text('page p1'));
    await tester.pumpAndSettle();
    verify(() => cubit.load()).called(1);
  });

  testWidgets('anglais : libellés traduits', (tester) async {
    when(() => cubit.state).thenReturn(const ReceptionsLoaded([_pending]));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: BlocProvider<ReceptionsCubit>.value(
              value: cubit,
              child: const ReceptionsSection(),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        locale: AppL10n.en,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Parcels coming to you', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('To confirm'), findsOneWidget);
    expect(find.text('From Awa'), findsOneWidget);
  });
}
