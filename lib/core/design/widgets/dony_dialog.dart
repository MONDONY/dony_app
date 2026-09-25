import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Dialogue standardisé Yadony.
///
/// Usage :
/// ```dart
/// final confirmed = await DonyDialog.show(
///   context,
///   title: 'Supprimer ce trajet ?',
///   message: 'Cette action est irréversible.',
///   confirmLabel: 'Supprimer',
///   variant: DonyDialogVariant.destructive,
/// );
/// ```
///
/// `showCancel: false` retire le bouton secondaire : le dialogue ne fait
/// qu'informer, et son unique bouton rend `true`. À réserver aux messages
/// sans alternative (une limite atteinte qu'aucune action ne peut lever).
enum DonyDialogVariant { info, destructive }

abstract final class DonyDialog {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? message,
    Widget? content,
    String? confirmLabel,
    String? cancelLabel,
    bool showCancel = true,
    DonyDialogVariant variant = DonyDialogVariant.info,
    IconData? icon,
    String? iconAsset,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => _DonyDialogWidget(
        title: title,
        message: message,
        content: content,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        showCancel: showCancel,
        variant: variant,
        icon: icon,
        iconAsset: iconAsset,
      ),
    );
  }

  /// Confirmation d'abandon d'un formulaire en cours de saisie.
  ///
  /// Retourne `true` si l'utilisateur confirme vouloir quitter, `false` ou
  /// `null` s'il préfère rester. Le message annonce explicitement la perte des
  /// données : rien n'est mis en brouillon derrière.
  ///
  /// À n'appeler que si le formulaire est réellement entamé, sinon on impose
  /// une confirmation pour rien à quelqu'un qui n'a fait qu'ouvrir l'écran.
  static Future<bool?> confirmDiscard(BuildContext context) {
    final l = context.l10n;
    return show(
      context,
      title: l.dsDiscardTitle,
      message: l.dsDiscardMessage,
      confirmLabel: l.dsDiscardConfirm,
      cancelLabel: l.dsDiscardCancel,
      variant: DonyDialogVariant.destructive,
      iconAsset: 'circle-alert',
    );
  }
}

class _DonyDialogWidget extends StatelessWidget {
  const _DonyDialogWidget({
    required this.title,
    this.message,
    this.content,
    this.confirmLabel,
    this.cancelLabel,
    required this.showCancel,
    required this.variant,
    this.icon,
    this.iconAsset,
  });

  final String title;
  final String? message;
  final Widget? content;
  final String? confirmLabel;
  final String? cancelLabel;
  final bool showCancel;
  final DonyDialogVariant variant;
  final IconData? icon;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final effectiveConfirmLabel = confirmLabel ?? l.commonConfirm;
    final effectiveCancelLabel = showCancel
        ? (cancelLabel ?? l.commonCancel)
        : null;

    final confirmColor = switch (variant) {
      DonyDialogVariant.info => cs.primary,
      DonyDialogVariant.destructive => cs.error,
    };

    final iconColor = switch (variant) {
      DonyDialogVariant.info => cs.primary,
      DonyDialogVariant.destructive => cs.error,
    };

    final iconBg = switch (variant) {
      DonyDialogVariant.info => cs.primaryContainer,
      DonyDialogVariant.destructive => cs.errorContainer,
    };

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.xl,
        vertical: DonySpacing.huge,
      ),
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null || iconAsset != null) ...[
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: iconAsset != null
                        ? DonyIcon(iconAsset!, color: iconColor, size: 26)
                        : Icon(icon, color: iconColor, size: 26),
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.base),
            ],
            Text(
              title,
              style: tt.headlineSmall,
              textAlign: (icon != null || iconAsset != null)
                  ? TextAlign.center
                  : TextAlign.left,
            ),
            if (message != null) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(
                message!,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: (icon != null || iconAsset != null)
                    ? TextAlign.center
                    : TextAlign.left,
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: DonySpacing.base),
              content!,
            ],
            const SizedBox(height: DonySpacing.xl),
            Row(
              children: [
                if (effectiveCancelLabel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(effectiveCancelLabel),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmColor,
                    ),
                    child: Text(effectiveConfirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
