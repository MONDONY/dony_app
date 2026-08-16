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
  departureDate: departureDate ?? DateTime(2026, 9, 1),
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
            desiredDate: DateTime(2026, 9, 1),
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
          desiredDate: DateTime(2026, 9, 1),
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
      when(
        () => announcementRepo.getMyAnnouncements(),
      ).thenAnswer((_) async => (announcements: <AnnouncementModel>[], totalElements: 0));

      var createTapped = false;
      await tester.pumpWidget(
        _harness(
          TripPickerSection(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            desiredDate: DateTime(2026, 9, 1),
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
}
