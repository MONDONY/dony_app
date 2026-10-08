import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/nego_archive.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/screens/shared/my_negotiations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements NegotiationRepository {}

class _MockBidRepo extends Mock implements BidNegotiationRepository {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

NegotiationThread _thread(
  String id, {
  NegotiationThreadStatus status = NegotiationThreadStatus.expired,
  String arrival = 'Dakar',
  bool archived = false,
}) => NegotiationThread(
  id: id,
  packageRequestId: 'pr-$id',
  travelerId: 'tr-1',
  travelerTravelDate: DateTime(2026, 6, 15),
  travelerAvailableKg: 10,
  status: status,
  currentPriceEur: 30,
  roundsCount: 1,
  lastActivityAt: DateTime(2026, 5, 10),
  createdAt: DateTime(2026, 5, 10),
  messages: const [],
  travelerName: 'Awa',
  departureCity: 'Paris',
  arrivalCity: arrival,
  archived: archived,
);

BidNegotiationSummary _trip(
  String bidId, {
  String status = 'REJECTED',
  String arrival = 'Bamako',
  bool archived = false,
}) => BidNegotiationSummary(
  bidId: bidId,
  announcementId: 'ann',
  status: status,
  departureCity: 'Lyon',
  arrivalCity: arrival,
  updatedAt: DateTime(2026, 5, 9),
  archived: archived,
);

/// Archiver / supprimer une discussion de prix terminée depuis « Discussions
/// de prix » (FLUTTER-EJ, yadony-back #423).
void main() {
  late _MockRepo repo;
  late _MockBidRepo bidRepo;
  late _MockAuthBloc authBloc;
  late NegotiationListBloc listBloc;
  late BidNegotiationListBloc tripBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();
    bidRepo = _MockBidRepo();
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(
      const AuthAuthenticated(
        UserModel(
          id: 'sender-1',
          roles: ['SENDER'],
          kycStatus: 'VERIFIED',
          status: 'ACTIVE',
        ),
      ),
    );
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => repo.findMine()).thenAnswer(
      (_) async => [
        _thread('t-open', status: NegotiationThreadStatus.open),
        _thread('t-done', arrival: 'Abidjan'),
      ],
    );
    when(() => bidRepo.myNegotiations()).thenAnswer((_) async => []);
    when(
      () => repo.findMine(archived: true),
    ).thenAnswer((_) async => [_thread('t-arch', archived: true)]);
    when(
      () => bidRepo.myNegotiations(archived: true),
    ).thenAnswer((_) async => []);
    if (!getIt.isRegistered<NegotiationFilterCubit>()) {
      getIt.registerFactory<NegotiationFilterCubit>(NegotiationFilterCubit.new);
    }
  });

  tearDown(() async {
    if (getIt.isRegistered<NegotiationFilterCubit>()) {
      await getIt.unregister<NegotiationFilterCubit>();
    }
  });

  Widget withBlocs(Widget child) => MultiBlocProvider(
    providers: [
      BlocProvider<NegotiationListBloc>.value(value: listBloc),
      BlocProvider<BidNegotiationListBloc>.value(value: tripBloc),
      BlocProvider<AuthBloc>.value(value: authBloc),
    ],
    child: child,
  );

  /// [archivedOnly] : l'écran d'archives. Sinon la liste courante, montée
  /// dans un GoRouter pour que la ligne « Archivées » puisse ouvrir
  /// `/negotiations/archives`.
  Future<void> pump(WidgetTester tester, {bool archivedOnly = false}) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Créés dans la zone du test : leurs flux doivent avancer avec pump().
    listBloc = NegotiationListBloc(repo);
    tripBloc = BidNegotiationListBloc(bidRepo);
    addTearDown(listBloc.close);
    addTearDown(tripBloc.close);
    listBloc.add(const NegotiationListFetchRequested());
    tripBloc.add(const BidNegotiationListFetchRequested());
    final router = GoRouter(
      initialLocation: archivedOnly
          ? '/negotiations/archives'
          : '/negotiations',
      routes: [
        GoRoute(
          path: '/negotiations',
          builder: (_, _) =>
              withBlocs(const Scaffold(body: MyNegotiationsBody())),
        ),
        GoRoute(
          path: '/negotiations/archives',
          builder: (_, _) => withBlocs(
            const Scaffold(body: MyNegotiationsBody(archivedOnly: true)),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipe(WidgetTester tester, String id) async {
    await tester.drag(
      find.byKey(ValueKey('slidable-$id')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('seules les tuiles terminées sont balayables', (tester) async {
    when(() => bidRepo.myNegotiations()).thenAnswer(
      (_) async => [
        _trip('b-open', status: 'NEGOTIATING', arrival: 'Douala'),
        _trip('b-done'),
      ],
    );
    await pump(tester);

    expect(find.byType(Slidable), findsNWidgets(2));
    expect(find.byKey(const ValueKey('slidable-t-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('slidable-b-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('slidable-t-open')), findsNothing);
    expect(find.byKey(const ValueKey('slidable-b-open')), findsNothing);
  });

  testWidgets('Archiver : appel serveur, snackbar et « Annuler »', (
    tester,
  ) async {
    when(() => repo.archive('t-done')).thenAnswer((_) async {});
    when(() => repo.unarchive('t-done')).thenAnswer((_) async {});
    await pump(tester);

    await swipe(tester, 't-done');
    expect(find.text('Archiver'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    await tester.tap(find.text('Archiver'));
    await tester.pump();

    expect(find.text('Discussion archivée'), findsOneWidget);
    verify(() => repo.archive('t-done')).called(1);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    verify(() => repo.unarchive('t-done')).called(1);
  });

  testWidgets('Archiver une tuile de trajet terminée', (tester) async {
    when(() => bidRepo.myNegotiations()).thenAnswer((_) async => [_trip('b')]);
    when(() => bidRepo.archive('b')).thenAnswer((_) async {});
    await pump(tester);

    await swipe(tester, 'b');
    await tester.tap(find.text('Archiver'));
    await tester.pumpAndSettle();

    verify(() => bidRepo.archive('b')).called(1);
  });

  testWidgets('Supprimer : confirmation en feuille, Annuler ne supprime pas', (
    tester,
  ) async {
    when(() => repo.delete('t-done')).thenAnswer((_) async {});
    await pump(tester);

    await swipe(tester, 't-done');
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer la discussion ?'), findsOneWidget);
    expect(
      find.text(
        'Cette discussion disparaîtra de votre liste. '
        "L'autre participant la conserve.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('nego-delete-cancel')));
    await tester.pumpAndSettle();
    verifyNever(() => repo.delete(any()));

    await swipe(tester, 't-done');
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nego-delete-confirm')));
    await tester.pumpAndSettle();
    verify(() => repo.delete('t-done')).called(1);
  });

  testWidgets('Supprimer une tuile de trajet terminée', (tester) async {
    when(() => bidRepo.myNegotiations()).thenAnswer((_) async => [_trip('b')]);
    when(() => bidRepo.delete('b')).thenAnswer((_) async {});
    await pump(tester);

    await swipe(tester, 'b');
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nego-delete-confirm')));
    await tester.pumpAndSettle();

    verify(() => bidRepo.delete('b')).called(1);
  });

  testWidgets('409 : « Discussion encore en cours »', (tester) async {
    when(
      () => repo.archive('t-done'),
    ).thenThrow(const ConflictException('x', code: kNegotiationStillOpenCode));
    await pump(tester);

    await swipe(tester, 't-done');
    await tester.tap(find.text('Archiver'));
    await tester.pumpAndSettle();

    expect(find.text('Discussion encore en cours'), findsOneWidget);
  });

  testWidgets('backend ancien (404) : retour arrière et message, sans crash', (
    tester,
  ) async {
    when(() => repo.archive('t-done')).thenThrow(const NotFoundException());
    await pump(tester);

    await swipe(tester, 't-done');
    await tester.tap(find.text('Archiver'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Cette action n'est pas encore disponible. Réessayez plus tard.",
      ),
      findsOneWidget,
    );
    expect(find.text('Paris → Abidjan'), findsOneWidget);
  });

  testWidgets('échec réseau : message d\'erreur, tuile restaurée', (
    tester,
  ) async {
    when(() => repo.archive('t-done')).thenThrow(const OfflineException());
    await pump(tester);

    await swipe(tester, 't-done');
    await tester.tap(find.text('Archiver'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Paris → Abidjan'), findsOneWidget);
  });

  group('ligne « Archivées (n) » (FLUTTER-FR)', () {
    testWidgets('compte les archives des deux types et remplace la puce', (
      tester,
    ) async {
      when(() => bidRepo.myNegotiations(archived: true)).thenAnswer(
        (_) async => [_trip('b-arch', arrival: 'Lomé', archived: true)],
      );
      await pump(tester);

      verify(() => repo.findMine(archived: true)).called(1);
      verify(() => bidRepo.myNegotiations(archived: true)).called(1);
      final row = find.byKey(const Key('nego-archived-row'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Archivées')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('2')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Archivées (2)'), findsOneWidget);
      expect(find.byKey(const Key('nego-filter-archived')), findsNothing);
    });

    testWidgets('masquée quand rien n\'est archivé', (tester) async {
      when(() => repo.findMine(archived: true)).thenAnswer((_) async => []);
      await pump(tester);

      expect(find.byKey(const Key('nego-archived-row')), findsNothing);
    });

    testWidgets('ouvre les archives : seules elles, avec Désarchiver', (
      tester,
    ) async {
      when(() => bidRepo.myNegotiations(archived: true)).thenAnswer(
        (_) async => [_trip('b-arch', arrival: 'Lomé', archived: true)],
      );
      when(() => repo.unarchive('t-arch')).thenAnswer((_) async {});
      await pump(tester);

      await tester.tap(find.byKey(const Key('nego-archived-row')));
      await tester.pumpAndSettle();

      // Les fils courants ne sont plus affichés, seulement les archives.
      expect(find.text('Paris → Abidjan'), findsNothing);
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.text('Lyon → Lomé'), findsOneWidget);
      // Ni puces ni ligne « Archivées » sur l'écran d'archives.
      expect(find.byKey(const Key('nego-filter-all')), findsNothing);
      expect(find.byKey(const Key('nego-archived-row')), findsNothing);

      await swipe(tester, 't-arch');
      expect(find.text('Désarchiver'), findsOneWidget);
      expect(find.text('Supprimer'), findsNothing);
      await tester.tap(find.text('Désarchiver'));
      await tester.pump();

      expect(find.text('Discussion désarchivée'), findsOneWidget);
      verify(() => repo.unarchive('t-arch')).called(1);
      await tester.pumpAndSettle();
      // Le fil désarchivé doit revenir dans la liste courante.
      verify(() => repo.findMine()).called(greaterThanOrEqualTo(2));
    });

    testWidgets('archiver recharge le compteur', (tester) async {
      when(() => repo.archive('t-done')).thenAnswer((_) async {});
      await pump(tester);
      verify(() => repo.findMine(archived: true)).called(1);

      await swipe(tester, 't-done');
      await tester.tap(find.byKey(const Key('nego-slide-archive')));
      await tester.pumpAndSettle();

      verify(() => repo.findMine(archived: true)).called(1);
    });

    testWidgets('écran d\'archives : état vide dédié', (tester) async {
      when(() => repo.findMine(archived: true)).thenAnswer((_) async => []);
      await pump(tester, archivedOnly: true);

      expect(
        find.text('Les discussions que vous archivez apparaîtront ici.'),
        findsOneWidget,
      );
    });

    testWidgets('écran d\'archives : réessayer recharge les archives', (
      tester,
    ) async {
      when(
        () => repo.findMine(archived: true),
      ).thenThrow(const OfflineException());
      when(
        () => bidRepo.myNegotiations(archived: true),
      ).thenThrow(const OfflineException());
      await pump(tester, archivedOnly: true);

      expect(find.text('Réessayer'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      verify(() => repo.findMine(archived: true)).called(2);
    });

    testWidgets('reste atteignable quand aucune discussion n\'est en cours', (
      tester,
    ) async {
      when(() => repo.findMine()).thenAnswer((_) async => []);
      await pump(tester);

      expect(find.text('Rechercher un trajet'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nego-archived-row')));
      await tester.pumpAndSettle();
      expect(find.text('Paris → Dakar'), findsOneWidget);
    });
  });

  /// FLUTTER-FR : « Archi… », « Supp… » à 0.55. Les libellés tiennent en
  /// entier, sur une ligne, avec une icône de 28.
  testWidgets('volet : libellés entiers, icônes de 28', (tester) async {
    await pump(tester);
    await swipe(tester, 't-done');

    for (final label in ['Archiver', 'Supprimer']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      final box = tester.getSize(find.text(label));
      final fitted = find.ancestor(
        of: find.text(label),
        matching: find.byType(FittedBox),
      );
      // Rendu à sa taille naturelle : aucune réduction n'a été nécessaire.
      expect(tester.getSize(fitted).width, greaterThanOrEqualTo(box.width));
    }
    final icons = tester.widgetList<Icon>(
      find.descendant(
        of: find.byKey(const Key('nego-slide-archive')),
        matching: find.byType(Icon),
      ),
    );
    expect(icons.single.size, 28);
  });
}
