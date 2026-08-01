# Brouillons de demandes et dépublication — plan Flutter

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consommer les brouillons et la dépublication de demandes côté app, refondre « Ma demande » autour d'une grille d'actions propriétaire, et ajouter la dépublication à l'écran détail trajet.

**Architecture:** Le wizard de demande reprend le pattern déjà validé du wizard de trajet (`AnnouncementPreviewSheet` → `PackageRequestPreviewSheet`). L'écran « Ma demande » existe en deux exemplaires (plein écran + bottom sheet) qui dupliquent déjà le même corps ; ce plan les fait converger vers un widget de corps commun avant d'y greffer la grille — sans cette extraction, la grille se réécrirait deux fois et divergerait. Les listes reprennent le traitement déjà en place pour les brouillons de trajet (badge, filtre, tri).

**Tech Stack:** Flutter / Dart, flutter_bloc, GoRouter, Dio, get_it, flutter_animate.

**Spec:** `docs/superpowers/specs/2026-08-01-brouillons-demandes-depublication-design.md` (dans `dony-back`, dépôt distinct)

**Dépendance :** ce plan consomme les 4 endpoints livrés par `docs/superpowers/plans/2026-08-01-brouillons-demandes-depublication-backend.md` (`dony-back`) : `POST /package-requests/{id}/publish`, `POST /package-requests/{id}/unpublish`, `POST /announcements/{id}/unpublish`, et `saveAsDraft` sur `POST /package-requests`. Ces endpoints doivent être déployés (ou au moins mergés + testables) avant la Task 3.

## Global Constraints

