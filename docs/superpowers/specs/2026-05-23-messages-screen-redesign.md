# Spec — Messages screen redesign

**Date:** 2026-05-23  
**Statut:** Approuvé  
**Fichier cible:** `lib/features/messaging/presentation/conversation_list_screen.dart`

---

## Contexte

L'écran actuel affiche une `ListView` simple sans recherche ni filtrage. Le seul geste disponible est le swipe-to-delete. Le fond des tuiles non lues est presque invisible (`primaryContainer @ 7%`). L'objectif est d'élever la lisibilité, d'ajouter une recherche et un filtrage client-side, et d'enrichir le swipe sans modifier le backend ni le modèle de données.

---

## Header

Trois blocs empilés dans un `Column`, fond `cs.surface`, séparés du reste par un `Divider` (hauteur 1, couleur `cs.outlineVariant`) :

### Bloc 1 — Titre
```
Row(
  children: [
    Text("Messages")   // textTheme.headlineLarge (Hanken Grotesk 22px w800)
    Spacer()
    TextButton("Modifier")  // labelSmall / cs.primary — visible uniquement hors recherche
  ]
)
padding: EdgeInsets.fromLTRB(DonySpacing.lg, DonySpacing.md, DonySpacing.lg, 0)
```

### Bloc 2 — Barre de recherche
```
TextField pleine largeur
padding: EdgeInsets.symmetric(horizontal: DonySpacing.lg, vertical: DonySpacing.sm)

Au repos   : fond cs.surfaceContainerHighest, border-radius DonyRadius.md (12)
Au focus   : fond cs.primaryContainer, bordure cs.primary width 1.5
Prefix     : Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant)
Suffix     : IconButton(Icons.close_rounded) — visible si query non vide
Placeholder: "Rechercher une conversation…" (cs.onSurfaceVariant)
```
Pendant la recherche : le bloc Titre affiche `Annuler` à droite (remplace `Modifier`) et les pills (bloc 3) sont masquées via `AnimatedSize` + `Visibility`.

### Bloc 3 — Pills de filtre
```
SingleChildScrollView(scrollDirection: Axis.horizontal)
  Row de FilterChip/ChoiceChip
  padding: EdgeInsets.fromLTRB(DonySpacing.lg, 0, DonySpacing.lg, DonySpacing.sm)
  gap: DonySpacing.xs
```

| Pill | Condition de filtre |
|------|---------------------|
| `Tous` | — (affiche tout) |
| `Non lus · N` | `hasUnread == true` |
| `En cours` | `bidStatus == 'BID_ACCEPTED'` |
| `Terminés` | `bidStatus == 'DELIVERY_CONFIRMED'` |

---

## Liste

### Regroupement temporel

Calculé localement à partir de `lastMessageAt` au moment du build — aucun appel réseau.

| Section | Condition |
|---------|-----------|
| `AUJOURD'HUI` | `diff.inDays == 0` |
| `CETTE SEMAINE` | `diff.inDays < 7` |
| `PLUS ANCIEN` | sinon |

Structure : `CustomScrollView` + `SliverList` avec `SliverStickyHeader` (ou sections insérées dans la liste plate comme actuellement).  
Section label : `padding: EdgeInsets.fromLTRB(DonySpacing.lg, DonySpacing.md, DonySpacing.lg, DonySpacing.xs)`, style `textTheme.labelSmall` / `cs.onSurfaceVariant` / uppercase / letter-spacing 0.8.

### Tuile — état non lu
- Fond : `Color(0xFFF4F7FF)` (bleu très léger, constant — pas opacity)
- Nom : `textTheme.titleLarge` / **w800** / `cs.onSurface`
- Timestamp : `cs.primary` / w700
- Badge compteur : `_UnreadBadge` existant (inchangé)
- Preview : `cs.onSurface` / w600

