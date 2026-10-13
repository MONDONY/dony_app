import 'package:bloc_test/bloc_test.dart';
import 'package:dony/app/main_shell.dart';
import 'package:dony/app/widgets/dony_nav_item.dart';
import 'package:dony/core/config/flights_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

class _MockTravelerBidsBloc
    extends MockBloc<TravelerBidsEvent, TravelerBidsState>
    implements TravelerBidsBloc {}

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

/// Visiteur : pas de flux Firestore pour le compteur de Messages.
class _GuestProbe implements FirebaseSessionProbe {
  const _GuestProbe();
  @override
  bool get hasSession => false;
  @override
  bool get isAnonymous => false;
  @override
  bool get hasRealSession => false;
}

void main() {
  late List<int> taps;

  setUp(() {
    taps = [];
    if (getIt.isRegistered<FirebaseSessionProbe>()) {
      getIt.unregister<FirebaseSessionProbe>();
    }
    getIt.registerSingleton<FirebaseSessionProbe>(const _GuestProbe());
  });

  tearDown(() {
    getIt.unregister<FirebaseSessionProbe>();
    resetFlightsFlagForTest();
  });

  Future<void> pumpNav(
    WidgetTester tester, {
    int currentIndex = 1,
    Locale locale = AppL10n.fr,
  }) async {
    final auth = _MockAuthBloc();
    when(() => auth.state).thenReturn(const AuthInitial());
    final role = _MockActiveRoleCubit();
    when(() => role.state).thenReturn(ActiveRole.sender);
    final travelerBids = _MockTravelerBidsBloc();
    when(() => travelerBids.state).thenReturn(const TravelerBidsInitial());
    final negos = _MockNegotiationListBloc();
    when(() => negos.state).thenReturn(NegotiationListState());

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<ActiveRoleCubit>.value(value: role),
            BlocProvider<TravelerBidsBloc>.value(value: travelerBids),
            BlocProvider<NegotiationListBloc>.value(value: negos),
          ],
          child: Scaffold(
            bottomNavigationBar: MainShellBottomNav(
              currentIndex: currentIndex,
              onTap: taps.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const frLabels = ['Rechercher', 'Activités', 'Messages', 'Moi'];

  for (final flights in [false, true]) {
    testWidgets(
      'cinq onglets avec libellés, billets ${flights ? 'allumés' : 'éteints'}',
      (tester) async {
        setFlightsEnabled(flights);
        await pumpNav(tester);

        // Quatre items et l'orbe Suivi au centre : plus d'onglet Billets.
        expect(find.byType(DonyNavItem), findsNWidgets(4));
        for (final label in frLabels) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.text('Billets'), findsNothing);
      },
    );
  }

  testWidgets('chaque onglet garde son index de branche', (tester) async {
    setFlightsEnabled(true);
    await pumpNav(tester, currentIndex: 0);

    await tester.tap(find.text('Rechercher'));
    await tester.tap(find.text('Activités'));
    await tester.tap(find.text('Messages'));
    await tester.tap(find.text('Moi'));

    expect(taps, [0, 1, 3, 4]);
  });

  testWidgets('libellés traduits en anglais', (tester) async {
    await pumpNav(tester, locale: AppL10n.en);

    for (final label in ['Search', 'Activity', 'Messages', 'Profile']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
