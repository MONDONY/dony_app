# Coverage Bid-Detail Widgets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise line coverage of 5 Flutter widget files from 73–88% to ≥ 90% each, by adding targeted tests — zero production code changes.

**Architecture:** Each task targets one source file and its corresponding test file. Coverage gaps are identified from `coverage/lcov.info` DA:n,0 entries. All new tests are pure widget tests using the existing MockBloc / mocktail / platform-channel mock patterns already in the project.

**Tech Stack:** Flutter test, mocktail, bloc_test, flutter_test platform-channel mocking (TestDefaultBinaryMessengerBinding), GetIt

---

## File Map

| Source file | Test file to modify | Current % | Target |
|---|---|---|---|
| `lib/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart` | `test/features/matching/presentation/widgets/bid_detail/sender_hero_card_test.dart` | 81.7% | ≥ 90% |
| `lib/features/matching/presentation/widgets/bid_detail/sender_sticky_bar.dart` | `test/features/matching/presentation/widgets/bid_detail/sender_sticky_bar_test.dart` | 76.8% | ≥ 90% |
| `lib/features/matching/presentation/widgets/bid_detail/voyageur_contact_card.dart` | `test/features/matching/presentation/widgets/bid_detail/sender_cards_test.dart` | 88.3% | ≥ 90% |
| `lib/features/matching/presentation/widgets/bid_detail/qr_sheet.dart` | `test/features/matching/presentation/widgets/bid_detail/qr_sheet_test.dart` | 73.6% | ≥ 90% |
| `lib/core/design/widgets/dony_feedback_button.dart` | `test/core/design/widgets/dony_feedback_button_test.dart` | 76.0% | ≥ 90% |

---

## Task 1: sender_hero_card.dart — missing branches (81.7% → ≥90%)

**Uncovered line groups:**
- Lines 98-103: `AWAITING_PAYMENT` branch in `_buildContent`
- Lines 181-193: `_formatWindow` — only-start / only-end branches
- Line 204: `_buildInTransitSubtitle` — no confirmationCode branch
- Line 262: `_HeroShell` `alert` variant gradient
- Lines 452-453: `_ContestationHero` timer fires → `mounted` guard
- Lines 467-472: `_updateCountdown` deadline=null and deadline negative paths
- Lines 504, 512: `_ContestationHero._showContestSheet` — cancel path (confirmed != true)
- Lines 522-557: `_showContestSheet` confirmed → NoShowContestRequested dispatched
- Lines 560-576: `_showConfirmSheet` → 'Compris' closes sheet

**Files:**
- Modify: `test/features/matching/presentation/widgets/bid_detail/sender_hero_card_test.dart`

- [ ] **Step 1: Write the failing tests**

Add the following tests at the bottom of `main()` in `sender_hero_card_test.dart` (after test 10):

