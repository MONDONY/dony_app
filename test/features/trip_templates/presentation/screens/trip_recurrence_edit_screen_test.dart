// Tests de TripRecurrenceEditScreen — garde « pas de prix au kilo » (constat
// #3) : cet écran n'a pas de champ prix éditable, une récurrence issue d'un
// modèle « grille seule » ne doit donc jamais pouvoir être créée avec un prix
// à 0.

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/presentation/screens/trip_recurrence_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockTripRecurrenceBloc
    extends MockBloc<TripRecurrenceEvent, TripRecurrenceState>
    implements TripRecurrenceBloc {}

class _MockAutocompleteService extends Mock
    implements AddressAutocompleteService {}

Widget _wrap(Widget child, TripRecurrenceBloc bloc) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: BlocProvider<TripRecurrenceBloc>.value(value: bloc, child: child),
  ),
  theme: AppTheme.light(),
);

TripTemplate _template({required double? pricePerKg}) => TripTemplate(
  id: 't1',
  label: 'Paris → Dakar',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  transportMode: 'PLANE',
  capacityUnit: 'SUITCASE_23KG',
  availableKg: 23,
  pricePerKg: pricePerKg,
  acceptedCategories: const ['Vêtements'],
);

void main() {
  late _MockTripRecurrenceBloc bloc;

  setUpAll(() {
    if (!getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.registerSingleton<AddressAutocompleteService>(
        _MockAutocompleteService(),
      );
    }
  });

  setUp(() {
    bloc = _MockTripRecurrenceBloc();
    when(() => bloc.state).thenReturn(const TripRecurrenceState());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('modèle sans prix au kilo : message affiché et CTA désactivé', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripRecurrenceEditScreen(template: _template(pricePerKg: null)),
        bloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Ce modèle n'a pas de prix au kilo"), findsOneWidget);
    final button = tester.widget<DonyButton>(
      find.widgetWithText(DonyButton, 'Activer la récurrence'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('modèle avec prix au kilo : pas de message de garde', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
        bloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Ce modèle n'a pas de prix au kilo"), findsNothing);
  });

  testWidgets('anglais : titre et avertissement traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        TripRecurrenceEditScreen(template: _template(pricePerKg: null)),
        bloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Recurring trip'), findsOneWidget);
    expect(find.text('This template has no price per kg'), findsOneWidget);
  });

  testWidgets('anglais : bouton et bloc actif traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
        bloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Make it a recurring trip'), findsOneWidget);
    expect(find.text('Recurring trip on'), findsOneWidget);
    expect(find.text('Automatically posts upcoming trips'), findsOneWidget);
  });

  /// `_weekdayLabels` (initiales des jours, lundi → dimanche) est calculé via
  /// `DateFormat.EEEEE(locale)` : ce test fige le rendu français (identique à
  /// l'ancien motif codé en dur `['L', 'M', 'M', 'J', 'V', 'S', 'D']`).
  testWidgets('initiales des jours en français : L, M, M, J, V, S, D', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
        bloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final letters = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s.length == 1)
        .toList();

    expect(letters, ['L', 'M', 'M', 'J', 'V', 'S', 'D']);
  });

  testWidgets('initiales des jours en anglais : M, T, W, T, F, S, S', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
        bloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final letters = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s.length == 1)
        .toList();

    expect(letters, ['M', 'T', 'W', 'T', 'F', 'S', 'S']);
  });
}
