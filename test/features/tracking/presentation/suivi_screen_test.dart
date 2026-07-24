import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/presentation/screens/suivi_screen.dart';
import 'package:dony/features/tracking/presentation/screens/tracking_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockAnalytics extends Mock implements AnalyticsService {}

UserModel _user({required List<String> roles, bool pro = false}) => UserModel(
  id: 'u1',
  roles: roles,
  kycStatus: 'APPROVED',
  status: 'ACTIVE',
  isProAccount: pro,
);

void main() {
  setUp(() {
    // Régression : SuiviScreen (in-shell) rend TrackingSearchScreen qui
    // consomme TrackingBloc. Sans provider → crash. SuiviScreen le fournit
    // désormais ; on enregistre un mock pour getIt<TrackingBloc>().
    if (getIt.isRegistered<TrackingBloc>()) getIt.unregister<TrackingBloc>();
    getIt.registerFactory<TrackingBloc>(() {
      final b = _MockTrackingBloc();
      when(() => b.state).thenReturn(TrackingInitial());
      return b;
    });
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(_MockAnalytics());
  });

  tearDown(() {
    if (getIt.isRegistered<TrackingBloc>()) getIt.unregister<TrackingBloc>();
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  Future<void> pump(WidgetTester tester, UserModel user) async {
    final auth = _MockAuthBloc();
    when(() => auth.state).thenReturn(AuthAuthenticated(user));
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: auth,
          child: const SuiviScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('expéditeur pur → TrackingSearchScreen rendu sans crash', (
    tester,
  ) async {
    await pump(tester, _user(roles: ['SENDER']));
    expect(find.byType(TrackingSearchScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Pas d'entrée scan pour un expéditeur pur.
    expect(find.text('Lire le QR d\'un trajet'), findsNothing);
  });

  testWidgets('voyageur occasionnel → recherche + entrée "Scanner un trajet"', (
    tester,
  ) async {
    await pump(tester, _user(roles: ['TRAVELER']));
    expect(find.byType(TrackingSearchScreen), findsOneWidget);
    expect(find.text('Lire le QR d\'un trajet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
