import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/zone_picker_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

Widget _host({
  LatLng? center,
  int radiusKm = 25,
  String? label,
  required Future<String?> Function(double, double) geocode,
  required void Function(double, double, int, String?) onChanged,
}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: ZonePickerField(
      initialCenter: center ?? const LatLng(48.85, 2.35),
      initialRadiusKm: radiusKm,
      initialLabel: label,
      reverseGeocode: geocode,
      onChanged: onChanged,
    ),
  ),
);

void main() {
  setUp(() {
    final cityBloc = MockCitySearchBloc();
    when(() => cityBloc.state).thenReturn(const CitySearchInitial());
    if (GetIt.I.isRegistered<CitySearchBloc>()) {
      GetIt.I.unregister<CitySearchBloc>();
    }
    GetIt.I.registerFactory<CitySearchBloc>(() => cityBloc);
  });

  tearDown(() => GetIt.I.reset());

  testWidgets('shows the city field and "ma position" button', (tester) async {
    await tester.pumpWidget(
      _host(geocode: (lat, lng) async => null, onChanged: (_, _, _, _) {}),
    );
    await tester.pump();

    expect(find.byKey(const Key('zone-city-field')), findsOneWidget);
    expect(find.byKey(const Key('zone-locate-me')), findsOneWidget);
    expect(find.text('Utiliser ma position'), findsOneWidget);
  });

  testWidgets('emits initial zone on mount + reverse-geocoded label', (
    tester,
  ) async {
    final calls = <(double, double, int, String?)>[];
    await tester.pumpWidget(
      _host(
        center: const LatLng(48.85, 2.35),
        geocode: (lat, lng) async => 'Lyon',
        onChanged: (lat, lng, r, label) => calls.add((lat, lng, r, label)),
      ),
    );
    await tester.pump(); // postFrame initial emit

    expect(calls, isNotEmpty);
    expect(calls.first.$1, 48.85);
    expect(calls.first.$2, 2.35);
    expect(calls.first.$3, 25);

    // Reverse-geocode debounce (500 ms) → label émis.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(calls.last.$4, 'Lyon');
  });

  testWidgets('radius slider increases radius via onChanged', (tester) async {
    final radii = <int>[];
    await tester.pumpWidget(
      _host(
        geocode: (lat, lng) async => null,
        onChanged: (lat, lng, r, label) => radii.add(r),
      ),
    );
    await tester.pump();

    await tester.drag(
      find.byKey(const Key('zone-radius-slider')),
      const Offset(400, 0),
    );
    await tester.pump();

    expect(radii.last, greaterThan(25));
  });

  testWidgets('clamps initialRadiusKm into [5,300]', (tester) async {
    final radii = <int>[];
    await tester.pumpWidget(
      _host(
        radiusKm: 999,
        geocode: (lat, lng) async => null,
        onChanged: (lat, lng, r, label) => radii.add(r),
      ),
    );
    await tester.pump();

    expect(radii.first, 300);
  });

  testWidgets('renders the radius label', (tester) async {
    await tester.pumpWidget(
      _host(
        radiusKm: 40,
        geocode: (lat, lng) async => null,
        onChanged: (_, _, _, _) {},
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('zone-radius-label')), findsOneWidget);
    expect(find.text('40 km'), findsOneWidget);
  });
}