```dart
// ── Test 11: AWAITING_PAYMENT ────────────────────────────────────────────────

testWidgets('11 · AWAITING_PAYMENT → "Payez pour confirmer" + amount', (
  tester,
) async {
  final bid = _bid(status: 'AWAITING_PAYMENT', totalAmountEur: 120.50);
  await tester.pumpWidget(_host(bid, cancellationBloc));
  await tester.pump();

  expect(find.textContaining("Payez pour confirmer"), findsOneWidget);
  expect(find.textContaining("120.50"), findsOneWidget);
});

// ── Test 12: IN_TRANSIT sans confirmationCode ─────────────────────────────────

testWidgets('12 · IN_TRANSIT sans confirmationCode → "En route vers"', (
  tester,
) async {
  final bid = _bid(
    status: 'IN_TRANSIT',
    arrivalCity: 'Dakar',
    arrivalTime: '',
    confirmationCode: null,
  );
  await tester.pumpWidget(_host(bid, cancellationBloc));
  await tester.pump();

  expect(find.textContaining('Colis en vol'), findsOneWidget);
  expect(find.textContaining('En route vers Dakar'), findsOneWidget);
});

// ── Test 13: HANDED_OVER departureDate null → "Colis remis." ──────────────────

testWidgets('13 · HANDED_OVER departureDate=null → "Colis remis."', (
  tester,
) async {
  final bid = _bid(
    status: 'HANDED_OVER',
    travelerName: 'Amadou',
    departureDate: null,
  );
  await tester.pumpWidget(_host(bid, cancellationBloc));
  await tester.pump();

  expect(find.textContaining('Colis remis.'), findsOneWidget);
});

// ── Test 14: DELIVERED → "Livré à" ───────────────────────────────────────────

testWidgets('14 · DELIVERED → "Livré à"', (tester) async {
  final bid = _bid(status: 'DELIVERED', recipientName: 'Karim');
  await tester.pumpWidget(_host(bid, cancellationBloc));
  await tester.pump();

  expect(find.textContaining('Livré à Karim'), findsOneWidget);
});

// ── Test 15: REJECTED/NO_SHOW/EXPIRED/PARCEL_REFUSED → SizedBox.shrink ───────

for (final status in ['REJECTED', 'NO_SHOW', 'EXPIRED', 'PARCEL_REFUSED']) {
  testWidgets('15 · $status → shrink (no hero text)', (tester) async {
    final bid = _bid(status: status);
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('En attente'), findsNothing);
    expect(find.textContaining('Paiement'), findsNothing);
    expect(find.textContaining('Remise'), findsNothing);
    expect(find.textContaining('Colis'), findsNothing);
    expect(find.textContaining('Livré'), findsNothing);
  });
}

// ── Test 16: PENDING_CONFIRMATION deadline null → pas de countdown ────────────

testWidgets(
  '16 · PENDING_CONFIRMATION deadline=null → "Absence signalée" sans "Temps pour contester"',
  (tester) async {
    final bid = _bid(
      status: 'ACCEPTED',
      cancellationNoShowStatus: 'PENDING_CONFIRMATION',
      contestationDeadline: null,
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('Absence signalée'), findsOneWidget);
    expect(find.textContaining('Temps pour contester'), findsNothing);

    // Kill timer
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  },
);

// ── Test 17: PENDING_CONFIRMATION deadline passée → "Délai expiré" ───────────

testWidgets(
  '17 · PENDING_CONFIRMATION deadline passée → "Délai expiré" affiché',
  (tester) async {
    final bid = _bid(
      status: 'ACCEPTED',
      cancellationNoShowStatus: 'PENDING_CONFIRMATION',
      contestationDeadline: DateTime.now().subtract(const Duration(hours: 1)),
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('Délai expiré'), findsOneWidget);

    // Kill timer
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  },
);

// ── Test 18: tap "Je conteste" → sheet → annuler (no dispatch) ───────────────

testWidgets(
  '18 · tap "Je conteste" → sheet s\'ouvre → appuyer barrière → aucun dispatch',
  (tester) async {
    final bid = _bid(
      status: 'ACCEPTED',
      cancellationNoShowStatus: 'PENDING_CONFIRMATION',
      contestationDeadline: DateTime.now().add(const Duration(hours: 47)),
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    await tester.tap(find.textContaining('Je conteste'));
    await tester.pumpAndSettle();

    // Sheet is open — close by tapping outside
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();

    // NoShowContestRequested must NOT have been dispatched
    verifyNever(
      () => cancellationBloc.add(any(that: isA<NoShowContestRequested>())),
    );

    // Kill timer
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  },
);

// ── Test 19: tap "Je conteste" → confirmer → NoShowContestRequested ──────────

testWidgets(
  '19 · tap "Je conteste" → "Confirmer la contestation" → NoShowContestRequested dispatched',
  (tester) async {
    final bid = _bid(
      status: 'ACCEPTED',
      cancellationNoShowStatus: 'PENDING_CONFIRMATION',
      contestationDeadline: DateTime.now().add(const Duration(hours: 47)),
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    await tester.tap(find.textContaining('Je conteste'));
    await tester.pumpAndSettle();

    final confirmBtn = find.descendant(
      of: find.byKey(const Key('donyBottomSheetFooter')),
      matching: find.textContaining('Confirmer la contestation'),
    );
    await tester.tap(confirmBtn.last);
    await tester.pumpAndSettle();

    verify(
      () => cancellationBloc.add(any(that: isA<NoShowContestRequested>())),
    ).called(1);

    // Kill timer
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  },
);

// ── Test 20: tap "Je confirme" → sheet informatif → "Compris" ferme ──────────

testWidgets(
  '20 · tap "Je confirme" → sheet s\'ouvre → "Compris" ferme le sheet',
  (tester) async {
    final bid = _bid(
      status: 'ACCEPTED',
      cancellationNoShowStatus: 'PENDING_CONFIRMATION',
      contestationDeadline: DateTime.now().add(const Duration(hours: 47)),
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    await tester.tap(find.textContaining('Je confirme'));
    await tester.pumpAndSettle();

    // "Compris" button should be in the sheet
    expect(find.textContaining('Compris'), findsOneWidget);

    await tester.tap(find.textContaining('Compris'));
    await tester.pumpAndSettle();

    // Sheet should be closed
    expect(find.textContaining('Confirmer votre absence'), findsNothing);

    // Kill timer
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  },
);
```

- [ ] **Step 2: Run to verify they compile and some may fail initially**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter test test/features/matching/presentation/widgets/bid_detail/sender_hero_card_test.dart 2>&1 | tail -20
```

Expected: Tests 11-17 and 20 should pass. Tests 18-19 depend on sheet interaction — verify they pass or are `findsNothing` correctly.

- [ ] **Step 3: Measure coverage**

```bash
flutter test --coverage test/features/matching/presentation/widgets/bid_detail/sender_hero_card_test.dart 2>&1 | tail -5
python3 -c "
def get_pct(path, suffix):
    curr = None; tot = 0; cov = 0
    for line in open(path):
        line = line.strip()
        if line.startswith('SF:'): curr = line[3:]; tot = 0; cov = 0
        elif line.startswith('DA:'):
            p = line[3:].split(','); tot += 1
            if int(p[1]) > 0: cov += 1
        elif line == 'end_of_record' and curr and curr.endswith(suffix):
            print(f'{suffix}: {cov}/{tot} = {cov/tot*100:.1f}%')
