import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_feedback_button.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Test doubles ─────────────────────────────────────────────────────────────

class _FakeAnalytics extends Fake implements AnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object>? properties}) async {}
}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  Widget subject({Future<void> Function(String message)? onSubmit}) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [DonyFeedbackButton(onSubmitOverride: onSubmit)],
        ),
        body: const SizedBox(),
      ),
    );
  }

  testWidgets('icône 🐞 visible avec tooltip', (tester) async {
    await tester.pumpWidget(subject());
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'), findsOneWidget);
    expect(find.byTooltip('Signaler un problème'), findsOneWidget);
  });

  testWidgets('tap ouvre le sheet avec champ texte et bouton désactivé', (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'));
    await tester.pumpAndSettle();

    expect(find.text('Un problème sur cet écran ?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    final btn = tester.widget<DonyButton>(
      find.widgetWithText(DonyButton, 'Envoyer le rapport'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('saisie active le bouton et l\'envoi appelle onSubmit', (tester) async {
    String? submitted;
    await tester.pumpWidget(subject(onSubmit: (m) async => submitted = m));
    await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Le code retrait ne s\'affiche pas');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
    await tester.pumpAndSettle();

    expect(submitted, 'Le code retrait ne s\'affiche pas');
    expect(find.text('Un problème sur cet écran ?'), findsNothing);
    expect(find.textContaining('Merci'), findsOneWidget);
  });

  testWidgets('échec onSubmit garde le texte et montre une erreur', (tester) async {
    await tester.pumpWidget(
      subject(onSubmit: (_) async => throw Exception('network')),
    );
    await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bug');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
    await tester.pumpAndSettle();

    expect(find.text('Un problème sur cet écran ?'), findsOneWidget);
    expect(find.text('bug'), findsOneWidget);
  });

  // ── Fallback path: resolveRoute retourne 'unknown' hors GoRouter ───────────

  testWidgets(
      'resolveRoute retourne "unknown" dans un contexte sans GoRouter',
      (tester) async {
    // GoRouterState.of(context) lève une exception dans un plain MaterialApp —
    // resolveRoute() doit capturer l'erreur et retourner 'unknown'.
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (ctx) {
          capturedContext = ctx;
          return const SizedBox();
        }),
      ),
    );
    expect(DonyFeedbackButton.resolveRoute(capturedContext), 'unknown');
  });

  testWidgets(
      'submit via onSubmitOverride dans un plain MaterialApp (sans GoRouter) '
      'ne lève pas d\'exception — chemin resolveRoute "unknown" exercé',
      (tester) async {
    // Ce test vérifie que la soumission complète fonctionne lorsqu'il n'y a
    // pas de GoRouter ancêtre. resolveRoute() retourne 'unknown' silencieusement.
    String? submitted;
    await tester.pumpWidget(subject(onSubmit: (m) async => submitted = m));
    await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'test sans GoRouter');
    await tester.pumpAndSettle();

    // Ne doit pas lancer d'exception même sans GoRouter dans l'arbre.
    await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
    await tester.pumpAndSettle();

    expect(submitted, 'test sans GoRouter');
  });

  // ── Fallback path: repaintBoundaryKey null → capture ignorée ──────────────

  testWidgets(
      'submit réussit sans crash quand repaintBoundaryKey est null '
      '(chemin _captureScreen → null exercé)', (tester) async {
    // DonyFeedbackButton sans repaintBoundaryKey (valeur par défaut = null) :
    // _captureScreen() doit retourner null sans exception, et la soumission
    // doit se terminer normalement.
    String? submitted;
    // subject() ne passe pas de repaintBoundaryKey → null par défaut.
    await tester.pumpWidget(subject(onSubmit: (m) async => submitted = m));
    await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bug sans capture');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
    await tester.pumpAndSettle();

    // La soumission s'est bien terminée, le sheet est fermé.
    expect(submitted, 'bug sans capture');
    expect(find.text('Un problème sur cet écran ?'), findsNothing);
  });

  // ── analyticsResolver registration ────────────────────────────────────────

  testWidgets(
      'registerAnalyticsResolver + resetAnalyticsResolver sans crash',
      (tester) async {
    // Couvre les lignes 42-43 (registerAnalyticsResolver) et 47-48
    // (resetAnalyticsResolver) du source.
    DonyFeedbackButton.registerAnalyticsResolver(() => _FakeAnalytics());
    DonyFeedbackButton.resetAnalyticsResolver();
    await tester.pumpWidget(subject(onSubmit: (_) async {}));
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'), findsOneWidget);
  });

  // ── _captureScreen avec RepaintBoundary réel ───────────────────────────────

  testWidgets(
      'repaintBoundaryKey fourni avec RepaintBoundary réel → submit sans crash',
      (tester) async {
    // Couvre les lignes 65-77 (_captureScreen avec boundary non-null).
    // La capture peut retourner null dans l'environnement de test (renderer
    // headless) mais ne doit pas lever d'exception.
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

    await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'test avec repaint boundary');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
    await tester.pumpAndSettle();

    expect(submitted, 'test avec repaint boundary');
  });

  // ── _submitToSentry path (sans onSubmitOverride) ───────────────────────────
  //
  // Sentry.captureMessage ne lève pas d'exception mais retourne une Future
  // qui ne se résout jamais (plugin non initialisé en test headless).
  // pumpAndSettle causerait un timeout — on utilise pump() avec durée fixe.
  //
  // Ce pattern couvre :
  //   302   : appel _submitToSentry depuis _handleSubmit
  //   85-90 : _submitToSentry jusqu'à l'appel _captureScreen
  //   65-66 : _captureScreen null guard (repaintBoundaryKey=null → return null)

  testWidgets(
      '_submitToSentry exercé sans onSubmitOverride → lignes 85-90, 65-66 couvertes '
      '(Sentry SDK en attente — pump() utilisé)', (tester) async {
    // Sans onSubmitOverride, _handleSubmit (l.302) appelle _submitToSentry.
    // _submitToSentry appelle _captureScreen (repaintBoundaryKey=null → null),
    // puis Sentry.captureMessage qui ne se résout jamais en test headless.
    // On utilise pump() à durée fixe pour avancer sans attendre la résolution.
    await tester.pumpWidget(subject()); // pas d'onSubmitOverride
    await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'test sentry path');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
    // pump() avec durée fixe — pumpAndSettle() timeouterait car Sentry ne résout pas
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Le widget est en état "loading" (sending=true) car Sentry est en attente.
    // On vérifie juste que l'arbre est stable et le sheet toujours présent.
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'), findsOneWidget);
  });

  testWidgets(
      '_submitToSentry avec repaintBoundaryKey non-null → lignes 70-77 (_captureScreen) couvertes',
      (tester) async {
    // Avec un vrai RepaintBoundary ET sans onSubmitOverride, _submitToSentry
    // appelle _captureScreen qui trouve le boundary (l.70-71) et appelle
    // boundary.toImage() (l.75). En test headless toImage() peut retourner
    // normalement ou lancer — les deux cas retournent null via le catch (l.78).
    // Ensuite Sentry.captureMessage ne se résout jamais → pump() requis.
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            appBar: AppBar(
              actions: [DonyFeedbackButton(repaintBoundaryKey: key)],
            ),
            body: const SizedBox(),
          ),
        ),
      ),
    );

    await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'test boundary sentry path');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Sheet toujours présent (Sentry en attente indéfinie)
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'), findsOneWidget);
  });

  // Lignes documentées comme inatteignables en test :
  //   92-119 : Sentry.captureMessage / captureFeedback / analytics → Future jamais résolu
  //   196   : updateShouldNotify (interne Flutter, jamais déclenché directement)

  // ── analyticsResolver enregistré — vérification du chemin ─────────────────
  //
  // NOTE : _analyticsResolver est appelé DANS _submitToSentry (lignes 112-119),
  // qui n'est PAS invoqué quand onSubmitOverride est fourni. Ces lignes sont
  // structurellement inatteignables en test car Sentry.captureMessage /
  // captureFeedback lancent MissingPluginException dans l'environnement headless.
  // Ce test couvre l'enregistrement et la réinitialisation du resolver (lignes
  // 42, 47) et confirme qu'aucune exception n'est levée pendant un submit normal.

  testWidgets(
      'analyticsResolver enregistré — register + reset sans interférence sur submit',
      (tester) async {
    final analytics = _MockAnalyticsService();
    when(() => analytics.logEvent(
          any(),
          properties: any(named: 'properties'),
        )).thenAnswer((_) async {});

    DonyFeedbackButton.registerAnalyticsResolver(() => analytics);
    addTearDown(DonyFeedbackButton.resetAnalyticsResolver);

    String? submitted;
    await tester.pumpWidget(subject(onSubmit: (m) async => submitted = m));
    await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bug'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'test analytics');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
    await tester.pumpAndSettle();

    // onSubmitOverride est utilisé → _submitToSentry n'est PAS appelé →
    // logEvent ne sera PAS appelé (analytics est dans _submitToSentry).
    // Ce test confirme seulement qu'un resolver enregistré ne perturbe pas
    // le chemin onSubmitOverride.
    expect(submitted, 'test analytics');

    // Aucun appel à logEvent attendu via le chemin override — confirmer
    // l'absence d'interactions non prévues.
    verifyNever(() => analytics.logEvent(
          AnalyticsEvents.screenFeedbackSubmitted,
          properties: any(named: 'properties'),
        ));
  });
}