### Tuile — état lu
- Fond : `cs.surface`
- Nom : `textTheme.titleLarge` / w700 / `cs.onSurface`
- Timestamp : `cs.onSurfaceVariant` / w400
- Indicateur lecture : `Text('✓✓', style: textTheme.labelSmall?.copyWith(color: cs.success))` — remplace le badge absent
- Preview : `cs.onSurfaceVariant` / w400

### Swipe gauche (Dismissible)
Deux actions exposées de droite à gauche :

```
[  Archiver 🗑  |  Supprimer 🗑  ]
   cs.warning       cs.error
   52px wide        52px wide
```

- **Archiver** : appelle `ConversationArchiveRequested(id)` — nouvel event BLoC ; retire la tuile de la liste (soft-hide local, pas de suppression backend)
- **Supprimer** : appelle `ConversationDeleteRequested(id)` — event existant, comportement inchangé

---

## BLoC — changements minimaux

### Nouvel enum
```dart
enum ConversationFilter { all, unread, active, done }
```

### State `ConversationListLoaded` — 2 champs ajoutés
```dart
final ConversationFilter filter;      // default: ConversationFilter.all
final String searchQuery;             // default: ''
```

La liste filtrée est un getter calculé — pas de liste dupliquée dans le state :
```dart
List<ConversationModel> get displayed => conversations.where((c) {
  final matchFilter = switch (filter) {
    ConversationFilter.all    => true,
    ConversationFilter.unread => c.hasUnread,
    ConversationFilter.active => c.bidStatus == 'BID_ACCEPTED',
    ConversationFilter.done   => c.bidStatus == 'DELIVERY_CONFIRMED',
  };
  final q = searchQuery.toLowerCase();
  final matchSearch = q.isEmpty ||
    c.otherParticipant.name.toLowerCase().contains(q) ||
    (c.tripOrigin?.toLowerCase().contains(q) ?? false) ||
    (c.tripDestination?.toLowerCase().contains(q) ?? false);
  return matchFilter && matchSearch;
}).toList();
```

### Nouvel event
```dart
class ConversationFilterChanged extends ConversationListEvent {
  final ConversationFilter filter;
  final String searchQuery;
  const ConversationFilterChanged({required this.filter, required this.searchQuery});
}
```

### Nouvel event (archive)
```dart
class ConversationArchiveRequested extends ConversationListEvent {
  final String conversationId;
  const ConversationArchiveRequested(this.conversationId);
}
```
Handler : retire la conversation de `state.conversations` localement (pas d'appel API dans un premier temps).

---

## Animations

- Entrée des tuiles : `flutter_animate` — `fadeIn(duration: 260ms) + slideY(begin: 0.03)` avec stagger `50ms × index` (comportement actuel conservé)
- Transition pills/recherche : `AnimatedSize(duration: 200ms, curve: Curves.easeInOutCubic)` sur le bloc 3
- Swipe reveal : comportement natif `Dismissible` Flutter

---

## Ce qui ne change pas

- `ConversationListBloc`, `ConversationsLoadRequested`, `ConversationDeleteRequested` — inchangés
- `ConversationModel` et `ParticipantModel` — inchangés
- Navigation : `context.push('/conversations/${conv.id}', extra: conv)` — inchangée
- `RefreshIndicator` — conservé
- États `Loading`, `Error` — conservés avec les mêmes widgets `DonyEmptyState`

---

## Fichiers à modifier

| Fichier | Type de changement |
|---------|--------------------|
| `presentation/conversation_list_screen.dart` | Réécriture UI complète |
| `bloc/conversation_list/conversation_list_state.dart` | +2 champs + getter `displayed` |
| `bloc/conversation_list/conversation_list_event.dart` | +2 events |
| `bloc/conversation_list/conversation_list_bloc.dart` | +2 handlers |

---

## Hors scope

- Backend : aucun endpoint nouveau
- Écran `ChatScreen` : inchangé
- Notification push : inchangée
- Mode sombre : suivi automatique via `cs.*` — aucun token hardcodé
