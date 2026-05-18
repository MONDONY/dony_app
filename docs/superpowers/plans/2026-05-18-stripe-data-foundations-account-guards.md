# Stripe Data Foundations + Account Guards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter les modèles Stripe manquants (`PaymentStatus` enum, `ConnectAccountStatus` DISABLED/REJECTED, `PaymentModel.disputed`) et bloquer la création d'annonces quand le compte Connect est désactivé ou rejeté.

**Architecture:** Un nouveau `StripeAccountBloc` chargé globalement (via `app.dart`) surveille le statut du compte Connect ; il alimente un banner persistant dans `MainShell` et des redirects GoRouter sur `/announcements/create`. Les écrans `/account/disabled` et `/account/rejected` informent l'utilisateur avec des actions adaptées.

**Tech Stack:** Flutter 3.x, flutter_bloc, go_router, mocktail, bloc_test, url_launcher (déjà dans pubspec)

**Worktree:** `/home/a-diakite/Desktop/MyProject/my_app/dony_app/.worktrees/stripe-flutter-features`

**Spec:** `docs/superpowers/specs/2026-05-18-stripe-data-foundations-account-guards-design.md`

---

## Structure des fichiers

### Créer
- `lib/core/models/connect_account_status.dart` — modèle partagé (déplacé depuis connect_onboarding)
- `lib/features/payments/data/models/payment_status.dart` — enum PaymentStatus
- `lib/features/stripe_account/bloc/stripe_account_bloc.dart`
- `lib/features/stripe_account/bloc/stripe_account_event.dart`
- `lib/features/stripe_account/bloc/stripe_account_state.dart`
- `lib/features/stripe_account/data/stripe_account_datasource.dart`
- `lib/features/stripe_account/data/stripe_account_repository.dart`
- `lib/features/stripe_account/presentation/widgets/account_disabled_banner.dart`
- `lib/features/stripe_account/presentation/widgets/account_rejected_banner.dart`
- `lib/features/stripe_account/presentation/screens/account_disabled_screen.dart`
- `lib/features/stripe_account/presentation/screens/account_rejected_screen.dart`
- `test/features/stripe_account/bloc/stripe_account_bloc_test.dart`
- `test/core/models/connect_account_status_test.dart`
- `test/features/payments/data/payment_status_test.dart`
- `test/features/stripe_account/presentation/widgets/account_disabled_banner_test.dart`
- `test/features/stripe_account/presentation/screens/account_disabled_screen_test.dart`
- `test/features/stripe_account/presentation/screens/account_rejected_screen_test.dart`

### Modifier
- `lib/features/connect_onboarding/data/connect_onboarding_repository.dart` — supprimer `ConnectAccountStatus`, importer depuis `core/models/`
- `lib/features/connect_onboarding/data/connect_onboarding_datasource.dart` — mettre à jour import
- `lib/features/connect_onboarding/bloc/connect_onboarding_bloc.dart` — handler pour DISABLED/REJECTED
- `lib/features/connect_onboarding/bloc/connect_onboarding_state.dart` — ajouter 2 états
- `lib/features/payments/data/models/payment_model.dart` — `status: String` → `PaymentStatus` + ajouter `disputed`
- `lib/features/payments/data/models/payment_model.g.dart` — régénérer avec build_runner
- `lib/core/di/injection.dart` — enregistrer StripeAccountBloc + repo + datasource
- `lib/app/app.dart` — ajouter `BlocProvider<StripeAccountBloc>`
- `lib/app/router.dart` — ajouter routes `/account/disabled` et `/account/rejected` + redirect guard
- `lib/app/main_shell.dart` — banner + WidgetsBindingObserver pour refresh
- `test/features/connect_onboarding/bloc/connect_onboarding_bloc_test.dart` — mettre à jour import + ajouter tests DISABLED/REJECTED

---

## Task 1 : Déplacer `ConnectAccountStatus` vers `core/models/` et ajouter DISABLED/REJECTED

**Files:**
- Create: `lib/core/models/connect_account_status.dart`
- Modify: `lib/features/connect_onboarding/data/connect_onboarding_repository.dart`
- Modify: `lib/features/connect_onboarding/data/connect_onboarding_datasource.dart`
- Modify: `test/features/connect_onboarding/bloc/connect_onboarding_bloc_test.dart`
- Test: `test/core/models/connect_account_status_test.dart`

- [ ] **Step 1 : Écrire le test failing pour `isDisabled` et `isRejected`**

```dart
// test/core/models/connect_account_status_test.dart
import 'package:dony/core/models/connect_account_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectAccountStatus', () {
    test('isComplete returns true for ONBOARDING_COMPLETE', () {
      const s = ConnectAccountStatus(status: 'ONBOARDING_COMPLETE');
      expect(s.isComplete, isTrue);
    });

    test('needsOnboarding returns true for NOT_CREATED', () {
      const s = ConnectAccountStatus(status: 'NOT_CREATED');
      expect(s.needsOnboarding, isTrue);
    });

    test('needsOnboarding returns true for PENDING_ONBOARDING', () {
      const s = ConnectAccountStatus(status: 'PENDING_ONBOARDING');
      expect(s.needsOnboarding, isTrue);
    });

    test('isDisabled returns true for DISABLED', () {
      const s = ConnectAccountStatus(status: 'DISABLED');
      expect(s.isDisabled, isTrue);
    });

    test('isDisabled returns false for ONBOARDING_COMPLETE', () {
      const s = ConnectAccountStatus(status: 'ONBOARDING_COMPLETE');
      expect(s.isDisabled, isFalse);
    });

    test('isRejected returns true for REJECTED', () {
      const s = ConnectAccountStatus(status: 'REJECTED');
      expect(s.isRejected, isTrue);
    });

    test('isRejected returns false for ONBOARDING_COMPLETE', () {
      const s = ConnectAccountStatus(status: 'ONBOARDING_COMPLETE');
      expect(s.isRejected, isFalse);
    });

    test('fromJson parses status and reason', () {
      final json = {
        'accountId': 'acct_123',
        'status': 'REJECTED',
        'country': 'FR',
        'isProAccount': false,
        'reason': 'Documents invalides',
      };
      final s = ConnectAccountStatus.fromJson(json);
      expect(s.status, 'REJECTED');
      expect(s.reason, 'Documents invalides');
      expect(s.isRejected, isTrue);
    });

    test('fromJson defaults status to NOT_CREATED when absent', () {
      final s = ConnectAccountStatus.fromJson({});
      expect(s.status, 'NOT_CREATED');
    });
  });
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app/.worktrees/stripe-flutter-features
flutter test test/core/models/connect_account_status_test.dart --reporter=expanded
```

