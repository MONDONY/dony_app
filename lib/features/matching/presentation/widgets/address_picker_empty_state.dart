import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// État vide, hors ligne ou en erreur du corps des pickers d'adresse
/// (remise et livraison). Plus compact que [DonyEmptyState] et accepte un
/// widget d'action libre (tuile GPS).
class AddressPickerEmptyState extends StatelessWidget {
  const AddressPickerEmptyState({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    // Avec le clavier ouvert, le corps de la sheet ne laisse qu'une centaine
    // de pixels sur un petit écran : la colonne débordait de 80 px (Sentry
    // FLUTTER-1B). Même mécanisme que DonyEmptyState : le défilement prend la
    // taille du contenu quand il tient (donc reste centré) et se borne à la
    // hauteur disponible sinon ; physique clamping pour laisser le geste au
    // parent sans dépassement.
    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(DonySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon(icon, size: 40, color: color),
            const SizedBox(height: DonySpacing.md),
            Text(
              title,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              subtitle,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: DonySpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
