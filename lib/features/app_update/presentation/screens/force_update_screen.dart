import 'package:dony/core/design/design_system.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Écran bloquant affiché quand `AppUpdateService.isUpdateRequired` détecte
/// une version trop ancienne. Aucune sortie possible en dehors du bouton :
/// ni retour arrière, ni fermeture. Une version qui plante sur le moindre
/// statut de négociation inconnu ne doit jamais redevenir accessible.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  static const _androidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.yadony.yadony';

  // TODO(app-store): remplacer par le lien direct
  // (https://apps.apple.com/app/idXXXXXXXXXX) une fois l'identifiant Apple
  // connu, après la première publication sur l'App Store.
  static const _iosStoreUrl = 'https://apps.apple.com/search?term=Yadony';

  Future<void> _openStore() async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final uri = Uri.parse(isIOS ? _iosStoreUrl : _androidStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

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
                  'Une mise à jour est nécessaire',
                  style: tt.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DonySpacing.sm),
                Text(
                  "Cette version de l'application n'est plus prise en "
                  'charge. Mets-la à jour pour continuer à utiliser Yadony.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DonySpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  child: DonyButton(
                    label: 'Mettre à jour maintenant',
                    onPressed: _openStore,
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