Expected: FAIL — `Target of URI doesn't exist: 'package:dony/core/models/connect_account_status.dart'`

- [ ] **Step 3 : Créer `lib/core/models/connect_account_status.dart`**

```dart
class ConnectAccountStatus {
  final String? accountId;
  final String status;
  final String? country;
  final bool isProAccount;
  final String? reason;

  const ConnectAccountStatus({
    this.accountId,
    required this.status,
    this.country,
    this.isProAccount = false,
    this.reason,
  });

  factory ConnectAccountStatus.fromJson(Map<String, dynamic> json) {
    return ConnectAccountStatus(
      accountId: json['accountId'] as String?,
      status: json['status'] as String? ?? 'NOT_CREATED',
      country: json['country'] as String?,
      isProAccount: json['isProAccount'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }

  bool get isComplete => status == 'ONBOARDING_COMPLETE';
  bool get needsOnboarding =>
      status == 'NOT_CREATED' || status == 'PENDING_ONBOARDING';
  bool get isDisabled => status == 'DISABLED';
  bool get isRejected => status == 'REJECTED';
}
```

- [ ] **Step 4 : Mettre à jour `connect_onboarding_repository.dart`**

Remplacer le contenu complet du fichier par :

```dart
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_datasource.dart';

export 'package:dony/core/models/connect_account_status.dart';

abstract class IConnectOnboardingRepository {
  Future<ConnectAccountStatus> getAccountStatus();
  Future<String> createOnboardingLink();
}

class ConnectOnboardingRepository implements IConnectOnboardingRepository {
  final ConnectOnboardingDatasource _datasource;

  ConnectOnboardingRepository(this._datasource);

  @override
  Future<ConnectAccountStatus> getAccountStatus() async {
    try {
      return await _datasource.getAccountStatus();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  @override
  Future<String> createOnboardingLink() async {
    try {
      return await _datasource.createOnboardingLink();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
```

Note : l'`export` permet aux fichiers qui importaient `connect_onboarding_repository.dart` pour obtenir `ConnectAccountStatus` de continuer à compiler sans changer leurs imports.

- [ ] **Step 5 : Mettre à jour `connect_onboarding_datasource.dart`**

Ajouter l'import explicite (optionnel, l'export du step 4 suffit mais rend la dépendance claire) :

```dart
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/network/api_client.dart';
// Supprimer l'import de connect_onboarding_repository.dart si présent

class ConnectOnboardingDatasource {
  final ApiClient _client;

  ConnectOnboardingDatasource(this._client);

  Future<ConnectAccountStatus> getAccountStatus() async {
    final response = await _client.dio.get('/payments/connect/account');
    final data = response.data as Map<String, dynamic>;
    return ConnectAccountStatus.fromJson(data);
  }

  Future<String> createOnboardingLink() async {
    final response = await _client.dio.post('/payments/connect/onboarding-link');
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String;
  }
}
```

- [ ] **Step 6 : Lancer les tests pour vérifier que tout passe**

```bash
flutter test test/core/models/connect_account_status_test.dart \
            test/features/connect_onboarding/ \
            --reporter=expanded
```

Expected: tous PASS, 0 rouge

- [ ] **Step 7 : Commit**

```bash
git add lib/core/models/connect_account_status.dart \
        lib/features/connect_onboarding/data/connect_onboarding_repository.dart \
        lib/features/connect_onboarding/data/connect_onboarding_datasource.dart \
        test/core/models/connect_account_status_test.dart
git commit -m "feat: move ConnectAccountStatus to core/models, add isDisabled/isRejected"
```

---

## Task 2 : Mettre à jour `ConnectOnboardingBloc` pour DISABLED/REJECTED

**Files:**
- Modify: `lib/features/connect_onboarding/bloc/connect_onboarding_state.dart`
- Modify: `lib/features/connect_onboarding/bloc/connect_onboarding_bloc.dart`
- Modify: `test/features/connect_onboarding/bloc/connect_onboarding_bloc_test.dart`

- [ ] **Step 1 : Écrire les tests failing pour les nouveaux états**

Ajouter dans `test/features/connect_onboarding/bloc/connect_onboarding_bloc_test.dart`, dans le group `ConnectOnboardingStatusRequested` (après le test `emits [Loading, NeedsOnboarding] when status is PENDING_ONBOARDING`) :

```dart
const _disabled = ConnectAccountStatus(status: 'DISABLED');
const _rejected = ConnectAccountStatus(status: 'REJECTED', reason: 'Docs invalides');
```

Et les tests :

