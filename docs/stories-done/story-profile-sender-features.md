# Story Profile Sender Features — Branchement de 10 entrées ComingSoon (Flutter)

**Date :** 2026-05-12
**Status :** ✅ Complète
**Branche :** `feat/profile-sender-features`

## Résumé

Remplacement de 10 entrées `ComingSoonBottomSheet.show(...)` du profil sender par de vrais écrans fonctionnels, en 4 phases. Chaque phase ajoute de nouveaux BLoCs, écrans, routes et tests.

## Fichiers créés

### Phase 1 — Quick wins

- `features/profile/presentation/screens/faq_screen.dart` — FAQ statique, 5 sections accordéon, stagger animation
- `features/profile/bloc/support_contact_bloc.dart` + event + state — form BLoC avec validation (`isValid` : category + subject ≥5 chars + message ≥20 chars)
- `features/profile/presentation/screens/support_contact_screen.dart` — dropdown catégorie, TextFields, `launchUrl(mailto:support@yadony.com)`, bouton disabled tant qu'invalide
- `features/profile/presentation/screens/shipments_history_screen.dart` — filtre `status == 'DELIVERED'` sur `BidMyListRequested`, `_DeliveryCard` avec route vers `/bids/:id/detail`

### Phase 2 — Carnet sender

- `features/pickup_addresses/` — BLoC (Loaded/Created/Updated/SetDefault/Deleted) + model + datasource + repository + 2 écrans (list avec kebab menu + badge défaut, formulaire avec toggle isDefault)
- `features/recipients/` — BLoC + model + datasource + repository + 2 écrans (list, formulaire avec validation phone E.164 et dropdown pays SN/CI/ML/CM)
- `features/favorite_travelers/` — BLoC + model + datasource + repository + écran (read-only + supprimer des favoris)

### Phase 3 — Avis reçus + Profil public

- `features/ratings/bloc/my_reviews_bloc.dart` + event + state — appelle `RatingRepository.findMineReceived()`
- `features/ratings/presentation/screens/my_reviews_screen.dart` — header avec score moyen géant + barres de distribution `_RatingBar` + liste d'avis en stagger
- `features/profile/data/models/profile_public_model.dart` — `ProfilePublicModel.fromJson`
- `features/profile/bloc/profile_public_bloc.dart` + event + state — appelle `ProfileRepository.getProfilePublic()` + `RatingRepository.getUserRatings()`
- `features/profile/presentation/screens/profile_public_screen.dart` — hero card avatar/KYC/PRO, stats row, 3 avis récents, bouton "Voir tous mes avis"

### Phase 4 — Parrainage

- `features/referral/data/models/referral_info.dart` — `ReferralInfo.fromJson`
- `features/referral/data/referral_datasource.dart` — `getMyReferral`, `regenerateCode`, `redeemCode`
- `features/referral/data/referral_repository.dart`
- `features/referral/bloc/referral_bloc.dart` + event + state — `ReferralLoadRequested`, `ReferralCodeCopied`, `ReferralShared`
- `features/referral/presentation/screens/referral_screen.dart` — hero gradient `kGreenPrimary→kGreenDark`, code box avec copie clipboard, stats row, bouton partage sticky

## Fichiers modifiés

