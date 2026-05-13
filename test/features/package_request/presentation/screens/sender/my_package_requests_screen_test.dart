import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/sender/my_package_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockPackageRequestBloc
    extends MockBloc<PackageRequestEvent, PackageRequestState>
    implements PackageRequestBloc {}

PackageRequest _request({
  PackageRequestStatus status = PackageRequestStatus.open,
  double? targetPriceEur = 35,
}) =>
    PackageRequest(
      id: 'pr-1',
      senderId: 's-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 6, 15),
      dateToleranceDays: 2,
      weightKg: 5,
      parcelSize: ParcelSize.medium,
      transportMode: TransportMode.plane,
      contentCategory: ContentCategory.vetements,
      targetPriceEur: targetPriceEur,
      status: status,
      createdAt: DateTime(2026, 5, 10),
    );

void main() {
  late _MockPackageRequestBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr', null);
    registerFallbackValue(const FetchMyRequests());
  });

  setUp(() {
    bloc = _MockPackageRequestBloc();
    when(() => bloc.state).thenReturn(const PackageRequestState());
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<PackageRequestState>.empty());
  });

  Widget wrap() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider<PackageRequestBloc>.value(
            value: bloc,
            child: const Scaffold(body: MyPackageRequestsBody()),
          ),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    );
  }

  group('MyPackageRequestsBody', () {
    testWidgets('affiche CircularProgressIndicator en état loading',
        (tester) async {
      when(() => bloc.state).thenReturn(const PackageRequestState(
        status: PackageRequestListStatus.loading,
      ));
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('affiche empty state "Aucun envoi en cours" quand la liste est vide',
        (tester) async {
      when(() => bloc.state).thenReturn(const PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Aucun envoi en cours'), findsOneWidget);
    });

    testWidgets('affiche le texte d\'erreur quand status = error',
        (tester) async {
      when(() => bloc.state).thenReturn(const PackageRequestState(
        status: PackageRequestListStatus.error,
        errorMessage: 'Erreur réseau',
      ));
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.text('Erreur réseau'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('affiche les cards quand des demandes existent', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(), _request(status: PackageRequestStatus.negotiating)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Paris → Dakar'), findsWidgets);
    });

    testWidgets('affiche les trois onglets dans le header', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.negotiating)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('À venir'), findsOneWidget);
      expect(find.text('Passés'), findsOneWidget);
    });
  });

  group('_RequestCard', () {
    testWidgets('affiche le badge OUVERTE pour status=open', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.open)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('À venir'));
      await tester.pumpAndSettle();
      expect(find.text('OUVERTE'), findsOneWidget);
    });

    testWidgets('affiche le badge NÉGOCIATION pour status=negotiating',
        (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.negotiating)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('NÉGOCIATION'), findsOneWidget);
    });

    testWidgets('affiche le badge ACCEPTÉE pour status=accepted', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.accepted)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('ACCEPTÉE'), findsOneWidget);
    });

    testWidgets('affiche le badge EXPIRÉE pour status=expired', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.expired)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passés'));
      await tester.pumpAndSettle();
      expect(find.text('EXPIRÉE'), findsOneWidget);
    });

    testWidgets('card affiche les 4 labels du stepper', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.negotiating)],
      ));
      // negotiating → tab "En cours" (défaut)
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Publié'), findsOneWidget);
      expect(find.text('Accepté'), findsOneWidget);
      expect(find.text('En route'), findsOneWidget);
      expect(find.text('Livré'), findsOneWidget);
    });
  });

  group('Filtrage par tab', () {
    testWidgets('tab "En cours" affiche negotiating et accepted, pas open',
        (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [
          _request(status: PackageRequestStatus.open),
          _request(status: PackageRequestStatus.negotiating),
          _request(status: PackageRequestStatus.accepted),
        ],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      // "En cours" est actif par défaut
      expect(find.text('NÉGOCIATION'), findsOneWidget);
      expect(find.text('ACCEPTÉE'), findsOneWidget);
      expect(find.text('OUVERTE'), findsNothing);
    });

    testWidgets('tab "À venir" affiche open uniquement', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [
          _request(status: PackageRequestStatus.open),
          _request(status: PackageRequestStatus.negotiating),
        ],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('À venir'));
      await tester.pumpAndSettle();
      expect(find.text('OUVERTE'), findsOneWidget);
      expect(find.text('NÉGOCIATION'), findsNothing);
    });

    testWidgets('tab "Passés" affiche completed et expired, pas open',
        (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [
          _request(status: PackageRequestStatus.completed),
          _request(status: PackageRequestStatus.expired),
          _request(status: PackageRequestStatus.open),
        ],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passés'));
      await tester.pumpAndSettle();
      expect(find.text('LIVRÉE'), findsOneWidget);
      expect(find.text('EXPIRÉE'), findsOneWidget);
      expect(find.text('OUVERTE'), findsNothing);
    });
  });

  group('CTA contextuel', () {
    testWidgets('CTA "Modifier →" pour status=open', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.open)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('À venir'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier →'), findsOneWidget);
    });

    testWidgets('CTA "Voir →" pour status=negotiating', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.negotiating)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Voir →'), findsOneWidget);
    });

    testWidgets('CTA "Voir →" pour status=accepted', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.accepted)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Voir →'), findsOneWidget);
    });

    testWidgets('CTA "Détail →" pour status=completed', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.completed)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passés'));
      await tester.pumpAndSettle();
      expect(find.text('Détail →'), findsOneWidget);
    });
  });

  group('Empty state par tab', () {
    testWidgets('tab "En cours" vide → "Aucun envoi en cours"', (tester) async {
      // Seule une demande open existe → tab "En cours" est vide
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.open)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      // "En cours" actif par défaut, aucun negotiating/accepted
      expect(find.text('Aucun envoi en cours'), findsOneWidget);
    });

    testWidgets('tab "À venir" vide → "Aucune demande ouverte"', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.negotiating)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('À venir'));
      await tester.pumpAndSettle();
      expect(find.text('Aucune demande ouverte'), findsOneWidget);
    });

    testWidgets('tab "Passés" vide → "Aucun historique"', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.open)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passés'));
      await tester.pumpAndSettle();
      expect(find.text('Aucun historique'), findsOneWidget);
    });
  });
}
