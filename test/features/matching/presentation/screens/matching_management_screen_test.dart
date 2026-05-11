import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/matching_management_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockPackageRequestBloc
    extends MockBloc<PackageRequestEvent, PackageRequestState>
    implements PackageRequestBloc {}

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

class _MockNegotiationRepository extends Mock implements NegotiationRepository {
}

void main() {
  late _MockAnnouncementBloc announcementBloc;
  late _MockBidBloc bidBloc;
  late _MockPackageRequestBloc packageBloc;
  late _MockNegotiationListBloc negoListBloc;
  late _MockNegotiationRepository negoRepo;

  setUp(() {
    announcementBloc = _MockAnnouncementBloc();
    bidBloc = _MockBidBloc();
    packageBloc = _MockPackageRequestBloc();
    negoListBloc = _MockNegotiationListBloc();
    negoRepo = _MockNegotiationRepository();

    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    when(() => announcementBloc.stream)
        .thenAnswer((_) => const Stream<AnnouncementState>.empty());
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream)
        .thenAnswer((_) => const Stream<BidState>.empty());
    when(() => packageBloc.state).thenReturn(const PackageRequestState());
    when(() => packageBloc.stream)
        .thenAnswer((_) => const Stream<PackageRequestState>.empty());
    when(() => negoListBloc.state).thenReturn(const NegotiationListState());
    when(() => negoListBloc.stream)
        .thenAnswer((_) => const Stream<NegotiationListState>.empty());
    when(() => negoRepo.findMine()).thenAnswer((_) async => []);

    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<BidBloc>()) getIt.unregister<BidBloc>();
    if (getIt.isRegistered<PackageRequestBloc>()) {
      getIt.unregister<PackageRequestBloc>();
    }
    if (getIt.isRegistered<NegotiationListBloc>()) {
      getIt.unregister<NegotiationListBloc>();
    }
    if (getIt.isRegistered<NegotiationRepository>()) {
      getIt.unregister<NegotiationRepository>();
    }
    getIt.registerFactory<AnnouncementBloc>(() => announcementBloc);
    getIt.registerFactory<BidBloc>(() => bidBloc);
    getIt.registerFactory<PackageRequestBloc>(() => packageBloc);
    getIt.registerFactory<NegotiationListBloc>(() => negoListBloc);
    getIt.registerLazySingleton<NegotiationRepository>(() => negoRepo);
  });

  tearDown(() {
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<BidBloc>()) getIt.unregister<BidBloc>();
    if (getIt.isRegistered<PackageRequestBloc>()) {
      getIt.unregister<PackageRequestBloc>();
    }
    if (getIt.isRegistered<NegotiationListBloc>()) {
      getIt.unregister<NegotiationListBloc>();
    }
    if (getIt.isRegistered<NegotiationRepository>()) {
      getIt.unregister<NegotiationRepository>();
    }
  });

  Widget wrap(ActiveRole role) {
    final cubit = _MockActiveRoleCubit();
    when(() => cubit.state).thenReturn(role);
    when(() => cubit.stream)
        .thenAnswer((_) => const Stream<ActiveRole>.empty());
    return MaterialApp(
      home: BlocProvider<ActiveRoleCubit>.value(
        value: cubit,
        child: const MatchingManagementScreen(),
      ),
    );
  }

  group('MatchingManagementScreen dispatch rôle-aware', () {
    testWidgets('sender → EnvoyerHubScreen rendu', (tester) async {
      await tester.pumpWidget(wrap(ActiveRole.sender));
      // Drain les animations `flutter_animate` du header (220ms fadeIn).
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(EnvoyerHubScreen), findsOneWidget);
      expect(find.byType(AnnouncementListScreen), findsNothing);
    });

    testWidgets('traveler → AnnouncementListScreen rendu', (tester) async {
      await tester.pumpWidget(wrap(ActiveRole.traveler));
      // `pumpAndSettle` évité — AnnouncementListScreen démarre un
      // auto-refresh qui ne se résout jamais en test. Le widget cible est
      // accessible dès le premier pump.
      await tester.pump();
      expect(find.byType(AnnouncementListScreen), findsOneWidget);
      expect(find.byType(EnvoyerHubScreen), findsNothing);
    });
  });
}