```dart
blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
  'emits [Loading, Disabled] when status is DISABLED',
  build: buildBloc,
  setUp: () {
    when(() => mockRepo.getAccountStatus())
        .thenAnswer((_) async => _disabled);
  },
  act: (b) => b.add(const ConnectOnboardingStatusRequested()),
  expect: () => [
    isA<ConnectOnboardingLoading>(),
    isA<ConnectOnboardingDisabled>(),
  ],
);

blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
  'emits [Loading, Rejected] with reason when status is REJECTED',
  build: buildBloc,
  setUp: () {
    when(() => mockRepo.getAccountStatus())
        .thenAnswer((_) async => _rejected);
  },
  act: (b) => b.add(const ConnectOnboardingStatusRequested()),
  expect: () => [
    isA<ConnectOnboardingLoading>(),
    isA<ConnectOnboardingRejected>().having(
      (s) => s.reason,
      'reason',
      'Docs invalides',
    ),
  ],
);
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

```bash
flutter test test/features/connect_onboarding/bloc/connect_onboarding_bloc_test.dart --reporter=expanded
```

Expected: FAIL — `ConnectOnboardingDisabled` et `ConnectOnboardingRejected` non définis

- [ ] **Step 3 : Ajouter les états dans `connect_onboarding_state.dart`**

```dart
// Ajouter après ConnectOnboardingComplete :

class ConnectOnboardingDisabled extends ConnectOnboardingState {
  const ConnectOnboardingDisabled();
}

class ConnectOnboardingRejected extends ConnectOnboardingState {
  final String? reason;
  const ConnectOnboardingRejected({this.reason});
}
```

- [ ] **Step 4 : Mettre à jour `_onStatusRequested` dans `connect_onboarding_bloc.dart`**

Remplacer :

```dart
if (status.isComplete) {
  emit(const ConnectOnboardingComplete());
} else if (status.needsOnboarding) {
  emit(const ConnectOnboardingNeedsOnboarding());
} else {
  emit(const ConnectOnboardingPending());
}
```

Par :

```dart
if (status.isComplete) {
  emit(const ConnectOnboardingComplete());
} else if (status.isDisabled) {
  emit(const ConnectOnboardingDisabled());
} else if (status.isRejected) {
  emit(ConnectOnboardingRejected(reason: status.reason));
} else if (status.needsOnboarding) {
  emit(const ConnectOnboardingNeedsOnboarding());
} else {
  emit(const ConnectOnboardingPending());
}
```

- [ ] **Step 5 : Vérifier que les tests passent**

```bash
flutter test test/features/connect_onboarding/ --reporter=expanded
```

Expected: tous PASS

- [ ] **Step 6 : Commit**

```bash
git add lib/features/connect_onboarding/bloc/connect_onboarding_state.dart \
        lib/features/connect_onboarding/bloc/connect_onboarding_bloc.dart \
        test/features/connect_onboarding/bloc/connect_onboarding_bloc_test.dart
git commit -m "feat: add ConnectOnboardingDisabled/Rejected states and bloc handlers"
```

---

## Task 3 : `PaymentStatus` enum + `PaymentModel.disputed`

**Files:**
- Create: `lib/features/payments/data/models/payment_status.dart`
- Modify: `lib/features/payments/data/models/payment_model.dart`
- Modify: `lib/features/payments/data/models/payment_model.g.dart` (régénéré)
- Test: `test/features/payments/data/payment_status_test.dart`

- [ ] **Step 1 : Écrire le test failing**

```dart
// test/features/payments/data/payment_status_test.dart
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentStatus.fromString', () {
    test('parses PENDING', () {
      expect(PaymentStatus.fromString('PENDING'), PaymentStatus.pending);
    });

    test('parses AUTHORIZED', () {
      expect(PaymentStatus.fromString('AUTHORIZED'), PaymentStatus.authorized);
    });

    test('parses CAPTURED', () {
      expect(PaymentStatus.fromString('CAPTURED'), PaymentStatus.captured);
    });

    test('parses REFUNDED', () {
      expect(PaymentStatus.fromString('REFUNDED'), PaymentStatus.refunded);
    });

    test('parses FAILED', () {
      expect(PaymentStatus.fromString('FAILED'), PaymentStatus.failed);
    });

    test('parses DISPUTED', () {
      expect(PaymentStatus.fromString('DISPUTED'), PaymentStatus.disputed);
    });

    test('parses CANCELED', () {
      expect(PaymentStatus.fromString('CANCELED'), PaymentStatus.canceled);
    });

    test('falls back to pending for unknown value', () {
      expect(PaymentStatus.fromString('UNKNOWN_XYZ'), PaymentStatus.pending);
    });

    test('is case-insensitive', () {
      expect(PaymentStatus.fromString('captured'), PaymentStatus.captured);
    });
  });

  group('PaymentModel.disputed field', () {
    test('fromJson parses disputed: true', () {
      // Import PaymentModel too
    });
  });
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

```bash
flutter test test/features/payments/data/payment_status_test.dart --reporter=expanded
```

Expected: FAIL — `package:dony/features/payments/data/models/payment_status.dart` introuvable

- [ ] **Step 3 : Créer `lib/features/payments/data/models/payment_status.dart`**

```dart
import 'package:json_annotation/json_annotation.dart';

enum PaymentStatus {
  @JsonValue('PENDING') pending,
  @JsonValue('AUTHORIZED') authorized,
  @JsonValue('CAPTURED') captured,
  @JsonValue('REFUNDED') refunded,
  @JsonValue('FAILED') failed,
  @JsonValue('DISPUTED') disputed,
  @JsonValue('CANCELED') canceled;

  static PaymentStatus fromString(String raw) =>
      PaymentStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == raw.toUpperCase(),
        orElse: () => PaymentStatus.pending,
      );
}
```

- [ ] **Step 4 : Mettre à jour `payment_model.dart`**

Remplacer le contenu complet par :

```dart
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:json_annotation/json_annotation.dart';

part 'payment_model.g.dart';

@JsonSerializable()
class PaymentModel {
  final String id;
  final String bidId;
  final String? clientSecret;
  final double amount;
  final double commissionAmount;
  final PaymentStatus status;
  @JsonKey(defaultValue: false)
  final bool disputed;

  const PaymentModel({
    required this.id,
    required this.bidId,
    this.clientSecret,
    required this.amount,
    required this.commissionAmount,
    required this.status,
    this.disputed = false,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) =>
      _$PaymentModelFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentModelToJson(this);
}
```