- Branche de travail dans `dony_app` : `feature/brouillons-demandes-depublication`. **Ne jamais commiter sur `main`.**
- Jamais de `Co-Authored-By: Claude` dans les messages de commit.
- BLoC pour tout état de feature — **jamais `setState`**, sauf dans les deux fichiers de cet écran qui l'utilisent déjà (`package_request_detail_screen.dart`) : ce plan n'étend pas le périmètre du `setState` existant, il le déplace vers le widget de corps commun sans en ajouter ailleurs.
- GoRouter pour toute navigation — jamais `Navigator.push()` (l'écran de succès de publication fait exception, voir `trip_owner_detail_screen.dart:118` : un `MaterialPageRoute` poussé sur le `Navigator` racine, pattern déjà utilisé pour l'écran de succès trajet).
- `DonyButton` dans une bottom sheet : **toujours** dans `stickyBottom`, jamais dans le `child` scrollable.
- Tracking analytics : tout nouvel événement métier déclaré dans `AnalyticsEvents`, tiré depuis le BLoC (ou, à défaut de BLoC sur cet écran, depuis le point d'appel repository — cf. patterns `wallet_topup_started` déclenchés hors BLoC), jamais de PII, toujours `unawaited()`.
- Jamais de tiret cadratin (—) dans un texte affiché à l'utilisateur ; remplacer par une virgule.
- Chaque tâche corrige ou ajoute ses tests avant le commit. Couverture globale ≥ 90 % (`flutter test --coverage`).
- `flutter analyze` sans nouvelle erreur avant chaque commit.
- **Jamais deux commandes Flutter en parallèle** (`flutter test` et `flutter run` simultanés fabriquent de faux échecs par collision sur `.dart_tool` et les assets partagés).

## File Structure

**Créés :**
- `lib/features/package_request/presentation/widgets/package_request_preview_sheet.dart` — sheet d'aperçu étape 3, miroir de `AnnouncementPreviewSheet`
- `lib/features/package_request/presentation/widgets/request_owner_action_grid.dart` — grille d'actions propriétaire (Publier / Modifier / Dépublier / Annuler)
- `lib/features/package_request/presentation/widgets/package_request_detail_body.dart` — corps commun extrait de l'écran et de la sheet (hero card + grille + section offres)
- `test/features/package_request/presentation/widgets/package_request_preview_sheet_test.dart`
- `test/features/package_request/presentation/widgets/request_owner_action_grid_test.dart`

**Modifiés :**
- `lib/features/package_request/data/models/package_request.dart` — `+ PackageRequestStatus.draft`
- `lib/features/package_request/data/package_request_repository.dart` — `create(..., saveAsDraft)`, `+ publish`, `+ unpublish`
- `lib/features/package_request/bloc/package_request_form_event.dart` — `FormStep3Submitted(..., saveAsDraft)`
- `lib/features/package_request/bloc/package_request_form_state.dart` — `+ draftLimitMessage` (avec flag d'effacement)
- `lib/features/package_request/bloc/package_request_form_bloc.dart` — `_onStep3` transmet `saveAsDraft`, détecte `draft-limit-reached`
- `lib/features/package_request/bloc/request_filter_cubit.dart` — `+ RequestQuickFilter.draft`, `isSearchRequest` inclut `DRAFT`
- `lib/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart` — CTA « Aperçu » au lieu de « Publier ma demande »
- `lib/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart` — branchement de la sheet, dialogue de limite de brouillons
- `lib/features/package_request/presentation/screens/sender/package_request_detail_screen.dart` — les deux enveloppes (écran + sheet) consomment `PackageRequestDetailBody`, suppression du `…` et du bouton rouge sticky
- `lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart` — filtre Brouillons, tri, badge, état vide
- `lib/features/matching/bloc/announcement_event.dart` — `+ AnnouncementUnpublishRequested`
- `lib/features/matching/bloc/announcement_state.dart` — `+ AnnouncementUnpublished`
- `lib/features/matching/bloc/announcement_bloc.dart` — handler de dépublication
- `lib/features/matching/data/repositories/announcement_repository.dart` — `+ unpublishAnnouncement`
- `lib/features/matching/data/datasources/announcement_remote_datasource.dart` — `+ unpublishAnnouncement`
- `lib/features/matching/presentation/widgets/owner_action_grid.dart` — `+` tuile Dépublier
- `lib/features/matching/presentation/screens/trip_owner_detail_screen.dart` — écoute `AnnouncementUnpublished`
- `test/features/package_request/presentation/screens/sender/package_request_detail_screen_test.dart`
- `test/features/package_request/presentation/screens/sender/my_package_requests_screen_test.dart`
- `test/features/package_request/bloc/request_filter_cubit_test.dart`
- `test/features/package_request/bloc/package_request_form_bloc_test.dart`
- `test/features/matching/bloc/announcement_bloc_test.dart`
- `test/features/matching/presentation/widgets/owner_action_grid_test.dart`

---

### Task 1 : contrat réseau — statut, création en brouillon, publish/unpublish

**Files:**
- Modify: `lib/features/package_request/data/models/package_request.dart:7-20`
- Modify: `lib/features/package_request/data/package_request_repository.dart:104-148,226-228`
- Modify: `lib/features/matching/data/repositories/announcement_repository.dart:61-62`
- Modify: `lib/features/matching/data/datasources/announcement_remote_datasource.dart:70-73`
- Test: `test/features/package_request/data/package_request_repository_test.dart` (créer s'il n'existe pas, sinon l'étendre)

**Interfaces:**
- Produces:
  - `PackageRequestStatus.draft` (wire `'DRAFT'`)
  - `PackageRequestRepository.create({..., bool saveAsDraft = false})` → `Future<PackageRequest>`
  - `PackageRequestRepository.publish(String id)` → `Future<PackageRequest>`
  - `PackageRequestRepository.unpublish(String id)` → `Future<PackageRequest>`
  - `AnnouncementRepository.unpublishAnnouncement(String id)` → `Future<AnnouncementModel>`

- [ ] **Step 1: Ajouter le statut `draft`**

Modifier `lib/features/package_request/data/models/package_request.dart` :

```dart
enum PackageRequestStatus {
  draft('DRAFT'),
  open('OPEN'),
  negotiating('NEGOTIATING'),
  accepted('ACCEPTED'),
  expired('EXPIRED'),
  cancelled('CANCELLED'),
  completed('COMPLETED');

  final String wireName;
  const PackageRequestStatus(this.wireName);

  static PackageRequestStatus fromJson(String s) =>
      PackageRequestStatus.values.firstWhere((e) => e.wireName == s);
}
```

- [ ] **Step 2: Vérifier qu'aucun `switch` exhaustif ne casse à la compilation**

Run: `flutter analyze`
Expected: toute erreur `non_exhaustive_switch` pointe un fichier à corriger dans une tâche ultérieure de ce plan (`my_package_requests_screen.dart` en Task 6). Si `flutter analyze` échoue ailleurs, noter le fichier — il sera traité en Task 6.

- [ ] **Step 3: Ajouter `saveAsDraft` à la création**

Modifier `lib/features/package_request/data/package_request_repository.dart`, méthode `create` (ligne 104-148) :

```dart
  Future<PackageRequest> create({
    required String departureCity,
    required String arrivalCity,
    required DateTime desiredDate,
    required int dateToleranceDays,
    required double weightKg,
    required ParcelSize parcelSize,
    required TransportMode transportMode,
    required List<String> categories,
    required bool negotiable,
    required Set<PaymentMethod> acceptedPaymentMethods,
    double? totalBudgetEur,
    String? description,
    String? photoUrl,
    String? pickupNeighborhood,
    String? deliveryNeighborhood,
    List<String>? photoKeys,
    bool saveAsDraft = false,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/package-requests',
      data: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        'desiredDate': desiredDate.toIso8601String().substring(0, 10),
        'dateToleranceDays': dateToleranceDays,
        'weightKg': weightKg,
        'parcelSize': parcelSize.wireName,
        'transportMode': transportModeToWire(transportMode),
        'contentCategory': categories.join(','),
        'negotiable': negotiable,
        'acceptedPaymentMethods': acceptedPaymentMethods
            .map((m) => m.wireName)
            .toList(),
        if (totalBudgetEur != null) 'totalBudgetEur': totalBudgetEur,
        if (description != null) 'description': description,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (pickupNeighborhood != null)
          'pickupNeighborhood': pickupNeighborhood,
        if (deliveryNeighborhood != null)
          'deliveryNeighborhood': deliveryNeighborhood,
        if (photoKeys != null && photoKeys.isNotEmpty) 'photoKeys': photoKeys,
        if (saveAsDraft) 'saveAsDraft': true,
      },
    );
    return PackageRequest.fromJson(response.data!);
  }
```

- [ ] **Step 4: Ajouter `publish` et `unpublish`**

Ajouter dans le même fichier, juste après `cancel` (ligne 226-228) :

```dart
  /// Publie un brouillon (DRAFT → OPEN). Rejoue les mêmes contrôles que la
  /// création (KYC, corridor, date, quota) ; 403 `draft-limit-reached` n'a
  /// pas cours ici, seul `publish` de trajet le porte.
  Future<PackageRequest> publish(String id) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/package-requests/$id/publish',
    );
    return PackageRequest.fromJson(response.data!);
  }

  /// Retire une demande de la circulation sans l'annuler (OPEN → DRAFT).
  /// 409 `request/has-offers` si un voyageur a déjà répondu, 403
  /// `draft-limit-reached` si le quota de brouillons est déjà atteint.
  Future<PackageRequest> unpublish(String id) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/package-requests/$id/unpublish',
    );
    return PackageRequest.fromJson(response.data!);
  }
```

- [ ] **Step 5: Ajouter `unpublishAnnouncement`**

Modifier `lib/features/matching/data/datasources/announcement_remote_datasource.dart`, après `publishAnnouncement` (ligne 70-73) :

```dart
  Future<AnnouncementModel> unpublishAnnouncement(String id) async {
    final response = await _apiClient.dio.post('/announcements/$id/unpublish');
    return AnnouncementModel.fromJson(response.data as Map<String, dynamic>);
  }
```

Modifier `lib/features/matching/data/repositories/announcement_repository.dart`, après `publishAnnouncement` (ligne 61-62) :

```dart
  Future<AnnouncementModel> unpublishAnnouncement(String id) =>
      _remoteDatasource.unpublishAnnouncement(id);
```

- [ ] **Step 6: Écrire/étendre les tests de repository**

Si `test/features/package_request/data/package_request_repository_test.dart` n'existe pas, vérifier d'abord :

Run: `find test/features/package_request/data -iname "*repository*"`

S'il existe déjà, y ajouter (adapter au style de mock Dio déjà présent dans le fichier — `DioAdapter` ou équivalent) :

```dart
  test('create() with saveAsDraft=true sends saveAsDraft:true in body', () async {
    // Poser le mock Dio pour capturer le body de la requête POST
    // /package-requests, appeler repository.create(..., saveAsDraft: true),
    // vérifier que le payload capturé contient 'saveAsDraft': true.
  });

  test('create() without saveAsDraft omits the field (comportement historique)', () async {
    // Même appel sans saveAsDraft → le payload ne contient pas la clé
    // 'saveAsDraft' du tout (pas 'saveAsDraft': false).
  });

  test('publish() posts to /package-requests/{id}/publish and parses response', () async {
    // Mock POST /package-requests/abc/publish → body JSON d'une demande
    // OPEN, vérifier que repository.publish('abc') retourne un
    // PackageRequest avec status == PackageRequestStatus.open.
  });

  test('unpublish() posts to /package-requests/{id}/unpublish and parses response', () async {
    // Symétrique : status == PackageRequestStatus.draft dans la réponse mockée.
  });
```

Remplir chaque corps en reprenant exactement le pattern de mock déjà utilisé par les tests voisins de ce fichier pour `cancel()` ou `create()`.

- [ ] **Step 7: Lancer les tests**

Run: `flutter test test/features/package_request/data/package_request_repository_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/package_request/data/ lib/features/matching/data/ \
        test/features/package_request/data/
git commit -m "feat(requests): ajoute saveAsDraft, publish et unpublish au repository"
```

---

### Task 2 : le formulaire de demande sait créer un brouillon

**Files:**
- Modify: `lib/features/package_request/bloc/package_request_form_event.dart:62-81`
- Modify: `lib/features/package_request/bloc/package_request_form_state.dart`
- Modify: `lib/features/package_request/bloc/package_request_form_bloc.dart:109-195`
- Test: `test/features/package_request/bloc/package_request_form_bloc_test.dart`

**Interfaces:**
- Consumes: `PackageRequestRepository.create(..., saveAsDraft)` (Task 1).
- Produces:
  - `FormStep3Submitted(..., bool saveAsDraft = false)`
  - `PackageRequestFormState.draftLimitMessage` → `String?`, effacé via `clearDraftLimitMessage: true`

- [ ] **Step 1: Ajouter le champ à l'event**

Modifier `lib/features/package_request/bloc/package_request_form_event.dart` (ligne 62-81) :

```dart
class FormStep3Submitted extends PackageRequestFormEvent {
  const FormStep3Submitted({
    this.targetPriceEur,
    this.photoKeys,
    this.pickupNeighborhood,
    this.deliveryNeighborhood,
    this.saveAsDraft = false,
  });
  final double? targetPriceEur;

  /// Clés S3 des photos colis. null = conserver (édition) ; liste = remplacer.
  final List<String>? photoKeys;
  final String? pickupNeighborhood;
  final String? deliveryNeighborhood;

  /// true → POST avec saveAsDraft. Ignoré en édition : un brouillon édité
  /// reste un brouillon côté backend, aucun signal à envoyer.
  final bool saveAsDraft;

  @override
  List<Object?> get props => [
    targetPriceEur,
    pickupNeighborhood,
    deliveryNeighborhood,
    saveAsDraft,
  ];
}
```

- [ ] **Step 2: Ajouter `draftLimitMessage` à l'état**

Modifier `lib/features/package_request/bloc/package_request_form_state.dart` — ajouter le champ, son paramètre de constructeur, son paramètre de `copyWith` (avec flag d'effacement, même pattern que `clearTotalBudgetEur`) et l'entrée dans `props` :

```dart
  const PackageRequestFormState({
    this.currentStep = 0,
    this.departureCity,
    this.arrivalCity,
    this.desiredDate,
    this.dateToleranceDays,
    this.transportMode,
    this.weightKg,
    this.parcelSize,
    this.categories = const [],
    this.description,
    this.targetPriceEur,
    this.photoUrl,
    this.pickupNeighborhood,
    this.deliveryNeighborhood,
    this.negotiable = true,
    this.acceptedPaymentMethods = const {PaymentMethod.stripe},
    this.totalBudgetEur,
    this.submissionStatus = FormSubmissionStatus.idle,
    this.errorMessage,
    this.draftLimitMessage,
    this.createdRequest,
    this.editingRequestId,
  });
```

```dart
  final String? draftLimitMessage;
```

(à ajouter juste après `final String? errorMessage;`)

```dart
  PackageRequestFormState copyWith({
    int? currentStep,
    String? departureCity,
    String? arrivalCity,
    DateTime? desiredDate,
    int? dateToleranceDays,
    TransportMode? transportMode,
    double? weightKg,
    ParcelSize? parcelSize,
    List<String>? categories,
    String? description,
    double? targetPriceEur,
    String? photoUrl,
    String? pickupNeighborhood,
    String? deliveryNeighborhood,
    bool? negotiable,
    Set<PaymentMethod>? acceptedPaymentMethods,
    double? totalBudgetEur,
    bool clearTotalBudgetEur = false,
    FormSubmissionStatus? submissionStatus,
    String? errorMessage,
    String? draftLimitMessage,
    // Même pattern que clearTotalBudgetEur : un message de limite affiché
    // une fois doit pouvoir être effacé, pas seulement remplacé.
    bool clearDraftLimitMessage = false,
    PackageRequest? createdRequest,
    String? editingRequestId,
  }) => PackageRequestFormState(
    currentStep: currentStep ?? this.currentStep,
    departureCity: departureCity ?? this.departureCity,
    arrivalCity: arrivalCity ?? this.arrivalCity,
    desiredDate: desiredDate ?? this.desiredDate,
    dateToleranceDays: dateToleranceDays ?? this.dateToleranceDays,
    transportMode: transportMode ?? this.transportMode,
    weightKg: weightKg ?? this.weightKg,
    parcelSize: parcelSize ?? this.parcelSize,
    categories: categories ?? this.categories,
    description: description ?? this.description,
    targetPriceEur: targetPriceEur ?? this.targetPriceEur,
    photoUrl: photoUrl ?? this.photoUrl,
    pickupNeighborhood: pickupNeighborhood ?? this.pickupNeighborhood,
    deliveryNeighborhood: deliveryNeighborhood ?? this.deliveryNeighborhood,
    negotiable: negotiable ?? this.negotiable,
    acceptedPaymentMethods:
        acceptedPaymentMethods ?? this.acceptedPaymentMethods,
    totalBudgetEur:
        clearTotalBudgetEur ? null : (totalBudgetEur ?? this.totalBudgetEur),
    submissionStatus: submissionStatus ?? this.submissionStatus,
    errorMessage: errorMessage ?? this.errorMessage,
    draftLimitMessage: clearDraftLimitMessage
        ? null
        : (draftLimitMessage ?? this.draftLimitMessage),
    createdRequest: createdRequest ?? this.createdRequest,
    editingRequestId: editingRequestId ?? this.editingRequestId,
  );
```

```dart
  @override
  List<Object?> get props => [
    currentStep,
    departureCity,
    arrivalCity,
    desiredDate,
    dateToleranceDays,
    transportMode,
    weightKg,
    parcelSize,
    categories,
    description,
    targetPriceEur,
    photoUrl,
    pickupNeighborhood,
    deliveryNeighborhood,
    negotiable,
    acceptedPaymentMethods,
    totalBudgetEur,
    submissionStatus,
    errorMessage,
    draftLimitMessage,
    createdRequest,
    editingRequestId,
  ];
```

- [ ] **Step 3: Écrire les tests bloc qui échouent**

Ajouter dans `test/features/package_request/bloc/package_request_form_bloc_test.dart` (le fichier utilise déjà `blocTest` avec un mock repository — reprendre le style des tests voisins de `FormStep3Submitted`) :

```dart
  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormStep3Submitted(saveAsDraft: true) creates with saveAsDraft:true',
    build: () => makeBloc(repo),
    seed: () => const PackageRequestFormState(
      currentStep: 2,
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: null, // à remplacer par une date valide, cf. seed existant du fichier
      dateToleranceDays: 2,
      weightKg: 3.0,
      categories: ['Documents'],
      negotiable: true,
    ),
    act: (b) => b.add(const FormStep3Submitted(saveAsDraft: true)),
    verify: (b) {
      final captured = verify(() => repo.create(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        desiredDate: any(named: 'desiredDate'),
        dateToleranceDays: any(named: 'dateToleranceDays'),
        weightKg: any(named: 'weightKg'),
        parcelSize: any(named: 'parcelSize'),
        transportMode: any(named: 'transportMode'),
        categories: any(named: 'categories'),
        negotiable: any(named: 'negotiable'),
        acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
        totalBudgetEur: any(named: 'totalBudgetEur'),
        description: any(named: 'description'),
        photoKeys: any(named: 'photoKeys'),
        pickupNeighborhood: any(named: 'pickupNeighborhood'),
        deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
        saveAsDraft: captureAny(named: 'saveAsDraft'),
      )).captured;
      expect(captured.single, isTrue);
    },
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormStep3Submitted() without saveAsDraft creates with saveAsDraft:false',
    build: () => makeBloc(repo),
    seed: () => const PackageRequestFormState(/* même seed valide que ci-dessus */),
    act: (b) => b.add(const FormStep3Submitted()),
    verify: (b) {
      final captured = verify(() => repo.create(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        desiredDate: any(named: 'desiredDate'),
        dateToleranceDays: any(named: 'dateToleranceDays'),
        weightKg: any(named: 'weightKg'),
        parcelSize: any(named: 'parcelSize'),
        transportMode: any(named: 'transportMode'),
        categories: any(named: 'categories'),
        negotiable: any(named: 'negotiable'),
        acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
        totalBudgetEur: any(named: 'totalBudgetEur'),
        description: any(named: 'description'),
        photoKeys: any(named: 'photoKeys'),
        pickupNeighborhood: any(named: 'pickupNeighborhood'),
        deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
        saveAsDraft: captureAny(named: 'saveAsDraft'),
      )).captured;
      expect(captured.single, isFalse);
    },
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'draft-limit-reached (403) sets draftLimitMessage, not the generic errorMessage',
    build: () {
      when(() => repo.create(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        desiredDate: any(named: 'desiredDate'),
        dateToleranceDays: any(named: 'dateToleranceDays'),
        weightKg: any(named: 'weightKg'),
        parcelSize: any(named: 'parcelSize'),
        transportMode: any(named: 'transportMode'),
        categories: any(named: 'categories'),
        negotiable: any(named: 'negotiable'),
        acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
        totalBudgetEur: any(named: 'totalBudgetEur'),
        description: any(named: 'description'),
        photoKeys: any(named: 'photoKeys'),
        pickupNeighborhood: any(named: 'pickupNeighborhood'),
        deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
        saveAsDraft: any(named: 'saveAsDraft'),
      )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/package-requests'),
        error: const ForbiddenException('Limite de 1 brouillon(s) atteinte.',
            'draft-limit-reached'),
      ));
      return makeBloc(repo);
    },
    seed: () => const PackageRequestFormState(/* même seed valide */),
    act: (b) => b.add(const FormStep3Submitted(saveAsDraft: true)),
    expect: () => [
      isA<PackageRequestFormState>().having(
        (s) => s.submissionStatus, 'submissionStatus', FormSubmissionStatus.submitting),
      isA<PackageRequestFormState>()
          .having((s) => s.submissionStatus, 'submissionStatus', FormSubmissionStatus.error)
          .having((s) => s.draftLimitMessage, 'draftLimitMessage',
              'Limite de 1 brouillon(s) atteinte.')
          .having((s) => s.errorMessage, 'errorMessage', isNull),
    ],
  );
```

Ajouter les imports nécessaires en tête du fichier de test s'ils n'y sont pas déjà : `import 'package:dio/dio.dart';` et `import 'package:dony/core/error/app_exception.dart';`.

Adapter le `seed` exact (`desiredDate`, etc.) au premier seed valide déjà présent plus haut dans ce même fichier de test, pour éviter tout écart de valeurs entre tests.

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/features/package_request/bloc/package_request_form_bloc_test.dart`
Expected: FAIL — `saveAsDraft` n'existe pas encore sur `FormStep3Submitted`, compilation impossible.

- [ ] **Step 5: Transmettre `saveAsDraft` et détecter la limite de brouillons**

Modifier `_onStep3` dans `lib/features/package_request/bloc/package_request_form_bloc.dart` (lignes 109-195).

Le chemin création (`else` de `if (editingId != null)`, lignes 144-165) reçoit `saveAsDraft: e.saveAsDraft` :

```dart
      } else {
        saved = await _repository.create(
          departureCity: state.departureCity!,
          arrivalCity: state.arrivalCity!,
          desiredDate: state.desiredDate!,
          dateToleranceDays: state.dateToleranceDays!,
          weightKg: state.weightKg!,
          categories: state.categories,
          parcelSize: state.parcelSize!,
          transportMode: state.transportMode!,
          negotiable: state.negotiable,
          acceptedPaymentMethods: state.acceptedPaymentMethods,
          totalBudgetEur: state.totalBudgetEur ?? e.targetPriceEur,
          description: state.description,
          photoKeys: e.photoKeys,
          pickupNeighborhood: _blankToNull(state.pickupNeighborhood),
          deliveryNeighborhood: _blankToNull(state.deliveryNeighborhood),
          saveAsDraft: e.saveAsDraft,
        );
      }
```

Le bloc `catch` (lignes 187-194) distingue `draft-limit-reached` :

```dart
    } catch (err) {
      final error = unwrapDioError(err);
      if (error is ForbiddenException && error.code == 'draft-limit-reached') {
        emit(
          state.copyWith(
            submissionStatus: FormSubmissionStatus.error,
            draftLimitMessage: error.message,
          ),
        );
      } else {
        emit(
          state.copyWith(
            submissionStatus: FormSubmissionStatus.error,
            errorMessage: error.message,
          ),
        );
      }
    }
```

Ajouter l'import en tête du fichier s'il n'y est pas :

```dart
import 'package:dony/core/error/app_exception.dart';
```

Note : le `catch` remplace `err.toString()` par `error.message` (le message métier propre plutôt que la représentation brute de l'exception) — c'est un effet de bord positif de ce changement, pas son objet.

- [ ] **Step 6: Lancer les tests pour vérifier qu'ils passent**

Run: `flutter test test/features/package_request/bloc/package_request_form_bloc_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/package_request/bloc/ test/features/package_request/bloc/package_request_form_bloc_test.dart
git commit -m "feat(requests): FormStep3Submitted sait créer un brouillon"
```

---

### Task 3 : sheet d'aperçu à l'étape 3 du wizard

**Files:**
- Create: `lib/features/package_request/presentation/widgets/package_request_preview_sheet.dart`
- Test: `test/features/package_request/presentation/widgets/package_request_preview_sheet_test.dart`
- Modify: `lib/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart`
- Modify: `lib/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart`
- Test: `test/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget_test.dart`

**Interfaces:**
- Consumes: `FormStep3Submitted(saveAsDraft)` (Task 2), `PackageRequestFormState.draftLimitMessage` (Task 2).
- Produces: `PackageRequestPreviewSheet.show(BuildContext, {required PackageRequestFormState formState, required VoidCallback onConfirm, VoidCallback? onSaveDraft, bool isSubmitting = false})`.

- [ ] **Step 1: Lire `AnnouncementPreviewSheet` en entier**

Run: `cat lib/features/matching/presentation/widgets/announcement_preview_sheet.dart`

C'est le gabarit exact à reproduire : `DonyBottomSheet.show`, deux boutons dans `stickyBottom` (le second visible seulement si `onSaveDraft != null`), un corps qui liste les champs du formulaire.

- [ ] **Step 2: Écrire le widget**

Créer `lib/features/package_request/presentation/widgets/package_request_preview_sheet.dart` en reproduisant la structure de `AnnouncementPreviewSheet` (mêmes imports `DonyBottomSheet`, `DonyButton`, `DonySpacing`) :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Sheet d'aperçu de l'étape 3 du wizard de demande d'envoi — miroir de
/// `AnnouncementPreviewSheet`. Deux sorties : publication immédiate ou
/// enregistrement en brouillon (proposé seulement si [onSaveDraft] est fourni).
abstract final class PackageRequestPreviewSheet {
  static Future<void> show(
    BuildContext context, {
    required PackageRequestFormState formState,
    required VoidCallback onConfirm,
    VoidCallback? onSaveDraft,
    bool isSubmitting = false,
  }) {
    return DonyBottomSheet.show<void>(
      context,
      title: 'Aperçu de ta demande',
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            key: const Key('preview-publish'),
            label: 'Publier ma demande',
            onPressed: isSubmitting ? null : onConfirm,
            isLoading: isSubmitting,
          ),
          if (onSaveDraft != null) ...[
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('preview-save-draft'),
              label: 'Enregistrer en brouillon',
              variant: DonyButtonVariant.secondary,
              onPressed: isSubmitting ? null : onSaveDraft,
            ),
          ],
        ],
      ),
      child: _PreviewBody(formState: formState),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.formState});
  final PackageRequestFormState formState;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final s = formState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${s.departureCity} → ${s.arrivalCity}',
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: DonySpacing.xs),
        if (s.desiredDate != null)
          Text(
            '${DateFormat('d MMMM', 'fr').format(s.desiredDate!)} '
            '±${s.dateToleranceDays ?? 0}j · ${s.weightKg?.toStringAsFixed(0) ?? '?'} kg',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        if (s.categories.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.xs),
          Text(
            s.categories.join(', '),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: DonySpacing.base),
        Text(
          s.negotiable
              ? (s.totalBudgetEur != null
                  ? 'Budget indicatif : ${s.totalBudgetEur!.toStringAsFixed(0)} €'
                  : 'Ouvert aux offres')
              : 'Prix ferme : ${s.totalBudgetEur?.toStringAsFixed(0) ?? '?'} €',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Écrire le test widget**

Créer `test/features/package_request/presentation/widgets/package_request_preview_sheet_test.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAndOpen(
    WidgetTester tester, {
    VoidCallback? onSaveDraft,
    required VoidCallback onConfirm,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => PackageRequestPreviewSheet.show(
              context,
              formState: const PackageRequestFormState(
                departureCity: 'Paris',
                arrivalCity: 'Dakar',
              ),
              onConfirm: onConfirm,
              onSaveDraft: onSaveDraft,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('sans onSaveDraft, seul le bouton Publier est affiché',
      (tester) async {
    await pumpAndOpen(tester, onConfirm: () {});
    expect(find.byKey(const Key('preview-publish')), findsOneWidget);
    expect(find.byKey(const Key('preview-save-draft')), findsNothing);
  });

  testWidgets('avec onSaveDraft, les deux boutons sont affichés',
      (tester) async {
    await pumpAndOpen(tester, onConfirm: () {}, onSaveDraft: () {});
    expect(find.byKey(const Key('preview-publish')), findsOneWidget);
    expect(find.byKey(const Key('preview-save-draft')), findsOneWidget);
  });

  testWidgets('tap sur Publier appelle onConfirm', (tester) async {
    var confirmed = false;
    await pumpAndOpen(tester, onConfirm: () => confirmed = true);
    await tester.tap(find.byKey(const Key('preview-publish')));
    expect(confirmed, isTrue);
  });

  testWidgets('tap sur Enregistrer en brouillon appelle onSaveDraft',
      (tester) async {
    var drafted = false;
    await pumpAndOpen(tester, onConfirm: () {}, onSaveDraft: () => drafted = true);
    await tester.tap(find.byKey(const Key('preview-save-draft')));
    expect(drafted, isTrue);
  });
}
```

- [ ] **Step 4: Lancer le test**

Run: `flutter test test/features/package_request/presentation/widgets/package_request_preview_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Le CTA de l'étape 3 devient « Aperçu »**

Modifier `lib/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart` — le bouton « Publier ma demande » de la coque est porté par `_StickyCta` dans `package_request_create_screen.dart`, pas par ce fichier (cf. commentaire ligne 211-212 : *« Le CTA "Publier ma demande" + la mention CGU sont portés par la barre sticky du wizard »*). Aucun changement n'est donc nécessaire dans `step_3_recap_budget.dart` lui-même — le changement de libellé et de comportement se fait dans `package_request_create_screen.dart` à l'étape suivante.

- [ ] **Step 6: Brancher la sheet dans la coque du wizard**

Modifier `lib/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart`.

Dans `_StickyCta`, le libellé de l'étape finale passe de `'Publier ma demande'` à `'Aperçu'`, et `onPressed` n'appelle plus directement la soumission mais ouvre la sheet. Repérer le bloc `isFinalStep ? 'Publier ma demande' : 'Continuer'` (deux occurrences, lignes ~438-442 et ~455-457 selon la version lue) et le remplacer par :

```dart
                      label: isSubmitting
                          ? 'Publication…'
                          : isFinalStep
                          ? 'Aperçu'
                          : 'Continuer',
                      iconRightAsset: isFinalStep ? 'arrow-right' : 'arrow-right',
```

Le `onPressed` de l'étape finale n'invoque plus `onPressed` (qui appelait `_step3Key.currentState?.submit()`) directement : il doit ouvrir `PackageRequestPreviewSheet.show(...)` avec `onConfirm` et `onSaveDraft` qui, eux, appellent la soumission. Le point d'insertion le plus sûr est `_onCtaPressed` :

```dart
  void _onCtaPressed(BuildContext context, PackageRequestFormState state) {
    switch (state.currentStep) {
      case 0:
        _step1Key.currentState?.submit();
      case 1:
        _step2Key.currentState?.submit();
      default:
        PackageRequestPreviewSheet.show(
          context,
          formState: state,
          onConfirm: () {
            Navigator.of(context, rootNavigator: true).pop();
            _step3Key.currentState?.submit();
          },
          onSaveDraft: () {
            Navigator.of(context, rootNavigator: true).pop();
            _step3Key.currentState?.submit(saveAsDraft: true);
          },
        );
    }
  }
```

Ajouter l'import :

```dart
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_sheet.dart';
```

Modifier `Step3RecapBudgetState.submit()` dans `step_3_recap_budget.dart` (lignes 63-83) pour accepter le paramètre :

```dart
  void submit({bool saveAsDraft = false}) {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final state = context.read<PackageRequestFormBloc>().state;
    // Le budget n'est obligatoire qu'en prix ferme publié ; un brouillon
    // peut être enregistré sans prix, il sera exigé à la publication.
    if (!saveAsDraft && !state.negotiable && state.totalBudgetEur == null) {
      _sync();
      return;
    }
    final photosCubit = context.read<PackageRequestPhotosCubit>();
    context.read<PackageRequestFormBloc>().add(
          FormStep3Submitted(
            photoKeys: photosCubit.touched ? photosCubit.readyKeys : null,
            saveAsDraft: saveAsDraft,
          ),
        );
  }
```

- [ ] **Step 7: Ajouter le dialogue de limite de brouillons**

Dans `package_request_create_screen.dart`, `_onStateChange` (lignes 177-222) gère aujourd'hui `success` et `error` génériques. Ajouter, avant la branche `error` générique :

```dart
    } else if (state.submissionStatus == FormSubmissionStatus.error &&
        state.draftLimitMessage != null) {
      unawaited(_handleDraftLimitReached(context, state.draftLimitMessage!));
    } else if (state.submissionStatus == FormSubmissionStatus.error) {
      ErrorPresenter.show(
        context,
        state.errorMessage ?? 'Erreur lors de la création',
      );
    }
```

Ajouter la méthode, calquée sur le dialogue `AnnouncementDraftLimitReached` de `create_trip_screen.dart` :

```dart
  Future<void> _handleDraftLimitReached(
    BuildContext context,
    String message,
  ) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Limite de brouillons atteinte',
      message: message,
      confirmLabel: 'Passer en PRO',
      cancelLabel: 'Plus tard',
    );
    if (confirmed == true && context.mounted) {
      unawaited(context.push('/profile/upgrade-to-pro'));
    }
  }
```

- [ ] **Step 8: Succès brouillon — variante de `DonySuccessScreen`**

Dans `_onStateChange`, le succès (lignes 181-215) navigue toujours vers l'écran « Demande publiée ! ». Distinguer le brouillon :

```dart
    if (state.submissionStatus == FormSubmissionStatus.success &&
        state.createdRequest != null) {
      final isEditing = state.isEditing;
      final isDraft = state.createdRequest!.status == PackageRequestStatus.draft;
      final requestId = state.createdRequest!.id;
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (routeContext) => DonySuccessScreen(
          mascotteType: DonyMascotteType.succes,
          title: isDraft
              ? 'Brouillon enregistré !'
              : isEditing
                  ? 'Demande modifiée !'
                  : 'Demande publiée !',
          subtitle: isDraft
              ? 'Tu pourras la publier quand tu le souhaites.'
              : isEditing
                  ? 'Tes modifications sont en ligne.'
                  : 'Les voyageurs sont notifiés. Tu recevras des offres '
                      'très vite.',
          ctaLabel: isDraft ? 'Voir mon brouillon' : 'Voir ma demande',
          onCta: () {
            final router = GoRouter.of(routeContext);
            Navigator.of(routeContext).pop();
            context.pop();
            router.push('/package-requests/$requestId');
          },
          analyticsContext: isDraft
              ? 'package_request_draft_saved'
              : 'package_request_published',
        ),
      ));
    }
```

Ajouter l'import si absent :

```dart
import 'package:dony/features/package_request/data/models/package_request.dart';
```

(déjà probablement présent — vérifier avant d'ajouter un doublon).

- [ ] **Step 9: Mettre à jour les tests d'étape 3**

Les tests widget de `step_3_recap_budget_test.dart` appellent `key.currentState!.submit()` sans argument (Task précédente de ce fichier, cf. tests déjà en place) — la signature reste compatible (`saveAsDraft` a une valeur par défaut). Lancer la suite pour confirmer :

Run: `flutter test test/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget_test.dart`
Expected: PASS sans modification (paramètre optionnel rétrocompatible).

- [ ] **Step 10: Lancer l'ensemble des tests du wizard**

Run: `flutter test test/features/package_request/`
Expected: PASS.

- [ ] **Step 11: Commit**

```bash
git add lib/features/package_request/presentation/ \
        test/features/package_request/presentation/widgets/package_request_preview_sheet_test.dart
git commit -m "feat(requests): sheet d'aperçu avec option brouillon à l'étape 3"
```

---

### Task 4 : grille d'actions propriétaire

**Files:**
- Create: `lib/features/package_request/presentation/widgets/request_owner_action_grid.dart`
- Test: `test/features/package_request/presentation/widgets/request_owner_action_grid_test.dart`

**Interfaces:**
- Consumes: `PackageRequestStatus.draft` (Task 1).
- Produces: `RequestOwnerActionGrid({required PackageRequest request, required bool hasOffers, required VoidCallback onEdit, required VoidCallback onPublish, required VoidCallback onUnpublish, required VoidCallback onCancel})`.

Ce widget est un composant de présentation pur (pas d'appel réseau, pas de BLoC) — les callbacks sont fournis par l'appelant (Task 5), qui porte la logique d'appel repository. C'est le même découpage que `owner_action_grid.dart`, dont les `onTap` dispatchent déjà vers l'extérieur.

- [ ] **Step 1: Écrire le widget**

Créer `lib/features/package_request/presentation/widgets/request_owner_action_grid.dart`, en reprenant la structure de `lib/features/matching/presentation/widgets/owner_action_grid.dart` (grille 2 colonnes, tuile `_tile()` désactivable avec tooltip) :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:flutter/material.dart';

/// Grille 2×2 d'actions propriétaire pour l'écran « Ma demande ».
///
/// Miroir de `OwnerActionGrid` (trajet) : chaque tuile porte une conséquence
/// nommée plutôt que d'être cachée derrière un menu `…`.
class RequestOwnerActionGrid extends StatelessWidget {
  const RequestOwnerActionGrid({
    super.key,
    required this.request,
    required this.hasOffers,
    required this.onEdit,
    required this.onPublish,
    required this.onUnpublish,
    required this.onCancel,
  });

  final PackageRequest request;

  /// Lu depuis les threads déjà chargés par l'écran appelant — pas un champ
  /// du modèle. Le backend reste l'autorité : il renvoie 409 `has-offers`
  /// si l'état a changé entre le chargement et le tap.
  final bool hasOffers;

  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback onCancel;

  bool get _canEdit =>
      request.status == PackageRequestStatus.draft ||
      request.status == PackageRequestStatus.open ||
      request.status == PackageRequestStatus.negotiating;

  bool get _canUnpublish =>
      request.status == PackageRequestStatus.open && !hasOffers;

  bool get _canCancel =>
      request.status == PackageRequestStatus.open ||
      request.status == PackageRequestStatus.negotiating;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final tiles = <Widget>[
      if (request.status == PackageRequestStatus.draft)
        _tile(
          iconAsset: 'send',
          label: 'Publier',
          accent: cs.primary,
          onTap: onPublish,
        ),
      _tile(
        iconAsset: 'square-pen',
        label: 'Modifier',
        accent: cs.onSurface,
        onTap: _canEdit ? onEdit : null,
        disabledMessage: 'Modification indisponible pour ce statut',
      ),
      if (request.status == PackageRequestStatus.open)
        _tile(
          iconAsset: 'eye-off',
          label: 'Dépublier',
          accent: cs.onSurface,
          onTap: _canUnpublish ? onUnpublish : null,
          disabledMessage:
              'Dépublier n\'est possible qu\'avant la première offre',
        ),
      if (_canCancel)
        _tile(
          iconAsset: 'circle-x',
          label: 'Annuler',
          accent: cs.error,
          onTap: onCancel,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: DonySpacing.sm),
          Row(
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: i + 1 < tiles.length
                    ? tiles[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

Widget _tile({
  required String iconAsset,
  required String label,
  required Color accent,
  VoidCallback? onTap,
  String? disabledMessage,
}) {
  if (onTap == null && disabledMessage != null) {
    return Tooltip(
      message: disabledMessage,
      child: Opacity(
        opacity: 0.4,
        child: _ActionTile(iconAsset: iconAsset, label: label, accent: accent),
      ),
    );
  }
  return _ActionTile(
    iconAsset: iconAsset,
    label: label,
    accent: accent,
    onTap: onTap,
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.iconAsset,
    required this.label,
    required this.accent,
    this.onTap,
  });

  final String iconAsset;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(child: DonyIcon(iconAsset, size: 20, color: accent)),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Vérifier que l'asset d'icône `'eye-off'` existe dans le set d'icônes du projet avant de commiter :

Run: `grep -rl "eye-off" lib/core/widgets/dony_icon.dart assets/ 2>/dev/null`

S'il n'existe pas, utiliser `'eye'` à la place (icône déjà utilisée ailleurs dans le projet, cf. `bid_qr_sheet_opened`/visionneuse) — vérifier avec la même commande adaptée avant d'écrire le widget définitif.

- [ ] **Step 2: Écrire le test widget**

Créer `test/features/package_request/presentation/widgets/request_owner_action_grid_test.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/presentation/widgets/request_owner_action_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/package_request_fixture.dart'; // adapter au chemin réel des fixtures du module

void main() {
  Widget wrap(PackageRequest request, {bool hasOffers = false}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: RequestOwnerActionGrid(
          request: request,
          hasOffers: hasOffers,
          onEdit: () {},
          onPublish: () {},
          onUnpublish: () {},
          onCancel: () {},
        ),
      ),
    );
  }

  testWidgets('brouillon : affiche Publier + Modifier, pas Dépublier ni Annuler',
      (tester) async {
    await tester.pumpWidget(wrap(fixtureRequest(status: PackageRequestStatus.draft)));
    expect(find.text('Publier'), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Dépublier'), findsNothing);
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets('ouverte sans offre : Dépublier actif', (tester) async {
    await tester.pumpWidget(
      wrap(fixtureRequest(status: PackageRequestStatus.open), hasOffers: false),
    );
    final tile = tester.widget<InkWell>(find.ancestor(
      of: find.text('Dépublier'),
      matching: find.byType(InkWell),
    ));
    expect(tile.onTap, isNotNull);
  });

  testWidgets('ouverte avec offre : Dépublier grisé', (tester) async {
    await tester.pumpWidget(
      wrap(fixtureRequest(status: PackageRequestStatus.open), hasOffers: true),
    );
    final tile = tester.widget<InkWell>(find.ancestor(
      of: find.text('Dépublier'),
      matching: find.byType(InkWell),
    ));
    expect(tile.onTap, isNull);
  });

  testWidgets('en négociation : Modifier actif, pas de Dépublier ni Publier',
      (tester) async {
    await tester.pumpWidget(wrap(fixtureRequest(status: PackageRequestStatus.negotiating)));
    expect(find.text('Publier'), findsNothing);
    expect(find.text('Dépublier'), findsNothing);
    final tile = tester.widget<InkWell>(find.ancestor(
      of: find.text('Modifier'),
      matching: find.byType(InkWell),
    ));
    expect(tile.onTap, isNotNull);
  });

  testWidgets('acceptée : ni Publier, ni Dépublier, ni Annuler', (tester) async {
    await tester.pumpWidget(wrap(fixtureRequest(status: PackageRequestStatus.accepted)));
    expect(find.text('Publier'), findsNothing);
    expect(find.text('Dépublier'), findsNothing);
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets('tap sur Publier appelle onPublish', (tester) async {
    var called = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: RequestOwnerActionGrid(
          request: fixtureRequest(status: PackageRequestStatus.draft),
          hasOffers: false,
          onEdit: () {},
          onPublish: () => called = true,
          onUnpublish: () {},
          onCancel: () {},
        ),
      ),
    ));
    await tester.tap(find.text('Publier'));
    expect(called, isTrue);
  });
}
```

Vérifier s'il existe déjà une fixture `PackageRequest` factory dans `test/` (chercher avant d'en créer une nouvelle) :

Run: `grep -rl "PackageRequest(" test/features/package_request/ | grep -i fixture`

Si aucune fixture partagée n'existe, construire l'objet `PackageRequest` directement dans le test avec un constructeur complet (reprendre les champs `required` de `lib/features/package_request/data/models/package_request.dart`) plutôt que d'introduire une fixture pour ce seul fichier — YAGNI.

- [ ] **Step 3: Lancer le test**

Run: `flutter test test/features/package_request/presentation/widgets/request_owner_action_grid_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/package_request/presentation/widgets/request_owner_action_grid.dart \
        test/features/package_request/presentation/widgets/request_owner_action_grid_test.dart
git commit -m "feat(requests): grille d'actions propriétaire pour Ma demande"
```

---

### Task 5 : intégration dans « Ma demande » (écran + sheet)

**Files:**
- Create: `lib/features/package_request/presentation/widgets/package_request_detail_body.dart`
- Modify: `lib/features/package_request/presentation/screens/sender/package_request_detail_screen.dart`
- Modify: `test/features/package_request/presentation/screens/sender/package_request_detail_screen_test.dart`

**Interfaces:**
- Consumes: `RequestOwnerActionGrid` (Task 4), `PackageRequestRepository.publish/unpublish` (Task 1).
- Produces: `PackageRequestDetailBody({required PackageRequest request, required List<NegotiationThread> threads, required bool actionInFlight, required VoidCallback onEdit, required VoidCallback onPublish, required VoidCallback onUnpublish, required VoidCallback onCancel})`, consommé par `PackageRequestDetailScreen` et `PackageRequestDetailBottomSheet`.

C'est la tâche qui referme la boucle : elle supprime le `…` mort et le bouton rouge sticky dupliqué.

- [ ] **Step 1: Lire le test existant en entier**

Run: `cat test/features/package_request/presentation/screens/sender/package_request_detail_screen_test.dart`

Repérer chaque assertion qui cible l'ancien bouton (`find.text('Annuler la demande')`, ligne ~131 et ~148 déjà connues de l'exploration) — elles seront réécrites pour cibler la tuile de la grille, pas contournées.

- [ ] **Step 2: Extraire le corps commun**

Créer `lib/features/package_request/presentation/widgets/package_request_detail_body.dart` en déplaçant `_HeroCard`, `_OffersSection`, `_OfferTile`, `CandidatesSection`, `_CandidateCard` et `_buildDetails` depuis `package_request_detail_screen.dart` (ce sont des widgets déjà autonomes, sans état propre au chargement de l'écran) :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/widgets/request_owner_action_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Corps commun à `PackageRequestDetailScreen` (plein écran) et
/// `PackageRequestDetailBottomSheet` (chemin principal, ouvert depuis la
/// liste). Les deux enveloppes ne diffèrent que par leur chrome (AppBar vs
/// handle de sheet) — le contenu métier vit ici pour ne pas être écrit deux fois.
class PackageRequestDetailBody extends StatelessWidget {
  const PackageRequestDetailBody({
    super.key,
    required this.request,
    required this.threads,
    required this.actionInFlight,
    required this.onEdit,
    required this.onPublish,
    required this.onUnpublish,
    required this.onCancel,
  });

  final PackageRequest request;
  final List<NegotiationThread> threads;
  final bool actionInFlight;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroCard(request: request, threadsCount: threads.length),
            const SizedBox(height: DonySpacing.base),
            IgnorePointer(
              ignoring: actionInFlight,
              child: Opacity(
                opacity: actionInFlight ? 0.5 : 1,
                child: RequestOwnerActionGrid(
                  request: request,
                  hasOffers: threads.isNotEmpty,
                  onEdit: onEdit,
                  onPublish: onPublish,
                  onUnpublish: onUnpublish,
                  onCancel: onCancel,
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.xl),
            _OffersSection(threads: threads, request: request),
          ],
        )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

// Le contenu de _HeroCard, _OffersSection, _OfferTile, CandidatesSection,
// _CandidateCard et _buildDetails() est déplacé ici tel quel depuis
// package_request_detail_screen.dart — copier-coller sans modification,
// seuls les imports changent (ajouter go_router pour context.push dans
// _OfferTile et CandidatesSection).
```

Déplacer intégralement (copier-coller, aucune modification de logique) les classes `_HeroCard`, `_OffersSection`, `_OfferTile`, `CandidatesSection`, `_CandidateCard` et la fonction `_buildDetails` depuis `package_request_detail_screen.dart` (lignes 200-880 de la version lue en exploration) vers ce nouveau fichier, en conservant leur code exact.

- [ ] **Step 3: Réécrire `PackageRequestDetailScreen` sur le corps commun**

Remplacer entièrement `lib/features/package_request/presentation/screens/sender/package_request_detail_screen.dart` — l'écran plein écran garde son chargement, son AppBar, et délègue le corps :

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_detail_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PackageRequestDetailScreen extends StatefulWidget {
  const PackageRequestDetailScreen({required this.requestId, super.key});
  final String requestId;

  @override
  State<PackageRequestDetailScreen> createState() =>
      _PackageRequestDetailScreenState();
}

class _PackageRequestDetailScreenState
    extends State<PackageRequestDetailScreen> {
  PackageRequest? _request;
  List<NegotiationThread> _threads = const [];
  String? _error;
  bool _loading = true;
  bool _actionInFlight = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = getIt<PackageRequestRepository>();
      final r = await repo.getById(widget.requestId);
      List<NegotiationThread> threads = const [];
      try {
        threads = await repo.listThreadsForRequest(widget.requestId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _request = r;
          _threads = threads;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Erreur');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _actionInFlight = true);
    try {
      await action();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        DonySnackbar.show(
          context,
          message: 'Une erreur est survenue. Veuillez réessayer.',
          type: DonySnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _edit() async {
    final changed = await PackageRequestCreateWizard.showEditing(context, _request!);
    if ((changed ?? false) && mounted) await _load();
  }

  Future<void> _publish() =>
      _runAction(() => getIt<PackageRequestRepository>().publish(widget.requestId));

  Future<void> _unpublish() =>
      _runAction(() => getIt<PackageRequestRepository>().unpublish(widget.requestId));

  Future<void> _cancel() async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Annuler cette demande ?',
      message: 'Cette action est irréversible. Les voyageurs ne pourront '
          'plus y répondre.',
      confirmLabel: 'Annuler la demande',
      variant: DonyDialogVariant.destructive,
      iconAsset: 'circle-x',
    );
    if (confirmed != true || !mounted) return;
    await _runAction(() => getIt<PackageRequestRepository>().cancel(widget.requestId));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DonyAppBar(title: 'Ma demande'),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : _request == null
          ? const SizedBox.shrink()
          : BlocProvider<NegotiationBloc>(
              create: (_) => getIt<NegotiationBloc>(),
              child: BlocListener<NegotiationBloc, NegotiationState>(
                listenWhen: (prev, curr) =>
                    curr is NegotiationLoaded && prev is! NegotiationLoaded,
                listener: (_, __) => _load(),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.xl,
                    DonySpacing.lg,
                    MediaQuery.of(context).padding.bottom + DonySpacing.xl,
                  ),
                  child: PackageRequestDetailBody(
                    request: _request!,
                    threads: _threads,
                    actionInFlight: _actionInFlight,
                    onEdit: _edit,
                    onPublish: _publish,
                    onUnpublish: _unpublish,
                    onCancel: _cancel,
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Bottom sheet detail ───────────────────────────────────────────────────────

abstract final class PackageRequestDetailBottomSheet {
  static Future<void> show(BuildContext context, String requestId) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetFrame(requestId: requestId),
    );
  }
}

class _SheetFrame extends StatefulWidget {
  const _SheetFrame({required this.requestId});
  final String requestId;

  @override
  State<_SheetFrame> createState() => _SheetFrameState();
}

class _SheetFrameState extends State<_SheetFrame> {
  PackageRequest? _request;
  List<NegotiationThread> _threads = const [];
  String? _error;
  bool _loading = true;
  bool _actionInFlight = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repo = getIt<PackageRequestRepository>();
      final r = await repo.getById(widget.requestId);
      List<NegotiationThread> threads = const [];
      try {
        threads = await repo.listThreadsForRequest(widget.requestId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _request = r;
          _threads = threads;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Erreur');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _actionInFlight = true);
    try {
      await action();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        DonySnackbar.show(
          context,
          message: 'Une erreur est survenue. Veuillez réessayer.',
          type: DonySnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _edit() async {
    final changed = await PackageRequestCreateWizard.showEditing(context, _request!);
    if ((changed ?? false) && mounted) await _load();
  }

  Future<void> _cancel() async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Annuler cette demande ?',
      message: 'Cette action est irréversible. Les voyageurs ne pourront '
          'plus y répondre.',
      confirmLabel: 'Annuler la demande',
      variant: DonyDialogVariant.destructive,
      iconAsset: 'circle-x',
    );
    if (confirmed != true || !mounted) return;
    await _runAction(() => getIt<PackageRequestRepository>().cancel(widget.requestId));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom + mq.viewPadding.bottom;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      height: mq.size.height * 0.92,
      decoration: BoxDecoration(
        color: cs.surfaceWarm,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DonyColors.neutral300,
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DonySpacing.lg, DonySpacing.sm, DonySpacing.base, 0),
            child: Row(
              children: [
                Expanded(child: Text('Ma demande', style: tt.headlineSmall)),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const DonyIcon('x', size: 20),
                  style: IconButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Divider(height: DonySpacing.base, color: cs.outline),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: cs.primary))
                : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : _request == null
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        DonySpacing.lg, 0, DonySpacing.lg, DonySpacing.xl + bottomInset),
                    child: PackageRequestDetailBody(
                      request: _request!,
                      threads: _threads,
                      actionInFlight: _actionInFlight,
                      onEdit: _edit,
                      onPublish: () => _runAction(
                          () => getIt<PackageRequestRepository>().publish(widget.requestId)),
                      onUnpublish: () => _runAction(
                          () => getIt<PackageRequestRepository>().unpublish(widget.requestId)),
                      onCancel: _cancel,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DonyIcon('circle-alert', size: 48, color: DonyColors.danger500),
            const SizedBox(height: DonySpacing.base),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DonySpacing.base),
            DonyButton(label: 'Réessayer', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
```

Effets de bord assumés et documentés par la spec :
- Le `…` de l'AppBar (`IconButton` avec `onPressed: () {}`) disparaît — c'était l'action morte que ce plan résorbe.
- `_SheetBtnConfig`, `_SheetFrame`'s ancien `ValueNotifier<_SheetBtnConfig?>`, `_SheetBody` : disparaissent, remplacés par un `_SheetFrame` `StatefulWidget` unique qui porte directement l'état (mécanique qui n'existait que pour porter le bouton « Annuler » en sticky ; ce bouton est maintenant une tuile de la grille, dans le corps scrollable).
- `PackageRequestCreateWizard.showEditing(context, request)` est une méthode qui n'existe pas encore sur `abstract final class PackageRequestCreateWizard` — l'ajouter dans la Step suivante.

- [ ] **Step 4: Ajouter `PackageRequestCreateWizard.showEditing`**

`PackageRequestCreateWizard.show` (dans `package_request_create_screen.dart`) accepte déjà un paramètre `initial` et gère l'avertissement d'édition (`requiresEditWarning`). Ajouter un alias explicite qui retourne `bool?` (signal de changement, cf. règle projet sur le rafraîchissement après navigation) :

```dart
  /// Édition depuis « Ma demande » — retourne `true` si la demande a été
  /// modifiée, pour que l'appelant sache s'il doit recharger.
  static Future<bool?> showEditing(BuildContext context, PackageRequest request) async {
    if (requiresEditWarning(request)) {
      final confirmed = await DonyDialog.show(
        context,
        title: 'Modifier votre demande ?',
        message:
            'Des voyageurs négocient actuellement cette demande. La '
            'modifier annulera toutes les offres en cours. Ils devront vous '
            'reproposer un trajet.',
        confirmLabel: 'Modifier quand même',
        cancelLabel: 'Annuler',
        variant: DonyDialogVariant.destructive,
        icon: Icons.warning_amber_rounded,
      );
      if (confirmed != true || !context.mounted) return null;
    }
    return context.push<bool>('/package-requests/new', extra: request);
  }
```

Vérifier la route `/package-requests/new` dans `lib/app/router.dart` : si elle ne fait pas déjà `context.pop(true)` après une édition réussie, le rafraîchissement ne se déclenchera pas. Chercher :

Run: `grep -n "package-requests/new" -A 5 lib/app/router.dart`

Si le retour de la route n'est pas `bool`, adapter `PackageRequestCreateScreen._onStateChange` (déjà lu en exploration, ligne 200-205) pour que le succès en mode édition fasse `context.pop(true)` avant `router.push(...)`, comme le fait le pattern trajet (`trip_owner_detail_screen.dart` avec `context.push<bool>`).

- [ ] **Step 5: Réécrire les tests de l'écran**

Modifier `test/features/package_request/presentation/screens/sender/package_request_detail_screen_test.dart` : remplacer chaque `find.text('Annuler la demande')` (utilisé comme preuve que le bouton existe) par une recherche de la tuile de la grille :

```dart
  testWidgets('shows Annuler tile when status is open', (tester) async {
    // ... setup identique à l'existant (mock repo.getById renvoyant un statut open) ...
    await tester.pumpWidget(/* ... */);
    await tester.pumpAndSettle();
    expect(find.text('Annuler'), findsOneWidget);
  });

  testWidgets('no Annuler tile for an accepted request', (tester) async {
    // ... setup avec statut accepted ...
    expect(find.text('Annuler'), findsNothing);
  });
```

Ajouter deux tests nouveaux :

```dart
  testWidgets('draft request shows Publier tile', (tester) async {
    // mock repo.getById renvoyant un statut draft
    await tester.pumpWidget(/* ... */);
    await tester.pumpAndSettle();
    expect(find.text('Publier'), findsOneWidget);
  });

  testWidgets('AppBar has no more overflow menu', (tester) async {
    await tester.pumpWidget(/* ... */);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_horiz), findsNothing);
  });
```

Reprendre exactement le style de mock déjà présent dans ce fichier (`getIt`/`GetIt.instance.registerSingleton` ou équivalent — lire les 30 premières lignes du fichier de test pour le pattern d'injection avant d'écrire).

- [ ] **Step 6: Lancer les tests**

Run: `flutter test test/features/package_request/presentation/screens/sender/package_request_detail_screen_test.dart`
Expected: PASS.

- [ ] **Step 7: `flutter analyze`**

Run: `flutter analyze`
Expected: aucune nouvelle erreur (les imports désormais inutilisés dans `package_request_detail_screen.dart` — `DonyEmoji`, `intl`, etc. déplacés vers `package_request_detail_body.dart` — doivent être retirés).

- [ ] **Step 8: Commit**

```bash
git add lib/features/package_request/presentation/ \
        test/features/package_request/presentation/screens/sender/package_request_detail_screen_test.dart
git commit -m "refactor(requests): Ma demande utilise la grille d'actions propriétaire"
```

---

### Task 6 : brouillons dans les listes

**Files:**
- Modify: `lib/features/package_request/bloc/request_filter_cubit.dart`
- Modify: `lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart`
- Test: `test/features/package_request/bloc/request_filter_cubit_test.dart`
- Test: `test/features/package_request/presentation/screens/sender/my_package_requests_screen_test.dart`

**Interfaces:**
- Consumes: `PackageRequestStatus.draft` (Task 1).
- Produces: `RequestQuickFilter.draft` ; `isSearchRequest` inclut `DRAFT`.

- [ ] **Step 1: Écrire les tests cubit qui échouent**

Ajouter dans `test/features/package_request/bloc/request_filter_cubit_test.dart` :

```dart
  test('isSearchRequest includes draft requests', () {
    final draft = fixtureRequest(status: PackageRequestStatus.draft); // adapter au helper du fichier
    expect(isSearchRequest(draft), isTrue);
  });

  test('requestMatchesPreset(draft) matches only RequestQuickFilter.draft', () {
    final draft = fixtureRequest(status: PackageRequestStatus.draft);
    expect(requestMatchesPreset(draft, RequestQuickFilter.draft), isTrue);
    expect(requestMatchesPreset(draft, RequestQuickFilter.open), isFalse);
    expect(requestMatchesPreset(draft, RequestQuickFilter.closed), isFalse);
    expect(requestMatchesPreset(draft, RequestQuickFilter.all), isTrue);
  });
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/features/package_request/bloc/request_filter_cubit_test.dart`
Expected: FAIL — `RequestQuickFilter.draft` n'existe pas.

- [ ] **Step 3: Étendre le filtre**

Modifier `lib/features/package_request/bloc/request_filter_cubit.dart` :

```dart
enum RequestQuickFilter { all, open, closed, draft }
```

```dart
/// Une demande « en recherche » = pas encore transformée en envoi payé.
/// Les demandes ACCEPTED/COMPLETED vivent dans l'onglet Envois — on ne les
/// affiche donc plus dans l'onglet Demandes. DRAFT y reste : un brouillon
/// doit être atteignable quelque part, et c'est la seule liste qui liste
/// les demandes de l'expéditeur par statut.
bool isSearchRequest(PackageRequest r) =>
    r.status != PackageRequestStatus.accepted &&
    r.status != PackageRequestStatus.completed;

bool requestMatchesPreset(PackageRequest r, RequestQuickFilter preset) =>
    switch (preset) {
      RequestQuickFilter.all => true,
      RequestQuickFilter.open =>
        r.status == PackageRequestStatus.open ||
            r.status == PackageRequestStatus.negotiating,
      RequestQuickFilter.closed =>
        r.status == PackageRequestStatus.expired ||
            r.status == PackageRequestStatus.cancelled,
      RequestQuickFilter.draft => r.status == PackageRequestStatus.draft,
    };
```

Note : `isSearchRequest` incluait déjà implicitement `DRAFT` (il n'exclut que `accepted`/`completed`) — seul le commentaire est mis à jour pour rendre l'intention explicite, aucune logique ne change ici.

- [ ] **Step 4: Lancer les tests cubit**

Run: `flutter test test/features/package_request/bloc/request_filter_cubit_test.dart`
Expected: PASS.

- [ ] **Step 5: Corriger le `switch` exhaustif de `_StatusBadge`**

`_StatusBadge._config` dans `my_package_requests_screen.dart` (lignes 570-601) est un `switch` exhaustif sans branche par défaut — `flutter analyze` doit déjà avoir signalé cette erreur en Task 1 Step 2. Ajouter la branche :

```dart
  ({Color bg, Color fg, String label}) get _config => switch (status) {
    PackageRequestStatus.draft => (
      bg: DonyColors.neutral100,
      fg: DonyColors.neutral500,
      label: 'BROUILLON',
    ),
    PackageRequestStatus.open => (
      bg: DonyColors.success50,
      fg: DonyColors.success500,
      label: 'OUVERTE',
    ),
    PackageRequestStatus.negotiating => (
      bg: DonyColors.warning50,
      fg: DonyColors.warning500,
      label: 'NÉGOCIATION',
    ),
    PackageRequestStatus.accepted => (
      bg: DonyColors.success50,
      fg: DonyColors.success500,
      label: 'ACCEPTÉE',
    ),
    PackageRequestStatus.completed => (
      bg: DonyColors.success50,
      fg: DonyColors.success500,
      label: 'LIVRÉE',
    ),
    PackageRequestStatus.expired => (
      bg: DonyColors.neutral100,
      fg: DonyColors.neutral500,
      label: 'EXPIRÉE',
    ),
    PackageRequestStatus.cancelled => (
      bg: DonyColors.danger50,
      fg: DonyColors.danger500,
      label: 'ANNULÉE',
    ),
  };
```

Compléter aussi `_accentColor` (ligne 425-430, `switch` avec `_ =>` par défaut — pas d'erreur de compilation, mais un brouillon tomberait dans le gris générique du défaut sans distinction) :

```dart
  Color _accentColor(ColorScheme cs) => switch (request.status) {
    PackageRequestStatus.draft => DonyColors.neutral500,
    PackageRequestStatus.open => cs.primary,
    PackageRequestStatus.negotiating => DonyColors.warning500,
    PackageRequestStatus.accepted => DonyColors.success500,
    _ => DonyColors.neutral300,
  };
```

- [ ] **Step 6: Ajouter le chip « Brouillons » et le tri**

Modifier `_FilterRow` (lignes 257-317) — ajouter le compteur et le chip :

```dart
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.current,
    required this.total,
    required this.openCount,
    required this.closedCount,
    required this.draftCount,
    required this.onChanged,
    this.negotiatingCount = 0,
  });

  final RequestQuickFilter current;
  final int total, openCount, closedCount, draftCount;
  final ValueChanged<RequestQuickFilter> onChanged;
  final int negotiatingCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.sm,
        DonySpacing.base,
        DonySpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'Toutes ($total)',
              active: current == RequestQuickFilter.all,
              onTap: () => onChanged(RequestQuickFilter.all),
            ),
            const SizedBox(width: DonySpacing.xs + 2),
            _FilterChip(
              label: 'Ouvertes ($openCount)',
              active: current == RequestQuickFilter.open,
              hasNew: negotiatingCount > 0 && current != RequestQuickFilter.open,
              onTap: () => onChanged(RequestQuickFilter.open),
            ),
            const SizedBox(width: DonySpacing.xs + 2),
            _FilterChip(
              label: 'Terminées ($closedCount)',
              active: current == RequestQuickFilter.closed,
              onTap: () => onChanged(RequestQuickFilter.closed),
            ),
            if (draftCount > 0) ...[
              const SizedBox(width: DonySpacing.xs + 2),
              _FilterChip(
                label: 'Brouillons ($draftCount)',
                active: current == RequestQuickFilter.draft,
                onTap: () => onChanged(RequestQuickFilter.draft),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

Le passage de `Row` avec `Expanded` à `SingleChildScrollView` horizontal est nécessaire : un 4e chip conditionnel ne peut pas se répartir en `Expanded` sans écraser les trois autres quand il est absent. Vérifier que ce changement ne casse pas la mise en page en lançant les tests de la Step suivante avant de continuer.

Dans le `build` principal (lignes 136-177), ajouter le calcul de `draftCount` et le tri :

```dart
            final draftCount = visible
                .where((r) => r.status == PackageRequestStatus.draft)
                .length;
            final filtered = applyRequestFilters(state.requests, filter)
              ..sort((a, b) => _statusPriority(a.status).compareTo(_statusPriority(b.status)));
```

Ajouter la fonction de tri en haut du fichier, à côté des autres fonctions top-level (même idée que `_statusPriority` de `announcement_list_screen.dart`, adaptée à l'enum) :

```dart
int _statusPriority(PackageRequestStatus status) => switch (status) {
      PackageRequestStatus.draft => 0,
      PackageRequestStatus.negotiating => 1,
      PackageRequestStatus.open => 2,
      PackageRequestStatus.accepted => 3,
      PackageRequestStatus.completed => 4,
      PackageRequestStatus.expired => 5,
      PackageRequestStatus.cancelled => 6,
    };
```

Passer `draftCount: draftCount` à l'appel de `_FilterRow` (ligne ~175-183).

- [ ] **Step 7: État vide dédié**

Dans `_FilterEmptyState` (lignes 379-417), ajouter la branche :

```dart
      label = switch (preset) {
        RequestQuickFilter.open => 'Aucune demande ouverte',
        RequestQuickFilter.closed => 'Aucune demande terminée',
        RequestQuickFilter.draft => 'Aucun brouillon',
        RequestQuickFilter.all => 'Aucune demande',
      };
```

- [ ] **Step 8: Écrire/étendre les tests d'écran**

Ajouter dans `test/features/package_request/presentation/screens/sender/my_package_requests_screen_test.dart` (reprendre le style de mock déjà présent — `PackageRequestBloc` mocké avec une liste de `PackageRequest`) :

```dart
  testWidgets('draft chip appears when there is at least one draft, and filters to it',
      (tester) async {
    // Seed state.requests avec un mélange OPEN + DRAFT.
    // Vérifier find.textContaining('Brouillons (1)') existe.
    // Tap dessus → seule la carte DRAFT reste visible (badge "BROUILLON").
  });

  testWidgets('no draft chip when there are zero drafts', (tester) async {
    // Seed state.requests avec uniquement des OPEN.
    // expect(find.textContaining('Brouillons'), findsNothing);
  });

  testWidgets('drafts sort before open requests', (tester) async {
    // Seed [OPEN, DRAFT] dans cet ordre côté state ; vérifier que la
    // première carte rendue (via find.byType(_RequestCard) ou équivalent
    // exposé) correspond au brouillon.
  });
```

Remplir chaque corps en reprenant exactement le pattern de setup déjà utilisé par les tests voisins de ce fichier (mock du `PackageRequestBloc`, `pumpWidget`, `pumpAndSettle`).

- [ ] **Step 9: Lancer les tests**

Run: `flutter test test/features/package_request/`
Expected: PASS.

- [ ] **Step 10: `flutter analyze`**

Run: `flutter analyze`
Expected: 0 erreur.

- [ ] **Step 11: Commit**

```bash
git add lib/features/package_request/bloc/request_filter_cubit.dart \
        lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart \
        test/features/package_request/bloc/request_filter_cubit_test.dart \
        test/features/package_request/presentation/screens/sender/my_package_requests_screen_test.dart
git commit -m "feat(requests): filtre, tri et badge Brouillons dans Mes demandes"
```

---

### Task 7 : dépublication du trajet

**Files:**
- Modify: `lib/features/matching/bloc/announcement_event.dart`
- Modify: `lib/features/matching/bloc/announcement_state.dart`
- Modify: `lib/features/matching/bloc/announcement_bloc.dart`
- Modify: `lib/features/matching/presentation/widgets/owner_action_grid.dart`
- Modify: `lib/features/matching/presentation/screens/trip_owner_detail_screen.dart`
- Test: `test/features/matching/bloc/announcement_bloc_test.dart`
- Test: `test/features/matching/presentation/widgets/owner_action_grid_test.dart`

**Interfaces:**
- Consumes: `AnnouncementRepository.unpublishAnnouncement` (Task 1).
- Produces: `AnnouncementUnpublishRequested(String id)`, `AnnouncementUnpublished(AnnouncementModel announcement)`.

- [ ] **Step 1: Écrire les tests bloc qui échouent**

Ajouter dans `test/features/matching/bloc/announcement_bloc_test.dart`, en reprenant le style des tests existants de `AnnouncementPublishRequested` dans ce même fichier :

```dart
  blocTest<AnnouncementBloc, AnnouncementState>(
    'AnnouncementUnpublishRequested success emits [Loading, Unpublished]',
    build: () {
      when(() => repo.unpublishAnnouncement('trip-1'))
          .thenAnswer((_) async => fixtureAnnouncement(status: 'DRAFT'));
      return makeBloc(repo);
    },
    act: (b) => b.add(const AnnouncementUnpublishRequested('trip-1')),
    expect: () => [
      isA<AnnouncementLoading>(),
      isA<AnnouncementUnpublished>()
          .having((s) => s.announcement.status, 'status', 'DRAFT'),
    ],
  );

  blocTest<AnnouncementBloc, AnnouncementState>(
    'AnnouncementUnpublishRequested has-bids emits AnnouncementError',
    build: () {
      when(() => repo.unpublishAnnouncement('trip-1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/announcements/trip-1/unpublish'),
          error: const ConflictException('Ce trajet a déjà reçu des demandes.',
              code: 'announcement/has-bids'),
        ),
      );
      return makeBloc(repo);
    },
    act: (b) => b.add(const AnnouncementUnpublishRequested('trip-1')),
    expect: () => [
      isA<AnnouncementLoading>(),
      isA<AnnouncementError>(),
    ],
  );
```

Adapter `fixtureAnnouncement(...)` au helper déjà présent dans ce fichier de test (chercher son nom exact avant d'écrire).

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/features/matching/bloc/announcement_bloc_test.dart`
Expected: FAIL — `AnnouncementUnpublishRequested` n'existe pas.

- [ ] **Step 3: Ajouter l'event et le state**

Modifier `lib/features/matching/bloc/announcement_event.dart`, à côté de `AnnouncementPublishRequested` (ligne 56) :

```dart
class AnnouncementUnpublishRequested extends AnnouncementEvent {
  final String id;
  const AnnouncementUnpublishRequested(this.id);
}
```

Modifier `lib/features/matching/bloc/announcement_state.dart`, à côté de `AnnouncementPublished` (ligne 75) :

```dart
class AnnouncementUnpublished extends AnnouncementState {
  final AnnouncementModel announcement;
  AnnouncementUnpublished(this.announcement);
}
```

- [ ] **Step 4: Implémenter le handler**

Modifier `lib/features/matching/bloc/announcement_bloc.dart` — enregistrer le handler à côté des autres (ligne 21-27) :

```dart
    on<AnnouncementUnpublishRequested>(_onUnpublishRequested);
```

Ajouter la méthode, à côté de `_onPublishRequested` :

```dart
  Future<void> _onUnpublishRequested(
    AnnouncementUnpublishRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    if (state is AnnouncementLoading) return;
    emit(AnnouncementLoading());
    try {
      final announcement = await _repository.unpublishAnnouncement(event.id);
      emit(AnnouncementUnpublished(announcement));
    } catch (e) {
      emit(AnnouncementError(unwrapDioError(e)));
    }
  }
```

- [ ] **Step 5: Lancer les tests bloc**

Run: `flutter test test/features/matching/bloc/announcement_bloc_test.dart`
Expected: PASS.

- [ ] **Step 6: Écrire le test de tuile qui échoue**

Ajouter dans `test/features/matching/presentation/widgets/owner_action_grid_test.dart` (reprendre le style de mock déjà présent pour `BidBloc`/`AnnouncementBloc`) :

```dart
  testWidgets('ACTIVE sans bid : tuile Dépublier active', (tester) async {
    // pumpWidget avec announcement status ACTIVE, bidsCount 0
    final tile = tester.widget<InkWell>(find.ancestor(
      of: find.text('Dépublier'),
      matching: find.byType(InkWell),
    ));
    expect(tile.onTap, isNotNull);
  });

  testWidgets('ACTIVE avec bid : tuile Dépublier grisée', (tester) async {
    // pumpWidget avec announcement status ACTIVE, bidsCount 1
    final tile = tester.widget<InkWell>(find.ancestor(
      of: find.text('Dépublier'),
      matching: find.byType(InkWell),
    ));
    expect(tile.onTap, isNull);
  });

  testWidgets('DRAFT : pas de tuile Dépublier', (tester) async {
    // pumpWidget avec announcement status DRAFT
    expect(find.text('Dépublier'), findsNothing);
  });
```

- [ ] **Step 7: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/features/matching/presentation/widgets/owner_action_grid_test.dart`
Expected: FAIL — la tuile n'existe pas.

- [ ] **Step 8: Ajouter la tuile**

Modifier `lib/features/matching/presentation/widgets/owner_action_grid.dart`. Ajouter, après le calcul de `isActive` (ligne 71) :

```dart
    final canUnpublish = isActive && (a.bidsCount ?? 0) == 0;
```

Insérer la tuile dans la liste `tiles` (après « Colis », avant « Modifier », ligne ~112) :

```dart
      if (isActive)
        _tile(
          iconAsset: 'eye-off',
          label: 'Dépublier',
          accent: cs.onSurface,
          onTap: canUnpublish
              ? () => context.read<AnnouncementBloc>().add(
                    AnnouncementUnpublishRequested(a.id),
                  )
              : null,
          disabledMessage: 'Dépublier n\'est possible qu\'avant la première demande',
        ),
```

(Réutiliser le même asset `'eye-off'` validé en Task 4 — si remplacé par `'eye'` là-bas, utiliser la même valeur ici pour cohérence visuelle entre les deux grilles.)

- [ ] **Step 9: Lancer les tests de tuile**

Run: `flutter test test/features/matching/presentation/widgets/owner_action_grid_test.dart`
Expected: PASS.

- [ ] **Step 10: Écouter `AnnouncementUnpublished` dans l'écran détail**

Modifier `lib/features/matching/presentation/screens/trip_owner_detail_screen.dart`, dans le `listener` du `BlocConsumer` (après la branche `AnnouncementPublished`, ligne ~137) :

```dart
            } else if (state is AnnouncementUnpublished) {
              _current = state.announcement;
              DonySnackbar.show(
                context,
                message: 'Trajet dépublié, il est repassé en brouillon.',
                type: DonySnackbarType.success,
              );
              context.read<AnnouncementBloc>().add(
                AnnouncementDetailRequested(widget.announcementId),
              );
            }
```

- [ ] **Step 11: Lancer toute la suite matching**

Run: `flutter test test/features/matching/`
Expected: PASS.

- [ ] **Step 12: Commit**

```bash
git add lib/features/matching/ test/features/matching/
git commit -m "feat(matching): dépublication d'un trajet depuis Ma demande"
```

---

## Vérification finale

- [ ] `flutter analyze` — 0 erreur
- [ ] `flutter test --coverage` — 0 rouge, couverture ≥ 90 %
- [ ] Lancer l'app sur un device/émulateur (`flutter run --dart-define-from-file=env.dev.json`) et suivre le parcours golden path manuellement :
  1. Créer une demande, choisir « Enregistrer en brouillon » à l'aperçu → écran de succès brouillon → « Mes demandes » montre le chip « Brouillons (1) »
  2. Ouvrir le brouillon (liste → sheet) → tuile « Publier » → demande publiée, offres visibles
  3. Sur une demande `OPEN` sans offre → tuile « Dépublier » → repasse en brouillon
  4. Sur un trajet `ACTIVE` sans demande → tuile « Dépublier » dans `OwnerActionGrid` → repasse en brouillon
  5. Tuile « Annuler » → dialogue de confirmation apparaît (absent avant ce plan) → confirmer → demande annulée
- [ ] `git log --oneline` — 7 commits fonctionnels, aucun sur `main`
- [ ] Ouvrir la PR sur `dony_app` en référençant la spec (dépôt `dony-back`) et la PR backend
