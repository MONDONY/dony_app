import 'package:dony/core/design/widgets/dony_dialog.dart';
import 'package:flutter/material.dart';

/// Porte les réglages d'accessibilité que [MediaQuery] ne couvre pas.
///
/// La taille de texte, le gras et la désactivation des animations passent par
/// `MediaQuery`, donc aucun widget n'a à les lire. Les quatre réglages ci-
/// dessous n'ont pas d'équivalent natif et sont diffusés ici.
///
/// Motif du choix d'un InheritedWidget plutôt qu'un `BlocProvider` : imposer
/// `AccessibilityBloc` à chaque widget du design system couplerait le design
/// system à une feature. Un scope monté une fois à la racine évite ce
/// couplage, et [of] retombe sur des valeurs par défaut sûres quand aucun
/// scope n'est présent, ce qui garde les widgets testables isolément.
class AccessibilityScope extends InheritedWidget {
  const AccessibilityScope({
    super.key,
    required this.underlineLinks,
    required this.reinforceLabels,
    required this.persistentMessages,
    required this.confirmImportantActions,
    required super.child,
    this.highContrast = false,
  });

  /// Le haut contraste est actif, système ou choix explicite déjà résolu.
  ///
  /// Le thème porte déjà la variante contrastée, donc presque aucun widget n'a
  /// à lire ce drapeau. L'exception est [DonyButton], qui peint un dégradé au
  /// lieu de lire `cs.primary` : sans ce drapeau il resterait sur ses couleurs
  /// normales alors que tout le reste de l'écran a basculé.
  final bool highContrast;

  /// Souligne les liens textuels, pour ne pas signaler un lien par la seule
  /// couleur (WCAG 1.4.1).
  final bool underlineLinks;

  /// Ajoute une icône et un mot aux statuts distingués par la couleur seule.
  final bool reinforceLabels;

  /// Les messages temporaires restent affichés jusqu'à fermeture manuelle
  /// (WCAG 2.2.1).
  final bool persistentMessages;

  /// Demande une confirmation explicite avant paiement (WCAG 3.3.4), via
  /// `requirePaymentAuth` (`features/payments/presentation/payment_auth.dart`).
  ///
  /// L'annulation et la suppression de compte n'ont pas besoin de ce réglage :
  /// elles ont chacune leur propre confirmation métier
  /// (`cancellation_bottom_sheet.dart`, `delete_account_bottom_sheet.dart`),
  /// inconditionnelle, donc toujours active, contrairement à ce drapeau qui
  /// reste optionnel. Ce n'est pas un oubli.
  final bool confirmImportantActions;

  static const AccessibilityScope _defaults = AccessibilityScope(
    underlineLinks: false,
    reinforceLabels: false,
    persistentMessages: false,
    confirmImportantActions: false,
    child: SizedBox.shrink(),
  );

  static AccessibilityScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccessibilityScope>() ??
      _defaults;

  @override
  bool updateShouldNotify(AccessibilityScope old) =>
      underlineLinks != old.underlineLinks ||
      reinforceLabels != old.reinforceLabels ||
      persistentMessages != old.persistentMessages ||
      confirmImportantActions != old.confirmImportantActions ||
      highContrast != old.highContrast;
}

extension AccessibilityContext on BuildContext {
  /// Réglages d'accessibilité non couverts par [MediaQuery].
  AccessibilityScope get a11y => AccessibilityScope.of(this);
}

/// Intercale une confirmation quand l'utilisateur a activé « Confirmer les
/// actions importantes ». Renvoie vrai si l'action peut se poursuivre.
///
/// Sans l'option, la fonction est transparente et renvoie vrai immédiatement :
/// elle ne doit jamais ajouter un dialogue à qui ne l'a pas demandé.
Future<bool> confirmImportantAction(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  if (!AccessibilityScope.of(context).confirmImportantActions) {
    return true;
  }
  final ok = await DonyDialog.show(
    context,
    title: title,
    message: message,
  );
  return ok ?? false;
}