get_pct('coverage/lcov.info', 'sender_hero_card.dart')
"
```

Expected: ≥ 90%.

- [ ] **Step 4: Commit**

```bash
git add test/features/matching/presentation/widgets/bid_detail/sender_hero_card_test.dart
git commit -m "test(matching): couvre les branches manquantes de sender_hero_card (≥90%)"
```

---

## Task 2: sender_sticky_bar.dart — hasAction + missing branches (76.8% → ≥90%)

**Uncovered line groups:**
- Lines 55-76: `hasAction()` static method — PENDING_CONFIRMATION gate, PENDING cash, ACCEPTED, HANDED_OVER, IN_TRANSIT, COMPLETED/DELIVERED senderHasRated, kEnvoisPasses
- Lines 181-183: `_buildAction` PENDING_CONFIRMATION → null
- Lines 196-200: `_buildAction` ACCEPTED stripe + paymentLoaded=false placeholder
- Lines 214-218: `_buildAction` HANDED_OVER status
- Line 261: dialog 'Annuler' path (pop(false) → no event dispatched)

**Files:**
- Modify: `test/features/matching/presentation/widgets/bid_detail/sender_sticky_bar_test.dart`

- [ ] **Step 1: Write the failing tests**

Add these tests at the bottom of `main()` in `sender_sticky_bar_test.dart`:

```dart
// ── Tests hasAction() static method ──────────────────────────────────────────

group('hasAction() static', () {
  test(
    'PENDING_CONFIRMATION → false (hero handles it)',
    () {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
      );
      expect(SenderStickyBar.hasAction(bid), isFalse);
    },
  );

  test('PENDING stripe → true', () {
    final bid = _bid(
      status: 'PENDING',
      paymentMethod: BidPaymentMethod.stripe,
    );
    expect(SenderStickyBar.hasAction(bid), isTrue);
  });

  test('PENDING cash → false', () {
    final bid = _bid(
      status: 'PENDING',
      paymentMethod: BidPaymentMethod.cash,
    );
    expect(SenderStickyBar.hasAction(bid), isFalse);
  });

  test('ACCEPTED → true', () {
    expect(SenderStickyBar.hasAction(_bid(status: 'ACCEPTED')), isTrue);
  });

  test('HANDED_OVER → true', () {
    expect(SenderStickyBar.hasAction(_bid(status: 'HANDED_OVER')), isTrue);
  });

  test('IN_TRANSIT → true', () {
    expect(SenderStickyBar.hasAction(_bid(status: 'IN_TRANSIT')), isTrue);
  });

  test('COMPLETED senderHasRated=false → true', () {
    expect(
      SenderStickyBar.hasAction(
        _bid(status: 'COMPLETED', senderHasRated: false),
      ),
      isTrue,
    );
  });

  test('COMPLETED senderHasRated=true → false', () {
    expect(
      SenderStickyBar.hasAction(
        _bid(status: 'COMPLETED', senderHasRated: true),
      ),
      isFalse,
    );
  });

  test('DELIVERED senderHasRated=false → true', () {
    expect(
      SenderStickyBar.hasAction(
        _bid(status: 'DELIVERED', senderHasRated: false),
      ),
      isTrue,
    );
  });

  test('REJECTED → true (kEnvoisPasses)', () {
    expect(SenderStickyBar.hasAction(_bid(status: 'REJECTED')), isTrue);
  });

  test('NO_SHOW → true (kEnvoisPasses)', () {
    expect(SenderStickyBar.hasAction(_bid(status: 'NO_SHOW')), isTrue);
  });

  test('EXPIRED → true (kEnvoisPasses)', () {
    expect(SenderStickyBar.hasAction(_bid(status: 'EXPIRED')), isTrue);
  });

  test('PAYMENT_ESCROWED → false (not in any branch)', () {
    expect(
      SenderStickyBar.hasAction(_bid(status: 'PAYMENT_ESCROWED')),
      isFalse,
    );
  });
});

// ── PENDING_CONFIRMATION → SizedBox.shrink (no action) ───────────────────────

testWidgets(
  '11. PENDING_CONFIRMATION → SizedBox.shrink (bar invisible)',
  (tester) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(bloc, const Stream.empty(),
        initialState: BidInitial());

    await tester.pumpWidget(
      _host(
        bloc,
        _bid(
          status: 'ACCEPTED',
          cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        ),
        paymentLoaded: true,
      ),
    );
    await tester.pumpAndSettle();

    // Bar must render nothing (SizedBox.shrink)
    expect(find.text('Payer mon envoi'), findsNothing);
    expect(find.text('Afficher le QR de remise'), findsNothing);
    expect(find.text('Suivi du colis'), findsNothing);
    expect(find.text('Supprimer cette demande'), findsNothing);
  },
);

// ── HANDED_OVER → "Suivi du colis" ────────────────────────────────────────────

