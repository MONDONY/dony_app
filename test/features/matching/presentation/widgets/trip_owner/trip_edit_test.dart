// Règle d'édition du trajet partagée par la grille, les sheets « Votre
// trajet », le pied et le menu : trajet engagé (demandes, colis acceptés,
// compteurs du modèle tant que les colis n'ont pas répondu) et statut ;
// ouverture de l'édition avec relecture au retour.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_edit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

const _statuses = [
  'DRAFT',
  'ACTIVE',
  'FULL',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'REMOVED_BY_ADMIN',
  'SOMETHING_NEW',
];

AnnouncementModel _trip({
  String status = 'ACTIVE',
  int? bidsCount,
  int pendingBidCount = 0,
  int confirmedParcelCount = 0,
}) {
  final now = DateTime(2026, 10, 30);
  return AnnouncementModel(
    id: 'trip-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Abidjan',
    departureDate: now.add(const Duration(days: 3)),
    availableKg: 20,
    totalKg: 20,
    status: status,
    createdAt: now,
    updatedAt: now,
    bidsCount: bidsCount,
    pendingBidCount: pendingBidCount,
    confirmedParcelCount: confirmedParcelCount,
  );
}

BidModel _bid(String id, String status, {String? rejectionReason}) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  status: status,
  rejectionReason: rejectionReason,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  group('tripHasBids', () {
    test('trajet vide, colis chargés ou non', () {
      expect(tripHasBids(_trip(), null), isFalse);
      expect(tripHasBids(_trip(), const []), isFalse);
    });

    test('bidsCount du back suffit', () {
      expect(tripHasBids(_trip(bidsCount: 1), const []), isTrue);
    });

    test('colis pas chargés : compteurs du modèle', () {
      expect(tripHasBids(_trip(pendingBidCount: 1), null), isTrue);
      expect(tripHasBids(_trip(confirmedParcelCount: 2), null), isTrue);
    });

    test('colis chargés : ils priment sur les compteurs du modèle', () {
      expect(
        tripHasBids(
          _trip(pendingBidCount: 3, confirmedParcelCount: 3),
          const [],
        ),
        isFalse,
      );
      expect(tripHasBids(_trip(), [_bid('b1', 'PENDING')]), isTrue);
      expect(tripHasBids(_trip(), [_bid('b1', 'PAYMENT_ESCROWED')]), isTrue);
      // Tous les colis acceptés : `bidsCount` vaut 0, le trajet est engagé.
      expect(
        tripHasBids(_trip(bidsCount: 0), [_bid('b1', 'ACCEPTED')]),
        isTrue,
      );
    });

    test('demande refusée ou auto-annulée : pas d\'engagement', () {
      expect(
        tripHasBids(_trip(), [
          _bid('b1', 'REJECTED'),
          _bid('b2', 'CANCELLED', rejectionReason: 'TRAVELER_NO_RESPONSE'),
        ]),
        isFalse,
      );
    });
  });

  group('canEditTrip', () {
    for (final status in _statuses) {
      test('$status sans demande', () {
        expect(
          canEditTrip(_trip(status: status), false),
          status == 'ACTIVE' || status == 'DRAFT',
        );
      });
      test('$status avec demandes : jamais', () {
        expect(canEditTrip(_trip(status: status), true), isFalse);
      });
    }
  });

  group('openTripEdit', () {
    late _MockAnnouncementBloc bloc;
    late Object? extra;

    setUpAll(() {
      registerFallbackValue(AnnouncementDetailRequested('fallback'));
    });

    setUp(() {
      bloc = _MockAnnouncementBloc();
      whenListen(
        bloc,
        const Stream<AnnouncementState>.empty(),
        initialState: AnnouncementInitial(),
      );
      extra = null;
    });

    Future<void> pump(WidgetTester tester, {bool withBloc = true}) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) {
              final page = Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => openTripEdit(context, _trip()),
                    child: const Text('edit'),
                  ),
                ),
              );
              return withBloc
                  ? BlocProvider<AnnouncementBloc>.value(
                      value: bloc,
                      child: page,
                    )
                  : page;
            },
          ),
          GoRoute(
            path: '/trips/create',
            builder: (context, state) {
              extra = state.extra;
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => context.pop(true),
                      child: const Text('save'),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('back'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
    }

    testWidgets('édition avec le trajet, relue si enregistrée', (tester) async {
      await pump(tester);
      expect(extra, isA<CreateTripArgs>());
      expect((extra! as CreateTripArgs).announcement?.id, 'trip-1');

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      final captured = verify(() => bloc.add(captureAny())).captured;
      expect(captured.single, isA<AnnouncementDetailRequested>());
      expect((captured.single as AnnouncementDetailRequested).id, 'trip-1');
    });

    testWidgets('retour sans enregistrer : rien n\'est relu', (tester) async {
      await pump(tester);
      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('sans bloc à l\'écran : l\'édition s\'ouvre, rien ne casse', (
      tester,
    ) async {
      await pump(tester, withBloc: false);
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('edit'), findsOneWidget);
    });
  });
}
