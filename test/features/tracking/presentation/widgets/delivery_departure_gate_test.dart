import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

BidModel _bid({
  DateTime? departureAt,
  DateTime? departureDate,
  String? departureTime,
}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  weightKg: 2,
  status: 'IN_TRANSIT',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  departureAt: departureAt,
  departureDate: departureDate,
  departureTime: departureTime,
);

/// Horloge pilotée par le test.
class _Clock {
  _Clock(this.value);
  DateTime value;
  DateTime call() => value;
}

Widget _gate(
  DeliveryWindow? window,
  _Clock clock, {
  Locale locale = AppL10n.fr,
}) => localizedApp(
  Scaffold(
    body: DeliveryDepartureGate(
      window: window,
      now: clock.call,
      builder: (context, hint) => Column(
        children: [
          ElevatedButton(
            key: const Key('btn'),
            onPressed: hint == null ? () {} : null,
            child: const Text('go'),
          ),
          if (hint != null) DeliveryLockedHint(hint),
        ],
      ),
    ),
  ),
  locale: locale,
);

bool _enabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byKey(const Key('btn'))).enabled;

void main() {
  group('DeliveryWindow.fromBid', () {
    test('departureAt du back → instant, heure connue', () {
      final at = DateTime.utc(2026, 10, 8, 8, 30);
      final w = DeliveryWindow.fromBid(_bid(departureAt: at))!;
      expect(w.hasTime, isTrue);
      expect(w.opensAt, at);
    });

    test('repli date + heure (fuseau de l\'appareil)', () {
      final w = DeliveryWindow.fromBid(
        _bid(departureDate: DateTime(2026, 10, 8), departureTime: '14:05'),
      )!;
      expect(w.hasTime, isTrue);
      expect(w.opensAt, DateTime(2026, 10, 8, 14, 5));
    });

    test('date seule → ouvert à partir du lendemain', () {
      final w = DeliveryWindow.fromBid(
        _bid(departureDate: DateTime(2026, 10, 8)),
      )!;
      expect(w.hasTime, isFalse);
      expect(w.opensAt, DateTime(2026, 10, 9));
    });

    test('aucune date → null (bouton actif)', () {
      expect(DeliveryWindow.fromBid(_bid()), isNull);
    });
  });

  group('DeliveryDepartureGate', () {
    final departure = DateTime(2026, 10, 8, 14, 30);
    final window = DeliveryWindow(departure: departure, hasTime: true);

    testWidgets('avant le départ : désactivé, date et heure expliquées', (
      tester,
    ) async {
      await tester.pumpWidget(
        _gate(window, _Clock(departure.subtract(const Duration(hours: 3)))),
      );

      expect(_enabled(tester), isFalse);
      expect(
        find.text(
          'Disponible après le départ du trajet (le 8 oct. 2026 à 14:30)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('anglais : explication traduite', (tester) async {
      enableEnglish();
      await tester.pumpWidget(
        _gate(
          window,
          _Clock(departure.subtract(const Duration(hours: 3))),
          locale: AppL10n.en,
        ),
      );

      expect(
        find.text('Available after the trip departs (on Oct 8, 2026 at 14:30)'),
        findsOneWidget,
      );
    });

    testWidgets('après le départ : actif, sans explication', (tester) async {
      await tester.pumpWidget(
        _gate(window, _Clock(departure.add(const Duration(minutes: 1)))),
      );

      expect(_enabled(tester), isTrue);
      expect(find.byType(DeliveryLockedHint), findsNothing);
    });

    testWidgets('date inconnue : actif', (tester) async {
      await tester.pumpWidget(_gate(null, _Clock(departure)));

      expect(_enabled(tester), isTrue);
      expect(find.byType(DeliveryLockedHint), findsNothing);
    });

    testWidgets(
      'date seule : verrouillé le jour même, explication sans heure',
      (tester) async {
        final dayOnly = DeliveryWindow(
          departure: DateTime(2026, 10, 8),
          hasTime: false,
        );
        await tester.pumpWidget(
          _gate(dayOnly, _Clock(DateTime(2026, 10, 8, 23))),
        );

        expect(_enabled(tester), isFalse);
        expect(
          find.text('Disponible après le départ du trajet (le 8 oct. 2026)'),
          findsOneWidget,
        );
      },
    );

    testWidgets('s\'active seul à l\'heure du départ, sans relancer l\'app', (
      tester,
    ) async {
      final clock = _Clock(departure.subtract(const Duration(minutes: 10)));
      await tester.pumpWidget(_gate(window, clock));
      expect(_enabled(tester), isFalse);

      clock.value = departure.add(const Duration(seconds: 1));
      await tester.pump(const Duration(minutes: 10, seconds: 1));

      expect(_enabled(tester), isTrue);
      expect(find.byType(DeliveryLockedHint), findsNothing);
    });

    testWidgets('départ lointain : revérifie au plus tard toutes les heures', (
      tester,
    ) async {
      final clock = _Clock(departure.subtract(const Duration(days: 3)));
      await tester.pumpWidget(_gate(window, clock));
      expect(_enabled(tester), isFalse);

      // L'appareil a dormi : l'horloge a sauté au-delà du départ.
      clock.value = departure.add(const Duration(minutes: 5));
      await tester.pump(
        DeliveryDepartureGate.maxWait + const Duration(seconds: 1),
      );

      expect(_enabled(tester), isTrue);
    });

    testWidgets('retour au premier plan : réévalue le verrou', (tester) async {
      final clock = _Clock(departure.subtract(const Duration(days: 3)));
      await tester.pumpWidget(_gate(window, clock));
      expect(_enabled(tester), isFalse);

      clock.value = departure.add(const Duration(minutes: 5));
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(_enabled(tester), isTrue);
    });

    testWidgets('la minuterie est annulée à la destruction', (tester) async {
      await tester.pumpWidget(
        _gate(window, _Clock(departure.subtract(const Duration(hours: 2)))),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      // Une minuterie restée active ferait échouer le test (pending timers).
      await tester.pump(const Duration(hours: 3));
    });
  });

  // Mode recette (FLUTTER-FA) : le back laisse un testeur livrer avant le
  // départ, le bouton ne doit pas l'en empêcher.
  group('mode recette', () {
    final departure = DateTime.now().add(const Duration(days: 4));
    final window = DeliveryWindow(departure: departure, hasTime: true);

    Widget withUser(UserModel? user) {
      final bloc = _MockAuthBloc();
      when(() => bloc.state).thenReturn(
        user == null ? const AuthInitial() : AuthAuthenticated(user),
      );
      return BlocProvider<AuthBloc>.value(
        value: bloc,
        child: _gate(window, _Clock(DateTime.now())),
      );
    }

    testWidgets('testeur (recetteMode servi par /auth/me) : bouton actif', (
      tester,
    ) async {
      await tester.pumpWidget(
        withUser(
          const UserModel(
            id: 'u1',
            roles: [],
            kycStatus: 'VERIFIED',
            status: 'ACTIVE',
            recetteMode: true,
          ),
        ),
      );

      expect(_enabled(tester), isTrue);
      expect(find.byKey(const Key('delivery-locked-hint')), findsNothing);
    });

    testWidgets('compte normal ou champ absent : verrou habituel', (
      tester,
    ) async {
      await tester.pumpWidget(
        withUser(
          const UserModel(
            id: 'u1',
            roles: [],
            kycStatus: 'VERIFIED',
            status: 'ACTIVE',
          ),
        ),
      );
      expect(_enabled(tester), isFalse);
      expect(find.byKey(const Key('delivery-locked-hint')), findsOneWidget);

      await tester.pumpWidget(withUser(null));
      expect(_enabled(tester), isFalse);
    });

    test('UserModel.recetteMode : lu dans /auth/me, faux par défaut', () {
      expect(UserModel.fromJson(const {'id': 'u1'}).recetteMode, isFalse);
      final tester = UserModel.fromJson(const {
        'id': 'u1',
        'recetteMode': true,
      });
      expect(tester.recetteMode, isTrue);
      expect(tester.toJson()['recetteMode'], isTrue);
      expect(
        UserModel.fromJson(tester.toJson()).recetteMode,
        isTrue,
        reason: 'aller-retour JSON (cache local)',
      );
      expect(tester.copyWith(firstName: 'Awa').recetteMode, isTrue);
      expect(tester.copyWith(recetteMode: false).recetteMode, isFalse);
      expect(
        UserModel.fromJson(const {
          'id': 'u1',
          'recetteMode': 'true',
        }).recetteMode,
        isFalse,
      );
    });
  });
}
