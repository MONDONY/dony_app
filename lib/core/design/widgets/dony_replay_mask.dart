import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Masque [child] dans le replay de session PostHog.
///
/// Les textes et les images sont visibles dans le replay (`maskAllTexts` et
/// `maskAllImages` à `false`) : tout champ de saisie personnel, avatar, photo
/// plein écran et feuille de paiement doit donc être enveloppé ici. Le widget
/// n'a aucun effet sur la mise en page ni sur l'affichage réel de l'app.
///
/// Un test (`replay_mask_coverage_test.dart`) échoue si un `TextField` ou un
/// `TextFormField` brut n'est pas enveloppé. Seuls les champs sans donnée
/// personnelle (recherche, ville) en sont dispensés.
class DonyReplayMask extends StatelessWidget {
  const DonyReplayMask({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => PostHogMaskWidget(child: child);
}
