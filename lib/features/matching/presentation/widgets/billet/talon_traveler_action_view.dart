import 'package:dony/core/design/design_system.dart';
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

  const TalonTravelerActionView({
    super.key,
    required this.bidId,
    required this.action,
    this.travelerName,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final (
      String label,
      String hint,
      IconData icon,
      DonyButtonVariant variant,
    ) = switch (action) {
      TalonTravelerAction.scan => (
        'Scanner le colis',
        "À la remise, scannez le QR de l'expéditeur.",
        Icons.qr_code_scanner_rounded,
        DonyButtonVariant.primary,
      ),
      TalonTravelerAction.confirmDelivery => (
        'Confirmer la livraison',
        "À l'arrivée, saisissez le code de retrait de l'expéditeur.",
        Icons.verified_rounded,
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
        DonyButton(
          label: label,
          icon: icon,
          variant: variant,
          onPressed: switch (action) {
            TalonTravelerAction.scan => () => context.push('/tracking/scan'),
            TalonTravelerAction.confirmDelivery => () => context.push(
              '/tracking/confirm',
              extra: <String, String>{
                'bidId': bidId,
                'travelerName': travelerName ?? 'Voyageur',
              },
            ),
          },
        ),
      ],
    );
  }
}
