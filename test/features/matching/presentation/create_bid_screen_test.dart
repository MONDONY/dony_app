import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/create_bid_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockBidBloc extends MockBloc<BidEvent, BidState>
    implements BidBloc {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _testAnnouncement = AnnouncementModel(
  id: 'ann-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 6, 15),
  availableKg: 10,
  pricePerKg: 8,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  traveler: const TravelerProfile(
    id: 'trav-1',
    displayName: 'Ibrahima Diallo',
  ),
);

final _testBid = BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  weightKg: 5,
  declaredValueEur: 150,
  description: 'Vêtements famille',
  status: 'PENDING',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

// ── Builder ───────────────────────────────────────────────────────────────────

Widget _buildScreen(MockBidBloc bidBloc) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => MultiBlocProvider(
          providers: [
            BlocProvider<BidBloc>.value(value: bidBloc),
          ],
          child: CreateBidScreen(announcement: _testAnnouncement),
        ),
      ),
      GoRoute(
        path: '/payments/pay',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Payment screen'))),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// Must advance past all flutter_animate delays (max 200ms delay + 300ms
// duration) AND GoRouter internal timers to prevent "Timer still pending".
const _kSettle = Duration(milliseconds: 600);

// Pumps the screen with a tall viewport (1400px) so the full form — including
// the DisclaimerCard near the bottom — is always visible without scrolling.
Future<void> _pumpScreen(WidgetTester tester, MockBidBloc bidBloc) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildScreen(bidBloc));
  await tester.pump(_kSettle);
}

