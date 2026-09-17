import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:flutter/material.dart';

({String label, String icon, bool enabled}) primaryButtonFor(
  RequestPrimaryAction action, {
  String? travelerName,
  String? amount,
}) {
  final name = travelerName ?? 'le voyageur';
  return switch (action) {
    RequestPrimaryAction.publish => (
      label: 'Publier',
      icon: 'send',
      enabled: true,
    ),
    RequestPrimaryAction.share => (
      label: 'Partager',
      icon: 'share-2',
      enabled: true,
    ),
    RequestPrimaryAction.openThread => (
      label: 'Ouvrir la discussion',
      icon: 'message-circle',
      enabled: true,
    ),
    RequestPrimaryAction.pay => (
      label: amount == null ? 'Payer' : 'Payer $amount',
      icon: 'credit-card',
      enabled: true,
    ),
    RequestPrimaryAction.waitTrip => (
      label: '$name ajoute son trajet',
      icon: 'clock',
      enabled: false,
    ),
    RequestPrimaryAction.trackParcel => (
      label: 'Suivre mon colis',
      icon: 'package',
      enabled: true,
    ),
    RequestPrimaryAction.rate => (
      label: 'Noter $name',
      icon: 'star',
      enabled: true,
    ),
    RequestPrimaryAction.republish => (
      label: 'Republier avec de nouvelles dates',
      icon: 'refresh-cw',
      enabled: true,
    ),
    RequestPrimaryAction.publishSimilar => (
      label: 'Publier une demande similaire',
      icon: 'copy',
      enabled: true,
    ),
  };
}

/// Barre fixe de « Ma demande » : une action principale, Modifier ou Message à côté.
class RequestDetailBottomBar extends StatelessWidget {
  const RequestDetailBottomBar({
    required this.actions,
    required this.busy,
    required this.onPrimary,
    this.onEdit,
    this.onMessage,
    this.travelerName,
    this.amount,
    this.primaryEnabled = true,
    super.key,
  });

  final RequestScreenActions actions;
  final bool busy;
  final VoidCallback onPrimary;
  final VoidCallback? onEdit;
  final VoidCallback? onMessage;
  final String? travelerName;
  final String? amount;

  /// Garde supplémentaire de l'appelant : `trackParcel`/`rate` ont besoin d'un
  /// identifiant (bid) qui peut manquer même quand l'action semble normale —
  /// mieux vaut désactiver le bouton qu'un bouton muet qui ne fait rien.
  final bool primaryEnabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rawPrimary = primaryButtonFor(
      actions.primary,
      travelerName: travelerName,
      amount: amount,
    );
    final primary = (
      label: rawPrimary.label,
      icon: rawPrimary.icon,
      enabled: rawPrimary.enabled && primaryEnabled,
    );
    final secondary = actions.showEdit
        ? (label: 'Modifier', icon: 'square-pen', onTap: onEdit)
        : actions.showMessage
        ? (label: 'Message', icon: 'message-circle', onTap: onMessage)
        : null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.md,
        DonySpacing.lg,
        DonySpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: Row(
        children: [
          if (secondary != null) ...[
            Expanded(
              child: DonyButton(
                label: secondary.label,
                iconAsset: secondary.icon,
                variant: DonyButtonVariant.secondary,
                onPressed: busy ? null : secondary.onTap,
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
          ],
          Expanded(
            child: DonyButton(
              label: primary.label,
              iconAsset: primary.icon,
              isLoading: busy && primary.enabled,
              onPressed: busy || !primary.enabled ? null : onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
