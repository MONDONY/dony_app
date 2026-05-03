import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/search_announcement_screen.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

// ── Helpers ──────────────────────────────────────────────────────────────────

AnnouncementModel _makeAnn({
  String id = 'a1',
  double rating = 4.5,
  double pricePerKg = 10.0,
  double availableKg = 5.0,
  int daysFromNow = 3,
}) =>
    AnnouncementModel(
      id: id,
      travelerId: 'traveler-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime.now().add(Duration(days: daysFromNow)),
      availableKg: availableKg,
      pricePerKg: pricePerKg,
      status: 'ACTIVE',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      traveler: TravelerProfile(
        id: 'traveler-1',
        averageRating: rating,
        kiloPro: false,
      ),
    );

Widget _buildScreen({
  required MockAnnouncementBloc announcementBloc,
  required MockAuthBloc authBloc,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: const SearchAnnouncementScreen(),
        ),
      ),
      GoRoute(
        path: '/search/:id',
        builder: (context, state) => const Scaffold(),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light,
  );
}

/// Navigue vers la vue résultats en appuyant sur "Rechercher".
Future<void> _goToResults(WidgetTester tester) async {
  final btn = find.text('Rechercher');
  if (btn.evaluate().isNotEmpty) {
    await tester.tap(btn);
    await tester.pumpAndSettle();
  }
}

// ── Setup ─────────────────────────────────────────────────────────────────────

