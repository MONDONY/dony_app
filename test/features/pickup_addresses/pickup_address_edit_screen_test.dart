import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:dony/features/pickup_addresses/data/repositories/pickup_address_repository.dart';
import 'package:dony/features/pickup_addresses/presentation/screens/pickup_address_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PickupAddressRepository {}

class _MockAutocompleteService extends Mock
    implements AddressAutocompleteService {}

Widget _wrap(PickupAddressBloc bloc) => MaterialApp(
      home: BlocProvider.value(
        value: bloc,
        child: const PickupAddressEditScreen(),
      ),
    );

void main() {
  late _MockRepo repo;
  late PickupAddressBloc bloc;

  setUpAll(() {
    // Register mock AddressAutocompleteService in GetIt so the screen can build.
    if (!getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.registerSingleton<AddressAutocompleteService>(
        _MockAutocompleteService(),
      );
    }
  });

  setUp(() {
    repo = _MockRepo();
    when(() => repo.getAll()).thenAnswer((_) async => <PickupAddress>[]);
    bloc = PickupAddressBloc(repo);
  });

  tearDown(() => bloc.close());

  testWidgets('chips Maison/Bureau/Atelier are rendered', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Maison'), findsOneWidget);
    expect(find.text('Bureau'), findsOneWidget);
    expect(find.text('Atelier'), findsOneWidget);
  });

  testWidgets('tapping chip fills the label field', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bureau'));
    await tester.pump();

    // Le champ étiquette doit contenir 'Bureau'
    final textFields =
        tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    final labelField = textFields.firstWhere(
      (tf) => tf.controller.text == 'Bureau',
      orElse: () => throw TestFailure('Aucun champ texte avec "Bureau"'),
    );
    expect(labelField.controller.text, 'Bureau');
  });

  testWidgets('CTA button is present', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text("Enregistrer l'adresse"), findsOneWidget);
  });
}
