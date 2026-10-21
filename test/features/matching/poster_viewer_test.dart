import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/screens/trip_poster_screen.dart';
import 'package:dony/features/matching/presentation/widgets/poster/poster_viewer.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/sender/package_request_poster_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/l10n_test_helpers.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

const _ownerId = 'owner-1';

AuthState _signedIn(String id) => AuthAuthenticated(
  UserModel(id: id, roles: const [], kycStatus: 'VERIFIED', status: 'ACTIVE'),
);

AnnouncementModel _trip() => AnnouncementModel.fromJson({
  'id': 'a1',
  'travelerId': _ownerId,
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': DateTime(2026, 8, 20).toIso8601String(),
  'availableKg': 12.0,
  'totalKg': 23.0,
  'pricePerKg': 6.0,
  'pricePerKgDisplay': 8.0,
  'currency': 'EUR',
  'pricingMode': 'KG',
  'status': 'ACTIVE',
  'createdAt': DateTime(2026, 8).toIso8601String(),
  'updatedAt': DateTime(2026, 8).toIso8601String(),
});

PackageRequest _request() => PackageRequest(
  id: 'r1',
  senderId: _ownerId,
  departureCity: 'Lyon',
  arrivalCity: 'Abidjan',
  desiredDate: DateTime(2026, 10, 23),
  dateToleranceDays: 3,
  weightKg: 8,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: const ['Vêtements'],
  status: PackageRequestStatus.open,
  createdAt: DateTime(2026, 10),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  late _MockAuthBloc authBloc;
  late _MockAnalyticsService analytics;

  setUp(() {
    authBloc = _MockAuthBloc();
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    authBloc.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    required Widget screen,
    AuthState? auth,
  }) async {
    if (auth != null) {
      whenListen(authBloc, const Stream<AuthState>.empty(), initialState: auth);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: auth == null
            ? screen
            : BlocProvider<AuthBloc>.value(value: authBloc, child: screen),
      ),
    );
    await tester.pump();
  }

  group('isPosterOwner', () {
    testWidgets('sans identifiant de propriétaire : faux', (tester) async {
      late bool result;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            result = isPosterOwner(context, null);
            return const SizedBox();
          },
        ),
      );
      expect(result, isFalse);
    });

    testWidgets('sans AuthBloc dans l\'arbre : faux, sans lever', (
      tester,
    ) async {
      late bool result;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            result = isPosterOwner(context, _ownerId);
            return const SizedBox();
          },
        ),
      );
      expect(result, isFalse);
    });
  });

  group('affiche de trajet', () {
    Widget screen() => TripPosterScreen(
      announcement: _trip(),
      shareBaseUrl: 'https://api.yadony.test/api/v1',
    );

    testWidgets('propriétaire : « Mon affiche », mesuré comme propriétaire', (
      tester,
    ) async {
      await pump(tester, screen: screen(), auth: _signedIn(_ownerId));

      expect(find.text('Mon affiche'), findsOneWidget);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.tripPosterOpened,
          properties: {'shared_by_owner': true},
        ),
      ).called(1);
    });

    testWidgets('visiteur : titre neutre, mesuré comme visiteur', (
      tester,
    ) async {
      await pump(tester, screen: screen(), auth: _signedIn('someone-else'));

      expect(find.text('Affiche'), findsOneWidget);
      expect(find.text('Mon affiche'), findsNothing);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.tripPosterOpened,
          properties: {'shared_by_owner': false},
        ),
      ).called(1);
    });

    testWidgets('en anglais : « Poster » pour un visiteur', (tester) async {
      useEnglish();
      await pump(tester, screen: screen(), auth: _signedIn('someone-else'));

      expect(find.text('Poster'), findsOneWidget);
    });

    testWidgets('invité sans compte : titre neutre', (tester) async {
      await pump(tester, screen: screen(), auth: const AuthGuestSessionReady());

      expect(find.text('Affiche'), findsOneWidget);
    });
  });

  group('affiche de demande d\'envoi', () {
    Widget screen() => PackageRequestPosterScreen(
      request: _request(),
      shareBaseUrl: 'https://api.yadony.test/api/v1',
    );

    testWidgets('propriétaire : « Mon affiche », mesuré comme propriétaire', (
      tester,
    ) async {
      await pump(tester, screen: screen(), auth: _signedIn(_ownerId));

      expect(find.text('Mon affiche'), findsOneWidget);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.packageRequestPosterOpened,
          properties: {'shared_by_owner': true},
        ),
      ).called(1);
    });

    testWidgets('voyageur visiteur : titre neutre, mesuré comme visiteur', (
      tester,
    ) async {
      await pump(tester, screen: screen(), auth: _signedIn('someone-else'));

      expect(find.text('Affiche'), findsOneWidget);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.packageRequestPosterOpened,
          properties: {'shared_by_owner': false},
        ),
      ).called(1);
    });
  });

  test('canShareRequestPoster : ouverte ou en négociation seulement', () {
    PackageRequest with_(PackageRequestStatus s) => PackageRequest(
      id: 'r',
      senderId: 's',
      departureCity: 'A',
      arrivalCity: 'B',
      desiredDate: DateTime(2026, 10),
      dateToleranceDays: 0,
      weightKg: 1,
      parcelSize: ParcelSize.small,
      transportMode: TransportMode.plane,
      status: s,
      createdAt: DateTime(2026, 10),
    );

    expect(canShareRequestPoster(with_(PackageRequestStatus.open)), isTrue);
    expect(
      canShareRequestPoster(with_(PackageRequestStatus.negotiating)),
      isTrue,
    );
    for (final s in [
      PackageRequestStatus.draft,
      PackageRequestStatus.accepted,
      PackageRequestStatus.expired,
      PackageRequestStatus.cancelled,
      PackageRequestStatus.completed,
    ]) {
      expect(canShareRequestPoster(with_(s)), isFalse, reason: s.wireName);
    }
  });
}
