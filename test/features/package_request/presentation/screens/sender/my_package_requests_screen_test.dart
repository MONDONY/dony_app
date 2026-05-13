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

  Widget wrap() => MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider<PackageRequestBloc>.value(
          value: bloc,
          child: const Scaffold(body: MyPackageRequestsBody()),
        ),
      );

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

    testWidgets('affiche _EmptyView quand la liste est vide', (tester) async {
      when(() => bloc.state).thenReturn(const PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Tu n\'as encore rien envoyé'), findsOneWidget);
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
  });

  group('_RequestCard', () {
    Widget wrapCard(PackageRequest r) => MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider<PackageRequestBloc>.value(
            value: bloc,
            child: const Scaffold(body: MyPackageRequestsBody()),
          ),
        );

    testWidgets('affiche le badge OUVERTE pour status=open', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.open)],
      ));
      await tester.pumpWidget(wrapCard(_request()));
      await tester.pumpAndSettle();
      expect(find.text('OUVERTE'), findsOneWidget);
    });

    testWidgets('affiche le badge NÉGOCIATION pour status=negotiating',
        (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.negotiating)],
      ));
      await tester.pumpWidget(wrapCard(_request()));
      await tester.pumpAndSettle();
      expect(find.text('NÉGOCIATION'), findsOneWidget);
    });

    testWidgets('affiche le badge ACCEPTÉE pour status=accepted', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.accepted)],
      ));
      await tester.pumpWidget(wrapCard(_request()));
      await tester.pumpAndSettle();
      expect(find.text('ACCEPTÉE'), findsOneWidget);
    });

    testWidgets('affiche le badge EXPIRÉE pour status=expired', (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.expired)],
      ));
      await tester.pumpWidget(wrapCard(_request()));
      await tester.pumpAndSettle();
      expect(find.text('EXPIRÉE'), findsOneWidget);
    });

    testWidgets('affiche "En attente d\'offres…" dans le footer pour open',
        (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.open)],
      ));
      await tester.pumpWidget(wrapCard(_request()));
      await tester.pumpAndSettle();
      expect(find.textContaining('En attente d\'offres'), findsOneWidget);
    });

    testWidgets('affiche "Négociation en cours" dans le footer pour negotiating',
        (tester) async {
      when(() => bloc.state).thenReturn(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_request(status: PackageRequestStatus.negotiating)],
      ));
      await tester.pumpWidget(wrapCard(_request()));
      await tester.pumpAndSettle();
      expect(find.text('Négociation en cours'), findsOneWidget);
    });
  });
}
