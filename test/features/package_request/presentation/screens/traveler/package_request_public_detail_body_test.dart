import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

PackageRequest _req({
  List<String> photoUrls = const [],
  PackageRequestStatus status = PackageRequestStatus.open,
  bool negotiable = true,
  String? viewerThreadId,
  DateTime? desiredDate,
  double? targetPriceEur = 35,
  double? grossPriceEur,
}) => PackageRequest(
  id: 'pr-1',
  senderId: 'sender-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: desiredDate ?? DateTime(2026, 8),
  dateToleranceDays: 3,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: const ['Vêtements'],
  status: status,
  createdAt: DateTime(2026, 6),
  negotiable: negotiable,
  targetPriceEur: targetPriceEur,
  grossPriceEur: grossPriceEur,
  photoUrls: photoUrls,
  viewerThreadId: viewerThreadId,
);

void main() {
  Widget wrap(PackageRequest r) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: PackageRequestPublicDetailBody(request: r)),
  );

  Widget wrapLogged(PackageRequest r, {String uid = 'traveler-1'}) =>
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PackageRequestPublicDetailBody(request: r, currentUserId: uid),
        ),
      );

  testWidgets('identité colis-first + chip statut Ouverte + CTA', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_req()));
    await tester.pumpAndSettle();
    expect(find.text('DEMANDE D\'ENVOI'), findsOneWidget);
    expect(find.text('Ouverte'), findsOneWidget);
    expect(find.textContaining('Paris → Dakar'), findsOneWidget);
    expect(find.text('Vêtements'), findsOneWidget);
    expect(find.text('5 kg'), findsOneWidget);
    expect(find.text('Proposer mon trajet'), findsOneWidget);
  });

  testWidgets('photos → carousel avec compteur', (tester) async {
    await tester.pumpWidget(wrap(_req(photoUrls: const ['u1', 'u2'])));
    await tester.pumpAndSettle();
    expect(find.text('📷 1 / 2'), findsOneWidget);
  });

  testWidgets('aucune photo → pas de compteur carousel', (tester) async {
    await tester.pumpWidget(wrap(_req()));
    await tester.pumpAndSettle();
    expect(find.textContaining('📷'), findsNothing);
  });

  testWidgets('statut reflété par le chip', (tester) async {
    await tester.pumpWidget(
      wrap(_req(status: PackageRequestStatus.negotiating)),
    );
    await tester.pumpAndSettle();
    expect(find.text('En négociation'), findsOneWidget);
  });

  testWidgets('offre en cours (négociable) → bouton « Voir ma négociation »', (
    tester,
  ) async {
    await tester.pumpWidget(wrapLogged(_req(viewerThreadId: 'thread-1')));
    await tester.pumpAndSettle();
    expect(find.text('Voir ma négociation'), findsOneWidget);
    expect(find.text('Proposer mon trajet'), findsNothing);
  });

  testWidgets('offre en cours (prix ferme) → bouton « Proposer mon trajet »', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapLogged(_req(viewerThreadId: 'thread-1', negotiable: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Proposer mon trajet'), findsOneWidget);
    expect(find.text('Voir ma négociation'), findsNothing);
  });

  testWidgets('tap → navigue vers /negotiations/:id', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: PackageRequestPublicDetailBody(
              request: _req(viewerThreadId: 't-9'),
              currentUserId: 'traveler-1',
            ),
          ),
        ),
        GoRoute(
          path: '/negotiations/:id',
          builder: (ctx, st) =>
              Scaffold(body: Text('NEGO ${st.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir ma négociation'));
    await tester.pumpAndSettle();
    expect(find.text('NEGO t-9'), findsOneWidget);
  });

  testWidgets('invité : tap CTA ouvre la sheet de connexion', (tester) async {
    await tester.pumpWidget(wrap(_req()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Proposer mon trajet'));
    await tester.pumpAndSettle();

    expect(find.text('Connexion requise'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Continuer à explorer'), findsOneWidget);
    expect(find.text('Recherche libre'), findsOneWidget);
  });

  // ── Vue propriétaire ─────────────────────────────────────────────────────

  Widget wrapOwner(PackageRequest r, {String? uid = 'sender-1'}) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: PackageRequestPublicDetailBody(request: r, currentUserId: uid),
    ),
  );

  testWidgets('propriétaire + demande éditable → Modifier + Offres reçues', (
    tester,
  ) async {
    await tester.pumpWidget(wrapOwner(_req()));
    await tester.pumpAndSettle();
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Offres reçues'), findsOneWidget);
    expect(find.text('Proposer mon trajet'), findsNothing);
  });

  testWidgets('propriétaire + NEGOTIATING → Modifier toujours visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapOwner(_req(status: PackageRequestStatus.negotiating)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Offres reçues'), findsOneWidget);
  });

  testWidgets('propriétaire + non éditable (ACCEPTED) → Offres reçues seul', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapOwner(_req(status: PackageRequestStatus.accepted)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Offres reçues'), findsOneWidget);
    expect(find.text('Modifier'), findsNothing);
  });

  testWidgets('non-propriétaire → CTA voyageur, aucun bouton owner', (
    tester,
  ) async {
    await tester.pumpWidget(wrapOwner(_req(), uid: 'someone-else'));
    await tester.pumpAndSettle();
    expect(find.text('Proposer mon trajet'), findsOneWidget);
    expect(find.text('Offres reçues'), findsNothing);
    expect(find.text('Modifier'), findsNothing);
  });

  testWidgets('tap Offres reçues → /package-requests/:id', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: PackageRequestPublicDetailBody(
              request: _req(),
              currentUserId: 'sender-1',
            ),
          ),
        ),
        GoRoute(
          path: '/package-requests/:id',
          builder: (ctx, st) =>
              Scaffold(body: Text('OWNER ${st.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offres reçues'));
    await tester.pumpAndSettle();
    expect(find.text('OWNER pr-1'), findsOneWidget);
  });

  // ── Budget (brut vs net, PR #219) ───────────────────────────────────────────

  testWidgets(
    'carte Budget affiche le brut (grossPriceEur) quand le serveur le fournit',
    (tester) async {
      await tester.pumpWidget(wrap(_req(grossPriceEur: 40)));
      await tester.pumpAndSettle();
      expect(find.textContaining('40'), findsWidgets);
      // Jamais les deux montants côte à côte (révélerait la commission).
      expect(find.textContaining('35'), findsNothing);
    },
  );

  testWidgets(
    'carte Budget retombe sur le net (targetPriceEur) quand grossPriceEur est absent',
    (tester) async {
      await tester.pumpWidget(wrap(_req()));
      await tester.pumpAndSettle();
      expect(find.textContaining('35'), findsWidgets);
    },
  );

  testWidgets('CTA invité prix ferme annonce le brut, pas le net', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_req(negotiable: false, grossPriceEur: 40)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Prendre à'), findsOneWidget);
    expect(find.textContaining('40'), findsWidgets);
    expect(find.textContaining('35'), findsNothing);
  });

  // ── Badge urgent (repli local — PackageRequest n'expose pas `urgent`) ───────

  testWidgets('date souhaitée proche → badge urgent affiché', (tester) async {
    await tester.pumpWidget(
      wrap(_req(desiredDate: DateTime.now().add(const Duration(days: 1)))),
    );
    await tester.pumpAndSettle();
    expect(find.text('🔥 Urgent'), findsOneWidget);
  });

  testWidgets('date souhaitée lointaine → badge urgent absent', (tester) async {
    await tester.pumpWidget(
      wrap(_req(desiredDate: DateTime.now().add(const Duration(days: 30)))),
    );
    await tester.pumpAndSettle();
    expect(find.text('🔥 Urgent'), findsNothing);
  });
}
