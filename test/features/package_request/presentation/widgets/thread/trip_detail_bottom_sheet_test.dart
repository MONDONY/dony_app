import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

LinkedTripSummary _trip() => const LinkedTripSummary(
      announcementId: 'ann-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: '2026-06-12',
      departureTime: '14:30',
      transportMode: 'PLANE',
      pickupAddressLabel: 'Gare de Lyon, Paris',
      deliveryAddressLabel: 'Plateau, Dakar',
      availableKg: 18,
      description: 'Remise possible la veille au soir.',
    );

void main() {
  late _MockNegotiationBloc bloc;

  setUp(() {
    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());
  });

  Future<void> openSheet(
    WidgetTester tester, {
    required bool isSender,
    LinkedTripSummary? trip,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => TripDetailBottomSheet.show(
            context,
            trip: trip ?? _trip(),
            isSender: isSender,
            bloc: bloc,
            threadId: 't-1',
          ),
          child: const Text('Ouvrir'),
        ),
      ),
    ));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  group('TripDetailBottomSheet', () {
    testWidgets('affiche le titre et l\'itinéraire', (tester) async {
      await openSheet(tester, isSender: true);
      expect(find.text('Trajet lié'), findsOneWidget);
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Dakar'), findsOneWidget);
    });

    testWidgets('affiche les chips mode, poids et date', (tester) async {
      await openSheet(tester, isSender: true);
      expect(find.textContaining('Avion'), findsOneWidget);
      expect(find.textContaining('18 kg dispo'), findsOneWidget);
      expect(find.textContaining('12 juin 2026'), findsOneWidget);
    });

    testWidgets('affiche les adresses remise et livraison', (tester) async {
      await openSheet(tester, isSender: true);
      expect(find.textContaining('Gare de Lyon, Paris'), findsOneWidget);
      expect(find.textContaining('Plateau, Dakar'), findsOneWidget);
    });

    testWidgets('affiche la note du voyageur', (tester) async {
      await openSheet(tester, isSender: true);
      expect(
          find.text('Remise possible la veille au soir.'), findsOneWidget);
    });

    testWidgets('côté expéditeur → bouton "Refuser le trajet" présent',
        (tester) async {
      await openSheet(tester, isSender: true);
      expect(find.text('Refuser le trajet'), findsOneWidget);
    });

    testWidgets('côté voyageur → pas de bouton "Refuser le trajet"',
        (tester) async {
      await openSheet(tester, isSender: false);
      expect(find.text('Refuser le trajet'), findsNothing);
    });

    testWidgets('tap "Refuser le trajet" ouvre le sheet de raison',
        (tester) async {
      await openSheet(tester, isSender: true);
      await tester.tap(find.text('Refuser le trajet'));
      await tester.pumpAndSettle();
      expect(find.text('Refuser ce trajet'), findsOneWidget);
    });

    testWidgets('gère les champs nullables sans crash', (tester) async {
      await openSheet(
        tester,
        isSender: true,
        trip: const LinkedTripSummary(announcementId: 'ann-x'),
      );
      expect(find.text('Trajet lié'), findsOneWidget);
    });

    testWidgets('affiche l\'icône bus pour le mode BUS', (tester) async {
      await openSheet(
        tester,
        isSender: false,
        trip: const LinkedTripSummary(
            announcementId: 'ann-bus', transportMode: 'BUS'),
      );
      expect(find.textContaining('🚌'), findsOneWidget);
    });

    testWidgets('affiche l\'icône bateau pour le mode BOAT', (tester) async {
      await openSheet(
        tester,
        isSender: false,
        trip: const LinkedTripSummary(
            announcementId: 'ann-boat', transportMode: 'BOAT'),
      );
      expect(find.textContaining('🚢'), findsOneWidget);
    });

    testWidgets('affiche l\'icône par défaut pour un mode inconnu',
        (tester) async {
      await openSheet(
        tester,
        isSender: false,
        trip: const LinkedTripSummary(
            announcementId: 'ann-unknown', transportMode: 'UNKNOWN_MODE'),
      );
      expect(find.textContaining('📦'), findsOneWidget);
    });

    testWidgets('_formatDate retourne la date brute pour une chaîne invalide',
        (tester) async {
      // Provide an invalid ISO date — the catch branch returns isoDate itself
      await openSheet(
        tester,
        isSender: false,
        trip: const LinkedTripSummary(
            announcementId: 'ann-bad', departureDate: 'not-a-date'),
      );
      // Should not crash; the chip displays the raw string
      expect(find.textContaining('not-a-date'), findsOneWidget);
    });
  });
}
