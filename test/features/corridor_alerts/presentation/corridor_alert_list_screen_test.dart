import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_list_bloc.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/corridor_alert_list_screen.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_card.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class MockListBloc
    extends MockBloc<CorridorAlertListEvent, CorridorAlertListState>
    implements CorridorAlertListBloc {}

// ContextualTutorialCard (contexte corridorAlerts) lit HelpCenterBloc via
// context.select : sans ce provider, context.select lève
// ProviderNotFoundException dès le premier pump.
const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

Widget _withHelpCenter(Widget child) => BlocProvider<HelpCenterBloc>(
  create: (_) => HelpCenterBloc(
    HelpCenterRepository(
      const _StaticHelpCenterSource(_emptyHelpConfigJson),
      fallbackJsonLoader: () async => _emptyHelpConfigJson,
    ),
    makeDisabledAnalytics(MockAnalyticsBackend()),
  )..add(const HelpCenterLoadRequested()),
  child: child,
);

CorridorAlertModel _alert(
  String id, {
  bool active = true,
  int matches = 3,
  int fresh = 0,
  AlertDirection direction = AlertDirection.travelerWantsPackages,
  String arrival = 'Bamako',
}) => CorridorAlertModel(
  id: id,
  departureCity: 'Paris',
  arrivalCity: arrival,
  active: active,
  matchCount: matches,
  newMatchCount: fresh,
  direction: direction,
  createdAt: DateTime(2026, 6, 20),
);

CorridorAlertModel _alertWithFilters(String id) => CorridorAlertModel(
  id: id,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  active: true,
  createdAt: DateTime(2026, 6, 20),
  dateFrom: DateTime(2026, 6, 20),
  dateTo: DateTime(2099, 6, 30),
  minWeightKg: 3.0,
  contentCategories: const ['Documents', 'Vêtements'],
);