- [ ] **Step 5 : Régénérer le fichier `.g.dart`**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app/.worktrees/stripe-flutter-features
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: `payment_model.g.dart` régénéré sans erreur

- [ ] **Step 6 : Compléter le test `payment_status_test.dart` et vérifier**

Ajouter l'import de `PaymentModel` dans le groupe `PaymentModel.disputed field` :

```dart
import 'package:dony/features/payments/data/models/payment_model.dart';
// Dans le test :
test('fromJson parses disputed: true', () {
  final json = {
    'id': 'pay_123',
    'bidId': 'bid_456',
    'amount': 50.0,
    'commissionAmount': 6.0,
    'status': 'CAPTURED',
    'disputed': true,
  };
  final model = PaymentModel.fromJson(json);
  expect(model.disputed, isTrue);
  expect(model.status, PaymentStatus.captured);
});

test('fromJson defaults disputed to false when absent', () {
  final json = {
    'id': 'pay_123',
    'bidId': 'bid_456',
    'amount': 50.0,
    'commissionAmount': 6.0,
    'status': 'PENDING',
  };
  final model = PaymentModel.fromJson(json);
  expect(model.disputed, isFalse);
});
```

```bash
flutter test test/features/payments/data/payment_status_test.dart --reporter=expanded
```

Expected: tous PASS

- [ ] **Step 7 : Vérifier que les tests payments existants passent toujours**

```bash
flutter test test/features/payments/ --reporter=expanded
```

Expected: tous PASS (le changement `status: String → PaymentStatus` peut casser des tests existants — les corriger avant de continuer)

Si des tests existants utilisent `status: 'CAPTURED'` (String), remplacer par `status: PaymentStatus.captured`.

- [ ] **Step 8 : Commit**

```bash
git add lib/features/payments/data/models/payment_status.dart \
        lib/features/payments/data/models/payment_model.dart \
        lib/features/payments/data/models/payment_model.g.dart \
        test/features/payments/data/payment_status_test.dart
git commit -m "feat: add PaymentStatus enum, migrate PaymentModel.status, add disputed field"
```

---

## Task 4 : `StripeAccountBloc` — couche data

**Files:**
- Create: `lib/features/stripe_account/data/stripe_account_datasource.dart`
- Create: `lib/features/stripe_account/data/stripe_account_repository.dart`

Pas de tests unitaires séparés pour la datasource (elle est une interface réseau pure testée par intégration). Le repository est testé indirectement via le BLoC.

- [ ] **Step 1 : Créer `lib/features/stripe_account/data/stripe_account_datasource.dart`**

```dart
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/network/api_client.dart';

class StripeAccountDatasource {
  final ApiClient _client;

  StripeAccountDatasource(this._client);

  Future<ConnectAccountStatus> getAccountStatus() async {
    final response = await _client.dio.get('/payments/connect/account');
    return ConnectAccountStatus.fromJson(response.data as Map<String, dynamic>);
  }
}
```

- [ ] **Step 2 : Créer `lib/features/stripe_account/data/stripe_account_repository.dart`**

```dart
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/stripe_account/data/stripe_account_datasource.dart';

abstract class IStripeAccountRepository {
  Future<ConnectAccountStatus> getAccountStatus();
}

class StripeAccountRepository implements IStripeAccountRepository {
  final StripeAccountDatasource _datasource;

  StripeAccountRepository(this._datasource);

  @override
  Future<ConnectAccountStatus> getAccountStatus() async {
    try {
      return await _datasource.getAccountStatus();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
```

- [ ] **Step 3 : Vérifier la compilation**

```bash
flutter analyze lib/features/stripe_account/data/
```

Expected: No issues found

- [ ] **Step 4 : Commit**

```bash
git add lib/features/stripe_account/data/
git commit -m "feat: add StripeAccountDatasource and StripeAccountRepository"
```

---

## Task 5 : `StripeAccountBloc` — couche BLoC

**Files:**
- Create: `lib/features/stripe_account/bloc/stripe_account_event.dart`
- Create: `lib/features/stripe_account/bloc/stripe_account_state.dart`
- Create: `lib/features/stripe_account/bloc/stripe_account_bloc.dart`
- Test: `test/features/stripe_account/bloc/stripe_account_bloc_test.dart`

- [ ] **Step 1 : Écrire le test failing**