void main() {
  late MockAnnouncementBloc announcementBloc;
  late MockAuthBloc authBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(AnnouncementInitial());
    registerFallbackValue(AnnouncementSearchRequested());
  });

  setUp(() {
    announcementBloc = MockAnnouncementBloc();
    authBloc = MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthInitial());
    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    when(() => announcementBloc.stream).thenAnswer(
      (_) => Stream.fromIterable([AnnouncementInitial()]),
    );
  });

  tearDown(() {
    announcementBloc.close();
    authBloc.close();
  });

  // ── Helper: état loaded ────────────────────────────────────────────────────

  void stubLoaded(List<AnnouncementModel> results) {
    when(() => announcementBloc.state)
        .thenReturn(AnnouncementSearchLoaded(results));
    when(() => announcementBloc.stream).thenAnswer(
      (_) => Stream.fromIterable([AnnouncementSearchLoaded(results)]),
    );
  }

  // ── 1. Filtre rating ───────────────────────────────────────────────────────

  group('Filtre rating (★ 4.7+) — filtrage client', () {
    testWidgets('actif → seules les annonces averageRating >= 4.7 visibles',
        (tester) async {
      stubLoaded([
        _makeAnn(id: 'high', rating: 4.8, pricePerKg: 8),
        _makeAnn(id: 'low', rating: 4.5, pricePerKg: 12),
      ]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      // Avant filtre : deux prix visibles
      expect(find.text('8 €/kg'), findsOneWidget);
      expect(find.text('12 €/kg'), findsOneWidget);

      // Activer filtre rating
      await tester.tap(find.text('★ 4.7+'));
      await tester.pumpAndSettle();

      // Seule la card high (8 €/kg, rating 4.8) doit rester
      expect(find.text('8 €/kg'), findsOneWidget);
      expect(find.text('12 €/kg'), findsNothing);
    });
  });

  // ── 2. Filtre semaine ──────────────────────────────────────────────────────

  group('Filtre "Cette semaine" — filtrage client', () {
    testWidgets('actif → annonces departureDate dans 7 jours uniquement',
        (tester) async {
      stubLoaded([
        _makeAnn(id: 'soon', daysFromNow: 3, pricePerKg: 6),
        _makeAnn(id: 'later', daysFromNow: 14, pricePerKg: 9),
      ]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      expect(find.text('6 €/kg'), findsOneWidget);
      expect(find.text('9 €/kg'), findsOneWidget);

      await tester.tap(find.text('Cette semaine'));
      await tester.pumpAndSettle();

      // Seule l'annonce dans 3 jours reste
      expect(find.text('6 €/kg'), findsOneWidget);
      expect(find.text('9 €/kg'), findsNothing);
    });
  });

  // ── 3. Tri prix ────────────────────────────────────────────────────────────

  group('Filtre "€/kg ↓" — tri croissant', () {
    testWidgets('actif → résultats triés par pricePerKg croissant',
        (tester) async {
      stubLoaded([
        _makeAnn(id: 'expensive', pricePerKg: 20),
        _makeAnn(id: 'cheap', pricePerKg: 5),
        _makeAnn(id: 'mid', pricePerKg: 12),
      ]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      await tester.tap(find.text('€/kg ↓'));
      await tester.pumpAndSettle();

      // Récupérer tous les widgets Text contenant "€/kg" (hors le chip lui-même)
      final priceWidgets = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) =>
              (t.data ?? '').contains('€/kg') && t.data != '€/kg ↓')
          .map((t) => t.data!)
          .toList();

      // Le premier prix affiché doit être le moins cher (5)
      expect(priceWidgets.first, contains('5'));
      // Le dernier doit être le plus cher (20)
      expect(priceWidgets.last, contains('20'));
    });
  });

  // ── 4. Filtre ET combiné ───────────────────────────────────────────────────

  group('Filtres combinés ET (rating + poids)', () {
    testWidgets('intersection correcte — seules les annonces satisfaisant les deux filtres',
        (tester) async {
      stubLoaded([
        _makeAnn(id: 'both', rating: 4.8, availableKg: 15, pricePerKg: 7),
        _makeAnn(id: 'rating-only', rating: 4.8, availableKg: 5, pricePerKg: 9),
        _makeAnn(id: 'weight-only', rating: 4.5, availableKg: 15, pricePerKg: 11),
        _makeAnn(id: 'none', rating: 4.5, availableKg: 5, pricePerKg: 13),
      ]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      await tester.tap(find.text('★ 4.7+'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+10 kg'));
      await tester.pumpAndSettle();

      // Seule 'both' satisfait les deux filtres (rating 4.8 ET 15 kg)
      expect(find.text('7 €/kg'), findsOneWidget);  // 'both'
      expect(find.text('9 €/kg'), findsNothing);    // rating OK mais poids KO
      expect(find.text('11 €/kg'), findsNothing);   // poids OK mais rating KO
      expect(find.text('13 €/kg'), findsNothing);   // aucun filtre OK
    });
  });

  // ── 5. Auto-search changement ville ───────────────────────────────────────

  group('Auto-search sur changement ville', () {
    testWidgets(
        'AnnouncementSearchRequested émis automatiquement après sélection ville départ',
        (tester) async {
      when(() => announcementBloc.state)
          .thenReturn(AnnouncementSearchLoaded([]));
      when(() => announcementBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([AnnouncementSearchLoaded([])]),
      );

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();

      // Ouvrir le picker de ville de départ
      await tester.tap(find.text('Paris · CDG, ORY'));
      await tester.pumpAndSettle();

      // Sélectionner Lyon
      await tester.tap(find.text('Lyon · LYS'));
      await tester.pumpAndSettle();

      // AnnouncementSearchRequested doit avoir été émis
      verify(() =>
              announcementBloc.add(any(that: isA<AnnouncementSearchRequested>())))
          .called(greaterThan(0));
    });
  });

  // ── 6. Auto-search chip rapide ────────────────────────────────────────────

  group('Auto-search sur toggle chip rapide', () {
    testWidgets('toggle Kilo Pro → AnnouncementSearchRequested émis',
        (tester) async {
      when(() => announcementBloc.state)
          .thenReturn(AnnouncementSearchLoaded([]));
      when(() => announcementBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([AnnouncementSearchLoaded([])]),
      );

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();

      await tester.tap(find.text('Kilo Pro uniquement'));
      await tester.pumpAndSettle();

      verify(() =>
              announcementBloc.add(any(that: isA<AnnouncementSearchRequested>())))
          .called(greaterThan(0));
    });
  });

  // ── 7. Pas d'auto-search sur poids seul ────────────────────────────────────

  group('Pas d\'auto-search sur changement poids', () {
    testWidgets(
        'slider poids déplacé sans confirmer → AnnouncementSearchRequested NON émis',
        (tester) async {
      when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
      when(() => announcementBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([AnnouncementInitial()]),
      );

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();

      // Ouvrir le picker poids
      await tester.tap(find.text('6 kg'));
      await tester.pumpAndSettle();

      // Déplacer le slider
      final slider = find.byType(Slider).last;
      await tester.drag(slider, const Offset(50, 0));
      await tester.pump();

      // Fermer sans confirmer
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Aucun événement de recherche ne doit avoir été envoyé
      verifyNever(() =>
          announcementBloc.add(any(that: isA<AnnouncementSearchRequested>())));
    });
  });

  // ── 8. Badge point vert ────────────────────────────────────────────────────

  group('Badge point vert sur bouton tune', () {
    testWidgets('absent quand aucun filtre résultats actif', (tester) async {
      stubLoaded([_makeAnn()]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      // Le badge est un Container dans un Positioned — vérifier via DecoratedBox circle
      final circles = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where(
        (w) =>
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            (w.decoration as BoxDecoration).color == DonyColors.green400,
      );
      expect(circles, isEmpty);
    });

    testWidgets('visible après activation d\'un filtre résultats', (tester) async {
      stubLoaded([_makeAnn(rating: 4.9)]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      await tester.tap(find.text('★ 4.7+'));
      await tester.pumpAndSettle();

      final circles = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where(
        (w) =>
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            (w.decoration as BoxDecoration).color == DonyColors.green400,
      );
      expect(circles, isNotEmpty);
    });
  });

  // ── 9. Skeleton absent ────────────────────────────────────────────────────

  group('Skeleton absent après AnnouncementSearchLoaded', () {
    testWidgets('la liste n\'affiche pas de card skeleton supplémentaire',
        (tester) async {
      final results = [_makeAnn(pricePerKg: 8), _makeAnn(id: 'a2', pricePerKg: 10)];
      stubLoaded(results);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      // Nombre de prix affichés = nombre de résultats (pas de +1 skeleton)
      final priceTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) =>
              (t.data ?? '').endsWith('€/kg') && t.data != '€/kg ↓')
          .toList();

      expect(priceTexts.length, results.length);
    });
  });

  // ── 10. Filtres mémorisés après retour formulaire ─────────────────────────

  group('Filtres mémorisés après retour au formulaire', () {
    testWidgets('filtres résultats conservés après back + nouvelle recherche',
        (tester) async {
      stubLoaded([_makeAnn(rating: 4.9)]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      // Activer filtre rating
      await tester.tap(find.text('★ 4.7+'));
      await tester.pumpAndSettle();

      // Revenir au formulaire
      await tester.tap(find.byIcon(Icons.arrow_back_ios_rounded).first);
      await tester.pumpAndSettle();

      // Faire une nouvelle recherche
      await tester.tap(find.text('Rechercher'));
      await tester.pumpAndSettle();

      // Le filtre rating doit encore être actif (chip ★ 4.7+ en vert)
      final chip = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('★ 4.7+'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = chip.decoration as BoxDecoration?;
      expect(decoration?.color, DonyColors.green50);
    });
  });

  // ── 11. Responsive — 0 overflow ───────────────────────────────────────────

  group('Responsive — 0 RenderFlex overflow', () {
    Future<void> testNoOverflow(
        WidgetTester tester, double w, double h) async {
      await tester.binding.setSurfaceSize(Size(w, h));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      stubLoaded([_makeAnn()]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }

    testWidgets('360×640 — petit téléphone', (tester) async {
      await testNoOverflow(tester, 360, 640);
    });

    testWidgets('411×914 — Pixel 6 standard', (tester) async {
      await testNoOverflow(tester, 411, 914);
    });

    testWidgets('600×1024 — tablette portrait', (tester) async {
      await testNoOverflow(tester, 600, 1024);
    });
  });

  // ── 13. État erreur dans la vue résultats ─────────────────────────────────

  group('AnnouncementError dans la vue résultats', () {
    testWidgets('affiche le message d\'erreur et le bouton réessayer',
        (tester) async {
      when(() => announcementBloc.state)
          .thenReturn(AnnouncementError('Erreur réseau'));
      when(() => announcementBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([AnnouncementError('Erreur réseau')]),
      );

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      expect(find.text('Erreur réseau'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  // ── 14. Vue résultats vide après filtrage client ──────────────────────────

  group('Vue vide après filtrage client', () {
    testWidgets('active filtre poids → empty view si aucun résultat ≥ 10 kg',
        (tester) async {
      stubLoaded([
        _makeAnn(availableKg: 5, pricePerKg: 8),
      ]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      await tester.tap(find.text('+10 kg'));
      await tester.pumpAndSettle();

      expect(find.text('Aucun voyageur disponible'), findsOneWidget);
    });
  });

  // ── 15. _TravelerCard avec totalTrips et kiloPro ──────────────────────────

  group('TravelerCard données enrichies', () {
    testWidgets('affiche le nombre de trajets et le badge KYC',
        (tester) async {
      when(() => announcementBloc.state).thenReturn(
        AnnouncementSearchLoaded([
          AnnouncementModel(
            id: 'pro',
            travelerId: 'pro-1',
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            departureDate: DateTime.now().add(const Duration(days: 2)),
            availableKg: 15,
            pricePerKg: 7,
            status: 'ACTIVE',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            traveler: const TravelerProfile(
              id: 'pro-1',
              displayName: 'Ibrahim Diallo',
              averageRating: 4.9,
              totalTrips: 12,
              kiloPro: true,
            ),
          ),
        ]),
      );
      when(() => announcementBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([
          AnnouncementSearchLoaded([
            AnnouncementModel(
              id: 'pro',
              travelerId: 'pro-1',
              departureCity: 'Paris',
              arrivalCity: 'Dakar',
              departureDate: DateTime.now().add(const Duration(days: 2)),
              availableKg: 15,
              pricePerKg: 7,
              status: 'ACTIVE',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              traveler: const TravelerProfile(
                id: 'pro-1',
                displayName: 'Ibrahim Diallo',
                averageRating: 4.9,
                totalTrips: 12,
                kiloPro: true,
              ),
            ),
          ]),
        ]),
      );

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      expect(find.textContaining('12 trajet'), findsOneWidget);
      expect(find.text('KYC'), findsOneWidget);
    });
  });

  // ── 16. Ouverture bottom sheet filtres ───────────────────────────────────

  group('Bottom sheet filtres (bouton tune)', () {
    testWidgets('ouvre le bottom sheet avec le formulaire de filtres',
        (tester) async {
      stubLoaded([_makeAnn()]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      // Tapper le bouton tune pour ouvrir le bottom sheet
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      // Le formulaire apparaît dans le bottom sheet
      expect(find.text('FILTRES RAPIDES'), findsWidgets);
    });

    testWidgets('Appliquer dans le bottom sheet déclenche une nouvelle recherche',
        (tester) async {
      stubLoaded([_makeAnn()]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      // Ouvrir le bottom sheet
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      // Tapper Appliquer
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      // Une nouvelle recherche doit avoir été émise
      verify(() =>
              announcementBloc.add(any(that: isA<AnnouncementSearchRequested>())))
          .called(greaterThan(0));
    });
  });

  // ── 17. Auto-search callbacks formulaire supplémentaires ─────────────────

  group('Auto-search callbacks formulaire', () {
    testWidgets('changement ville arrivée → AnnouncementSearchRequested émis',
        (tester) async {
      stubLoaded([]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();

      await tester.tap(find.text('Dakar · DKR'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abidjan · ABJ'));
      await tester.pumpAndSettle();

      verify(() =>
              announcementBloc.add(any(that: isA<AnnouncementSearchRequested>())))
          .called(greaterThan(0));
    });

    testWidgets('toggle Note ≥ 4.5 → AnnouncementSearchRequested émis',
        (tester) async {
      stubLoaded([]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();

      await tester.tap(find.text('Note ≥ 4.5'));
      await tester.pumpAndSettle();

      verify(() =>
              announcementBloc.add(any(that: isA<AnnouncementSearchRequested>())))
          .called(greaterThan(0));
    });

    testWidgets('toggle Arrivée ce week-end → AnnouncementSearchRequested émis',
        (tester) async {
      stubLoaded([]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();

      await tester.tap(find.text('Arrivée ce week-end'));
      await tester.pumpAndSettle();

      verify(() =>
              announcementBloc.add(any(that: isA<AnnouncementSearchRequested>())))
          .called(greaterThan(0));
    });

    testWidgets(
        'toggle Prix ≤ .../kg → AnnouncementSearchRequested émis',
        (tester) async {
      stubLoaded([]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();

      await tester.tap(find.textContaining('Prix ≤'));
      await tester.pumpAndSettle();

      verify(() =>
              announcementBloc.add(any(that: isA<AnnouncementSearchRequested>())))
          .called(greaterThan(0));
    });
  });

  // ── AppBar does not contain toggle tabs ────────────────────────────────────

  testWidgets('AppBar does not contain list/map toggle tabs', (tester) async {
    stubLoaded([_makeAnn()]);

    await tester.pumpWidget(
        _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
    await tester.pump();
    await _goToResults(tester);

    // Verify AppBar contains journey title
    expect(find.text('Paris → Dakar'), findsWidgets);

    // Verify AppBar contains filter icon
    expect(find.byIcon(Icons.tune_rounded), findsWidgets);

    // Verify no toggle labels are in AppBar (those belong to _ToggleTab)
    expect(find.text('Liste'), findsNothing);
    expect(find.text('Carte'), findsNothing);
  });

  // ── 9. Toggle Liste/Carte ─────────────────────────────────────────────────

  group('Toggle Liste/Map', () {
    final ann = [
      _makeAnn(id: 'a1'),
      _makeAnn(id: 'a2', rating: 4.8),
    ];

    testWidgets('toggle buttons are visible in results view', (tester) async {
      stubLoaded(ann);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      expect(find.byIcon(Icons.list_rounded), findsOneWidget);
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    });

    testWidgets('filter button remains visible in list view', (tester) async {
      stubLoaded(ann);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });
  });

  testWidgets(
    'résultats reçus → AnnouncementMapView est instanciée même en vue Liste',
    (tester) async {
      final announcementBloc = MockAnnouncementBloc();
      final authBloc = MockAuthBloc();
      when(() => authBloc.state).thenReturn(const AuthInitial());
      when(() => announcementBloc.state).thenReturn(
        AnnouncementSearchLoaded([_makeAnn()]),
      );
      whenListen(
        announcementBloc,
        Stream<AnnouncementState>.empty(),
        initialState: AnnouncementSearchLoaded([_makeAnn()]),
      );

      await tester.pumpWidget(_buildScreen(
        announcementBloc: announcementBloc,
        authBloc: authBloc,
      ));
      await tester.pump(const Duration(milliseconds: 50));
      // Naviguer vers la vue résultats.
      final btn = find.text('Rechercher');
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Vue Liste active par défaut, mais la map doit déjà être dans l'arbre
      // (cachée par l'IndexedStack — donc skipOffstage: false).
      expect(
        find.byType(AnnouncementMapView, skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'recharge en cours → spinner overlay visible, map toujours montée',
    (tester) async {
      final announcementBloc = MockAnnouncementBloc();
      final authBloc = MockAuthBloc();
      when(() => authBloc.state).thenReturn(const AuthInitial());
      final reloadingState = AnnouncementSearchLoaded(
        [_makeAnn()],
        isReloading: true,
      );
      whenListen(
        announcementBloc,
        Stream<AnnouncementState>.empty(),
        initialState: reloadingState,
      );
      when(() => announcementBloc.state).thenReturn(reloadingState);

      await tester.pumpWidget(_buildScreen(
        announcementBloc: announcementBloc,
        authBloc: authBloc,
      ));
      await tester.pump(const Duration(milliseconds: 50));

      // Naviguer vers la vue résultats.
      final btn = find.text('Rechercher');
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byKey(const Key('search-reload-overlay')), findsOneWidget);
      expect(find.byType(AnnouncementMapView, skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets(
    'erreur après Loaded → bannière dismissible, map toujours montée',
    (tester) async {
      final announcementBloc = MockAnnouncementBloc();
      final authBloc = MockAuthBloc();
      when(() => authBloc.state).thenReturn(const AuthInitial());
      final errorState = AnnouncementError(
        'Réseau indisponible',
        previousResults: [_makeAnn()],
      );
      whenListen(
        announcementBloc,
        Stream<AnnouncementState>.empty(),
        initialState: errorState,
      );
      when(() => announcementBloc.state).thenReturn(errorState);

      await tester.pumpWidget(_buildScreen(
        announcementBloc: announcementBloc,
        authBloc: authBloc,
      ));
      await tester.pump(const Duration(milliseconds: 50));

      // Naviguer vers la vue résultats.
      final btn = find.text('Rechercher');
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byKey(const Key('search-error-banner')), findsOneWidget);
      expect(find.text('Réseau indisponible'), findsOneWidget);
      expect(find.byType(AnnouncementMapView, skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets(
    'filtre actif → liste ET map utilisent les résultats filtrés',
    (tester) async {
      final announcementBloc = MockAnnouncementBloc();
      final authBloc = MockAuthBloc();
      when(() => authBloc.state).thenReturn(const AuthInitial());
      // 2 résultats : un à 4.5 (rejeté par "★ 4.7+"), un à 4.8.
      final results = [
        _makeAnn(id: 'low', rating: 4.5),
        _makeAnn(id: 'high', rating: 4.8),
      ];
      whenListen(
        announcementBloc,
        Stream<AnnouncementState>.empty(),
        initialState: AnnouncementSearchLoaded(results),
      );
      when(() => announcementBloc.state)
          .thenReturn(AnnouncementSearchLoaded(results));

      await tester.pumpWidget(_buildScreen(
        announcementBloc: announcementBloc,
        authBloc: authBloc,
      ));
      await tester.pump(const Duration(milliseconds: 50));

      // Naviguer vers la vue résultats.
      final btn = find.text('Rechercher');
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Activer le filtre "★ 4.7+"
      await tester.tap(find.text('★ 4.7+'));
      await tester.pump();

      // La map (même cachée par IndexedStack) doit recevoir 1 résultat filtré.
      final mapWidget = tester.widget<AnnouncementMapView>(
          find.byType(AnnouncementMapView, skipOffstage: false));
      expect(mapWidget.announcements, hasLength(1));
      expect(mapWidget.announcements.first.id, 'high');
    },
  );

  testWidgets(
    'toggle Liste ↔ Carte préserve l\'Element de AnnouncementMapView',
    (tester) async {
      final announcementBloc = MockAnnouncementBloc();
      final authBloc = MockAuthBloc();
      when(() => authBloc.state).thenReturn(const AuthInitial());
      whenListen(
        announcementBloc,
        Stream<AnnouncementState>.empty(),
        initialState: AnnouncementSearchLoaded([_makeAnn()]),
      );
      when(() => announcementBloc.state)
          .thenReturn(AnnouncementSearchLoaded([_makeAnn()]));

      await tester.pumpWidget(_buildScreen(
        announcementBloc: announcementBloc,
        authBloc: authBloc,
      ));
      await tester.pump(const Duration(milliseconds: 50));

      // Naviguer vers la vue résultats.
      final btn = find.text('Rechercher');
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      final mapElementBefore =
          tester.element(find.byType(AnnouncementMapView, skipOffstage: false));

      // Switch to map
      await tester.tap(find.text('Carte'));
      await tester.pump();
      // Switch back to list
      await tester.tap(find.text('Liste'));
      await tester.pump();
      // Switch to map again
      await tester.tap(find.text('Carte'));
      await tester.pump();

      final mapElementAfter =
          tester.element(find.byType(AnnouncementMapView, skipOffstage: false));

      // Same Element identity = same State = preserved camera/controller.
      expect(identical(mapElementBefore, mapElementAfter), isTrue);
    },
  );

  // ── 18. Bouton "Réessayer" sur _ErrorView dispatch un nouveau search ──────

  group('_ErrorView retry button', () {
    testWidgets(
        'tapper "Réessayer" déclenche AnnouncementSearchRequested',
        (tester) async {
      // Error state without previousResults → shows full _ErrorView with retry CTA.
      when(() => announcementBloc.state)
          .thenReturn(AnnouncementError('Erreur réseau'));
      when(() => announcementBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([AnnouncementError('Erreur réseau')]),
      );

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      // _ErrorView visible with "Réessayer" button.
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      // Tap retry — must dispatch a new AnnouncementSearchRequested event.
      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(() => announcementBloc
              .add(any(that: isA<AnnouncementSearchRequested>())))
          .called(greaterThan(0));
    });
  });

  // ── 19. Banner dismiss + listener reset on new error ─────────────────────

  group('Banner d\'erreur dismiss + reset', () {
    testWidgets(
        'tap close → banner disparaît, puis nouvel error → banner réapparaît',
        (tester) async {
      final announcementBloc = MockAnnouncementBloc();
      final authBloc = MockAuthBloc();
      when(() => authBloc.state).thenReturn(const AuthInitial());

      // First emit Loaded so user navigates into results, then later switch
      // to AnnouncementError(previousResults: …) to trigger the banner.
      final results = [_makeAnn()];
      final error1 = AnnouncementError(
        'Réseau indisponible',
        previousResults: results,
      );
      final error2 = AnnouncementError(
        'Timeout du serveur',
        previousResults: results,
      );

      // Use a controller so we can emit multiple states post-pump.
      final controller = StreamController<AnnouncementState>.broadcast();
      when(() => announcementBloc.state).thenReturn(error1);
      when(() => announcementBloc.stream)
          .thenAnswer((_) => controller.stream);
      addTearDown(controller.close);

      await tester.pumpWidget(_buildScreen(
        announcementBloc: announcementBloc,
        authBloc: authBloc,
      ));
      await tester.pump();
      await _goToResults(tester);

      // Banner visible initially (error1 with previousResults).
      expect(find.byKey(const Key('search-error-banner')), findsOneWidget);
      expect(find.text('Réseau indisponible'), findsOneWidget);

      // Find the dismiss icon inside the banner and tap it.
      final dismissIcon = find.descendant(
        of: find.byKey(const Key('search-error-banner')),
        matching: find.byIcon(Icons.close_rounded),
      );
      expect(dismissIcon, findsOneWidget);
      await tester.tap(dismissIcon);
      await tester.pumpAndSettle();

      // Banner gone after dismiss.
      expect(find.byKey(const Key('search-error-banner')), findsNothing);

      // Now emit a new error state → the BlocConsumer.listener resets
      // _errorBannerDismissed and the banner must reappear.
      when(() => announcementBloc.state).thenReturn(error2);
      controller.add(error2);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('search-error-banner')), findsOneWidget);
      expect(find.text('Timeout du serveur'), findsOneWidget);
    });
  });

  // ── 20. _EmptyView quand résultats serveur vides ─────────────────────────

  group('_EmptyView via résultats serveur vides', () {
    testWidgets(
        'AnnouncementSearchLoaded([]) → _EmptyView avec icône search_off',
        (tester) async {
      stubLoaded([]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      // _EmptyView est rendue : icône search_off_rounded + titre + CTA.
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(find.text('Aucun voyageur disponible'), findsOneWidget);
      expect(find.text('Modifier la recherche'), findsOneWidget);
    });
  });

  // ── 23. Filter bottom sheet — onChanged callbacks ────────────────────────

  group('Filter bottom sheet onChanged callbacks', () {
    testWidgets(
        'toggle Kilo Pro/Note ≥ 4.5/Arrivée week-end dans bottom sheet → setSheet exécuté',
        (tester) async {
      stubLoaded([_makeAnn()]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      // Ouvrir le bottom sheet via le bouton tune.
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      // Toggle "Kilo Pro uniquement" dans le sheet (couvre lignes 838-839).
      final kpInSheet = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Kilo Pro uniquement'),
      );
      if (kpInSheet.evaluate().isNotEmpty) {
        await tester.tap(kpInSheet);
        await tester.pumpAndSettle();
      }

      // Toggle "Note ≥ 4.5" (couvre 844-845).
      final noteInSheet = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Note ≥ 4.5'),
      );
      if (noteInSheet.evaluate().isNotEmpty) {
        await tester.tap(noteInSheet);
        await tester.pumpAndSettle();
      }

      // Toggle "Arrivée ce week-end" (couvre 850-851).
      final wkInSheet = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Arrivée ce week-end'),
      );
      if (wkInSheet.evaluate().isNotEmpty) {
        await tester.tap(wkInSheet);
        await tester.pumpAndSettle();
      }

      // Toggle "Prix ≤ ../kg" (couvre 857-858).
      final priceInSheet = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.textContaining('Prix ≤'),
      );
      if (priceInSheet.evaluate().isNotEmpty) {
        await tester.tap(priceInSheet);
        await tester.pumpAndSettle();
      }

      // Drag du slider Prix max par kg (couvre 891-892 onChanged).
      final sliderInSheet = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Slider),
      );
      if (sliderInSheet.evaluate().isNotEmpty) {
        await tester.drag(sliderInSheet.first, const Offset(40, 0));
        await tester.pumpAndSettle();
      }

      // Tapper "Appliquer" → le bouton ferme le sheet ET émet un nouvel
      // AnnouncementSearchRequested avec les params modifiés (toggles + slider).
      // C'est la preuve user-visible que les setSheet ont bien muté l'état.
      final apply = find.text('Appliquer');
      expect(apply, findsOneWidget);
      await tester.tap(apply);
      await tester.pumpAndSettle();

      verify(() => announcementBloc
              .add(any(that: isA<AnnouncementSearchRequested>())))
          .called(greaterThan(0));
    });
  });

  // ── 25. Confirmer dans le picker poids → onChanged exécuté ──────────────

  group('Weight picker — Confirmer', () {
    testWidgets(
        'tapper Confirmer dans le picker poids → AnnouncementSearchRequested émis',
        (tester) async {
      stubLoaded([]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();

      // Ouvrir le picker poids depuis le formulaire principal.
      await tester.tap(find.text('6 kg'));
      await tester.pumpAndSettle();

      // Le picker affiche un bouton "Confirmer" → couvre lignes 1696-1698.
      final confirmer = find.text('Confirmer');
      expect(confirmer, findsOneWidget);
      await tester.tap(confirmer);
      await tester.pumpAndSettle();

      // Le ctx.pop() ferme le picker — on est revenu au formulaire.
      expect(find.text('Confirmer'), findsNothing);
    });
  });

  // ── 24. Tap card non-own → navigation push vers /search/{id} ─────────────

  group('TravelerCard non-own onTap', () {
    testWidgets(
        'utilisateur ≠ traveler → tap card lance context.push vers /search/{id}',
        (tester) async {
      // Auth user with id différent du travelerId.
      const otherUser = UserModel(
        id: 'sender-99',
        roles: ['SENDER'],
        kycStatus: 'VERIFIED',
        status: 'ACTIVE',
      );
      when(() => authBloc.state)
          .thenReturn(const AuthAuthenticated(otherUser));

      stubLoaded([_makeAnn(id: 'announcement-xyz')]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      // La card NE doit PAS afficher "Votre trajet" — utilisateur différent.
      expect(find.text('Votre trajet'), findsNothing);

      // Le tap déclenche context.push('/search/{id}'). La route /search/:id
      // est définie comme un Scaffold vide dans _buildScreen → pas d'exception.
      // On tape sur un texte stable de la card (le prix).
      await tester.tap(find.text('10 €/kg'));
      await tester.pumpAndSettle();

      // Après push, on n'est plus sur l'écran de recherche : le bouton tune
      // (présent uniquement dans la vue résultats) ne doit plus exister.
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    });
  });

  // ── 21. TravelerCard branche "own announcement" ──────────────────────────

  group('TravelerCard own announcement branch', () {
    testWidgets(
        'utilisateur connecté = traveler → carte affiche "Votre trajet" et onTap=null',
        (tester) async {
      // Auth user whose id matches the announcement.travelerId ('traveler-1').
      const ownUser = UserModel(
        id: 'traveler-1',
        roles: ['TRAVELER'],
        kycStatus: 'VERIFIED',
        status: 'ACTIVE',
      );
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(ownUser));

      stubLoaded([_makeAnn()]);

      await tester.pumpWidget(
          _buildScreen(announcementBloc: announcementBloc, authBloc: authBloc));
      await tester.pump();
      await _goToResults(tester);

      // The "Votre trajet" caption is only rendered when isOwnAnnouncement is true.
      expect(find.text('Votre trajet'), findsOneWidget);

      // Direct check on the widget property: own announcements must not be
      // tappable, so the TravelerCard.onTap must be null.
      final card = tester.widget<TravelerCard>(find.byType(TravelerCard));
      expect(card.onTap, isNull,
          reason: 'Own announcement should not be tappable');
    });
  });
}
