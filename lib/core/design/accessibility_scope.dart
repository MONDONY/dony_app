import 'package:flutter/widgets.dart';

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
  });

  /// Souligne les liens textuels, pour ne pas signaler un lien par la seule
  /// couleur (WCAG 1.4.1).
  final bool underlineLinks;

  /// Ajoute une icône et un mot aux statuts distingués par la couleur seule.
  final bool reinforceLabels;

  /// Les messages temporaires restent affichés jusqu'à fermeture manuelle
  /// (WCAG 2.2.1).
  final bool persistentMessages;

  /// Demande une confirmation explicite avant paiement, annulation et
  /// suppression de compte (WCAG 3.3.4).
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
      confirmImportantActions != old.confirmImportantActions;
}

extension AccessibilityContext on BuildContext {
  /// Réglages d'accessibilité non couverts par [MediaQuery].
  AccessibilityScope get a11y => AccessibilityScope.of(this);
}
