import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/presentation/widgets/trip_picker_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

AnnouncementModel _announcement({
  required String id,
  required String status,
  required String departureCity,
  required String arrivalCity,
  DateTime? departureDate,
  double availableKg = 20,
}) => AnnouncementModel(
  id: id,
  travelerId: 'trav-1',
  departureCity: departureCity,
  arrivalCity: arrivalCity,
  departureDate: departureDate ?? DateTime(2026, 9),
  availableKg: availableKg,
  totalKg: 23,
  pricePerKg: 7,
  status: status,
  transportMode: TransportMode.plane,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  acceptedPaymentMethods: const {
    BidPaymentMethod.stripe,
    BidPaymentMethod.cash,
  },
);

late MockAnnouncementRepository announcementRepo;

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  setUp(() {
    announcementRepo = MockAnnouncementRepository();
    if (getIt.isRegistered<AnnouncementRepository>()) {
      getIt.unregister<AnnouncementRepository>();
    }
    getIt.registerFactory<AnnouncementRepository>(() => announcementRepo);
  });

  tearDown(() {
    if (getIt.isRegistered<AnnouncementRepository>()) {
      getIt.unregister<AnnouncementRepository>();
    }
  });

  testWidgets(
    'shows only ACTIVE trips matching corridor, date window and capacity',
    (tester) async {
      when(() => announcementRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (
          announcements: [
            _announcement(
              id: 'a1',
              status: 'ACTIVE',
              departureCity: 'Paris',
              arrivalCity: 'Dakar',
            ),
            _announcement(
              id: 'a2',
              status: 'COMPLETED',
              departureCity: 'Paris',
              arrivalCity: 'Dakar',
            ),
            _announcement(
              id: 'a3',
              status: 'ACTIVE',
              departureCity: 'Lyon',
              arrivalCity: 'Dakar',
            ),
          ],
          totalElements: 3,
        ),
      );

      await tester.pumpWidget(
        _harness(
          TripPickerSection(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            desiredDate: DateTime(2026, 9),
            dateToleranceDays: 3,
            weightKg: 10,
            onSelected: (_) {},
            onCreateDedicated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trip-tile-0')), findsOneWidget);
      expect(find.text('Tes trajets compatibles'), findsOneWidget);
    },
  );

  testWidgets('tapping a trip tile calls onSelected with the announcement', (
    tester,
  ) async {
    when(() => announcementRepo.getMyAnnouncements()).thenAnswer(
      (_) async => (
        announcements: [
          _announcement(
            id: 'a1',
            status: 'ACTIVE',
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
          ),
        ],
        totalElements: 1,
      ),
    );

    AnnouncementModel? selected;
    await tester.pumpWidget(
      _harness(
        TripPickerSection(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 9),
          dateToleranceDays: 3,
          weightKg: 10,
          onSelected: (ann) => selected = ann,
          onCreateDedicated: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('trip-tile-select-inkwell')));
    await tester.pumpAndSettle();

    expect(selected?.id, 'a1');
  });

  testWidgets(
    'tapping "Créer un nouveau trajet" calls onCreateDedicated, not navigation',
    (tester) async {
      when(() => announcementRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (announcements: <AnnouncementModel>[], totalElements: 0),
      );

      var createTapped = false;
      await tester.pumpWidget(
        _harness(
          TripPickerSection(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            desiredDate: DateTime(2026, 9),
            dateToleranceDays: 3,
            weightKg: 10,
            onSelected: (_) {},
            onCreateDedicated: () => createTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Créer un nouveau trajet'));
      await tester.pump();

      expect(createTapped, isTrue);
    },
  );

  testWidgets(
    'échec réseau → message d\'erreur + Réessayer, pas la fausse liste vide',
    (tester) async {
      when(
        () => announcementRepo.getMyAnnouncements(),
      ).thenThrow(Exception('network down'));

      await tester.pumpWidget(
        _harness(
          TripPickerSection(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            desiredDate: DateTime(2026, 9),
            dateToleranceDays: 3,
            weightKg: 10,
            onSelected: (_) {},
            onCreateDedicated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sans le garde-fou, l'écran vide affiche "Aucun de tes trajets ne
      // correspond" — indiscernable pour l'utilisateur d'un vrai échec réseau.
      expect(find.text('Aucun de tes trajets ne correspond'), findsNothing);
      expect(find.text('Impossible de charger tes trajets'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    },
  );

  testWidgets(
    '"Réessayer" relance le chargement et affiche la liste en cas de succès',
    (tester) async {
      var callCount = 0;
      when(() => announcementRepo.getMyAnnouncements()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw Exception('network down');
        return (
          announcements: [
            _announcement(
              id: 'a1',
              status: 'ACTIVE',
              departureCity: 'Paris',
              arrivalCity: 'Dakar',
            ),
          ],
          totalElements: 1,
        );
      });

      await tester.pumpWidget(
        _harness(
          TripPickerSection(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            desiredDate: DateTime(2026, 9),
            dateToleranceDays: 3,
            weightKg: 10,
            onSelected: (_) {},
            onCreateDedicated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Impossible de charger tes trajets'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Impossible de charger tes trajets'), findsNothing);
      expect(find.byKey(const Key('trip-tile-0')), findsOneWidget);
    },
  );

  testWidgets(
    'changement de desiredDate après montage recharge la liste des trajets',
    (tester) async {
      when(() => announcementRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (
          announcements: [
            // Ne matche que la fenêtre du 1er septembre, pas celle du 1er juin.
            _announcement(
              id: 'a1',
              status: 'ACTIVE',
              departureCity: 'Paris',
              arrivalCity: 'Dakar',
            ),
          ],
          totalElements: 1,
        ),
      );

      Widget build(DateTime desiredDate) => _harness(
        TripPickerSection(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: desiredDate,
          dateToleranceDays: 3,
          weightKg: 10,
          onSelected: (_) {},
          onCreateDedicated: () {},
        ),
      );

      await tester.pumpWidget(build(DateTime(2026, 6)));
      await tester.pumpAndSettle();
      // Hors fenêtre (juin vs trajet en septembre) : aucun trajet compatible.
      expect(find.byKey(const Key('trip-tile-0')), findsNothing);

      await tester.pumpWidget(build(DateTime(2026, 9)));
      await tester.pumpAndSettle();
      // Même widget, nouvelle desiredDate → didUpdateWidget recharge et le
      // trajet de septembre apparaît désormais.
      expect(find.byKey(const Key('trip-tile-0')), findsOneWidget);
    },
  );
}
