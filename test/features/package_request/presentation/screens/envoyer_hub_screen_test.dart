import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPackageRequestBloc
    extends MockBloc<PackageRequestEvent, PackageRequestState>
    implements PackageRequestBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockNegotiationRepository extends Mock implements NegotiationRepository {
}

void main() {
  late _MockPackageRequestBloc packageBloc;
  late _MockBidBloc bidBloc;
  late _MockNegotiationRepository negoRepo;

  setUpAll(() {
    registerFallbackValue(const FetchMyRequests());
    registerFallbackValue(const BidMyListAutoRefreshRequested());
  });

  setUp(() {
    packageBloc = _MockPackageRequestBloc();
    bidBloc = _MockBidBloc();
    negoRepo = _MockNegotiationRepository();

    when(() => packageBloc.state).thenReturn(const PackageRequestState());
    when(() => packageBloc.stream)
        .thenAnswer((_) => const Stream<PackageRequestState>.empty());
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream)
        .thenAnswer((_) => const Stream<BidState>.empty());
    when(() => negoRepo.findMine()).thenAnswer((_) async => []);

    if (getIt.isRegistered<PackageRequestBloc>()) {
      getIt.unregister<PackageRequestBloc>();
    }
    if (getIt.isRegistered<BidBloc>()) {
      getIt.unregister<BidBloc>();
    }
    if (getIt.isRegistered<NegotiationRepository>()) {
      getIt.unregister<NegotiationRepository>();
    }
    getIt.registerFactory<PackageRequestBloc>(() => packageBloc);
    getIt.registerFactory<BidBloc>(() => bidBloc);
    getIt.registerLazySingleton<NegotiationRepository>(() => negoRepo);
  });

  tearDown(() async {
    if (getIt.isRegistered<PackageRequestBloc>()) {
      getIt.unregister<PackageRequestBloc>();
    }
    if (getIt.isRegistered<BidBloc>()) {
      getIt.unregister<BidBloc>();
    }
    if (getIt.isRegistered<NegotiationRepository>()) {
      getIt.unregister<NegotiationRepository>();
    }
  });

  Widget wrap() => const MaterialApp(home: EnvoyerHubScreen());

  group('EnvoyerHubScreen', () {
    testWidgets('rend le titre "Envoyer" et le sous-titre par défaut',
        (tester) async {
      await tester.pumpWidget(wrap());
      // Drain animations + async (flutter_animate + findMine future).
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Envoyer'), findsOneWidget);
      expect(find.text('Aucune demande en cours'), findsOneWidget);
    });

    testWidgets('rend les 3 onglets Demandes / Envois / Négos',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Demandes'), findsOneWidget);
      expect(find.text('Envois'), findsOneWidget);
      expect(find.text('Négos'), findsOneWidget);
    });

    testWidgets('rend le FAB Publier', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(FloatingActionButton), findsOneWidget);
      // Au moins une icône "+" (FAB + header action)
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
    });
  });
}
