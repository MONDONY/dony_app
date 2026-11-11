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

/// Réponse au dialogue de sortie d'un formulaire avec brouillon
/// ([DonyDialog.confirmExitWithDraft]). `null` : l'utilisateur reste.
enum DraftExitChoice { save, discard }

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

  /// Sortie d'un formulaire de publication entamé : garder la saisie en
  /// brouillon, la jeter, ou rester (`null`, y compris tap hors du dialogue).
  static Future<DraftExitChoice?> confirmExitWithDraft(BuildContext context) {
    return showDialog<DraftExitChoice>(
      context: context,
      builder: (_) => const _DraftExitDialog(),
    );
  }
}

class _DraftExitDialog extends StatelessWidget {
  const _DraftExitDialog();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
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
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: DonyIcon('notebook-pen', color: cs.primary, size: 26),
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              l.formDraftExitTitle,
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              l.formDraftExitMessage,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            // Trois issues de poids différent, empilées : l'action conseillée
            // en plein, la destructive en contour rouge, rester en texte.
            FilledButton(
              key: const Key('draft-exit-save'),
              onPressed: () => Navigator.of(context).pop(DraftExitChoice.save),
              child: Text(l.formDraftExitSave),
            ),
            const SizedBox(height: DonySpacing.sm),
            OutlinedButton(
              key: const Key('draft-exit-discard'),
              onPressed: () =>
                  Navigator.of(context).pop(DraftExitChoice.discard),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error),
              ),
              child: Text(l.formDraftExitDiscard),
            ),
            const SizedBox(height: DonySpacing.xs),
            TextButton(
              key: const Key('draft-exit-stay'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.formDraftExitStay),
            ),
          ],
        ),
      ),
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
            _DialogActions(
              confirmLabel: effectiveConfirmLabel,
              cancelLabel: effectiveCancelLabel,
              confirmColor: confirmColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// Boutons de la boîte de dialogue : côte à côte quand les deux libellés
/// tiennent chacun sur une ligne à taille normale, sinon empilés en pleine
/// largeur, bouton principal en haut. Jamais de libellé coupé ni de police
/// réduite.
class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.confirmLabel,
    required this.cancelLabel,
    required this.confirmColor,
  });

  final String confirmLabel;
  final String? cancelLabel;
  final Color confirmColor;

  /// Marge horizontale interne d'un bouton Material (24 de chaque côté) plus
  /// une réserve pour l'arrondi des mesures de texte.
  static const double _buttonInset = 52;

  bool _fitsSideBySide(BuildContext context, double maxWidth) {
    if (cancelLabel == null) return true;
    final style =
        Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    final each = (maxWidth - DonySpacing.sm) / 2;
    return measure(confirmLabel) + _buttonInset <= each &&
        measure(cancelLabel!) + _buttonInset <= each;
  }

  @override
  Widget build(BuildContext context) {
    final confirm = FilledButton(
      onPressed: () => Navigator.of(context).pop(true),
      style: FilledButton.styleFrom(backgroundColor: confirmColor),
      child: Text(confirmLabel, maxLines: 1, softWrap: false),
    );
    final cancel = cancelLabel == null
        ? null
        : OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel!, maxLines: 1, softWrap: false),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (cancel == null) {
          return SizedBox(width: double.infinity, child: confirm);
        }
        if (_fitsSideBySide(context, constraints.maxWidth)) {
          return Row(
            children: [
              Expanded(child: cancel),
              const SizedBox(width: DonySpacing.sm),
              Expanded(child: confirm),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            confirm,
            const SizedBox(height: DonySpacing.sm),
            cancel,
          ],
        );
      },
    );
  }
}
