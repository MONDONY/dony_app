# Dark mode — Guide d'auteur de widget

Ce document explique comment écrire des widgets compatibles dark mode dans le DS dony.

## Règle absolue

Lire toutes les couleurs sémantiques via `Theme.of(context).colorScheme.X`, jamais via les constantes `DonyColors.X`.

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  // ... utiliser cs.surface, cs.onSurface, cs.primary, etc.
}
```

## Couleurs unies, jamais de dégradé

Aucun dégradé dans l'application (demande du propriétaire, pour ne pas faire « généré par IA ») : pas de `LinearGradient`, `RadialGradient`, `SweepGradient`, ni de `ShaderMask` ou `createShader` coloré. Chaque surface prend **une** couleur unie :

- fond de marque → `cs.primary`, texte dessus `cs.onPrimary` (blanc en clair, noir en sombre : blanc sur `blueDark500` ne fait que 3.28:1, noir 6.39:1) ;
- héros sombre → une seule couleur sombre (`cs.inverseSurface`, une surface, ou la teinte sombre du statut) ;
- reflets, halos, lueurs décoratives → supprimés, ou un aplat discret (`cs.primaryContainer`) ;
- fondu de bord → pas de fondu, le contenu est simplement coupé ;
- chargement → pulsation d'opacité (`DonyShimmer`), pas de reflet qui balaie.

## Checklist avant de hardcoder une couleur

Pose-toi ces 6 questions avant d'écrire `DonyColors.X` :

1. **Cette couleur représente-t-elle un rôle sémantique** (texte principal, fond, bordure, primary action) ? → utilise `cs.X`.
2. **Est-elle utilisée pour un état métier** (success, warning, error) ? → utilise l'extension `cs.success` / `cs.warning` / `cs.info` / `cs.errorLight`.
3. **Est-ce une couleur de surface communautaire** (sand) ? → utilise `cs.surfaceWarm` (extension).
4. **Est-ce une couleur de marque utilisée dans une illustration** (logo, icône hero) ? → primitive `DonyColors.blue500` OK, pas brightness-aware.
5. **Est-ce une couleur "on colored bg"** (texte sur primary, sur error) ? → utilise `cs.onPrimary` / `cs.onError`, qui passent au noir en thème sombre. `DonyColors.textOnBrand` (blanc) seulement sur un fond sombre garanti dans les deux thèmes.
6. **Cette couleur peut-elle dépendre d'un contexte `const` ?** Si oui, primitive obligatoire (les `cs.X` ne sont pas const). Sinon, sémantique.

## Patterns corrects

### Card avec texte

```dart
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    color: cs.surface,
    child: Text('Bonjour', style: TextStyle(color: cs.onSurface)),
  );
}
```

### Bordure adaptative

```dart
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: cs.outline),
    ),
  );
}
```

### Statut succès

```dart
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    color: cs.successLight, // brightness-aware via extension
    child: Icon(Icons.check, color: cs.success),
  );
}
```

## Patterns incorrects

### ❌ Hardcoded surface

```dart
return Container(
  color: DonyColors.surface, // CASSE en dark — fond blanc sur bg noir
);
```

### ❌ Hardcoded text color

```dart
Text('...', style: TextStyle(color: DonyColors.textPrimary)) // CASSE en dark
```

## Tester localement en dark

```dart
testWidgets('mon widget rend en dark', (tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: MonWidget()),
  ));
});
```

## Cas d'exception

Tu peux conserver une couleur primitive `DonyColors.X` si :

- C'est dans un contexte `const Color(...)` (impossible d'accéder au `BuildContext`)
- C'est une illustration (aplat décoratif, icône avec couleur de marque)
- C'est sur un fond de couleur garantie, identique dans les deux thèmes (ex: `DonyColors.white` sur l'aplat sombre d'une carte héros de statut). Sur `cs.primary`, utiliser `cs.onPrimary` : le fond change avec le thème

Documente avec un commentaire :

```dart
// Couleur primitive intentionnelle : illustration de marque
color: DonyColors.terra500,
```
