/// Garde-fou : ne déclenche [onChanged] que lorsque la langue reçue diffère
/// de la dernière transmise. Isolé de `_DonyAppState` pour être testable sans
/// monter tout l'arbre de `DonyApp` (Firebase, GetIt, une dizaine de BLoCs) :
/// `MaterialApp.router.builder` est rebâti à chaque frame, pas seulement à
/// chaque changement de langue.
class LanguageChangeGuard {
  String? _last;

  /// Appelle [onChanged] avec [languageCode] seulement si cette langue
  /// diffère de la dernière transmise (y compris au tout premier appel).
  void notify(
    String languageCode,
    void Function(String languageCode) onChanged,
  ) {
    if (_last == languageCode) return;
    _last = languageCode;
    onChanged(languageCode);
  }
}
