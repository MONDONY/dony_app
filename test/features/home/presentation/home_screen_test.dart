import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockNotificationBloc
    extends MockBloc<NotificationEvent, NotificationState>
    implements NotificationBloc {}

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

class MockHiveService extends Mock implements HiveService {}

// Simule un utilisateur qui a déjà publié → banner masqué pour tester la liste principale
// (le banner est testé séparément dans role_guidance_banner_test.dart)
class _FakeBox extends Fake implements Box<dynamic> {
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    if (key == HiveService.kHasPublishedAsTraveler ||
        key == HiveService.kHasPublishedAsSender) {
      return true;
    }
    return defaultValue;
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {}
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

UserModel _makeUser({List<String> roles = const ['ROLE_SENDER']}) => UserModel(
      id: 'uid-1',
      phoneNumber: '+33600000000',
      firstName: 'Ibrahima',
      lastName: 'Diallo',
      roles: roles,
      kycStatus: 'VERIFIED',
      status: 'ACTIVE',
    );

AnnouncementModel _makeAnn({String id = 'a1'}) => AnnouncementModel(
      id: id,
      travelerId: 'traveler-1',
      departureCity: 'Paris · CDG, ORY',
      arrivalCity: 'Dakar · DKR',
      departureDate: DateTime(2026, 6, 15),
      availableKg: 10,
      totalKg: 20,
      pricePerKg: 7,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

Widget _buildHome({
  AnnouncementState? announcementState,
  ActiveRole role = ActiveRole.sender,
  UserModel? user,
  BidState? bidState,
}) {
  final announcementBloc = MockAnnouncementBloc();
  final authBloc = MockAuthBloc();
  final roleCubit = MockActiveRoleCubit();
  final notifBloc = MockNotificationBloc();
  final bidBloc = MockBidBloc();

  when(() => announcementBloc.state)
      .thenReturn(announcementState ?? AnnouncementInitial());
  when(() => announcementBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => authBloc.state).thenReturn(AuthAuthenticated(user ?? _makeUser()));
  when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => roleCubit.state).thenReturn(role);
  when(() => roleCubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => notifBloc.state).thenReturn(const NotificationInitial());
  when(() => notifBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => bidBloc.state).thenReturn(bidState ?? BidInitial());
  when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());

  return MultiBlocProvider(
    providers: [
      BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
      BlocProvider<NotificationBloc>.value(value: notifBloc),
      BlocProvider<BidBloc>.value(value: bidBloc),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr'), Locale('en')],
      locale: const Locale('fr'),
      home: const HomeScreen(),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    final hive = MockHiveService();
    final box = _FakeBox();
    when(() => hive.userPrefs).thenReturn(box);
    when(() => hive.listenUserPrefs(keys: any(named: 'keys')))
        .thenReturn(ValueNotifier<Box>(box));
    getIt.registerSingleton<HiveService>(hive);
  });

  tearDown(getIt.reset);

  group('HomeScreen — Map sender view', () {
    testWidgets('shows corridor label in search bar', (tester) async {
      await tester.pumpWidget(_buildHome());
      await tester.pump();

      expect(find.text('Tous les corridors'), findsWidgets);
    });

    testWidgets('shows Voyageurs tab active by default with count 0',
        (tester) async {
      await tester.pumpWidget(_buildHome());
      await tester.pump();

      expect(find.text('Voyageurs · 0'), findsOneWidget);
    });

    testWidgets('tapping Demandes tab shows placeholder', (tester) async {
      await tester.pumpWidget(_buildHome());
      await tester.pump();

      await tester.tap(find.text('Demandes'));
      await tester.pump();

      expect(find.text('Demandes bientôt disponibles'), findsOneWidget);
    });

    testWidgets('shows TravelerCards when announcements loaded',
        (tester) async {
      await tester.pumpWidget(_buildHome(
        announcementState: AnnouncementSearchLoaded(
          [_makeAnn(), _makeAnn(id: 'a2')],
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(TravelerCard), findsAtLeastNWidgets(1));
    });

    testWidgets('shows empty message when search loaded with no results',
        (tester) async {
      await tester.pumpWidget(_buildHome(
        announcementState: AnnouncementSearchLoaded(const []),
      ));
      await tester.pump();

      expect(find.text('Aucun voyageur sur ce corridor'), findsOneWidget);
    });
  });

  group('HomeScreen — Traveler view', () {
    testWidgets('renders traveler-specific stats label', (tester) async {
      await tester.pumpWidget(_buildHome(role: ActiveRole.traveler));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('CE MOIS-CI'), findsOneWidget);
    });
  });
}