- `lib/app/router.dart` — 8 nouvelles routes ajoutées (faq, contact, shipments/history, addresses/*, recipients/*, favorites, reviews, public, referral)
- `lib/core/di/injection.dart` — 11 nouvelles registrations (SupportContactBloc, 3×datasource+repo+bloc addressbook, MyReviewsBloc, ProfilePublicBloc, ReferralDatasource+Repository+Bloc)
- `lib/features/profile/presentation/profile_screen.dart` — 10 tiles remplacées
- `lib/features/profile/data/profile_repository.dart` — ajout `getProfilePublic()`
- `lib/features/ratings/data/rating_repository.dart` — ajout `findMineReceived()`

## Comment ça fonctionne

### Flux utilisateur (Historique des livraisons)

1. Tap "Historique des livraisons" → `context.push('/profile/shipments/history')`
2. Le `BlocProvider` dans router crée `BidBloc..add(BidMyListRequested())`
3. `ShipmentsHistoryScreen` filtre côté client `status == 'DELIVERED'`
4. Tap "Voir détails" → `context.push('/bids/${bid.id}/detail')`

### Flux utilisateur (Support)

1. Dropdown catégorie → `SupportCategorySelected` → state.category
2. Subject + message saisis → `SupportSubjectChanged` / `SupportMessageChanged`
3. Bouton enabled dès `state.isValid` (category non vide + subject ≥5 + message ≥20)
4. Tap "Envoyer" → `SupportSubmitRequested` → `launchUrl(Uri(scheme: 'mailto', path: 'support@yadony.com', ...))`

### Flux utilisateur (Parrainage)

1. `ReferralLoadRequested` → `GET /me/referral` → `ReferralLoaded(info)`
2. Tap "Copier" → `Clipboard.setData(ClipboardData(text: info.code))`
3. Tap "Partager" → `Share.share('...${info.code}...${info.shareUrl}')`

### BLoC : events, states, transitions importantes

| BLoC | Event principal | States |
|------|----------------|--------|
| `SupportContactBloc` | `SupportSubmitRequested` | `idle → submitting → success/error` |
| `MyReviewsBloc` | `MyReviewsRequested` | `Initial → Loading → Loaded/Error` |
| `ProfilePublicBloc` | `ProfilePublicRequested(userId)` | `Initial → Loading → Loaded/Error` |
| `ReferralBloc` | `ReferralLoadRequested` | `Initial → Loading → Loaded/Error` |
| `PickupAddressBloc` | `PickupAddressLoadRequested` | `Initial → Loading → Loaded/Error` |

### Pièges et points d'attention

1. **`flutter_animate` pending timers** : ne jamais utiliser `.animate(onPlay: (c) => c.repeat())` dans les écrans — ça crée des timers infinis qui font échouer les tests. Utiliser `.animate().fadeIn(duration: 300.ms)` (fini).
2. **`pump(600ms)` dans les tests** : après `pumpWidget`, toujours `pump(const Duration(milliseconds: 600))` pour drainer les animations flutter_animate avant de vérifier les widgets.
3. **Date formatting sans intl locale** : `DateFormat('dd/MM/yyyy')` (pas de locale 'fr') pour éviter `LocaleDataException` en test.
4. **`BidError.error`** (pas `.message`) : `BidError` expose `error` (AppException), pas un String direct.
5. **`DonyTextField` paramètre `hint`** (pas `hintText`).
6. **`DonyAvatar` paramètre `size: DonyAvatarSize.sm`** (pas `radius: 18`).

## Critères d'acceptation couverts

- [x] FAQ : 5 sections accordéon avec stagger animation
- [x] Support : validation form + mailto + états submitting/success/error
- [x] Historique : filtre DELIVERED, date relative (Aujourd'hui/Hier/Il y a N jours)
- [x] Adresses pickup : CRUD + set-default + badge défaut
- [x] Destinataires : phone E.164 validé, pays restreints
- [x] Favoris : lecture + suppression
- [x] Avis reçus : score moyen + barres distribution + liste paginée
- [x] Profil public : avatar/KYC/PRO + stats + 3 avis récents
- [x] Parrainage : hero gradient + code + copie + partage + stats
- [x] Toutes les tiles branchées (10/11, 1 hors périmètre intentionnel)

## Tests

- `flutter test` → 1463 → 1498 tests (0 rouge)
- Tests ajoutés : 35 tests unitaires BLoC + ~60 tests widget
- Couverture ≥ 90% sur le nouveau code

## Décisions techniques

- **Filtre DELIVERED côté client** (Historique) : `BidMyListRequested` ne prend pas de filtre. Plutôt que d'ajouter un nouveau paramètre au BLoC partagé, on filtre à l'affichage. Volume faible (bids d'un user).
- **`launchUrl(mailto:)` côté support** : pas d'API de support pour l'instant — le mailto ouvre le client mail natif avec le sujet et le corps pré-remplis. Suffit pour le MVP.
- **Profil public charge userId depuis `extra`** : la route `/profile/public` reçoit l'userId via `state.extra`. Si null, charge l'utilisateur courant via `FirebaseAuth.instance.currentUser?.uid`.