```dart
// test/features/stripe_account/bloc/stripe_account_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/data/stripe_account_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStripeAccountRepository extends Mock
    implements IStripeAccountRepository {}

const _complete = ConnectAccountStatus(status: 'ONBOARDING_COMPLETE');
const _disabled = ConnectAccountStatus(status: 'DISABLED');
const _rejected = ConnectAccountStatus(status: 'REJECTED', reason: 'Docs invalides');

void main() {
  late MockStripeAccountRepository mockRepo;

  setUp(() {
    mockRepo = MockStripeAccountRepository();
  });

  StripeAccountBloc buildBloc() => StripeAccountBloc(mockRepo);

  group('StripeAccountBloc — initial state', () {
    test('initial state is StripeAccountInitial', () {
      expect(buildBloc().state, isA<StripeAccountInitial>());
    });
  });

  group('StripeAccountStatusLoaded', () {
    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [Loading, Ready(complete)] on success',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getAccountStatus())
            .thenAnswer((_) async => _complete);
      },
      act: (b) => b.add(const StripeAccountStatusLoaded()),
      expect: () => [
        isA<StripeAccountLoading>(),
        isA<StripeAccountReady>().having(
          (s) => s.accountStatus.isComplete,
          'isComplete',
          isTrue,
        ),
      ],
    );

    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [Loading, Ready(disabled)] when account is DISABLED',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getAccountStatus())
            .thenAnswer((_) async => _disabled);
      },
      act: (b) => b.add(const StripeAccountStatusLoaded()),
      expect: () => [
        isA<StripeAccountLoading>(),
        isA<StripeAccountReady>().having(
          (s) => s.accountStatus.isDisabled,
          'isDisabled',
          isTrue,
        ),
      ],
    );

    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [Loading, Ready(rejected)] when account is REJECTED',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getAccountStatus())
            .thenAnswer((_) async => _rejected);
      },
      act: (b) => b.add(const StripeAccountStatusLoaded()),
      expect: () => [
        isA<StripeAccountLoading>(),
        isA<StripeAccountReady>().having(
          (s) => s.accountStatus.isRejected,
          'isRejected',
          isTrue,
        ),
      ],
    );

    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [Loading, LoadError] when repo throws',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getAccountStatus())
            .thenThrow(Exception('Network error'));
      },
      act: (b) => b.add(const StripeAccountStatusLoaded()),
      expect: () => [
        isA<StripeAccountLoading>(),
        isA<StripeAccountLoadError>(),
      ],
    );
  });

  group('StripeAccountStatusRefreshed', () {
    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [Ready(complete)] without Loading on refresh',
      build: buildBloc,
      seed: () => const StripeAccountReady(_disabled),
      setUp: () {
        when(() => mockRepo.getAccountStatus())
            .thenAnswer((_) async => _complete);
      },
      act: (b) => b.add(const StripeAccountStatusRefreshed()),
      expect: () => [
        isA<StripeAccountReady>().having(
          (s) => s.accountStatus.isComplete,
          'isComplete',
          isTrue,
        ),
      ],
    );

    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [LoadError] silently on refresh failure',
      build: buildBloc,
      seed: () => const StripeAccountReady(_complete),
      setUp: () {
        when(() => mockRepo.getAccountStatus())
            .thenThrow(Exception('Timeout'));
      },
      act: (b) => b.add(const StripeAccountStatusRefreshed()),
      expect: () => [isA<StripeAccountLoadError>()],
    );
  });
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

```bash
flutter test test/features/stripe_account/bloc/stripe_account_bloc_test.dart --reporter=expanded
```

Expected: FAIL — fichiers BLoC introuvables

- [ ] **Step 3 : Créer `stripe_account_event.dart`**

```dart
part of 'stripe_account_bloc.dart';

sealed class StripeAccountEvent {
  const StripeAccountEvent();
}

class StripeAccountStatusLoaded extends StripeAccountEvent {
  const StripeAccountStatusLoaded();
}

class StripeAccountStatusRefreshed extends StripeAccountEvent {
  const StripeAccountStatusRefreshed();
}
```

- [ ] **Step 4 : Créer `stripe_account_state.dart`**

```dart
part of 'stripe_account_bloc.dart';

sealed class StripeAccountState {
  const StripeAccountState();
}

class StripeAccountInitial extends StripeAccountState {
  const StripeAccountInitial();
}

class StripeAccountLoading extends StripeAccountState {
  const StripeAccountLoading();
}

class StripeAccountReady extends StripeAccountState {
  final ConnectAccountStatus accountStatus;
  const StripeAccountReady(this.accountStatus);
}

class StripeAccountLoadError extends StripeAccountState {
  const StripeAccountLoadError();
}
```

- [ ] **Step 5 : Créer `stripe_account_bloc.dart`**

```dart
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/stripe_account/data/stripe_account_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'stripe_account_event.dart';
part 'stripe_account_state.dart';

class StripeAccountBloc
    extends Bloc<StripeAccountEvent, StripeAccountState> {
  final IStripeAccountRepository _repository;

  StripeAccountBloc(this._repository) : super(const StripeAccountInitial()) {
    on<StripeAccountStatusLoaded>(_onLoad);
    on<StripeAccountStatusRefreshed>(_onRefresh);
  }

  Future<void> _onLoad(
    StripeAccountStatusLoaded event,
    Emitter<StripeAccountState> emit,
  ) async {
    emit(const StripeAccountLoading());
    await _fetch(emit);
  }

  Future<void> _onRefresh(
    StripeAccountStatusRefreshed event,
    Emitter<StripeAccountState> emit,
  ) async {
    await _fetch(emit);
  }

  Future<void> _fetch(Emitter<StripeAccountState> emit) async {
    try {
      final status = await _repository.getAccountStatus();
      emit(StripeAccountReady(status));
    } catch (_) {
      // Erreur réseau silencieuse — ne bloque pas l'utilisateur,
      // retry au prochain retour en foreground.
      emit(const StripeAccountLoadError());
    }
  }
}
```

- [ ] **Step 6 : Lancer le test pour vérifier qu'il passe**

```bash
flutter test test/features/stripe_account/bloc/stripe_account_bloc_test.dart --reporter=expanded
```

Expected: tous PASS (10 tests)

- [ ] **Step 7 : Commit**

```bash
git add lib/features/stripe_account/bloc/ \
        test/features/stripe_account/bloc/stripe_account_bloc_test.dart
