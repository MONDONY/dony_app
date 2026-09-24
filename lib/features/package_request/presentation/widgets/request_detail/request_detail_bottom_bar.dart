import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

({String label, String icon, bool enabled}) primaryButtonFor(
  AppLocalizations l,
  RequestPrimaryAction action, {
  String? travelerName,
  String? amount,
}) {
  final name = travelerName ?? l.requestTravelerFallbackNameLower;
  return switch (action) {
    RequestPrimaryAction.publish => (
      label: l.requestDetailPublishCta,
      icon: 'send',
      enabled: true,
    ),
    RequestPrimaryAction.share => (
      label: l.commonShare,
      icon: 'share-2',
      enabled: true,
    ),
    RequestPrimaryAction.openThread => (
      label: l.requestDetailOpenThreadCta,
      icon: 'message-circle',
      enabled: true,
    ),
    RequestPrimaryAction.pay => (
      label: amount == null
          ? l.requestDetailPayCta
          : l.requestDetailPayCtaWithAmount(amount),
      icon: 'credit-card',
      enabled: true,
    ),
    RequestPrimaryAction.waitTrip => (
      label: l.requestTravelerAddingTrip(name),
      icon: 'clock',
      enabled: false,
    ),
    RequestPrimaryAction.trackParcel => (
      label: l.requestDetailTrackParcelCta,
      icon: 'package',
      enabled: true,
    ),
    RequestPrimaryAction.rate => (
      label: l.requestDetailRateCta(name),
      icon: 'star',
      enabled: true,
    ),
    RequestPrimaryAction.republish => (
      label: l.requestDetailRepublishCta,
      icon: 'refresh-cw',
      enabled: true,
    ),
    RequestPrimaryAction.publishSimilar => (
      label: l.requestDetailPublishSimilarCta,
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
    final l = context.l10n;
    final rawPrimary = primaryButtonFor(
      l,
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
        ? (label: l.commonEdit, icon: 'square-pen', onTap: onEdit)
        : actions.showMessage
        ? (
            label: l.requestDetailMessageCta,
            icon: 'message-circle',
            onTap: onMessage,
          )
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
