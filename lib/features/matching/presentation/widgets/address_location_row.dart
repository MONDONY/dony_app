import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/utils/map_launcher.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Ouvre [address] dans l'app de carte native (Plans sur iOS, Google Maps sur
/// Android).
void openAddressInMaps(AddressData address) => unawaited(
  openInMaps(
    getIt<ExternalUrlLauncher>(),
    lat: address.lat,
    lng: address.lng,
    label: address.label,
  ),
);

/// Copie le libellé de [address] et le confirme par un snackbar : coller une
/// adresse dans une autre app reste utile (WhatsApp, VTC).
void copyAddress(BuildContext context, AddressData address) {
  unawaited(HapticFeedback.selectionClick());
  unawaited(Clipboard.setData(ClipboardData(text: address.label)));
  DonySnackbar.show(
    context,
    message: context.l10n.addressCopiedMessage,
    type: DonySnackbarType.success,
  );
}

/// Une ligne d'adresse entièrement tappable : ouvre le point dans l'app de
/// carte native. Le badge « Itinéraire » signale l'affordance sans laisser
/// croire à un lien web. Appui long = copie de l'adresse.
///
/// [pill] s'affiche à côté du titre (ex. « Étape en cours ») ; [dimmed] atténue
/// une étape qui n'est pas celle du moment.
class AddressLocationRow extends StatelessWidget {
  const AddressLocationRow({
    super.key,
    required this.iconAsset,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.address,
    this.pill,
    this.dimmed = false,
  });

  final String iconAsset;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final AddressData address;
  final Widget? pill;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => openAddressInMaps(address),
      onLongPress: () => copyAddress(context, address),
      child: Opacity(
        opacity: dimmed ? 0.62 : 1,
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.md),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(DonyRadius.sm),
                ),
                alignment: Alignment.center,
                child: DonyIcon(iconAsset, size: 14, color: iconColor),
              ),
              const SizedBox(width: DonySpacing.sm + DonySpacing.xxs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: DonySpacing.xs,
                      runSpacing: DonySpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: tt.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        ?pill,
                      ],
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Text(address.label, style: tt.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DonyIcon('map-pin', size: 13, color: cs.primary),
                  const SizedBox(width: DonySpacing.xxs),
                  Text(
                    context.l10n.listingRouteLabel,
                    style: tt.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Petite pastille d'état posée à côté du titre d'une [AddressLocationRow].
class AddressStepPill extends StatelessWidget {
  const AddressStepPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.xs + DonySpacing.xxs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Mini-carte non interactive centrée sur un seul point. Tap = ouvre le point
/// dans la carte native. En `liteMode` sur Android (bitmap léger) ; sur iOS,
/// une carte figée (tous les gestes désactivés). Un `GestureDetector`
/// par-dessus capte le tap partout.
class AddressPointMiniMap extends StatelessWidget {
  const AddressPointMiniMap({
    super.key,
    required this.address,
    this.markerHue = BitmapDescriptor.hueAzure,
  });

  final AddressData address;

  /// Teinte de l'épingle (bleu pour la remise, orange pour la récupération,
  /// comme les pictos des lignes).
  final double markerHue;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(address.lat, address.lng);
    return SizedBox(
      height: 130,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            // La clé force une nouvelle carte quand l'étape change (remise →
            // récupération) : la caméra initiale n'est lue qu'à la création.
            key: ValueKey('${address.lat},${address.lng}'),
            initialCameraPosition: CameraPosition(target: point, zoom: 14),
            liteModeEnabled: true,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            zoomGesturesEnabled: false,
            scrollGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('point'),
                position: point,
                icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
              ),
            },
          ),
          Positioned.fill(
            child: GestureDetector(
              key: const Key('address-mini-map-tap'),
              behavior: HitTestBehavior.opaque,
              onTap: () => openAddressInMaps(address),
            ),
          ),
        ],
      ),
    );
  }
}
