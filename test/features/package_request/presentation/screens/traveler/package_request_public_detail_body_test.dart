import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
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
}) => PackageRequest(
  id: 'pr-1',
  senderId: 'sender-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 8, 1),
  dateToleranceDays: 3,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  contentCategory: ContentCategory.vetements,
  status: status,
  createdAt: DateTime(2026, 6, 1),
  negotiable: negotiable,
  targetPriceEur: 35,
  photoUrls: photoUrls,
  viewerThreadId: viewerThreadId,
);

void main() {
  Widget wrap(PackageRequest r) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: PackageRequestPublicDetailBody(request: r)),
  );

  testWidgets('identité colis-first + chip statut Ouverte + CTA', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_req()));
    await tester.pumpAndSettle();
    expect(find.text('DEMANDE D\'ENVOI'), findsOneWidget);
    expect(find.text('Ouverte'), findsOneWidget);
    expect(find.text('5 kg · Vêtements · M'), findsOneWidget);
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
    await tester.pumpWidget(wrap(_req(viewerThreadId: 'thread-1')));
    await tester.pumpAndSettle();
    expect(find.text('Voir ma négociation'), findsOneWidget);
    expect(find.text('Proposer mon trajet'), findsNothing);
  });

  testWidgets('offre en cours (prix ferme) → bouton « Proposer mon trajet »', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(_req(viewerThreadId: 'thread-1', negotiable: false)),
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
      MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir ma négociation'));
    await tester.pumpAndSettle();
    expect(find.text('NEGO t-9'), findsOneWidget);
  });

  // ── Vue propriétaire ─────────────────────────────────────────────────────

  Widget wrapOwner(PackageRequest r, {String? uid = 'sender-1'}) => MaterialApp(
    theme: AppTheme.light,
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
      MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offres reçues'));
    await tester.pumpAndSettle();
    expect(find.text('OWNER pr-1'), findsOneWidget);
  });
}
