import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_form_cubit.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockFormCubit extends MockCubit<CorridorAlertFormState>
    implements CorridorAlertFormCubit {}

class MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

void main() {
  late MockFormCubit cubit;
  late MockCitySearchBloc cityBloc;

  setUp(() {
    cubit = MockFormCubit();
    cityBloc = MockCitySearchBloc();
    when(() => cityBloc.state).thenReturn(const CitySearchInitial());
    when(() => cubit.isEditing).thenReturn(false);

    if (GetIt.I.isRegistered<CorridorAlertFormCubit>()) {
      GetIt.I.unregister<CorridorAlertFormCubit>();
    }
    if (GetIt.I.isRegistered<CitySearchBloc>()) {
      GetIt.I.unregister<CitySearchBloc>();
    }

    // Sheet resolves cubit via getIt with a factoryParam.
    GetIt.I.registerFactoryParam<CorridorAlertFormCubit, dynamic, void>(
        (editing, _) => cubit);
    // Form body needs a CitySearchBloc per autocomplete field.
    GetIt.I.registerFactory<CitySearchBloc>(() => cityBloc);
  });

  tearDown(() => GetIt.I.reset());

  testWidgets('submit button is disabled while corridor is invalid',
      (t) async {
    when(() => cubit.state)
        .thenReturn(const CorridorAlertFormState()); // invalid
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => CorridorAlertFormSheet.show(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    // The sticky submit button exists but is disabled (DonyButton with null onPressed).
    final submit = find.byKey(const Key('corridor-alert-submit'));
    expect(submit, findsOneWidget);
    // Tapping should NOT call submit() because onPressed is null.
    await t.tap(submit, warnIfMissed: false);
    await t.pump();
    verifyNever(() => cubit.submit());
  });

  testWidgets('submit button enabled when valid → calls submit()',
      (t) async {
    when(() => cubit.state).thenReturn(const CorridorAlertFormState(
      departureCity: 'Paris',
      arrivalCity: 'Bamako',
    ));
    when(() => cubit.submit()).thenAnswer((_) async {});
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => CorridorAlertFormSheet.show(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('corridor-alert-submit')));
    await t.pump();
    verify(() => cubit.submit()).called(1);
  });
}
