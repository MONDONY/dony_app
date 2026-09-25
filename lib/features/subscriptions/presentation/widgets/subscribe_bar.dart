import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Barre d'abonnement à un voyageur, partagée par la fiche voyageur du
/// matching et le hub voyageur.
///
/// Les deux écrans en portaient chacun une copie, avec la même cloche muette :
/// un bouton d'icône dont rien ne disait ce qu'il coupait. Or l'abonnement
/// arrive avec les alertes push **désactivées** côté serveur, et couper la
/// cloche n'empêche pas la notification d'apparaître dans le centre de
/// notifications. La barre l'écrit maintenant en toutes lettres.
class SubscribeBar extends StatelessWidget {
  const SubscribeBar({
    super.key,
    required this.subscribed,
    required this.pushEnabled,
    required this.onSubscribe,
    required this.onUnsubscribe,
    required this.onTogglePush,
    this.subscribeLabel,
  });

  final bool subscribed;
  final bool pushEnabled;
  final VoidCallback onSubscribe;
  final VoidCallback onUnsubscribe;
  final ValueChanged<bool> onTogglePush;

  /// `null` pour le libellé partagé ([AppLocalizations.followFollowButton]) ;
  /// certains appelants (fiche voyageur du matching) le remplacent par une
  /// phrase plus longue.
  final String? subscribeLabel;

  String _caption(AppLocalizations l) {
    if (!subscribed) {
      return l.followSubscribeCaption;
    }
    return pushEnabled ? l.followPushOnCaption : l.followPushOffCaption;
  }

  Future<void> _confirmUnsubscribe(BuildContext context) async {
    final l = context.l10n;
    final confirmed = await DonyDialog.show(
      context,
      title: l.followUnfollowDialogTitle,
      message: l.followUnsubscribeConfirmMessage,
      confirmLabel: l.followUnfollowButton,
      variant: DonyDialogVariant.destructive,
      iconAsset: 'bell-off',
    );
    if ((confirmed ?? false) && context.mounted) onUnsubscribe();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.sm),
          child: Text(
            _caption(l),
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        if (subscribed)
          Row(
            children: [
              Expanded(
                child: DonyButton(
                  label: l.followFollowingButton,
                  variant: DonyButtonVariant.secondary,
                  fullWidth: false,
                  onPressed: () => _confirmUnsubscribe(context),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              _PushToggle(
                enabled: pushEnabled,
                onPressed: () => onTogglePush(!pushEnabled),
              ),
            ],
          )
        else
          DonyButton(
            label: subscribeLabel ?? l.followFollowButton,
            iconAsset: 'bell',
            onPressed: onSubscribe,
          ),
      ],
    );
  }
}

/// Bascule des alertes push, étiquetée plutôt que muette : une icône de cloche
/// seule ne dit ni son état ni ce qu'elle commande.
class _PushToggle extends StatelessWidget {
  const _PushToggle({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = enabled ? cs.primary : cs.onSurfaceVariant;

    return Semantics(
      toggled: enabled,
      label: l.followPushToggleSemantics,
      child: Tooltip(
        message: enabled ? l.followPushOffTooltip : l.followPushOnTooltip,
        child: Material(
          color: enabled ? cs.primary.withValues(alpha: 0.08) : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.lg),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(DonyRadius.lg),
            child: Container(
              // 48 de haut : même cible tactile que le bouton voisin, sans
              // quoi la bascule serait plus difficile à viser que l'action
              // destructrice d'à côté.
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DonyRadius.lg),
                border: Border.all(
                  color: enabled
                      ? cs.primary.withValues(alpha: 0.4)
                      : cs.outline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DonyIcon(enabled ? 'bell' : 'bell-off', size: 18, color: fg),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    l.followPushBadge,
                    style: tt.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
