import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Case « Ne plus afficher » d'un modal, posée dans la zone fixe du bas,
/// AVANT les boutons (jamais dans le contenu qui défile).
///
/// L'état vit dans [checked], créé par `VideoModalPresenter` : seul un geste
/// de la personne y écrit, donc rien n'est écrit après la fermeture du modal.
class VideoModalDontShowAgain extends StatelessWidget {
  const VideoModalDontShowAgain({super.key, required this.checked});

  final ValueNotifier<bool> checked;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: checked,
      builder: (context, value, _) => DonyCheckbox(
        key: const Key('video-modal-dont-show-again'),
        label: context.l10n.videoModalDontShowAgain,
        value: value,
        onChanged: (v) => checked.value = v ?? false,
      ),
    );
  }
}

/// Le pied d'un modal : la case « Ne plus afficher » quand la campagne la
/// propose, puis les boutons.
class VideoModalFooterContent extends StatelessWidget {
  const VideoModalFooterContent({
    super.key,
    required this.allowDontShowAgain,
    required this.dontShowAgain,
    required this.buttons,
  });

  final bool allowDontShowAgain;
  final ValueNotifier<bool>? dontShowAgain;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final checked = dontShowAgain;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (allowDontShowAgain && checked != null) ...[
          VideoModalDontShowAgain(checked: checked),
          const SizedBox(height: DonySpacing.xs),
        ],
        ...buttons,
      ],
    );
  }
}