git commit -m "feat: add StripeAccountBloc with load/refresh events"
```

---

## Task 6 : GetIt injection + `app.dart`

**Files:**
- Modify: `lib/core/di/injection.dart`
- Modify: `lib/app/app.dart`

- [ ] **Step 1 : Ajouter dans `injection.dart`**

Ajouter les imports en haut du fichier :

```dart
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/data/stripe_account_datasource.dart';
import 'package:dony/features/stripe_account/data/stripe_account_repository.dart';
```

Ajouter avant l'accolade fermante `}` de la fonction d'initialisation :

```dart
getIt.registerLazySingleton<StripeAccountDatasource>(
  () => StripeAccountDatasource(getIt<ApiClient>()),
);
getIt.registerLazySingleton<IStripeAccountRepository>(
  () => StripeAccountRepository(getIt<StripeAccountDatasource>()),
);
getIt.registerLazySingleton<StripeAccountBloc>(
  () => StripeAccountBloc(getIt<IStripeAccountRepository>()),
  dispose: (b) => b.close(),
);
```

- [ ] **Step 2 : Ajouter dans `app.dart`**

Ajouter l'import :

```dart
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
```

Ajouter dans le `MultiBlocProvider.providers` (après `BlocProvider<RatingBloc>`) :

```dart
BlocProvider<StripeAccountBloc>(
  create: (_) => getIt<StripeAccountBloc>(),
),
```

- [ ] **Step 3 : Vérifier la compilation complète**

```bash
flutter analyze lib/
```

Expected: No issues

- [ ] **Step 4 : Commit**

```bash
git add lib/core/di/injection.dart lib/app/app.dart
git commit -m "feat: register StripeAccountBloc as global singleton in GetIt and app.dart"
```

---

## Task 7 : Widgets banner

**Files:**
- Create: `lib/features/stripe_account/presentation/widgets/account_disabled_banner.dart`
- Create: `lib/features/stripe_account/presentation/widgets/account_rejected_banner.dart`
- Test: `test/features/stripe_account/presentation/widgets/account_disabled_banner_test.dart`

- [ ] **Step 1 : Écrire les tests failing**

```dart
// test/features/stripe_account/presentation/widgets/account_disabled_banner_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/widgets/account_disabled_banner.dart';
import 'package:dony/features/stripe_account/presentation/widgets/account_rejected_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

void main() {
  late MockStripeAccountBloc mockBloc;

  setUp(() {
    mockBloc = MockStripeAccountBloc();
  });

  Widget buildWidget(Widget child) => MaterialApp(
        home: BlocProvider<StripeAccountBloc>.value(
          value: mockBloc,
          child: Scaffold(body: child),
        ),
      );

  group('AccountDisabledBanner', () {
    testWidgets('renders warning icon and message', (tester) async {
      await tester.pumpWidget(buildWidget(const AccountDisabledBanner()));
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('temporairement désactivé'), findsOneWidget);
    });

    testWidgets('shows "En savoir plus" button', (tester) async {
      await tester.pumpWidget(buildWidget(const AccountDisabledBanner()));
      expect(find.text('En savoir plus'), findsOneWidget);
    });
  });

  group('AccountRejectedBanner', () {
    testWidgets('renders error icon and message', (tester) async {
      await tester.pumpWidget(buildWidget(const AccountRejectedBanner()));
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.textContaining('rejeté'), findsOneWidget);
    });

    testWidgets('shows "Reconfigurer" button', (tester) async {
      await tester.pumpWidget(buildWidget(const AccountRejectedBanner()));
      expect(find.text('Reconfigurer'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

```bash
flutter test test/features/stripe_account/presentation/widgets/ --reporter=expanded
```

Expected: FAIL — widgets introuvables

- [ ] **Step 3 : Créer `account_disabled_banner.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccountDisabledBanner extends StatelessWidget {
  const AccountDisabledBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: Colors.orange.withOpacity(0.12),
      leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
      content: const Text(
        'Votre compte Stripe est temporairement désactivé',
        style: TextStyle(fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => context.push('/account/disabled'),
          child: const Text('En savoir plus'),
        ),
      ],
    );
  }
}
```

Note : utiliser `Colors.orange` au lieu de `DonyColors.warning` si la constante n'est pas accessible depuis ce package ; ajuster selon le design system réel.

- [ ] **Step 4 : Créer `account_rejected_banner.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccountRejectedBanner extends StatelessWidget {
  const AccountRejectedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: Colors.red.withOpacity(0.12),
      leading: const Icon(Icons.error_outline_rounded, color: Colors.red),
      content: const Text(
        'Votre compte Stripe a été rejeté',
        style: TextStyle(fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => context.push('/account/rejected'),
          child: const Text('Reconfigurer'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5 : Vérifier les tests**

```bash
flutter test test/features/stripe_account/presentation/widgets/ --reporter=expanded
```

Expected: tous PASS

- [ ] **Step 6 : Commit**

```bash
git add lib/features/stripe_account/presentation/widgets/ \
        test/features/stripe_account/presentation/widgets/
git commit -m "feat: add AccountDisabledBanner and AccountRejectedBanner widgets"
```

---

## Task 8 : Écrans informatifs

**Files:**
- Create: `lib/features/stripe_account/presentation/screens/account_disabled_screen.dart`
- Create: `lib/features/stripe_account/presentation/screens/account_rejected_screen.dart`
- Test: `test/features/stripe_account/presentation/screens/account_disabled_screen_test.dart`
- Test: `test/features/stripe_account/presentation/screens/account_rejected_screen_test.dart`

- [ ] **Step 1 : Écrire les tests failing**

```dart
// test/features/stripe_account/presentation/screens/account_disabled_screen_test.dart
import 'package:dony/features/stripe_account/presentation/screens/account_disabled_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildWidget() => const MaterialApp(
        home: AccountDisabledScreen(),
      );

  testWidgets('affiche le titre et le message', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('temporairement désactivé'), findsWidgets);
    expect(find.textContaining('réactivation automatique'), findsOneWidget);
  });

  testWidgets('affiche le bouton Stripe dès le premier affichage', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Voir mon compte Stripe'), findsOneWidget);
  });

  testWidgets('bouton support absent au premier affichage', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Contacter le support Dony'), findsNothing);
  });

  testWidgets('bouton support apparaît après 2 taps sur le bouton principal',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Voir mon compte Stripe'));
    await tester.pump();
    expect(find.text('Contacter le support Dony'), findsNothing);
    await tester.tap(find.text('Voir mon compte Stripe'));
    await tester.pump();
    expect(find.text('Contacter le support Dony'), findsOneWidget);
  });
}
```

```dart
// test/features/stripe_account/presentation/screens/account_rejected_screen_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/screens/account_rejected_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectOnboardingBloc
    extends MockBloc<ConnectOnboardingEvent, ConnectOnboardingState>
    implements ConnectOnboardingBloc {}

class MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

void main() {
  late MockConnectOnboardingBloc mockOnboardingBloc;
  late MockStripeAccountBloc mockStripeBloc;

  setUp(() {
    mockOnboardingBloc = MockConnectOnboardingBloc();
    mockStripeBloc = MockStripeAccountBloc();
    when(() => mockOnboardingBloc.state)
        .thenReturn(const ConnectOnboardingInitial());
    when(() => mockStripeBloc.state)
        .thenReturn(const StripeAccountReady(ConnectAccountStatus(
          status: 'REJECTED',
          reason: 'Documents invalides',
        )));
  });

  Widget buildWidget() => MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ConnectOnboardingBloc>.value(value: mockOnboardingBloc),
            BlocProvider<StripeAccountBloc>.value(value: mockStripeBloc),
          ],
          child: const AccountRejectedScreen(),
        ),
      );

  testWidgets('affiche le titre et le message', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('rejeté'), findsWidgets);
  });

  testWidgets('affiche la raison du rejet si disponible', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Documents invalides'), findsOneWidget);
  });

  testWidgets('affiche le bouton Reconfigurer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Reconfigurer mon compte'), findsOneWidget);
  });

  testWidgets('bouton support absent au premier affichage', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Contacter le support Dony'), findsNothing);
  });

  testWidgets('bouton support apparaît après 2 taps sur Reconfigurer',
      (tester) async {
    when(() => mockOnboardingBloc.state).thenReturn(const ConnectOnboardingInitial());
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Reconfigurer mon compte'));
    await tester.pump();
    await tester.tap(find.text('Reconfigurer mon compte'));
    await tester.pump();
    expect(find.text('Contacter le support Dony'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

```bash
flutter test test/features/stripe_account/presentation/screens/ --reporter=expanded
```

Expected: FAIL — écrans introuvables

- [ ] **Step 3 : Créer `account_disabled_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountDisabledScreen extends StatefulWidget {
  const AccountDisabledScreen({super.key});

  @override
  State<AccountDisabledScreen> createState() => _AccountDisabledScreenState();
}

class _AccountDisabledScreenState extends State<AccountDisabledScreen> {
  int _primaryTapCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Compte désactivé'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Compte temporairement désactivé',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Votre compte Stripe est temporairement désactivé. '
              "La création de nouvelles annonces est bloquée jusqu'à "
              'la réactivation automatique par Stripe.',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  setState(() => _primaryTapCount++);
                  final uri = Uri.parse('https://dashboard.stripe.com/');
                  if (await canLaunchUrl(uri)) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Voir mon compte Stripe'),
              ),
            ),
            if (_primaryTapCount >= 2) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final uri = Uri.parse('mailto:support@dony.app');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  child: const Text('Contacter le support Dony'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4 : Créer `account_rejected_screen.dart`**

```dart
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountRejectedScreen extends StatefulWidget {
  const AccountRejectedScreen({super.key});

  @override
  State<AccountRejectedScreen> createState() => _AccountRejectedScreenState();
}

class _AccountRejectedScreenState extends State<AccountRejectedScreen> {
  int _primaryTapCount = 0;

  @override
  Widget build(BuildContext context) {
    final stripeState = context.watch<StripeAccountBloc>().state;
    final reason = stripeState is StripeAccountReady
        ? stripeState.accountStatus.reason
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Compte rejeté'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Compte rejeté',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Votre compte Stripe a été rejeté. Vous devez '
              'reconfigurer un nouveau compte pour continuer.',
            ),
            if (reason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Raison : $reason',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _primaryTapCount++);
                  context
                      .read<ConnectOnboardingBloc>()
                      .add(const ConnectOnboardingLinkRequested());
                },
                child: const Text('Reconfigurer mon compte'),
              ),
            ),
            if (_primaryTapCount >= 2) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final uri = Uri.parse('mailto:support@dony.app');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  child: const Text('Contacter le support Dony'),
                ),
              ),
            ],
            BlocListener<ConnectOnboardingBloc, ConnectOnboardingState>(
              listener: (context, state) async {
                if (state is ConnectOnboardingUrlReady) {
                  final uri = Uri.parse(state.url);
                  if (await canLaunchUrl(uri)) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5 : Vérifier les tests**

```bash
flutter test test/features/stripe_account/presentation/screens/ --reporter=expanded
```

Expected: tous PASS

- [ ] **Step 6 : Commit**

```bash
git add lib/features/stripe_account/presentation/screens/ \
        test/features/stripe_account/presentation/screens/
git commit -m "feat: add AccountDisabledScreen and AccountRejectedScreen with conditional support button"
```

---

## Task 9 : GoRouter — routes + redirect guard

**Files:**
- Modify: `lib/app/router.dart`

- [ ] **Step 1 : Ajouter les imports dans `router.dart`**

Ajouter après les imports existants :

```dart
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/screens/account_disabled_screen.dart';
import 'package:dony/features/stripe_account/presentation/screens/account_rejected_screen.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
```

- [ ] **Step 2 : Ajouter le redirect guard dans `appRouter`**

Remplacer :

```dart
redirect: (context, state) {
  final user = FirebaseAuth.instance.currentUser;
  final isAuthenticated = user != null;
  final isPublic =
      _publicRoutes.any((r) => state.matchedLocation.startsWith(r));
  if (!isAuthenticated && !isPublic) {
    return '/auth/phone';
  }
  return null;
},
```

Par :

```dart
redirect: (context, state) {
  final user = FirebaseAuth.instance.currentUser;
  final isAuthenticated = user != null;
  final isPublic =
      _publicRoutes.any((r) => state.matchedLocation.startsWith(r));
  if (!isAuthenticated && !isPublic) {
    return '/auth/phone';
  }

  const _guardedRoutes = {'/announcements/create'};
  if (_guardedRoutes.contains(state.matchedLocation)) {
    final accountState = context.read<StripeAccountBloc>().state;
    if (accountState is StripeAccountReady) {
      if (accountState.accountStatus.isDisabled) return '/account/disabled';
      if (accountState.accountStatus.isRejected) return '/account/rejected';
    }
  }

  return null;
},
```

- [ ] **Step 3 : Ajouter les routes `/account/disabled` et `/account/rejected`**

Ajouter avant le commentaire `// ── Connect onboarding (hors shell)` (ligne ~186) :

```dart
// ── Stripe account status (hors shell) ──────────────────────────────
GoRoute(
  path: '/account/disabled',
  builder: (context, state) => const AccountDisabledScreen(),
),
GoRoute(
  path: '/account/rejected',
  builder: (context, state) => BlocProvider(
    create: (_) => getIt<ConnectOnboardingBloc>(),
    child: const AccountRejectedScreen(),
  ),
),
```

- [ ] **Step 4 : Vérifier la compilation**

```bash
flutter analyze lib/app/router.dart
```

Expected: No issues

- [ ] **Step 5 : Lancer les tests existants du router**

```bash
flutter test --reporter=expanded 2>&1 | grep -E "PASS|FAIL|ERROR" | tail -20
```

Expected: aucun nouveau FAIL introduit par ce changement

- [ ] **Step 6 : Commit**

```bash
git add lib/app/router.dart
git commit -m "feat: add /account/disabled and /account/rejected routes + GoRouter redirect guard"
```

---

## Task 10 : `MainShell` — banner persistant + lifecycle refresh

**Files:**
- Modify: `lib/app/main_shell.dart`

- [ ] **Step 1 : Mettre à jour `main_shell.dart`**

Ajouter les imports :

```dart
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/widgets/account_disabled_banner.dart';
import 'package:dony/features/stripe_account/presentation/widgets/account_rejected_banner.dart';
```

Modifier la classe `_MainShellState` pour ajouter `WidgetsBindingObserver` :

```dart
class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
```

Dans `initState`, ajouter observer et déclenchement du chargement initial :

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    context.read<NotificationBloc>().add(const NotificationsLoadRequested());
    context.read<RatingBloc>().add(const PendingRatingChecked());
    context.read<StripeAccountBloc>().add(const StripeAccountStatusLoaded());
    _fcmSub = getIt<NotificationService>().newNotificationStream.listen((_) {
      if (mounted) {
        context.read<NotificationBloc>().add(const NotificationsLoadRequested());
      }
    });
  });
}
```

Ajouter `didChangeAppLifecycleState` :

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed && mounted) {
    context.read<StripeAccountBloc>().add(const StripeAccountStatusRefreshed());
  }
}
```

