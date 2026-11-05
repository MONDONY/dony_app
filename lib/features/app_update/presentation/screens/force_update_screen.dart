import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/app_update/data/services/app_store_launcher.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Écran bloquant affiché quand `AppUpdateService.isUpdateRequired` détecte
/// une version trop ancienne. Aucune sortie possible en dehors du bouton :
/// ni retour arrière, ni fermeture. Une version qui plante sur le moindre
/// statut de négociation inconnu ne doit jamais redevenir accessible.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    // Cet écran peut s'afficher avant que la langue de l'app ne soit connue
    // (bloquant, planté avant tout parcours) : context.l10n retombe alors
    // sur AppL10n.current (langue effective, pas systématiquement le
    // français) plutôt que de planter.
    final l = context.l10n;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.huge,
              DonySpacing.lg,
              DonySpacing.xl,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const DonyMascotteAnimated(
                  type: DonyMascotteType.erreurLegere,
                  size: DonyMascotteSize.lg,
                ),
                const SizedBox(height: DonySpacing.xl),
                Text(
                  l.appUpdateTitle,
                  style: tt.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DonySpacing.sm),
                Text(
                  l.appUpdateMessage,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DonySpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  child: DonyButton(
                    label: l.appUpdateButton,
                    onPressed: AppStoreLauncher.open,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
