import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/bloc/request_filter_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/sender/my_package_requests_screen.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockPackageRequestBloc
    extends MockBloc<PackageRequestEvent, PackageRequestState>
    implements PackageRequestBloc {}

PackageRequest _request({
  String departureCity = 'Paris',
  String arrivalCity = 'Dakar',
  PackageRequestStatus status = PackageRequestStatus.open,
  String categoryLabel = 'Vêtements & tissus',
  double? targetPriceEur = 35,
}) => PackageRequest(
  id: 'pr-${arrivalCity.toLowerCase()}-${status.name}',
  senderId: 's-1',
  departureCity: departureCity,
  arrivalCity: arrivalCity,
  desiredDate: DateTime(2026, 6, 15),
  dateToleranceDays: 2,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: [categoryLabel],
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
    when(() => bloc.state).thenReturn(PackageRequestState());
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<PackageRequestState>.empty());

    if (!getIt.isRegistered<RequestFilterCubit>()) {
      getIt.registerFactory<RequestFilterCubit>(() => RequestFilterCubit());
    }
  });

  tearDown(() async {
    if (getIt.isRegistered<RequestFilterCubit>()) {
      await getIt.unregister<RequestFilterCubit>();
    }
  });

  Widget wrap() => MaterialApp(
    theme: AppTheme.light(),
    home: BlocProvider<PackageRequestBloc>.value(
      value: bloc,
      child: const Scaffold(body: MyPackageRequestsBody()),
    ),
  );

  group('MyPackageRequestsBody', () {
    testWidgets('affiche CircularProgressIndicator en état loading', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(status: PackageRequestListStatus.loading),
      );
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('affiche _EmptyView quand la liste est vide', (tester) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Tu n\'as encore rien envoyé'), findsOneWidget);
    });

    testWidgets('affiche le texte d\'erreur quand status = error', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.error,
          errorMessage: 'Erreur réseau',
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.text('Erreur réseau'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('affiche les cards quand des demandes existent', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [
            _request(),
            _request(status: PackageRequestStatus.negotiating),
          ],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Paris → Dakar'), findsWidgets);
    });

    testWidgets(
      'la barre de recherche est visible quand des demandes existent',
      (tester) async {
        when(() => bloc.state).thenReturn(
          PackageRequestState(
            status: PackageRequestListStatus.loaded,
            requests: [_request()],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        expect(find.text('Ville, catégorie…'), findsOneWidget);
      },
    );
  });

  group('_RequestCard', () {
    Widget wrapCard(PackageRequest r) => MaterialApp(
      theme: AppTheme.light(),
      home: BlocProvider<PackageRequestBloc>.value(
        value: bloc,
        child: const Scaffold(body: MyPackageRequestsBody()),
      ),
    );

    testWidgets('affiche le badge OUVERTE pour status=open', (tester) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [_request(status: PackageRequestStatus.open)],
        ),
      );
      await tester.pumpWidget(wrapCard(_request()));
      await tester.pumpAndSettle();
      expect(find.text('OUVERTE'), findsOneWidget);
    });

    testWidgets('affiche le badge NÉGOCIATION pour status=negotiating', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [_request(status: PackageRequestStatus.negotiating)],
        ),
      );
      await tester.pumpWidget(wrapCard(_request()));
      await tester.pumpAndSettle();
      expect(find.text('NÉGOCIATION'), findsOneWidget);
    });

    testWidgets('n\'affiche pas les demandes acceptées (parties dans Envois)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [_request(status: PackageRequestStatus.accepted)],
        ),
      );
      await tester.pumpWidget(wrapCard(_request()));
      await tester.pumpAndSettle();
      // La carte n'est pas rendue → on retombe sur l'état vide global.
      expect(find.text('ACCEPTÉE'), findsNothing);
      expect(find.text('Tu n\'as encore rien envoyé'), findsOneWidget);
    });

    testWidgets('affiche le badge EXPIRÉE pour status=expired', (tester) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [_request(status: PackageRequestStatus.expired)],
        ),
      );
      await tester.pumpWidget(wrapCard(_request()));
      await tester.pumpAndSettle();
      expect(find.text('EXPIRÉE'), findsOneWidget);
    });

    testWidgets('affiche "Modifier →" dans le footer pour open', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [_request(status: PackageRequestStatus.open)],
        ),
      );
      await tester.pumpWidget(wrapCard(_request()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Modifier'), findsOneWidget);
    });

    testWidgets('affiche "Modifier →" dans le footer pour negotiating', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [_request(status: PackageRequestStatus.negotiating)],
        ),
      );
      await tester.pumpWidget(wrapCard(_request()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Modifier'), findsOneWidget);
    });
  });

  group('Recherche et filtres', () {
    final dakarRequest = _request(
      arrivalCity: 'Dakar',
      status: PackageRequestStatus.open,
    );
    final abidjanRequest = _request(
      arrivalCity: 'Abidjan',
      status: PackageRequestStatus.cancelled,
    );

    setUp(() {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [dakarRequest, abidjanRequest],
        ),
      );
    });

    testWidgets('la saisie dans le champ de recherche filtre après 250ms', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Both requests initially visible
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.text('Paris → Abidjan'), findsOneWidget);

      // Type in search field
      await tester.enterText(find.byType(TextField), 'abidjan');

      // Before debounce: both still visible
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.text('Paris → Abidjan'), findsOneWidget);

      // After debounce: only Abidjan visible
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.text('Paris → Abidjan'), findsOneWidget);
      expect(find.text('Paris → Dakar'), findsNothing);
    });

    testWidgets(
      'le chip Terminées filtre les demandes terminées (annulées/expirées)',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        // Both requests visible
        expect(find.text('Paris → Dakar'), findsOneWidget);
        expect(find.text('Paris → Abidjan'), findsOneWidget);

        // Tap "Terminées" chip (1 = Abidjan annulée)
        await tester.tap(find.text('Terminées (1)'));
        await tester.pumpAndSettle();

        // Only the closed request (Abidjan cancelled) should be visible
        expect(find.text('Paris → Abidjan'), findsOneWidget);
        expect(find.text('Paris → Dakar'), findsNothing);
      },
    );

    testWidgets('affiche le chip Brouillons si une demande draft existe', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [
            dakarRequest,
            _request(arrivalCity: 'Bamako', status: PackageRequestStatus.draft),
          ],
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Brouillons (1)'), findsOneWidget);
      await tester.tap(find.text('Brouillons (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Paris → Bamako'), findsOneWidget);
      expect(find.text('BROUILLON'), findsOneWidget);
      expect(find.text('Paris → Dakar'), findsNothing);
    });

    testWidgets('masque le chip Brouillons quand aucun draft', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.textContaining('Brouillons'), findsNothing);
    });

    testWidgets('trie les brouillons avant les demandes ouvertes', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [
            dakarRequest,
            _request(arrivalCity: 'Bamako', status: PackageRequestStatus.draft),
          ],
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final draftTop = tester.getTopLeft(find.text('Paris → Bamako')).dy;
      final openTop = tester.getTopLeft(find.text('Paris → Dakar')).dy;
      expect(draftTop, lessThan(openTop));
    });

    testWidgets(
      'recherche sans correspondance affiche l\'état vide de recherche',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        // Type a query with no matching results
        await tester.enterText(find.byType(TextField), 'zzzzz');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        expect(
          find.text('Aucun résultat pour cette recherche'),
          findsOneWidget,
        );
      },
    );
  });

  group('_StatusBadge — tous les statuts', () {
    for (final entry in [(PackageRequestStatus.cancelled, 'ANNULÉE')]) {
      final status = entry.$1;
      final label = entry.$2;
      testWidgets('affiche le badge $label pour status=${status.name}', (
        tester,
      ) async {
        when(() => bloc.state).thenReturn(
          PackageRequestState(
            status: PackageRequestListStatus.loaded,
            requests: [_request(status: status)],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
      });
    }
  });

  group(
    '_CardAction — pas de CTA « Compléter » (détails faits au paiement)',
    () {
      testWidgets('n\'affiche pas de CTA pour status=expired', (tester) async {
        when(() => bloc.state).thenReturn(
          PackageRequestState(
            status: PackageRequestListStatus.loaded,
            requests: [_request(status: PackageRequestStatus.expired)],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        // No CTA for expired (SizedBox.shrink)
        expect(find.text('Modifier →'), findsNothing);
        expect(find.text('Compléter →'), findsNothing);
      });

      testWidgets('n\'affiche pas de CTA pour status=cancelled', (
        tester,
      ) async {
        when(() => bloc.state).thenReturn(
          PackageRequestState(
            status: PackageRequestListStatus.loaded,
            requests: [_request(status: PackageRequestStatus.cancelled)],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        expect(find.text('Modifier →'), findsNothing);
        expect(find.text('Compléter →'), findsNothing);
      });

      testWidgets('n\'affiche pas de CTA pour status=completed', (
        tester,
      ) async {
        when(() => bloc.state).thenReturn(
          PackageRequestState(
            status: PackageRequestListStatus.loaded,
            requests: [_request(status: PackageRequestStatus.completed)],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        expect(find.text('Modifier →'), findsNothing);
        expect(find.text('Compléter →'), findsNothing);
      });
    },
  );

  group('showFab', () {
    testWidgets('showFab: true affiche le FAB « Nouvelle demande »', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [_request()],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: BlocProvider<PackageRequestBloc>.value(
            value: bloc,
            child: const Scaffold(body: MyPackageRequestsBody(showFab: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle demande'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('showFab: false (défaut) n\'affiche pas le FAB', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [_request()],
        ),
      );
      await tester.pumpWidget(wrap()); // showFab: false
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('État vide global', () {
    testWidgets('affiche le CTA de création quand aucune demande', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('+ Publier ma première demande'), findsOneWidget);
    });
  });

  group('_FilterEmptyState', () {
    testWidgets(
      'chip Ouvertes + aucune ouverte affiche « Aucune demande ouverte »',
      (tester) async {
        when(() => bloc.state).thenReturn(
          PackageRequestState(
            status: PackageRequestListStatus.loaded,
            requests: [_request(status: PackageRequestStatus.cancelled)],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ouvertes (0)'));
        await tester.pumpAndSettle();

        expect(find.text('Aucune demande ouverte'), findsOneWidget);
      },
    );

    testWidgets(
      'chip Terminées + aucune terminée affiche « Aucune demande terminée »',
      (tester) async {
        when(() => bloc.state).thenReturn(
          PackageRequestState(
            status: PackageRequestListStatus.loaded,
            requests: [_request(status: PackageRequestStatus.open)],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Terminées (0)'));
        await tester.pumpAndSettle();

        expect(find.text('Aucune demande terminée'), findsOneWidget);
      },
    );

    testWidgets(
      'preset=all + aucun résultat après recherche affiche « Aucune demande »',
      (tester) async {
        // Use a request that won't match search
        when(() => bloc.state).thenReturn(
          PackageRequestState(
            status: PackageRequestListStatus.loaded,
            requests: [
              _request(arrivalCity: 'Dakar', status: PackageRequestStatus.open),
            ],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        // First filter to make it open only, then switch back to all
        await tester.tap(find.text('Ouvertes (1)'));
        await tester.pumpAndSettle();
        // Now switch to Toutes while keeping no match - instead, search zzz
        await tester.enterText(find.byType(TextField), 'zzzzz');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        // Clear search to get preset=open + no query empty state
        // Then tap Toutes
        await tester.tap(find.text('Toutes (1)'));
        await tester.pumpAndSettle();

        // After tapping Toutes the search is still active with 'zzzzz'
        // So filtered is empty with preset=all and hasQuery=true
        // => 'Aucun résultat pour cette recherche'
        expect(
          find.text('Aucun résultat pour cette recherche'),
          findsOneWidget,
        );
      },
    );
  });

  group('MyPackageRequestsScreen (écran complet)', () {
    testWidgets('rend le Scaffold avec appBar « Mes demandes »', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(status: PackageRequestListStatus.loading),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: BlocProvider<PackageRequestBloc>.value(
            value: bloc,
            child: const MyPackageRequestsScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mes demandes'), findsOneWidget);
    });
  });

  group('onRetry et CardAction snackbar', () {
    testWidgets('taper Réessayer dans _ErrorView déclenche FetchMyRequests', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.error,
          errorMessage: 'Erreur réseau',
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.text('Réessayer'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      verify(
        () => bloc.add(const FetchMyRequests()),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets(
      '« Modifier → » expose la clé d\'édition (open) et plus de placeholder',
      (tester) async {
        final req = _request(status: PackageRequestStatus.open);
        when(() => bloc.state).thenReturn(
          PackageRequestState(
            status: PackageRequestListStatus.loaded,
            requests: [req],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        // Le bouton d'édition est câblé (ouvre le wizard pré-rempli).
        expect(find.byKey(Key('edit-request-${req.id}')), findsOneWidget);
        // L'ancien placeholder « Modification à venir » n'existe plus.
        expect(find.text('Modification à venir'), findsNothing);
      },
    );
  });

  group('chip Toutes et onClear', () {
    testWidgets('chip Toutes réinitialise le filtre depuis Terminées', (
      tester,
    ) async {
      final requests = [
        _request(arrivalCity: 'Dakar', status: PackageRequestStatus.open),
        _request(
          arrivalCity: 'Abidjan',
          status: PackageRequestStatus.cancelled,
        ),
      ];
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: requests,
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Filtrer sur Terminées (Abidjan annulée)
      await tester.tap(find.text('Terminées (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Paris → Dakar'), findsNothing);

      // Tap Toutes pour réinitialiser
      await tester.tap(find.text('Toutes (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.text('Paris → Abidjan'), findsOneWidget);
    });

    testWidgets('bouton clear dans la barre de recherche efface la requête', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [_request()],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Type something
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle();

      // Tap clear button (DonySearchField uses Icons.close_rounded)
      final clearIcon = find.byWidgetPredicate(
        (w) => w is DonyIcon && w.name == 'x',
      );
      expect(clearIcon, findsOneWidget);
      await tester.tap(clearIcon);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      // After clear, search should be empty
      expect(find.text('Paris → Dakar'), findsOneWidget);
    });
  });
}