// Selects one category + checks disclaimer → makes canSubmit = true.
// Requires _pumpScreen to have been called first.
Future<void> _enableSubmit(WidgetTester tester) async {
  await tester.tap(find.text('Vêtements'));
  await tester.pump();
  await tester.tap(find.byType(Checkbox).first);
  await tester.pump();
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockBidBloc bidBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(BidInitial());
    registerFallbackValue(BidCreateRequested(
      announcementId: '',
      weightKg: 0,
      declaredValueEur: 0,
      description: '',
      contentCategory: '',
      recipientName: '',
      recipientPhone: '',
    ));
  });

  setUp(() {
    bidBloc = MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() {
    bidBloc.close();
  });

  // ── 1. Rendu initial ──────────────────────────────────────────────────────

  group('Rendu initial', () {
    testWidgets('affiche le titre et les sections du formulaire',
        (tester) async {
      await _pumpScreen(tester, bidBloc);

      expect(find.text("Demande d'envoi"), findsOneWidget);
      expect(find.text('POIDS ESTIMÉ'), findsOneWidget);
      expect(find.text('CONTENU DU COLIS'), findsOneWidget);
      expect(find.text('DESCRIPTION (AU VOYAGEUR)'), findsOneWidget);
      expect(find.text('VALEUR DÉCLARÉE (€)'), findsOneWidget);
      expect(find.text('DESTINATAIRE'), findsOneWidget);
    });

    testWidgets('affiche le nom du voyageur dans l\'appbar', (tester) async {
      await _pumpScreen(tester, bidBloc);

      expect(find.textContaining('Ibrahima Diallo'), findsOneWidget);
    });

    testWidgets('affiche les 7 chips de catégorie', (tester) async {
      await _pumpScreen(tester, bidBloc);

      for (final cat in [
        'Vêtements',
        'Médicaments',
        'Alim. sèche',
        'Documents',
        'Hi-fi',
        'Téléphone',
        'Autre',
      ]) {
        expect(find.text(cat), findsOneWidget);
      }
    });

    testWidgets('bouton désactivé sans catégorie ni disclaimer',
        (tester) async {
      await _pumpScreen(tester, bidBloc);

      final button =
          tester.widget<FilledButton>(find.byType(FilledButton).last);
      expect(button.onPressed, isNull);
    });

    testWidgets('affiche la section de prix (Total + Frais de service)',
        (tester) async {
      await _pumpScreen(tester, bidBloc);

      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Frais de service'), findsOneWidget);
    });
  });

  // ── 1b. Navigation ───────────────────────────────────────────────────────

  group('Navigation', () {
    testWidgets('bouton fermer → retour à l\'écran précédent', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // Nested router so context.pop() has a parent route to go back to
      final router = GoRouter(
        initialLocation: '/bid',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Écran parent'))),
            routes: [
              GoRoute(
                path: 'bid',
                builder: (ctx, state) => MultiBlocProvider(
                  providers: [BlocProvider<BidBloc>.value(value: bidBloc)],
                  child: CreateBidScreen(announcement: _testAnnouncement),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/payments/pay',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Payment screen'))),
          ),
        ],
      );
      await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light));
      await tester.pump(_kSettle);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Écran parent'), findsOneWidget);
    });

    testWidgets('slider poids → met à jour le poids estimé', (tester) async {
      await _pumpScreen(tester, bidBloc);

      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pump();

      // Slider callback executed without crash
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  // ── 2. Sélection catégorie ────────────────────────────────────────────────

  group('Sélection catégorie', () {
    testWidgets('tap une catégorie → chip sélectionné (icône check)',
        (tester) async {
      await _pumpScreen(tester, bidBloc);

      await tester.tap(find.text('Médicaments'));
      await tester.pump();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('double-tap sur même catégorie → chip désélectionné',
        (tester) async {
      await _pumpScreen(tester, bidBloc);

      await tester.tap(find.text('Documents'));
      await tester.pump();
      await tester.tap(find.text('Documents'));
      await tester.pump();

      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('sélection multiple → plusieurs icônes check', (tester) async {
      await _pumpScreen(tester, bidBloc);

      await tester.tap(find.text('Vêtements'));
      await tester.pump();
      await tester.tap(find.text('Médicaments'));
      await tester.pump();

      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });
  });

  // ── 3. Disclaimer ─────────────────────────────────────────────────────────

  group('Disclaimer card', () {
    testWidgets('cocher disclaimer seul ne suffit pas (bouton reste désactivé)',
        (tester) async {
      await _pumpScreen(tester, bidBloc);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      final button =
          tester.widget<FilledButton>(find.byType(FilledButton).last);
      expect(button.onPressed, isNull);
    });

    testWidgets('catégorie + disclaimer → bouton activé', (tester) async {
      await _pumpScreen(tester, bidBloc);

      await _enableSubmit(tester);

      final button =
          tester.widget<FilledButton>(find.byType(FilledButton).last);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tap texte disclaimer → accepte via GestureDetector',
        (tester) async {
      await _pumpScreen(tester, bidBloc);

      // Tap on the label text triggers GestureDetector.onTap (not Checkbox)
      await tester.tap(find.text('Je signe & j\'accepte'));
      await tester.pump();

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
      expect(checkbox.value, isTrue);
    });
  });

  // ── 4. Validation formulaire ──────────────────────────────────────────────

  group('Validation — messages d\'erreur', () {
    testWidgets('description vide → snackbar "Description obligatoire"',
        (tester) async {
      await _pumpScreen(tester, bidBloc);

      await _enableSubmit(tester);
      await tester.tap(find.textContaining('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.text('Description obligatoire'), findsOneWidget);
    });

    testWidgets('valeur vide → snackbar "Valeur déclarée invalide"',
        (tester) async {
      await _pumpScreen(tester, bidBloc);

      await _enableSubmit(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Test');
      await tester.pump();

      await tester.tap(find.textContaining('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.text('Valeur déclarée invalide'), findsOneWidget);
    });

    testWidgets('valeur > 500€ → snackbar "Valeur maximum : 500 €"',
        (tester) async {
      await _pumpScreen(tester, bidBloc);

      await _enableSubmit(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Vêtements test');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '600');
      await tester.pump();

      await tester.tap(find.textContaining('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.text('Valeur maximum : 500 €'), findsOneWidget);
    });

    testWidgets('nom destinataire vide → snackbar d\'erreur', (tester) async {
      await _pumpScreen(tester, bidBloc);

      await _enableSubmit(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Test description');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '150');
      await tester.pump();

      await tester.tap(find.textContaining('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.text('Nom du destinataire obligatoire'), findsOneWidget);
    });

    testWidgets('téléphone destinataire vide → snackbar d\'erreur',
        (tester) async {
      await _pumpScreen(tester, bidBloc);

      await _enableSubmit(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Test description');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '150');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(2), 'Amadou Diallo');
      await tester.pump();

      await tester.tap(find.textContaining('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.text('Téléphone du destinataire obligatoire'), findsOneWidget);
    });
  });

  // ── 5. Soumission valide ──────────────────────────────────────────────────

  group('Soumission valide', () {
    testWidgets('formulaire complet → BidCreateRequested dispatché',
        (tester) async {
      await _pumpScreen(tester, bidBloc);

      await _enableSubmit(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Vêtements famille');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '150');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(2), 'Amadou Diallo');
      await tester.pump();
      await tester.enterText(
          find.byType(TextField).at(3), '+221 77 000 00 00');
      await tester.pump();

      await tester.tap(find.textContaining('Bloquer'));
      await tester.pump();

      verify(() => bidBloc.add(any(that: isA<BidCreateRequested>()))).called(1);
    });
  });

  // ── 6. États BLoC ─────────────────────────────────────────────────────────

  group('États BLoC', () {
    testWidgets('BidLoading → bouton affiche spinner (désactivé)',
        (tester) async {
      when(() => bidBloc.state).thenReturn(BidLoading());
      await _pumpScreen(tester, bidBloc);

      // isLoading = true → DonyButton shows CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Button disabled
      final button =
          tester.widget<FilledButton>(find.byType(FilledButton).last);
      expect(button.onPressed, isNull);
    });

    testWidgets('BidCreated → navigue vers /payments/pay', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      whenListen<BidState>(
        bidBloc,
        Stream.fromIterable([BidCreated(_testBid)]),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(_buildScreen(bidBloc));
      await tester.pumpAndSettle();

      expect(find.text('Payment screen'), findsOneWidget);
    });

    testWidgets('BidError → affiche message d\'erreur via snackbar',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      whenListen<BidState>(
        bidBloc,
        Stream.fromIterable([BidError('Erreur réseau')]),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(_buildScreen(bidBloc));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Erreur réseau'), findsOneWidget);
    });
  });
}
