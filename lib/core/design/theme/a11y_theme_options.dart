/// Réglages d'accessibilité qui influent sur la construction du [ThemeData].
///
/// Les trois réglages ci-dessous ne peuvent pas passer par `MediaQuery` :
/// ils changent des couleurs, des bordures, des styles de bouton et les
/// transitions de page, donc ils appartiennent au thème.
class A11yThemeOptions {
  const A11yThemeOptions({
    this.highContrast = false,
    this.reduceMotion = false,
    this.underlineLinks = false,
  });

  final bool highContrast;
  final bool reduceMotion;
  final bool underlineLinks;

  @override
  bool operator ==(Object other) =>
      other is A11yThemeOptions &&
      other.highContrast == highContrast &&
      other.reduceMotion == reduceMotion &&
      other.underlineLinks == underlineLinks;

  @override
  int get hashCode => Object.hash(highContrast, reduceMotion, underlineLinks);
}
