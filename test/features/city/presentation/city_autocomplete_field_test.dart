import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCitySearchBloc
    extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

void main() {
  late MockCitySearchBloc mockBloc;

  setUp(() {
    mockBloc = MockCitySearchBloc();
    when(() => mockBloc.state).thenReturn(const CitySearchInitial());
  });

  Widget buildWidget({void Function(CityModel)? onSelected}) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<CitySearchBloc>.value(
          value: mockBloc,
          child: CityAutocompleteField(
            label: 'Ville de départ',
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('affiche le label correctement', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Ville de départ'), findsOneWidget);
  });

  testWidgets('affiche les résultats quand état est Loaded', (tester) async {
    when(() => mockBloc.state).thenReturn(
      const CitySearchLoaded([
        CityModel(
          name: 'Dakar',
          countryCode: 'SN',
          countryName: 'Sénégal',
          lat: 14.71,
          lng: -17.47,
        ),
      ]),
    );

    await tester.pumpWidget(buildWidget());
    // Avancer le temps pour laisser les animations se terminer
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Dakar'), findsOneWidget);
    expect(find.text('Sénégal'), findsOneWidget);
  });

  testWidgets('appelle onSelected quand on tape sur un résultat', (tester) async {
    CityModel? selected;
    const city = CityModel(
      name: 'Dakar',
      countryCode: 'SN',
      countryName: 'Sénégal',
      lat: 14.71,
      lng: -17.47,
    );
    when(() => mockBloc.state).thenReturn(const CitySearchLoaded([city]));

    await tester.pumpWidget(buildWidget(onSelected: (c) => selected = c));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Dakar'));
    await tester.pump();
    expect(selected?.name, 'Dakar');
  });

  testWidgets('affiche LinearProgressIndicator quand état est Loading',
      (tester) async {
    when(() => mockBloc.state).thenReturn(const CitySearchLoading());

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
