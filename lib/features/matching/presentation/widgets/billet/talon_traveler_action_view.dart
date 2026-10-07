import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum TalonTravelerAction { scan, confirmDelivery }

/// Talon voyageur actionnable : scan de prise en charge / confirmation
/// de livraison.
/// - [TalonTravelerAction.scan] → `/tracking/scan` (scanner QR)
/// - [TalonTravelerAction.confirmDelivery] → `/tracking/confirm` (saisie code 6 chiffres)
class TalonTravelerActionView extends StatelessWidget {
  final String bidId;
  final TalonTravelerAction action;

  /// Nom du voyageur, requis uniquement pour le mode [TalonTravelerAction.confirmDelivery].
  final String? travelerName;

  /// Départ du trajet : en mode [TalonTravelerAction.confirmDelivery], le
  /// bouton reste désactivé tant qu'il n'est pas atteint (422
  /// `trip-not-departed`, FLUTTER-CB). `null` : inconnu, bouton actif.
  final DeliveryWindow? deliveryWindow;

  const TalonTravelerActionView({
    super.key,
    required this.bidId,
    required this.action,
    this.travelerName,
    this.deliveryWindow,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    final (
      String label,
      String hint,
      String iconAsset,
      DonyButtonVariant variant,
    ) = switch (action) {
      TalonTravelerAction.scan => (
        l.ticketScanQrActionLabel,
        l.ticketScanQrActionHint,
        'scan-line',
        DonyButtonVariant.primary,
      ),
      TalonTravelerAction.confirmDelivery => (
        l.ticketConfirmDeliveryActionLabel,
        l.ticketConfirmDeliveryActionHint,
        'badge-check',
        DonyButtonVariant.success,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hint,
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
        DeliveryDepartureGate(
          window: action == TalonTravelerAction.confirmDelivery
              ? deliveryWindow
              : null,
          builder: (context, lockedHint) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DonyButton(
                label: label,
                iconAsset: iconAsset,
                variant: variant,
                onPressed: lockedHint != null
                    ? null
                    : switch (action) {
                        TalonTravelerAction.scan => () => context.push(
                          '/tracking/scan',
                        ),
                        TalonTravelerAction.confirmDelivery =>
                          () => context.push(
                            '/tracking/confirm',
                            extra: <String, String>{
                              'bidId': bidId,
                              'travelerName':
                                  travelerName ?? l.tripTravelerFallbackName,
                            },
                          ),
                      },
              ),
              if (lockedHint != null) ...[
                const SizedBox(height: DonySpacing.xs),
                DeliveryLockedHint(lockedHint),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