Dans `dispose`, ajouter `removeObserver` :

```dart
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _fcmSub?.cancel();
  super.dispose();
}
```

Remplacer la méthode `build` complète par :

```dart
@override
Widget build(BuildContext context) {
  return MultiBlocListener(
    listeners: [
      BlocListener<RatingBloc, RatingState>(
        listener: (context, state) {
          if (state is PendingRatingFound && !_ratingPromptShown) {
            _ratingPromptShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              RatingBottomSheet.show(
                context,
                bidId: state.bidId,
                travelerName: state.otherPartyName,
                isTravelerRating: state.isTravelerRating,
              );
            });
          }
        },
      ),
    ],
    child: BlocBuilder<StripeAccountBloc, StripeAccountState>(
      buildWhen: (prev, curr) {
        if (prev is StripeAccountReady && curr is StripeAccountReady) {
          return prev.accountStatus.isDisabled != curr.accountStatus.isDisabled ||
              prev.accountStatus.isRejected != curr.accountStatus.isRejected;
        }
        return prev.runtimeType != curr.runtimeType;
      },
      builder: (context, accountState) {
        Widget? banner;
        if (accountState is StripeAccountReady) {
          if (accountState.accountStatus.isDisabled) {
            banner = const AccountDisabledBanner();
          } else if (accountState.accountStatus.isRejected) {
            banner = const AccountRejectedBanner();
          }
        }
        return Scaffold(
          body: Column(
            children: [
              if (banner != null) banner,
              Expanded(child: widget.navigationShell),
            ],
          ),
          bottomNavigationBar: _DonyBottomNav(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: _onTap,
          ),
        );
      },
    ),
  );
}
```

- [ ] **Step 2 : Vérifier la compilation**

```bash
flutter analyze lib/app/main_shell.dart
```

Expected: No issues

- [ ] **Step 3 : Lancer tous les tests**

```bash
flutter test --reporter=expanded
```

Expected: 0 nouveau rouge. Noter les tests initialement en échec (36 pré-existants au baseline) — ne pas en introduire de nouveaux.

- [ ] **Step 4 : Vérifier la couverture sur `stripe_account/`**

```bash
flutter test --coverage test/features/stripe_account/ test/core/models/ test/features/payments/data/payment_status_test.dart
```

Expected: couverture ≥ 90 % sur les fichiers `stripe_account/`

- [ ] **Step 5 : Commit final**

```bash
git add lib/app/main_shell.dart
git commit -m "feat: integrate StripeAccountBloc banner in MainShell with lifecycle refresh"
```

---

## Vérification finale

```bash
# Analyse statique complète
flutter analyze lib/

# Tous les tests
flutter test --reporter=expanded

# Couverture globale
flutter test --coverage
```

Expected : `flutter analyze` → 0 erreur, `flutter test` → 0 nouveau rouge par rapport au baseline (36 pré-existants).
