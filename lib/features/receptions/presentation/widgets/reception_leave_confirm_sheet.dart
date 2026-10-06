import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Geste du destinataire qui le sépare d'un colis.
enum ReceptionLeaveKind {
  /// « Ce n'est pas pour moi », avant d'avoir confirmé le colis.
  decline,

  /// « Me retirer de ce colis », après l'avoir confirmé (FLUTTER-9F).
  withdraw,
}

/// Feuille de confirmation avant `POST /receptions/{bidId}/decline`
/// (FLUTTER-E8). Une simple boîte de dialogue se validait par réflexe : un
/// destinataire a confirmé son colis puis s'en est retiré dix secondes plus
/// tard par erreur. La feuille dit ce qu'il perd (le colis et son code de
/// retrait), le bouton destructif et « Annuler » sont dans le `stickyBottom`.
///
/// Rend `true` sur la confirmation, `false` ou `null` sinon (« Annuler »,
/// glissement, tap hors de la feuille).
abstract final class ReceptionLeaveConfirmSheet {
  static Future<bool?> show(
    BuildContext context, {
    required ReceptionLeaveKind kind,
  }) {
    final l = context.l10n;
    final withdraw = kind == ReceptionLeaveKind.withdraw;
    return DonyBottomSheet.show<bool>(
      context,
      title: withdraw
          ? l.receptionWithdrawDialogTitle
          : l.receptionDeclineDialogTitle,
      isDanger: true,
      stickyBottom: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyButton(
              key: const Key('reception-leave-confirm'),
              label: withdraw
                  ? l.receptionWithdrawConfirm
                  : l.receptionDeclineButton,
              iconAsset: 'user-x',
              variant: DonyButtonVariant.destructive,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: DonySpacing.xs),
            DonyButton(
              key: const Key('reception-leave-cancel'),
              label: l.commonCancel,
              variant: DonyButtonVariant.ghost,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
      child: _LeaveContent(withdraw: withdraw),
    );
  }
}

class _LeaveContent extends StatelessWidget {
  const _LeaveContent({required this.withdraw});

  final bool withdraw;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const Key('reception-leave-warning'),
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonyIcon('triangle-alert', size: 18, color: cs.error),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    l.receptionLeaveWarning,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            withdraw
                ? l.receptionWithdrawSheetNote
                : l.receptionDeclineSheetNote,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
