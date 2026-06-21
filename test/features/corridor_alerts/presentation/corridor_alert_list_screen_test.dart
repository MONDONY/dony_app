import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_list_bloc.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/corridor_alert_list_screen.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockListBloc
    extends MockBloc<CorridorAlertListEvent, CorridorAlertListState>
    implements CorridorAlertListBloc {}

CorridorAlertModel _alert(
  String id, {
  bool active = true,
  int matches = 3,
  AlertDirection direction = AlertDirection.travelerWantsPackages,
}) =>
    CorridorAlertModel(
      id: id,
      departureCity: 'Paris',
      arrivalCity: 'Bamako',
      active: active,
      matchCount: matches,
      direction: direction,
      createdAt: DateTime(2026, 6, 20),
    );

CorridorAlertModel _alertWithFilters(String id) => CorridorAlertModel(
      id: id,
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      active: true,
      matchCount: 0,
      createdAt: DateTime(2026, 6, 20),
      dateFrom: DateTime(2026, 6, 20),
      dateTo: DateTime(2026, 6, 30),
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
    AlertDirection direction = AlertDirection.travelerWantsPackages,
  }) =>
      MaterialApp(
        theme: AppTheme.light,
        home: CorridorAlertListScreen(direction: direction),
      );

  testWidgets('loaded → renders a tile per alert with matchCount badge',
      (t) async {
    when(() => bloc.state).thenReturn(CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [_alert('a1'), _alert('a2')],
    ));
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(CorridorAlertTile), findsNWidgets(2));
    expect(find.textContaining('Paris → Bamako'), findsNWidgets(2));
  });

  testWidgets('empty → CTA créer une alerte', (t) async {
    when(() => bloc.state).thenReturn(const CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [],
    ));
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(DonyEmptyState), findsOneWidget);
  });

  testWidgets('tap toggle → dispatches CorridorAlertActiveToggled',
      (t) async {
    when(() => bloc.state).thenReturn(CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [_alert('a1', active: true)],
    ));
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.byType(Switch));
    await t.pump();
    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(captured.any((e) => e is CorridorAlertActiveToggled), isTrue);
  });

  testWidgets('FAB present for creating an alert', (t) async {
    when(() => bloc.state).thenReturn(CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [_alert('a1')],
    ));
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('swipe left on tile → dispatches CorridorAlertDeleted with alert id',
      (t) async {
    when(() => bloc.state).thenReturn(CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [_alert('a1'), _alert('a2')],
    ));
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

  testWidgets('tile WITH filters shows compact filter summary', (t) async {
    final alert = _alertWithFilters('b1');
    when(() => bloc.state).thenReturn(CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [alert],
    ));
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    // Summary must contain date range, weight and categories.
    expect(find.textContaining('≥ 3 kg'), findsOneWidget);
    expect(find.textContaining('Documents'), findsOneWidget);
  });

  testWidgets('tile WITHOUT filters shows neutral fallback', (t) async {
    when(() => bloc.state).thenReturn(CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [_alert('c1')],
    ));
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Toute date · tout poids'), findsOneWidget);
  });

  testWidgets(
      'travelerWantsPackages screen hides senderWantsTrips alerts (filter)',
      (t) async {
    when(() => bloc.state).thenReturn(CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [
        _alert('a1', direction: AlertDirection.travelerWantsPackages),
        _alert('a2', direction: AlertDirection.senderWantsTrips),
      ],
    ));
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    // Only the travelerWantsPackages alert is visible on this screen.
    expect(find.byType(CorridorAlertTile), findsOneWidget);
    // Titre direction-aware.
    expect(find.text('Mes alertes colis'), findsOneWidget);
  });

  testWidgets(
      'senderWantsTrips screen shows only senderWantsTrips alerts (filter)',
      (t) async {
    when(() => bloc.state).thenReturn(CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [
        _alert('a1', direction: AlertDirection.travelerWantsPackages),
        _alert('a2', direction: AlertDirection.senderWantsTrips),
      ],
    ));
    await t.pumpWidget(pump(direction: AlertDirection.senderWantsTrips));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(CorridorAlertTile), findsOneWidget);
    // Titre direction-aware.
    expect(find.text('Mes alertes trajets'), findsOneWidget);
  });
}
