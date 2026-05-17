// Tests de LieuxCapaciteStep — étape 1 du formulaire "Publier un trajet".
//
// Structure miroir de capacity_control_test.dart (host pattern) et
// create_announcement_cash_toggle_test.dart (GetIt registration pour
// AddressAutocompleteService).
//
// Note sur la dépendance AddressPickerField :
//   Le widget appelle getIt<AddressAutocompleteService>() dans build().
//   La résolution est assurée en enregistrant un MockAddressAutocompleteService
//   dans GetIt via setUpAll(), en suivant le même pattern que
//   create_announcement_cash_toggle_test.dart.
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_picker_field.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/capacity_control.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAddressAutocompleteService extends Mock
    implements AddressAutocompleteService {}

/// Construit le widget sous test à l'intérieur d'un arbre minimal valide :
/// MaterialApp - Scaffold - BlocProvider(AnnouncementFormBloc) - Form -
/// SingleChildScrollView - LieuxCapaciteStep.
///
/// Le Form est nécessaire car AddressPickerField étend FormField.
Widget _host({
  AddressData? initialPickupAddress,
  AddressData? initialDeliveryAddress,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<AnnouncementFormBloc>(
        create: (_) => AnnouncementFormBloc(),
        child: Form(
          child: SingleChildScrollView(
            child: LieuxCapaciteStep(
              initialPickupAddress: initialPickupAddress,
              initialDeliveryAddress: initialDeliveryAddress,
              onPickupSaved: (_) {},
              onDeliverySaved: (_) {},
              onPickupChanged: (_) {},
              onDeliveryChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

/// Pompe le widget et laisse toutes les animations flutter_animate se terminer
/// (fadeIn avec delay 80/90 ms → pump 200 ms suffit).
Future<void> _pumpHost(
  WidgetTester tester, {
  AddressData? initialPickupAddress,
  AddressData? initialDeliveryAddress,
}) async {
  await tester.pumpWidget(_host(
    initialPickupAddress: initialPickupAddress,
    initialDeliveryAddress: initialDeliveryAddress,
  ));
  // Avancer le temps pour que les animations flutter_animate (fadeIn delay ≤ 90 ms)
  // se terminent sans laisser de timers pendants.
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
}

void main() {
  setUpAll(() {
    // Enregistre un mock pour AddressAutocompleteService dans GetIt.
    // LieuxCapaciteStep appelle getIt<AddressAutocompleteService>() dans build()
    // via AddressPickerField ; sans cet enregistrement le test lève une exception.
    if (!getIt.isRegistered<AddressAutocompleteService>()) {
      final mockService = MockAddressAutocompleteService();
      when(() => mockService.search(any(), any())).thenAnswer((_) async => []);
      getIt.registerSingleton<AddressAutocompleteService>(mockService);
    }
  });

  group('LieuxCapaciteStep', () {
    testWidgets('se construit sans exception', (tester) async {
      await _pumpHost(tester);
      // Pas d'exception levée = le widget peut se construire dans le contexte
      // BlocProvider + Form sans dépendance manquante.
      expect(find.byType(LieuxCapaciteStep), findsOneWidget);
    });

    testWidgets('deux AddressPickerField sont présents', (tester) async {
      await _pumpHost(tester);
      // Un champ pour le lieu de remise, un pour le lieu de récupération.
      expect(find.byType(AddressPickerField), findsNWidgets(2));
    });

    testWidgets('label lieu de remise affiché', (tester) async {
      await _pumpHost(tester);
      expect(find.text('Lieu de remise du colis *'), findsOneWidget);
    });

    testWidgets('label lieu de récupération affiché', (tester) async {
      await _pumpHost(tester);
      expect(find.text('Lieu de récupération *'), findsOneWidget);
    });

    testWidgets('CapacityControl est présent', (tester) async {
      await _pumpHost(tester);
      expect(find.byType(CapacityControl), findsOneWidget);
    });

    testWidgets('label de section Lieux de remise affiché', (tester) async {
      await _pumpHost(tester);
      expect(find.text('Lieux de remise'), findsOneWidget);
    });

    testWidgets('label de section Capacité disponible affiché', (tester) async {
      await _pumpHost(tester);
      // CapacityControl affiche aussi "Capacité disponible" en interne → au moins 1 occurrence
      expect(find.text('Capacité disponible'), findsAtLeastNWidgets(1));
    });

    testWidgets('les libellés de section sont en casse normale (pas en majuscules intégrales)',
        (tester) async {
      await _pumpHost(tester);
      // Vérifie que les libellés en casse normale sont présents
      expect(find.text('Lieux de remise'), findsOneWidget,
          reason: 'Le libellé doit être en casse normale, pas en MAJUSCULES');
      // CapacityControl affiche aussi "Capacité disponible" → findsAtLeastNWidgets
      expect(find.text('Capacité disponible'), findsAtLeastNWidgets(1),
          reason: 'Le libellé doit être en casse normale, pas en MAJUSCULES');
      // Vérifie que les anciennes versions en majuscules ne sont plus présentes
      expect(find.text('LIEUX DE REMISE'), findsNothing,
          reason: 'Les majuscules intégrales ne doivent plus être utilisées');
      expect(find.text('CAPACITÉ DISPONIBLE'), findsNothing,
          reason: 'Les majuscules intégrales ne doivent plus être utilisées');
    });

    testWidgets(
        'initialPickupAddress affiche la valeur initiale dans le champ remise',
        (tester) async {
      const address = AddressData(
        label: '12 rue Victor Hugo, Lyon',
        lat: 45.748,
        lng: 4.846,
      );
      await _pumpHost(tester, initialPickupAddress: address);
      expect(find.text('12 rue Victor Hugo, Lyon'), findsOneWidget);
    });

    testWidgets(
        'initialDeliveryAddress affiche la valeur initiale dans le champ récupération',
        (tester) async {
      const address = AddressData(
        label: 'Aéroport CDG, Roissy',
        lat: 49.01,
        lng: 2.55,
      );
      await _pumpHost(tester, initialDeliveryAddress: address);
      expect(find.text('Aéroport CDG, Roissy'), findsOneWidget);
    });
  });
}
