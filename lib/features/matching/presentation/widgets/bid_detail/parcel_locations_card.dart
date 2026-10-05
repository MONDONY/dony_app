import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/address_location_row.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Statuts pour lesquels le colis a déjà été remis au voyageur.
const kParcelHandedOverStatuses = <String>{
  'HANDED_OVER',
  'IN_TRANSIT',
  // ARRIVED implique HANDED_OVER (le scan Transit est facultatif) : le colis a
  // forcément été remis.
  'ARRIVED',
  'COMPLETED',
  'DELIVERED',
};

/// Statuts où le destinataire a déjà récupéré le colis.
const _kDeliveredStatuses = <String>{'COMPLETED', 'DELIVERED'};

/// Statuts d'une demande encore dans la course : la carte Lieux n'a plus de
/// sens pour une demande refusée, annulée ou expirée.
const _kVisibleStatuses = <String>{
  'PENDING',
  'AWAITING_PAYMENT',
  'PAYMENT_ESCROWED',
  'ACCEPTED',
  ...kParcelHandedOverStatuses,
};

/// Carte « Lieux » de la fiche colis (vue expéditeur), sur le modèle de celle
/// du détail d'un trajet : une mini-carte puis les deux adresses, « Remise du
/// colis » et « Récupération », chacune ouvrable dans l'app de carte native.
///
/// La mini-carte ne montre que l'étape du moment : le lieu de remise tant que
/// le colis n'est pas chez le voyageur, puis le lieu où le destinataire le
/// récupère.
class ParcelLocationsCard extends StatelessWidget {
  const ParcelLocationsCard({super.key, required this.bid});

  final BidModel bid;

  static bool shouldShow(BidModel bid) =>
      _kVisibleStatuses.contains(bid.status) &&
      (bid.handoverAddress != null || bid.deliveryAddress != null);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final handover = bid.handoverAddress;
    final delivery = bid.deliveryAddress;
    final handedOver = kParcelHandedOverStatuses.contains(bid.status);
    final delivered = _kDeliveredStatuses.contains(bid.status);

    // Étape montrée sur la carte ; à défaut d'adresse pour l'étape du moment,
    // on montre l'autre plutôt que rien.
    final showDelivery = delivery != null && (handedOver || handover == null);
    final mapped = showDelivery ? delivery : handover;

    final currentPill = AddressStepPill(
      label: l.parcelLocationsCurrentStep,
      background: showDelivery ? DonyColors.accent : cs.primary,
      foreground: Colors.white,
    );

    return Container(
      key: const Key('parcel-locations-card'),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mapped != null)
            AddressPointMiniMap(
              address: mapped,
              markerHue: showDelivery
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueAzure,
            ),
          if (handover != null)
            AddressLocationRow(
              key: const Key('parcel-location-handover'),
              iconAsset: handedOver ? 'check' : 'upload',
              iconColor: handedOver ? cs.success : cs.primary,
              iconBackground: handedOver
                  ? cs.success.withValues(alpha: 0.12)
                  : cs.primaryContainer,
              title: l.listingPickupParcelTitle,
              address: handover,
              dimmed: handedOver,
              pill: handedOver
                  ? AddressStepPill(
                      label: l.parcelLocationsHandedOver,
                      background: cs.success.withValues(alpha: 0.12),
                      foreground: cs.success,
                    )
                  : currentPill,
            ),
          if (handover != null && delivery != null)
            Divider(height: 1, color: cs.surfaceContainerHighest),
          if (delivery != null)
            AddressLocationRow(
              key: const Key('parcel-location-delivery'),
              iconAsset: 'download',
              iconColor: DonyColors.accent,
              iconBackground: DonyColors.accentSoft,
              title: l.listingDeliveryPickupTitle,
              address: delivery,
              dimmed: !showDelivery,
              pill: delivered
                  ? AddressStepPill(
                      label: l.parcelLocationsDelivered,
                      background: cs.success.withValues(alpha: 0.12),
                      foreground: cs.success,
                    )
                  : showDelivery
                  ? currentPill
                  : AddressStepPill(
                      label: l.parcelLocationsOnArrival,
                      background: cs.surfaceContainerHighest,
                      foreground: cs.onSurfaceVariant,
                    ),
            ),
        ],
      ),
    );
  }
}
