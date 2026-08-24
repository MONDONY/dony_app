import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/core/widgets/address/address_section_label.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_suggest_field.dart';
import 'package:flutter/material.dart';

/// Les champs d'une adresse de résidence : rue, code postal, ville.
///
/// Partagés par l'étape « Vos informations » du parcours d'inscription et par
/// l'édition du profil. Cette adresse a un consommateur unique et exigeant —
/// Stripe Connect — qui réclame une rue et un code postal, pas seulement une
/// ville. L'écran de profil ne demandait qu'une ville en texte libre : le
/// compte de paiement n'avait alors rien d'exploitable, et l'activation
/// échouait sans que rien ne l'explique. Un seul composant pour les deux
/// écrans empêche les deux formulaires de diverger à nouveau.
///
/// L'autocomplétion est la même que pour les adresses de retrait et de
/// livraison (proxy backend `/addresses/autocomplete`, une session Google
/// facturée par saisie complète) : choisir une suggestion remplit le code
/// postal et la ville. Le texte libre reste accepté, pour les quartiers que
/// Google couvre mal.
class ResidenceAddressFields extends StatelessWidget {
  const ResidenceAddressFields({
    super.key,
    required this.streetCtrl,
    required this.postalCtrl,
    required this.cityCtrl,
    required this.addressService,
    required this.onAddressResolved,
    this.line2Ctrl,
    this.enabled = true,
    this.showSectionLabel = true,
  });

  final TextEditingController streetCtrl;
  final TextEditingController postalCtrl;
  final TextEditingController cityCtrl;

  /// Complément d'adresse, quand l'écran le propose. `null` masque le champ.
  final TextEditingController? line2Ctrl;

  final AddressAutocompleteService addressService;
  final ValueChanged<AddressData> onAddressResolved;
  final bool enabled;

  /// Le parcours affiche déjà ses propres intitulés de section ; le profil,
  /// non.
  final bool showSectionLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSectionLabel) const AddressSectionLabel('Adresse'),
        AddressSuggestField(
          key: const Key('residence-street'),
          controller: streetCtrl,
          service: addressService,
          label: 'Rue et numéro',
          hint: '12 rue de la Paix',
          prefixIconAsset: 'map-pin',
          prefixIconColor: cs.primary,
          onResolved: onAddressResolved,
        ),
        const SizedBox(height: DonySpacing.base),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DonyTextField(
                key: const Key('residence-postal'),
                textInputAction: TextInputAction.next,
                controller: postalCtrl,
                enabled: enabled,
                label: 'Code postal',
                hint: '75001',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              flex: 3,
              child: DonyTextField(
                key: const Key('residence-city'),
                textInputAction: TextInputAction.next,
                controller: cityCtrl,
                enabled: enabled,
                label: 'Ville',
                hint: 'Paris',
                prefixWidget: DonyIcon(
                  'building-2',
                  size: 20,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
        if (line2Ctrl case final line2?) ...[
          const SizedBox(height: DonySpacing.base),
          DonyTextField(
            key: const Key('residence-line2'),
            textInputAction: TextInputAction.done,
            controller: line2,
            enabled: enabled,
            label: 'Étage / Appartement',
            hint: 'Optionnel (Ex : Bât. B, 3ème étage)',
            prefixWidget: DonyIcon('house', size: 20, color: cs.primary),
          ),
        ],
      ],
    );
  }
}
