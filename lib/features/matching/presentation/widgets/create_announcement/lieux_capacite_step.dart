// Étape 1 du formulaire "Publier un trajet" : Lieux de remise + Capacité.
// Extrait de create_announcement_bottom_sheet.dart — refactor pur pour la partie
// lieux ; swap CapacitySelector → CapacityControl pour la partie capacité.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_selector_field.dart';
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

  /// Capacité verrouillée (kg) : fixée par la demande dans le flux trajet dédié.
  /// Si non-null, la capacité interactive ([CapacityControl]) est remplacée par
  /// un affichage en lecture seule. Les adresses restent éditables.
  final double? lockedCapacityKg;

  /// Messages des adresses obligatoires non renseignées.
  ///
  /// Nuls par défaut : le parent ne les publie qu'après une première
  /// interaction avec l'étape.
  final String? pickupAddressError;
  final String? deliveryAddressError;

  const LieuxCapaciteStep({
    super.key,
    this.initialPickupAddress,
    this.initialDeliveryAddress,
    required this.onPickupSaved,
    required this.onDeliverySaved,
    required this.onPickupChanged,
    required this.onDeliveryChanged,
    this.lockedCapacityKg,
    this.pickupAddressError,
    this.deliveryAddressError,
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
          iconAsset: 'arrow-left-right',
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          'Précisez l\'endroit exact de remise et récupération',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
        AddressSelectorField(
          type: AddressSelectorType.remise,
          value: initialPickupAddress,
          onChanged: (addr) {
            onPickupChanged(addr);
            onPickupSaved(addr);
            if (context.mounted) {
              context.read<AnnouncementFormBloc>().add(
                PickupAddressChanged(addr),
              );
            }
          },
        ).animate().fadeIn(delay: 80.ms),
        DonyFieldError(
          message: pickupAddressError,
          textKey: const Key('pickup-address-error'),
        ),
        const SizedBox(height: DonySpacing.base),
        AddressSelectorField(
          type: AddressSelectorType.livraison,
          value: initialDeliveryAddress,
          onChanged: (addr) {
            onDeliveryChanged(addr);
            onDeliverySaved(addr);
            if (context.mounted) {
              context.read<AnnouncementFormBloc>().add(
                DeliveryAddressChanged(addr),
              );
            }
          },
        ).animate().fadeIn(delay: 90.ms),
        DonyFieldError(
          message: deliveryAddressError,
          textKey: const Key('delivery-address-error'),
        ),
        const SizedBox(height: DonySpacing.xxl),

        // ── CAPACITÉ DISPONIBLE ─────────────────────────────────────────────
        const CaSectionLabel(
          label: 'Capacité disponible',
          iconAsset: 'luggage',
        ),
        const SizedBox(height: DonySpacing.base),
        // Trajet dédié : capacité fixée par la demande → affichage verrouillé.
        lockedCapacityKg != null
            ? _LockedCapacityDisplay(kg: lockedCapacityKg!)
            : const CapacityControl(),
        const SizedBox(height: DonySpacing.xxl),
      ],
    );
  }
}

/// Affichage en lecture seule de la capacité quand elle est imposée par la
/// demande (flux trajet dédié). Remplace [CapacityControl].
class _LockedCapacityDisplay extends StatelessWidget {
  const _LockedCapacityDisplay({required this.kg});
  final double kg;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('locked-capacity-display'),
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          DonyIcon('luggage', color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${kg.toStringAsFixed(0)} kg',
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  'Capacité fixée par la demande',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          DonyIcon('lock', size: 16, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
