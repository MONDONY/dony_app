// Tests complémentaires de couverture pour LieuxCapaciteStep :
// couvre les callbacks onPickupChanged / onDeliveryChanged (lignes 75-80, 93-98).
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/address_suggestion.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAddressAutocompleteService2 extends Mock
    implements AddressAutocompleteService {}

late MockAddressAutocompleteService2 _mockSvc;

Widget _host({
  void Function(AddressData? addr)? onPickupChanged,
  void Function(AddressData? addr)? onDeliveryChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<AnnouncementFormBloc>(
        create: (_) => AnnouncementFormBloc(),
        child: Form(
          child: SingleChildScrollView(
            child: LieuxCapaciteStep(
              onPickupSaved: (_) {},
              onDeliverySaved: (_) {},
              onPickupChanged: onPickupChanged ?? (_) {},
              onDeliveryChanged: onDeliveryChanged ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    _mockSvc = MockAddressAutocompleteService2();
    when(() => _mockSvc.search(any(), any())).thenAnswer((_) async => []);
    when(() => _mockSvc.resolvePlace(any(), any())).thenAnswer((_) async =>
        const AddressData(label: 'Paris, France', lat: 48.85, lng: 2.35));

    if (!getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.registerSingleton<AddressAutocompleteService>(_mockSvc);
    }
  });

  group('LieuxCapaciteStep callbacks', () {
    testWidgets('se construit correctement avec tous les callbacks', (tester) async {
      AddressData? capturedPickup;
      AddressData? capturedDelivery;

      await tester.pumpWidget(_host(
        onPickupChanged: (addr) => capturedPickup = addr,
        onDeliveryChanged: (addr) => capturedDelivery = addr,
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.byType(LieuxCapaciteStep), findsOneWidget);
      // Les callbacks sont enregistrés — pas encore appelés
      expect(capturedPickup, isNull);
      expect(capturedDelivery, isNull);
    });

    testWidgets('les champs de lieu ont le bon placeholder/label', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      // Le label de chaque champ est visible
      expect(find.text('Lieu de remise du colis *'), findsOneWidget);
      expect(find.text('Lieu de récupération *'), findsOneWidget);
    });

    testWidgets('le texte descriptif des lieux est affiché', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(
        find.textContaining("Précisez l'endroit exact"),
        findsOneWidget,
      );
    });

    testWidgets('onPickupChanged est appelé quand une suggestion est sélectionnée',
        (tester) async {
      // Préparer le mock pour retourner une suggestion
      const suggestion = AddressSuggestion(
        placeId: 'place-1',
        mainText: 'Paris',
        secondaryText: 'France',
      );
      when(() => _mockSvc.search(any(), any()))
          .thenAnswer((_) async => [suggestion]);
      when(() => _mockSvc.resolvePlace('place-1', any())).thenAnswer(
          (_) async => const AddressData(label: 'Paris, France', lat: 48.85, lng: 2.35));

      AddressData? capturedPickup;
      await tester.pumpWidget(_host(
        onPickupChanged: (addr) => capturedPickup = addr,
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      // Trouver le premier champ de texte (Lieu de remise)
      final textFields = find.byType(TextField);
      await tester.tap(textFields.first);
      await tester.pump();

      // Saisir du texte pour déclencher la recherche
      await tester.enterText(textFields.first, 'Par');
      // Attendre le debounce (300ms) + traitement
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 200));

      // La suggestion apparaît dans l'overlay
      expect(find.text('Paris'), findsOneWidget);

      // Taper sur la suggestion
      await tester.tap(find.text('Paris'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      // Le callback onPickupChanged a été appelé
      expect(capturedPickup?.label, equals('Paris, France'));

      // Reset mock pour les tests suivants
      when(() => _mockSvc.search(any(), any())).thenAnswer((_) async => []);
    });

    testWidgets('onDeliveryChanged est appelé quand une suggestion est sélectionnée',
        (tester) async {
      // Préparer le mock pour retourner une suggestion
      const suggestion = AddressSuggestion(
        placeId: 'place-2',
        mainText: 'Dakar',
        secondaryText: 'Sénégal',
      );
      when(() => _mockSvc.search(any(), any()))
          .thenAnswer((_) async => [suggestion]);
      when(() => _mockSvc.resolvePlace('place-2', any())).thenAnswer(
          (_) async => const AddressData(label: 'Dakar, Sénégal', lat: 14.69, lng: -17.44));

      AddressData? capturedDelivery;
      await tester.pumpWidget(_host(
        onDeliveryChanged: (addr) => capturedDelivery = addr,
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      // Trouver le deuxième champ (Lieu de récupération)
      final textFields = find.byType(TextField);
      await tester.tap(textFields.at(1));
      await tester.pump();

      await tester.enterText(textFields.at(1), 'Dak');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 200));

      // La suggestion apparaît
      expect(find.text('Dakar'), findsOneWidget);

      // Taper sur la suggestion
      await tester.tap(find.text('Dakar'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      // Le callback onDeliveryChanged a été appelé
      expect(capturedDelivery?.label, equals('Dakar, Sénégal'));

      // Reset mock
      when(() => _mockSvc.search(any(), any())).thenAnswer((_) async => []);
    });
  });
}
