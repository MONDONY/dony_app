import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Avertissement affiché avant de désactiver « Profils vérifiés uniquement ».
///
/// Désactiver ce réglage ouvre le trajet aux expéditeurs dont l'identité n'a pas
/// été vérifiée : c'est une prise de risque que l'utilisateur doit accepter en
/// connaissance de cause, d'où la case à cocher plutôt qu'un simple bouton.
///
/// Retourne `true` seulement si l'utilisateur confirme.
class UnverifiedContactWarningSheet extends StatefulWidget {
  const UnverifiedContactWarningSheet({
    super.key,
    required this.acceptedNotifier,
  });

  final ValueNotifier<bool> acceptedNotifier;

  static Future<bool?> show(BuildContext context) {
    final acceptedNotifier = ValueNotifier<bool>(false);

    return DonyBottomSheet.show<bool>(
      context,
      isDanger: true,
      title: 'Accepter les profils non vérifiés ?',
      subtitle: "Cette option n'est pas recommandée par Yadony.",
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: acceptedNotifier,
        builder: (context, accepted, _) => DonyButton(
          label: 'Accepter quand même',
          variant: DonyButtonVariant.destructive,
          onPressed: accepted
              ? () => Navigator.of(context, rootNavigator: true).pop(true)
              : null,
        ),
      ),
      child: UnverifiedContactWarningSheet(acceptedNotifier: acceptedNotifier),
    ).whenComplete(acceptedNotifier.dispose);
  }

  @override
  State<UnverifiedContactWarningSheet> createState() =>
      _UnverifiedContactWarningSheetState();
}

class _UnverifiedContactWarningSheetState
    extends State<UnverifiedContactWarningSheet> {
  static const _consequences = [
    (
      icon: 'user-x',
      text:
          "Tous les utilisateurs pourront t'envoyer une demande, "
          "qu'ils aient vérifié leur identité ou non.",
    ),
    (
      icon: 'shield',
      text:
          "Yadony ne peut pas confirmer l'identité d'un profil non vérifié, "
          'ni son nom, ni ses papiers.',
    ),
    (
      icon: 'triangle-alert',
      text:
          "Yadony n'est pas responsable des difficultés que tu pourrais "
          'rencontrer avec un profil non vérifié.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.errorLight,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.error.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in _consequences) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DonyIcon(item.icon, color: cs.error, size: 18),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: Text(
                        item.text,
                        style: tt.bodySmall?.copyWith(
                          color: cs.error,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item != _consequences.last)
                  const SizedBox(height: DonySpacing.md),
              ],
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        Text(
          'Tu peux réactiver ce réglage à tout moment. Les demandes déjà reçues '
          'ne sont pas affectées.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.lg),
        ValueListenableBuilder<bool>(
          valueListenable: widget.acceptedNotifier,
          builder: (context, accepted, _) => GestureDetector(
            onTap: () =>
                widget.acceptedNotifier.value = !widget.acceptedNotifier.value,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: accepted,
                  activeColor: cs.error,
                  onChanged: (v) => widget.acceptedNotifier.value = v ?? false,
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: DonySpacing.md),
                    child: Text(
                      "J'ai compris et j'accepte d'assumer ce risque.",
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.xl),
      ],
    );
  }
}