void main() {
  late MockListBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const CorridorAlertDeleted('x'));
    registerFallbackValue(const CorridorAlertActiveToggled('x', false));
  });

  setUp(() {
    bloc = MockListBloc();
    if (GetIt.I.isRegistered<CorridorAlertListBloc>()) {
      GetIt.I.unregister<CorridorAlertListBloc>();
    }
    GetIt.I.registerFactory<CorridorAlertListBloc>(() => bloc);
  });

  tearDown(() => GetIt.I.reset());

  Widget pump({
    AlertDirection? direction = AlertDirection.travelerWantsPackages,
  }) => MaterialApp(
    theme: AppTheme.light(),
    home: _withHelpCenter(CorridorAlertListScreen(direction: direction)),
  );

  void loaded(List<CorridorAlertModel> alerts) =>
      when(() => bloc.state).thenReturn(
        CorridorAlertListState(
          status: CorridorAlertListStatus.loaded,
          alerts: alerts,
        ),
      );

  testWidgets('loaded → une carte par alerte', (t) async {
    loaded([_alert('a1'), _alert('a2')]);
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(CorridorAlertCard), findsNWidgets(2));
    expect(find.textContaining('Paris → Bamako'), findsNWidgets(2));
  });

  testWidgets('loading sans donnée → squelettes', (t) async {
    when(() => bloc.state).thenReturn(
      const CorridorAlertListState(status: CorridorAlertListStatus.loading),
    );
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(DonyListCardSkeleton), findsNWidgets(4));
    expect(find.byType(CorridorAlertCard), findsNothing);
  });

  testWidgets('erreur sans donnée → état d\'erreur, Réessayer recharge', (
    t,
  ) async {
    when(() => bloc.state).thenReturn(
      const CorridorAlertListState(
        status: CorridorAlertListStatus.error,
        errorMessage: 'boom',
      ),
    );
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Erreur de chargement'), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);

    await t.tap(find.text('Réessayer'));
    await t.pump();
    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(captured.any((e) => e is CorridorAlertListRequested), isTrue);
  });

  testWidgets('erreur avec données déjà là → les cartes restent', (t) async {
    when(() => bloc.state).thenReturn(
      CorridorAlertListState(
        status: CorridorAlertListStatus.error,
        alerts: [_alert('a1')],
        errorMessage: 'boom',
      ),
    );
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(CorridorAlertCard), findsOneWidget);
    expect(find.text('Erreur de chargement'), findsNothing);
  });

  testWidgets('empty → CTA créer une alerte', (t) async {
    when(() => bloc.state).thenReturn(
      const CorridorAlertListState(status: CorridorAlertListStatus.loaded),
    );
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(DonyEmptyState), findsOneWidget);
  });

  testWidgets('FAB present for creating an alert', (t) async {
    loaded([_alert('a1')]);
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('swipe left on card → dispatches CorridorAlertDeleted', (
    t,
  ) async {
    loaded([_alert('a1'), _alert('a2')]);
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    await t.drag(find.byType(Dismissible).first, const Offset(-500, 0));
    await t.pumpAndSettle();
    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(
      captured.any((e) => e is CorridorAlertDeleted && e.id == 'a1'),
      isTrue,
    );
  });

  testWidgets('menu ⋯ → « Mettre en pause » dispatches toggle false', (
    t,
  ) async {
    loaded([_alert('a1')]);
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.byKey(const Key('alert-card-menu-a1')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('alert-action-pause')), findsOneWidget);
    expect(find.byKey(const Key('alert-action-resume')), findsNothing);
    await t.tap(find.byKey(const Key('alert-action-pause')));
    await t.pumpAndSettle();
    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(
      captured.any(
        (e) => e is CorridorAlertActiveToggled && e.id == 'a1' && !e.active,
      ),
      isTrue,
    );
  });

  testWidgets('menu ⋯ d\'une alerte en pause → « Reprendre » et suppression', (
    t,
  ) async {
    loaded([_alert('a1', active: false)]);
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.byKey(const Key('alert-card-menu-a1')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('alert-action-resume')), findsOneWidget);
    await t.tap(find.byKey(const Key('alert-action-delete')));
    await t.pumpAndSettle();
    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(
      captured.any((e) => e is CorridorAlertDeleted && e.id == 'a1'),
      isTrue,
    );
  });

  testWidgets('« Reprendre » sur la carte en pause → toggle true', (t) async {
    loaded([_alert('a1', active: false)]);
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.text('Reprendre'));
    await t.pump();
    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(
      captured.any(
        (e) => e is CorridorAlertActiveToggled && e.id == 'a1' && e.active,
      ),
      isTrue,
    );
  });

  testWidgets('card WITH filters shows weight and categories as chips', (
    t,
  ) async {
    loaded([_alertWithFilters('b1')]);
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('≥ 3 kg'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Vêtements'), findsOneWidget);
  });

  testWidgets('card WITHOUT filters shows neutral chips', (t) async {
    loaded([_alert('c1')]);
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Toute date'), findsOneWidget);
    expect(find.text('Tout poids'), findsOneWidget);
  });

  testWidgets('nouveautés visibles sur la carte', (t) async {
    loaded([_alert('n1', fresh: 2)]);
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('2 nouveaux colis'), findsOneWidget);
  });

  testWidgets(
    'travelerWantsPackages screen hides senderWantsTrips alerts (filter)',
    (t) async {
      loaded([
        _alert('a1'),
        _alert('a2', direction: AlertDirection.senderWantsTrips),
      ]);
      await t.pumpWidget(pump());
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(CorridorAlertCard), findsOneWidget);
      expect(find.text('Mes alertes colis'), findsOneWidget);
      // Écran mono-direction : pas d'en-tête de groupe.
      expect(find.text('COLIS SURVEILLÉS'), findsNothing);
    },
  );

  testWidgets(
    'senderWantsTrips screen shows only senderWantsTrips alerts (filter)',
    (t) async {
      loaded([
        _alert('a1'),
        _alert('a2', direction: AlertDirection.senderWantsTrips),
      ]);
      await t.pumpWidget(pump(direction: AlertDirection.senderWantsTrips));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(CorridorAlertCard), findsOneWidget);
      expect(find.text('Mes alertes trajets'), findsOneWidget);
    },
  );

  testWidgets('hub (sans direction) : groupes trajets puis colis', (t) async {
    loaded([
      _alert('p1'),
      _alert(
        't1',
        direction: AlertDirection.senderWantsTrips,
        arrival: 'Dakar',
      ),
    ]);
    await t.pumpWidget(pump(direction: null));
    await t.pump(const Duration(milliseconds: 600));

    expect(find.text('Mes alertes'), findsOneWidget);
    expect(find.byType(CorridorAlertCard), findsNWidgets(2));
    final trips = t.getTopLeft(find.text('TRAJETS SURVEILLÉS'));
    final packages = t.getTopLeft(find.text('COLIS SURVEILLÉS'));
    final dakar = t.getTopLeft(find.text('Paris → Dakar'));
    final bamako = t.getTopLeft(find.text('Paris → Bamako'));
    expect(trips.dy, lessThan(dakar.dy));
    expect(dakar.dy, lessThan(packages.dy));
    expect(packages.dy, lessThan(bamako.dy));
  });

  testWidgets('hub avec une seule direction : un seul en-tête', (t) async {
    loaded([_alert('p1'), _alert('p2')]);
    await t.pumpWidget(pump(direction: null));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('COLIS SURVEILLÉS'), findsOneWidget);
    expect(find.text('TRAJETS SURVEILLÉS'), findsNothing);
  });
}
