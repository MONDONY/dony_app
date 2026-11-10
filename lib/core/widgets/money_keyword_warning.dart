import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/money_keyword_detector.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Bandeau orange affiché sous la description d'un colis dès qu'elle évoque
/// l'envoi d'argent (règle : [MoneyKeywordDetector]). Il rappelle que les
/// espèces, chèques et cartes bancaires ne voyagent pas (CGU, article 4).
///
/// Non bloquant : aucun bouton, rien à fermer, l'envoi reste possible. Une
/// bague en argent déclenche aussi le bandeau, d'où le « ignorez ce message ».
/// Le back signale de son côté la demande à la modération.
///
/// Recalculé à chaque frappe sur [controller] ; l'apparition et la
/// disparition passent par un [AnimatedSize] (interruptible pendant la
/// saisie, sans animation au premier affichage d'un texte pré-rempli).
class MoneyKeywordWarning extends StatelessWidget {
  const MoneyKeywordWarning({super.key, required this.controller});

  /// Contrôleur du champ description surveillé.
  final TextEditingController controller;

  /// Clé du bandeau, pour les tests.
  static const bannerKey = Key('money-keyword-warning');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final visible =
            MoneyKeywordDetector.firstMatch(controller.text) != null;
        final l = context.l10n;
        return AnimatedSize(
          duration: DonyDuration.base,
          curve: DonyCurve.enter,
          alignment: Alignment.topCenter,
          child: visible
              // Marge seulement quand le bandeau est là : rien sinon.
              ? Padding(
                  padding: const EdgeInsets.only(top: DonySpacing.sm),
                  child: DonyStatusBanner(
                    key: bannerKey,
                    type: DonyStatusBannerType.warning,
                    title: l.moneyKeywordWarningTitle,
                    message: l.moneyKeywordWarningBody,
                  ),
                )
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }
}
