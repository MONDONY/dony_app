import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EscrowExplainerBottomSheet extends StatelessWidget {
  const EscrowExplainerBottomSheet({
    super.key,
    required this.amount,
    required this.travelerName,
  });

  final double amount;
  final String travelerName;

  static Future<void> show(
    BuildContext context, {
    required double amount,
    required String travelerName,
  }) {
    return DonyBottomSheet.show(
      context,
      title: '🔒 Paiement sécurisé',
      subtitle: travelerName,
      stickyBottom: DonyButton(
        label: "J'ai compris",
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: EscrowExplainerBottomSheet(
        amount: amount,
        travelerName: travelerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          fmt.format(amount),
          style: tt.displaySmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          "Retenu jusqu'à la livraison",
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.xl),
        _InfoTile(
          iconAsset: 'lock',
          text:
              "Votre paiement est bloqué en séquestre jusqu'à confirmation de livraison par le destinataire.",
          cs: cs,
          tt: tt,
        ),
        const SizedBox(height: DonySpacing.sm),
        _InfoTile(
          iconAsset: 'clock',
          text:
              'Libération automatique 48h après la date de livraison prévue si aucune confirmation.',
          cs: cs,
          tt: tt,
        ),
        const SizedBox(height: DonySpacing.sm),
        _InfoTile(
          iconAsset: 'shield',
          text:
              'En cas de litige, Yadony intervient pour arbitrer et protéger les deux parties.',
          cs: cs,
          tt: tt,
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.text,
    required this.cs,
    required this.tt,
    this.icon,
    this.iconAsset,
  });

  final IconData? icon;
  final String? iconAsset;
  final String text;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconAsset != null
              ? DonyIcon(iconAsset!, size: 16, color: cs.primary)
              : Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              text,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
