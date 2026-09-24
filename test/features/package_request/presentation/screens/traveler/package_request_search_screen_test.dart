import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/package_request_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockBloc
    extends MockBloc<PackageRequestSearchEvent, PackageRequestSearchState>
    implements PackageRequestSearchBloc {}

PackageRequestSearchItem _item({
  List<String> categories = const [],
  double? targetPriceEur = 30,
}) => PackageRequestSearchItem(
  id: 'r-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 10, 6),
  dateToleranceDays: 3,
  weightKg: 5,
  parcelSize: ParcelSize.small,
  categories: categories,
  targetPriceEur: targetPriceEur,
  sender: const SenderPublicProfile(
    id: 's-1',
    displayName: 'Amina',
    averageRating: 4.8,
    totalRatings: 12,
    kycVerified: true,
  ),
);

void main() {
  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    if (getIt.isRegistered<PackageRequestSearchBloc>()) {
      getIt.unregister<PackageRequestSearchBloc>();
    }
    getIt.registerFactory<PackageRequestSearchBloc>(() => bloc);
  });

  tearDown(() {
    if (getIt.isRegistered<PackageRequestSearchBloc>()) {
      getIt.unregister<PackageRequestSearchBloc>();
    }
  });

  Widget wrap() => MaterialApp(
    theme: AppTheme.light(),
    home: const PackageRequestSearchScreen(),
  );

  testWidgets('en français : titre, champs et carte de résultat', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      PackageRequestSearchState(
        status: SearchStatus.loaded,
        results: [
          _item(categories: const ['Vêtements & tissus']),
        ],
      ),
    );
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<PackageRequestSearchState>.empty());

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Demandes ouvertes'), findsOneWidget);
    expect(find.text('Départ'), findsOneWidget);
    expect(find.text('Arrivée'), findsOneWidget);
    expect(find.text('Vêtements & tissus'), findsOneWidget);
    expect(find.textContaining('Budget:'), findsOneWidget);
    // Bug corrigé : le badge affichait le nom brut de l'enum (SMALL) même en
    // français, faute de passer par ParcelSize.label(l).
    expect(find.text('PETIT'), findsOneWidget);
    expect(find.text('SMALL'), findsNothing);
  });

  testWidgets('état vide : message affiché', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const PackageRequestSearchState(status: SearchStatus.loaded));
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<PackageRequestSearchState>.empty());

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(
      find.text('Aucune demande ne correspond à votre filtre'),
      findsOneWidget,
    );
  });

  testWidgets('en anglais : titre, champs, catégorie et budget traduits', (
    tester,
  ) async {
    useEnglish();
    when(() => bloc.state).thenReturn(
      PackageRequestSearchState(
        status: SearchStatus.loaded,
        results: [
          _item(categories: const ['Vêtements & tissus']),
        ],
      ),
    );
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<PackageRequestSearchState>.empty());

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Open requests'), findsOneWidget);
    expect(find.text('Departure'), findsOneWidget);
    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Clothing & fabrics'), findsOneWidget);
    expect(find.textContaining('Budget:'), findsOneWidget);
    expect(find.text('Demandes ouvertes'), findsNothing);
    expect(find.text('SMALL'), findsOneWidget);
    expect(find.text('PETIT'), findsNothing);
  });

  testWidgets('en anglais : état vide traduit', (tester) async {
    useEnglish();
    when(
      () => bloc.state,
    ).thenReturn(const PackageRequestSearchState(status: SearchStatus.loaded));
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<PackageRequestSearchState>.empty());

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('No request matches your filter'), findsOneWidget);
  });
}
