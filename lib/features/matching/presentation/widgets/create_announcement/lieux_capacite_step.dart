// Étape 1 du formulaire "Publier un trajet" : Lieux de remise + Capacité.
// Extrait de create_announcement_bottom_sheet.dart — refactor pur pour la partie
// lieux ; swap CapacitySelector → CapacityControl pour la partie capacité.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_picker_field.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/capacity_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Corps de l'étape 1 (Lieux de remise + Capacité disponible) du formulaire
/// de création d'annonce.
///
/// Les adresses sélectionnées sont remontées via [onPickupSaved],
/// [onPickupChanged], [onDeliverySaved] et [onDeliveryChanged].
/// Le state parent ([_CreateAnnouncementContentState]) reste propriétaire des
/// variables [_pickupAddress] et [_deliveryAddress] (nécessaires pour [_submit]).
///
/// La partie capacité utilise [CapacityControl] (autonome : lit/écrit
/// [AnnouncementFormBloc] lui-même sans paramètres).
class LieuxCapaciteStep extends StatelessWidget {
  final AddressData? initialPickupAddress;
  final AddressData? initialDeliveryAddress;

  /// Appelé lorsque le formulaire est sauvegardé (Form.save()).
  final void Function(AddressData? addr) onPickupSaved;
  final void Function(AddressData? addr) onDeliverySaved;

  /// Appelé à chaque changement (saisie confirmée dans le champ adresse).
  /// La remontée vers [AnnouncementFormBloc] est effectuée ici dans le step.
  final void Function(AddressData? addr) onPickupChanged;
  final void Function(AddressData? addr) onDeliveryChanged;

  const LieuxCapaciteStep({
    super.key,
    this.initialPickupAddress,
    this.initialDeliveryAddress,
    required this.onPickupSaved,
    required this.onDeliverySaved,
    required this.onPickupChanged,
    required this.onDeliveryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── LIEUX DE REMISE ─────────────────────────────────────────────────
        const CaSectionLabel(
          label: 'Lieux de remise',
          icon: Icons.swap_horiz_rounded,
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          'Précisez l\'endroit exact de remise et récupération',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
        AddressPickerField(
          fieldLabel: 'Lieu de remise du colis *',
          isRequired: true,
          initialValue: initialPickupAddress,
          prefixIconColor: cs.primary,
          onSaved: onPickupSaved,
          onChanged: (addr) {
            onPickupChanged(addr);
            if (context.mounted) {
              context
                  .read<AnnouncementFormBloc>()
                  .add(PickupAddressChanged(addr));
            }
          },
          autocompleteService: getIt<AddressAutocompleteService>(),
        ).animate().fadeIn(delay: 80.ms),
        const SizedBox(height: DonySpacing.base),
        AddressPickerField(
          fieldLabel: 'Lieu de récupération *',
          isRequired: true,
          showGpsButton: false,
          initialValue: initialDeliveryAddress,
          prefixIconColor: cs.secondary,
          onSaved: onDeliverySaved,
          onChanged: (addr) {
            onDeliveryChanged(addr);
            if (context.mounted) {
              context
                  .read<AnnouncementFormBloc>()
                  .add(DeliveryAddressChanged(addr));
            }
          },
          autocompleteService: getIt<AddressAutocompleteService>(),
        ).animate().fadeIn(delay: 90.ms),
        const SizedBox(height: DonySpacing.xxl),

        // ── CAPACITÉ DISPONIBLE ─────────────────────────────────────────────
        const CaSectionLabel(
          label: 'Capacité disponible',
          icon: Icons.luggage_rounded,
        ),
        const SizedBox(height: DonySpacing.base),
        const CapacityControl(),
        const SizedBox(height: DonySpacing.xxl),
      ],
    );
  }
}
