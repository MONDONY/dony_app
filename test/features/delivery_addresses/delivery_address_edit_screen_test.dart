import 'package:dio/dio.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_bloc.dart';
import 'package:dony/features/delivery_addresses/data/models/delivery_address.dart';
import 'package:dony/features/delivery_addresses/data/repositories/delivery_address_repository.dart';
import 'package:dony/features/delivery_addresses/presentation/screens/delivery_address_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements DeliveryAddressRepository {}

class _MockDio extends Mock implements Dio {}

Widget _wrap(DeliveryAddressBloc bloc) => MaterialApp(
      home: BlocProvider.value(
        value: bloc,
        child: const DeliveryAddressEditScreen(),
      ),
    );

void main() {
  late _MockRepo repo;
  late DeliveryAddressBloc bloc;

  setUpAll(() {
    // Register AddressAutocompleteService in GetIt for widget tests
    if (!getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.registerLazySingleton<AddressAutocompleteService>(
        () => AddressAutocompleteService(dio: _MockDio()),
      );
    }
  });

  setUp(() {
    repo = _MockRepo();
    when(() => repo.getAll()).thenAnswer((_) async => <DeliveryAddress>[]);
    bloc = DeliveryAddressBloc(repo);
  });

  tearDown(() => bloc.close());

  testWidgets('chips Famille/Maison/Boutique are rendered', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Famille'), findsOneWidget);
    expect(find.text('Maison'), findsOneWidget);
    expect(find.text('Boutique'), findsOneWidget);
  });

  testWidgets('default country is Sénégal', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Sénégal'), findsOneWidget);
  });

  testWidgets('CTA button is present', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text("Enregistrer l'adresse"), findsOneWidget);
  });
}
