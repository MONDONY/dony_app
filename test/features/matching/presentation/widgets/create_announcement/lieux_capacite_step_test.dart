// Tests de LieuxCapaciteStep — étape 1 du formulaire "Publier un trajet".
//
// Après migration AddressPickerField → AddressSelectorField, les tests vérifient :
//   - présence de deux AddressSelectorField (remise + livraison)
//   - types corrects (AddressSelectorType.remise / .livraison)
//   - affichage des valeurs initiales (label des AddressData)
//   - présence du CapacityControl
//   - libellés de section en casse normale
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_selector_field.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/capacity_control.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

/// Construit le widget sous test à l'intérieur d'un arbre minimal valide.
/// AddressSelectorField n'utilise pas getIt directement dans build() —
/// il ouvre des sheets via GestureDetector → pas besoin de mock GetIt ici.
Widget _host({
  AddressData? initialPickupAddress,
  AddressData? initialDeliveryAddress,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<AnnouncementFormBloc>(
        create: (_) => AnnouncementFormBloc(
          analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        ),
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
  await tester.pumpWidget(
    _host(
      initialPickupAddress: initialPickupAddress,
      initialDeliveryAddress: initialDeliveryAddress,
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
}

void main() {
  group('LieuxCapaciteStep', () {
    testWidgets('se construit sans exception', (tester) async {
      await _pumpHost(tester);
      expect(find.byType(LieuxCapaciteStep), findsOneWidget);
    });

    testWidgets('deux AddressSelectorField sont présents', (tester) async {
      await _pumpHost(tester);
      expect(find.byType(AddressSelectorField), findsNWidgets(2));
    });

    testWidgets('AddressSelectorField remise a le bon type', (tester) async {
      await _pumpHost(tester);
      final fields = tester
          .widgetList<AddressSelectorField>(find.byType(AddressSelectorField))
          .toList();
      expect(fields.length, 2);
      expect(fields.first.type, equals(AddressSelectorType.remise));
    });

    testWidgets('AddressSelectorField livraison a le bon type', (tester) async {
      await _pumpHost(tester);
      final fields = tester
          .widgetList<AddressSelectorField>(find.byType(AddressSelectorField))
          .toList();
      expect(fields.length, 2);
      expect(fields.last.type, equals(AddressSelectorType.livraison));
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

    testWidgets(
      'les libellés de section sont en casse normale (pas en majuscules intégrales)',
      (tester) async {
        await _pumpHost(tester);
        expect(
          find.text('Lieux de remise'),
          findsOneWidget,
          reason: 'Le libellé doit être en casse normale, pas en MAJUSCULES',
        );
        expect(
          find.text('Capacité disponible'),
          findsAtLeastNWidgets(1),
          reason: 'Le libellé doit être en casse normale, pas en MAJUSCULES',
        );
        expect(
          find.text('LIEUX DE REMISE'),
          findsNothing,
          reason: 'Les majuscules intégrales ne doivent plus être utilisées',
        );
        expect(
          find.text('CAPACITÉ DISPONIBLE'),
          findsNothing,
          reason: 'Les majuscules intégrales ne doivent plus être utilisées',
        );
      },
    );

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
      },
    );

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
      },
    );

    testWidgets(
      'AddressSelectorField remise reçoit la valeur initiale pickup',
      (tester) async {
        const address = AddressData(
          label: '12 rue Victor Hugo, Lyon',
          lat: 45.748,
          lng: 4.846,
        );
        await _pumpHost(tester, initialPickupAddress: address);
        final fields = tester
            .widgetList<AddressSelectorField>(find.byType(AddressSelectorField))
            .toList();
        expect(fields.first.value, equals(address));
      },
    );

    testWidgets(
      'AddressSelectorField livraison reçoit la valeur initiale delivery',
      (tester) async {
        const address = AddressData(
          label: 'Aéroport CDG, Roissy',
          lat: 49.01,
          lng: 2.55,
        );
        await _pumpHost(tester, initialDeliveryAddress: address);
        final fields = tester
            .widgetList<AddressSelectorField>(find.byType(AddressSelectorField))
            .toList();
        expect(fields.last.value, equals(address));
      },
    );
  });
}
