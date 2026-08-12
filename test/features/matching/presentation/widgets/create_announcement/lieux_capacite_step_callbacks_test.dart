// Tests complémentaires de couverture pour LieuxCapaciteStep :
// couvre les callbacks onPickupChanged / onDeliveryChanged et la structure du widget.
//
// Après migration AddressPickerField → AddressSelectorField, la sélection
// d'adresse se fait via des bottom sheets (PickupAddressPickerSheet /
// DeliveryAddressPickerSheet) et non via un TextField avec autocomplete.
// Les callbacks sont testés en invoquant directement onChanged sur les widgets.
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_selector_field.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  void Function(AddressData? addr)? onPickupChanged,
  void Function(AddressData? addr)? onDeliveryChanged,
  void Function(AddressData? addr)? onPickupSaved,
  void Function(AddressData? addr)? onDeliverySaved,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<AnnouncementFormBloc>(
        create: (_) => AnnouncementFormBloc(),
        child: Form(
          child: SingleChildScrollView(
            child: LieuxCapaciteStep(
              onPickupSaved: onPickupSaved ?? (_) {},
              onDeliverySaved: onDeliverySaved ?? (_) {},
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

    testWidgets('le texte descriptif des lieux est affiché', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(
        find.textContaining("Précisez l'endroit exact"),
        findsOneWidget,
      );
    });

    testWidgets('les deux AddressSelectorField sont présents et cliquables',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      final fields = find.byType(AddressSelectorField);
      expect(fields, findsNWidgets(2));
    });

    testWidgets(
        'AddressSelectorField remise affiche le prompt quand value est null',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Choisir une adresse de remise'), findsOneWidget);
    });

    testWidgets(
        'AddressSelectorField livraison affiche le prompt quand value est null',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Choisir une adresse de livraison'), findsOneWidget);
    });

    testWidgets('onPickupChanged et onPickupSaved sont appelés via le onChanged du widget',
        (tester) async {
      AddressData? capturedChanged;
      AddressData? capturedSaved;
      const address =
          AddressData(label: 'Paris, France', lat: 48.85, lng: 2.35);

      await tester.pumpWidget(_host(
        onPickupChanged: (addr) => capturedChanged = addr,
        onPickupSaved: (addr) => capturedSaved = addr,
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      // Invoquer directement le onChanged du premier AddressSelectorField (remise)
      final fields = tester
          .widgetList<AddressSelectorField>(find.byType(AddressSelectorField))
          .toList();
      fields.first.onChanged(address);

      expect(capturedChanged?.label, equals('Paris, France'));
      expect(capturedSaved?.label, equals('Paris, France'));
    });

    testWidgets('onDeliveryChanged et onDeliverySaved sont appelés via le onChanged du widget',
        (tester) async {
      AddressData? capturedChanged;
      AddressData? capturedSaved;
      const address =
          AddressData(label: 'Dakar, Sénégal', lat: 14.69, lng: -17.44);

      await tester.pumpWidget(_host(
        onDeliveryChanged: (addr) => capturedChanged = addr,
        onDeliverySaved: (addr) => capturedSaved = addr,
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      // Invoquer directement le onChanged du second AddressSelectorField (livraison)
      final fields = tester
          .widgetList<AddressSelectorField>(find.byType(AddressSelectorField))
          .toList();
      fields.last.onChanged(address);

      expect(capturedChanged?.label, equals('Dakar, Sénégal'));
      expect(capturedSaved?.label, equals('Dakar, Sénégal'));
    });
  });
}