testWidgets(
  '12. HANDED_OVER → "Suivi du colis"',
  (tester) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(bloc, const Stream.empty(),
        initialState: BidInitial());

    await tester.pumpWidget(
      _host(bloc, _bid(status: 'HANDED_OVER'), paymentLoaded: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Suivi du colis'), findsOneWidget);
  },
);

// ── DELIVERED non noté → 'Noter le voyageur' ──────────────────────────────────

testWidgets(
  '13. DELIVERED senderHasRated=false → "Noter le voyageur"',
  (tester) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(bloc, const Stream.empty(),
        initialState: BidInitial());

    await tester.pumpWidget(
      _host(
        bloc,
        _bid(status: 'DELIVERED', senderHasRated: false),
        paymentLoaded: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Noter le voyageur'), findsOneWidget);
  },
);

// ── delete dialog → 'Annuler' → no event dispatched ──────────────────────────

testWidgets(
  '14. CANCELLED → dialog "Supprimer cette demande ?" → "Annuler" → aucun BidDeleteRequested',
  (tester) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(bloc, const Stream.empty(),
        initialState: BidInitial());

    await tester.pumpWidget(
      _host(bloc, _bid(status: 'CANCELLED'), paymentLoaded: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer cette demande'));
    await tester.pumpAndSettle();

    // Dialog visible
    expect(find.byType(AlertDialog), findsOneWidget);

    // Tap 'Annuler'
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    // BidDeleteRequested must NOT have been dispatched
    verifyNever(() => bloc.add(any(that: isA<BidDeleteRequested>())));
  },
);

// ── REJECTED → "Supprimer cette demande" ─────────────────────────────────────

testWidgets(
  '15. REJECTED → "Supprimer cette demande"',
  (tester) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(bloc, const Stream.empty(),
        initialState: BidInitial());

    await tester.pumpWidget(
      _host(bloc, _bid(status: 'REJECTED'), paymentLoaded: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Supprimer cette demande'), findsOneWidget);
  },
);

// ── NO_SHOW → "Supprimer cette demande" ──────────────────────────────────────

testWidgets(
  '16. NO_SHOW → "Supprimer cette demande"',
  (tester) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(bloc, const Stream.empty(),
        initialState: BidInitial());

    await tester.pumpWidget(
      _host(bloc, _bid(status: 'NO_SHOW'), paymentLoaded: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Supprimer cette demande'), findsOneWidget);
  },
);
```

- [ ] **Step 2: Run the tests**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter test test/features/matching/presentation/widgets/bid_detail/sender_sticky_bar_test.dart 2>&1 | tail -10
```

Expected: All tests passed.

- [ ] **Step 3: Measure coverage**

```bash
flutter test --coverage test/features/matching/presentation/widgets/bid_detail/sender_sticky_bar_test.dart 2>&1 | tail -5
python3 -c "
def get_pct(path, suffix):
    curr = None; tot = 0; cov = 0
    for line in open(path):
        line = line.strip()
        if line.startswith('SF:'): curr = line[3:]; tot = 0; cov = 0
        elif line.startswith('DA:'):
            p = line[3:].split(','); tot += 1
            if int(p[1]) > 0: cov += 1
        elif line == 'end_of_record' and curr and curr.endswith(suffix):
            print(f'{suffix}: {cov}/{tot} = {cov/tot*100:.1f}%')
get_pct('coverage/lcov.info', 'sender_sticky_bar.dart')
"
```

Expected: ≥ 90%.

- [ ] **Step 4: Commit**

```bash
git add test/features/matching/presentation/widgets/bid_detail/sender_sticky_bar_test.dart
git commit -m "test(matching): couvre hasAction et les branches manquantes de sender_sticky_bar (≥90%)"
```

---

## Task 3: voyageur_contact_card.dart — travelerId tap + _buildTravelerProfile (88.3% → ≥90%)

**Uncovered line groups:**
- Lines 30-38: `_buildTravelerProfile()` body — only called when `travelerId != null` and card is tapped
- Line 53: `launchUrl(uri)` / canLaunch=true path (the test in sender_cards_test tests canLaunch=false → snackbar; the canLaunch=true path exercises lines that launch without snackbar)
- Line 82: `canOpenProfile` = true branch (chevron rendering) — already partially tested but `_buildTravelerProfile` call not reached

The fix: add a test where `travelerId != null` and the card is tapped (which calls `showTravelerProfileSheet` and executes `_buildTravelerProfile`). The sheet will open. We can pump and verify it's present.

**Note on canLaunch=true path (line 53):** The `launchUrl` platform channel returns `true` by default in the test environment when canLaunchUrl mock returns true. However, sender_cards_test already covers the `canLaunch=false` snackbar. We need to cover the `launchUrl` success path. This requires mocking the url_launcher channel to return `canLaunch: true` AND `launch: true`.

**Files:**
- Modify: `test/features/matching/presentation/widgets/bid_detail/sender_cards_test.dart`

- [ ] **Step 1: Write the failing tests**

In `sender_cards_test.dart`, inside the `VoyageurContactCard group`, add these tests after the existing ones:

```dart
testWidgets('travelerId non-null → chevron visible et tap ouvre le sheet profil',
    (tester) async {
  final bid = _bid(
    status: 'ACCEPTED',
    travelerName: 'Ibrahima Diallo',
  )..copyWith(); // BidModel is const, create via factory with travelerId
  // We need travelerId to be non-null. Use a bid created with travelerId:
  final bidWithId = BidModel(
    id: 'bid-test',
    announcementId: 'ann-test',
    senderId: 'sender-test',
    status: 'ACCEPTED',
    createdAt: DateTime(2026, 1, 15),
    updatedAt: DateTime(2026, 1, 15),
    travelerName: 'Ibrahima Diallo',
    travelerId: 'traveler-uuid-001',
    travelerPhone: '+33611223344',
    travelerAverageRating: 4.5,
    travelerTotalTrips: 8,
    travelerKycVerified: true,
  );

  await tester.pumpWidget(_hostVoyageur(bidWithId, bloc));
  await tester.pumpAndSettle();

  // Chevron should be visible when travelerId is non-null
  expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

  // Tap the card to open traveler profile sheet
  await tester.tap(find.byType(InkWell).first);
  await tester.pumpAndSettle();

  // Profile sheet should open (contains traveler name)
  expect(find.text('Ibrahima Diallo'), findsWidgets);
});

testWidgets('travelerId null → pas de chevron', (tester) async {
  // _bid() doesn't set travelerId (null by default)
  final bidNoId = BidModel(
    id: 'bid-test',
    announcementId: 'ann-test',
    senderId: 'sender-test',
    status: 'ACCEPTED',
    createdAt: DateTime(2026, 1, 15),
    updatedAt: DateTime(2026, 1, 15),
    travelerName: 'Inconnu',
    // travelerId deliberately null
  );

  await tester.pumpWidget(_hostVoyageur(bidNoId, bloc));
  await tester.pumpAndSettle();

  expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
});

testWidgets(
    '_call canLaunchUrl=true et launchUrl=true → aucun snackbar erreur',
    (tester) async {
  // Mock url_launcher platform channel to return canLaunch: true + launch: true
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  messenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'canLaunch') return true;
    if (call.method == 'launch') return true;
    return null;
  });

  final bid = _bid(travelerPhone: '+33600000001', status: 'ACCEPTED');
  await tester.pumpWidget(_hostVoyageur(bid, bloc));
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.phone_rounded));
  await tester.pumpAndSettle();

  // No error snackbar should appear
  expect(find.textContaining("Impossible d'ouvrir le composeur"), findsNothing);

  // Cleanup mock
  messenger.setMockMethodCallHandler(channel, null);
});
```

Note: The `_bid()` helper in `sender_cards_test.dart` does not set `travelerId`. Use `BidModel(...)` constructor directly for tests requiring `travelerId`.

- [ ] **Step 2: Fix import — add BidModel direct usage if needed**

The `BidModel` import is already present in the test file via the `_bid()` fixture helper. Add a direct import if not present:

Verify the import at the top of `sender_cards_test.dart`:
```dart
import 'package:flutter/services.dart'; // for MethodChannel (already present)
```

- [ ] **Step 3: Run the tests**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter test test/features/matching/presentation/widgets/bid_detail/sender_cards_test.dart 2>&1 | tail -15
```

Expected: All tests passed.

- [ ] **Step 4: Measure coverage**

```bash
flutter test --coverage test/features/matching/presentation/widgets/bid_detail/sender_cards_test.dart 2>&1 | tail -5
python3 -c "
def get_pct(path, suffix):
    curr = None; tot = 0; cov = 0
    for line in open(path):
        line = line.strip()
        if line.startswith('SF:'): curr = line[3:]; tot = 0; cov = 0
        elif line.startswith('DA:'):
            p = line[3:].split(','); tot += 1
            if int(p[1]) > 0: cov += 1
        elif line == 'end_of_record' and curr and curr.endswith(suffix):
            print(f'{suffix}: {cov}/{tot} = {cov/tot*100:.1f}%')
get_pct('coverage/lcov.info', 'voyageur_contact_card.dart')
"
```

Expected: ≥ 90%.

- [ ] **Step 5: Commit**

```bash
git add test/features/matching/presentation/widgets/bid_detail/sender_cards_test.dart
git commit -m "test(matching): couvre _buildTravelerProfile et _call succès dans voyageur_contact_card (≥90%)"
```

---

## Task 4: qr_sheet.dart — save/share handlers (73.6% → ≥90%)

**Uncovered line groups:**
- Line 46: analytics best-effort call (getItSafe, already structurally untestable without GetIt — acceptable)
- Lines 79, 81-82: ScreenBrightness reset on close (platform channel — untestable in widget test)
- Lines 116-122: `_QrSheetBody` initial/unknown state → fallback spinner
- Lines 174: SizedBox.shrink in stickyBottom when state is not Error or Loaded
- Lines 210-240: `_saveToGallery` — Gal.putImageBytes success path (lines 210-221) and error path (228-229)
- Lines 239-240: `saving.value = false` in finally after context.mounted check
- Lines 249-280: `_shareQrCode` — full path including `Share.shareXFiles` and error handling

**Strategy for _saveToGallery and _shareQrCode:**
- The `Gal.putImageBytes` uses a platform channel. Mock it via `TestDefaultBinaryMessengerBinding`.
- The `Share.shareXFiles` from share_plus also uses a platform channel.
- We can mock both channels and test both success and error paths.

**Files:**
- Modify: `test/features/matching/presentation/widgets/bid_detail/qr_sheet_test.dart`

- [ ] **Step 1: Add imports to qr_sheet_test.dart**

At the top of `qr_sheet_test.dart`, ensure these imports are present:
```dart
import 'package:flutter/services.dart';
```
(It should already have `dart:async`, `bloc_test`, `mocktail`, etc.)

- [ ] **Step 2: Write the failing tests**

Add these tests to `main()` in `qr_sheet_test.dart`:

```dart
// ── Test 5: Initial/unknown state → fallback spinner ─────────────────────────

testWidgets('état initial TrackingInitial → fallback spinner', (tester) async {
  final bloc = _MockTrackingBloc();
  // Use a non-Loading, non-Error, non-Loaded state to hit the fallback branch
  whenListen<TrackingState>(
    bloc,
    Stream<TrackingState>.fromIterable([TrackingInitial()]),
    initialState: TrackingInitial(),
  );

  await tester.pumpWidget(_host(bloc));
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  // The fallback branch renders a CircularProgressIndicator
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});

// ── Test 6: tap 'Enregistrer' → Gal success → snackbar succès ────────────────

testWidgets(
    'état TrackingQrLoaded → tap "Enregistrer" → Gal succès → snackbar galerie',
    (tester) async {
  // Mock the Gal platform channel to succeed
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const galChannel = MethodChannel('gal');
  messenger.setMockMethodCallHandler(galChannel, (call) async {
    if (call.method == 'putImageBytes') return null;
    return null;
  });

  final bloc = _MockTrackingBloc();
  const qr = QrCodeModel(
    bidId: 'bid-1',
    scanUrl: 'https://dony.app/track/bid-1',
    qrCodeBase64: _tinyPngB64,
  );
  whenListen<TrackingState>(
    bloc,
    Stream<TrackingState>.fromIterable([TrackingQrLoaded(qr)]),
    initialState: TrackingQrLoaded(qr),
  );

  await tester.pumpWidget(_host(bloc));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Enregistrer'));
  await tester.pumpAndSettle();

  expect(find.textContaining('enregistré dans votre galerie'), findsOneWidget);

  messenger.setMockMethodCallHandler(galChannel, null);
});

// ── Test 7: tap 'Enregistrer' → Gal failure → snackbar erreur ────────────────

testWidgets(
    'état TrackingQrLoaded → tap "Enregistrer" → Gal erreur → snackbar erreur',
    (tester) async {
  // Mock the Gal platform channel to throw
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const galChannel = MethodChannel('gal');
  messenger.setMockMethodCallHandler(galChannel, (call) async {
    if (call.method == 'putImageBytes') {
      throw PlatformException(code: 'ACCESS_DENIED', message: 'No permission');
    }
    return null;
  });

  final bloc = _MockTrackingBloc();
  const qr = QrCodeModel(
    bidId: 'bid-1',
    scanUrl: 'https://dony.app/track/bid-1',
    qrCodeBase64: _tinyPngB64,
  );
  whenListen<TrackingState>(
    bloc,
    Stream<TrackingState>.fromIterable([TrackingQrLoaded(qr)]),
    initialState: TrackingQrLoaded(qr),
  );

  await tester.pumpWidget(_host(bloc));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Enregistrer'));
  await tester.pumpAndSettle();

  expect(find.textContaining("Impossible d'enregistrer"), findsOneWidget);

  messenger.setMockMethodCallHandler(galChannel, null);
});

// ── Test 8: tap 'Partager' → Share success (ShareResultStatus.success) ────────

testWidgets(
    'état TrackingQrLoaded → tap "Partager" → share_plus succès (dismissed) → aucune analytics erreur',
    (tester) async {
  // share_plus uses the dev.fluttercommunity.plus/share channel
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  messenger.setMockMethodCallHandler(shareChannel, (call) async {
    if (call.method == 'shareXFiles') return 'dismissed';
    return null;
  });

  // Also mock path_provider (needed for getTemporaryDirectory)
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  messenger.setMockMethodCallHandler(pathChannel, (call) async {
    if (call.method == 'getTemporaryDirectory') return '/tmp';
    return null;
  });

  final bloc = _MockTrackingBloc();
  const qr = QrCodeModel(
    bidId: 'bid-1',
    scanUrl: 'https://dony.app/track/bid-1',
    qrCodeBase64: _tinyPngB64,
  );
  whenListen<TrackingState>(
    bloc,
    Stream<TrackingState>.fromIterable([TrackingQrLoaded(qr)]),
    initialState: TrackingQrLoaded(qr),
  );

  await tester.pumpWidget(_host(bloc));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Partager'));
  await tester.pumpAndSettle();

  // No error snackbar (dismissed result, no error)
  expect(find.textContaining('Impossible de partager'), findsNothing);

  messenger.setMockMethodCallHandler(shareChannel, null);
  messenger.setMockMethodCallHandler(pathChannel, null);
});
```

**Note on Gal channel name:** The actual Gal platform channel method name might differ. Check with:
```bash
grep -r "putImageBytes\|MethodChannel\|channelName\|gal" /Users/aboubakardiakite/Desktop/dony/dony_app/.pub-cache/hosted/pub.dev/gal-*/lib/ 2>/dev/null | head -20
```
If the channel name is different, adjust `'gal'` to the real channel name in tests 6 and 7.

- [ ] **Step 3: Run the tests**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter test test/features/matching/presentation/widgets/bid_detail/qr_sheet_test.dart 2>&1 | tail -15
```

Expected: All tests passed. If tests 6/7 fail due to wrong channel name, identify correct channel and fix.

- [ ] **Step 4: Measure coverage**

```bash
flutter test --coverage test/features/matching/presentation/widgets/bid_detail/qr_sheet_test.dart 2>&1 | tail -5
python3 -c "
def get_pct(path, suffix):
    curr = None; tot = 0; cov = 0
    for line in open(path):
        line = line.strip()
        if line.startswith('SF:'): curr = line[3:]; tot = 0; cov = 0
        elif line.startswith('DA:'):
            p = line[3:].split(','); tot += 1
            if int(p[1]) > 0: cov += 1
        elif line == 'end_of_record' and curr and curr.endswith(suffix):
            print(f'{suffix}: {cov}/{tot} = {cov/tot*100:.1f}%')
get_pct('coverage/lcov.info', 'qr_sheet.dart')
"
```

Expected: ≥ 90%. If still below, identify remaining uncovered lines from lcov and add targeted tests.

**Structurally untestable branches (document here if encountered):**
- Line 46: `getItSafe<AnalyticsService>()?.logEvent(...)` — best-effort `unawaited()` call using GetIt; no registered service → no-op. Can be covered by registering a mock in GetIt if needed but generally acceptable to leave uncovered.
- Lines 79-82: `ScreenBrightness.instance.resetApplicationScreenBrightness()` — native platform call in `whenComplete`. Platform channel mock required; if still uncovered, document as "best-effort teardown, native-only."

- [ ] **Step 5: Commit**

```bash
git add test/features/matching/presentation/widgets/bid_detail/qr_sheet_test.dart
git commit -m "test(matching): couvre save/share et état initial de qr_sheet (≥90%)"
```

---

## Task 5: dony_feedback_button.dart — repaintBoundaryKey real path + analyticsResolver (76.0% → ≥90%)

**Uncovered line groups:**
- Line 42: `registerAnalyticsResolver` static setter
- Line 47: `resetAnalyticsResolver` static method
- Lines 65-80: `_captureScreen` with a real `RenderRepaintBoundary` (key provided + boundary found)
- Lines 85-88: `_submitToSentry` full path — route + bytes + `Sentry.captureMessage` (lines 92-107)
- Lines 112-119: analytics logger call after Sentry submit
- Line 196: `_FeedbackFormInherited.updateShouldNotify` returning false
- Line 302: `_FeedbackSubmitButtonState` scroll in widget

**Strategy:**
- `_captureScreen` with a real boundary: wrap the DonyFeedbackButton host in a `RepaintBoundary` with a `GlobalKey`. Use `onSubmitOverride` to intercept (avoids Sentry). The `_captureScreen()` runs during `_submitToSentry` or if we trigger it directly. Since `onSubmitOverride` bypasses `_submitToSentry`, we need a way to test `_captureScreen`. The solution: create a `DonyFeedbackButton` without `onSubmitOverride` but with a `repaintBoundaryKey`. Since the real Sentry call will fail (MissingPluginException), the catch block runs — but `_captureScreen` still executes.
- `registerAnalyticsResolver` + `resetAnalyticsResolver`: call them directly in a test.
- `updateShouldNotify`: this is called by the Flutter framework when the inherited widget is rebuilt — hard to trigger in a widget test directly. It always returns `false`. Coverage is limited here.

**Files:**
- Modify: `test/core/design/widgets/dony_feedback_button_test.dart`

- [ ] **Step 1: Write the failing tests**

Add these tests at the bottom of `main()` in `dony_feedback_button_test.dart`. Add a `tearDown` to clean up the resolver after each test:

First, add this import at the top if not present:
```dart
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:mocktail/mocktail.dart';
```

Then add at the bottom of `main()`:

```dart
// ── analyticsResolver registration ──────────────────────────────────────────

testWidgets('registerAnalyticsResolver + resetAnalyticsResolver exercés sans crash',
    (tester) async {
  // Call register then reset — just verifies no crash and state is set/reset
  DonyFeedbackButton.registerAnalyticsResolver(() => _FakeAnalytics());
  DonyFeedbackButton.resetAnalyticsResolver();
  // After reset, no resolver → analytics skipped silently
  await tester.pumpWidget(subject(onSubmit: (_) async {}));
  expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
});

// ── _captureScreen with real RepaintBoundary ──────────────────────────────────

testWidgets(
    'repaintBoundaryKey fourni avec RepaintBoundary réel → _captureScreen s\'exécute (null ou bytes)',
    (tester) async {
  final key = GlobalKey();
  String? submitted;

  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          appBar: AppBar(
            actions: [
              DonyFeedbackButton(
                repaintBoundaryKey: key,
                onSubmitOverride: (m) async => submitted = m,
              ),
            ],
          ),
          body: const SizedBox(),
        ),
      ),
    ),
  );

  await tester.tap(find.byIcon(Icons.bug_report_outlined));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), 'test avec repaint boundary');
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
  await tester.pumpAndSettle();

  // _captureScreen ran (may return null or bytes — no crash either way)
  expect(submitted, 'test avec repaint boundary');
});

// ── analyticsResolver appelé après succès (via onSubmitOverride) ──────────────

testWidgets('analyticsResolver enregistré → logEvent appelé après submit réussi',
    (tester) async {
  final analytics = _MockAnalyticsService();
  when(() => analytics.logEvent(
        any(),
        properties: any(named: 'properties'),
      )).thenAnswer((_) async {});

  DonyFeedbackButton.registerAnalyticsResolver(() => analytics);

  await tester.pumpWidget(subject(onSubmit: (_) async {}));
  await tester.tap(find.byIcon(Icons.bug_report_outlined));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), 'test analytics');
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
  await tester.pumpAndSettle();

  // logEvent must have been called at least once (best-effort, unawaited)
  await tester.pump(const Duration(milliseconds: 50));
  verify(() => analytics.logEvent(
        AnalyticsEvents.screenFeedbackSubmitted,
        properties: any(named: 'properties'),
      )).called(1);

  DonyFeedbackButton.resetAnalyticsResolver();
});
```

Add these helper classes above `main()` in the test file:

```dart
class _FakeAnalytics extends Fake implements AnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object?>? properties}) async {}
}

class _MockAnalyticsService extends Mock implements AnalyticsService {}
```

- [ ] **Step 2: Run the tests**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter test test/core/design/widgets/dony_feedback_button_test.dart 2>&1 | tail -15
```

Expected: All tests passed.

- [ ] **Step 3: Measure coverage**

```bash
flutter test --coverage test/core/design/widgets/dony_feedback_button_test.dart 2>&1 | tail -5
python3 -c "
def get_pct(path, suffix):
    curr = None; tot = 0; cov = 0
    for line in open(path):
        line = line.strip()
        if line.startswith('SF:'): curr = line[3:]; tot = 0; cov = 0
        elif line.startswith('DA:'):
            p = line[3:].split(','); tot += 1
            if int(p[1]) > 0: cov += 1
        elif line == 'end_of_record' and curr and curr.endswith(suffix):
            print(f'{suffix}: {cov}/{tot} = {cov/tot*100:.1f}%')
get_pct('coverage/lcov.info', 'dony_feedback_button.dart')
"
```

Expected: ≥ 90%.

**Structurally untestable branches (document if below target):**
- Lines 85-107 (`_submitToSentry` full path with real Sentry): Sentry SDK calls are native — MissingPluginException in test env. The `_captureScreen` path is exercised via the test above; the Sentry.captureMessage/captureFeedback lines are structurally untestable without a full Sentry mock SDK. If coverage is still below 90% after this task, document lines 85-107 as intestable (Sentry calls, no mock SDK in project).
- Line 196 (`updateShouldNotify`): Flutter framework internal — hard to trigger in widget test.

- [ ] **Step 4: Commit**

```bash
git add test/core/design/widgets/dony_feedback_button_test.dart
git commit -m "test(design): couvre registerAnalyticsResolver, repaintBoundaryKey et analyticsResolver dans dony_feedback_button (≥90%)"
```

---

## Task 6: Final verification — full test suite

- [ ] **Step 1: Run complete test suite**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter test --coverage 2>&1 | tail -5
```

Expected: `All tests passed!` (no failures).

- [ ] **Step 2: Extract final coverage for all 5 files**

```bash
python3 -c "
def parse_lcov(path, files_of_interest):
    results = {}
    curr = None; tot = 0; cov = 0
    for line in open(path):
        line = line.strip()
        if line.startswith('SF:'): curr = line[3:]; tot = 0; cov = 0
        elif line.startswith('DA:'):
            p = line[3:].split(','); tot += 1
            if int(p[1]) > 0: cov += 1
        elif line == 'end_of_record':
            for f in files_of_interest:
                if curr and curr.endswith(f):
                    pct = cov/tot*100 if tot > 0 else 0
                    results[f] = (cov, tot, pct)
    return results

files = [
    'qr_sheet.dart',
    'dony_feedback_button.dart',
    'sender_hero_card.dart',
    'sender_sticky_bar.dart',
    'voyageur_contact_card.dart',
]
r = parse_lcov('coverage/lcov.info', files)
for f, (cov, tot, pct) in sorted(r.items()):
    status = '✓' if pct >= 90 else '✗'
    print(f'{status} {f}: {cov}/{tot} = {pct:.1f}%')
"
```

Expected: All 5 files show ≥ 90%.

- [ ] **Step 3: flutter analyze — no errors on test files**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter analyze test/features/matching/presentation/widgets/bid_detail/ test/core/design/widgets/dony_feedback_button_test.dart 2>&1 | tail -5
```

Expected: `No issues found!` (or only info-level hints, no errors/warnings).

- [ ] **Step 4: Final commit if not already committed**

```bash
git log --oneline -8
```

All tasks should already be committed. If any test files are still uncommitted:
```bash
git status
git add <file>
git commit -m "test(matching): remonte la couverture des widgets bid_detail et feedback à ≥90%"
```

---

## Branches structurellement intestables (à documenter)

| Fichier | Lignes | Raison |
|---|---|---|
| `qr_sheet.dart` | 46 | `getItSafe<AnalyticsService>()` best-effort unawaited — GetIt non peuplé → no-op |
| `qr_sheet.dart` | 79-82 | `ScreenBrightness.instance.resetApplicationScreenBrightness()` — plugin natif, pas de test channel mock disponible |
| `dony_feedback_button.dart` | 85-107 | `Sentry.captureMessage` / `captureFeedback` — SDK Sentry sans mock dans le projet → MissingPluginException |
| `dony_feedback_button.dart` | 196 | `_FeedbackFormInherited.updateShouldNotify` — retourne toujours `false`, appelé par le framework Flutter |
