import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
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

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

class _MockNegotiationRepository extends Mock implements NegotiationRepository {
}

void main() {
  late _MockPackageRequestBloc packageBloc;
  late _MockBidBloc bidBloc;
  late _MockNegotiationListBloc negoListBloc;
  late _MockNegotiationRepository negoRepo;

  setUpAll(() {
    registerFallbackValue(const FetchMyRequests());
    registerFallbackValue(const BidMyListAutoRefreshRequested());
    registerFallbackValue(const NegotiationListFetchRequested());
  });

  setUp(() {
    packageBloc = _MockPackageRequestBloc();
    bidBloc = _MockBidBloc();
    negoListBloc = _MockNegotiationListBloc();
    negoRepo = _MockNegotiationRepository();

    when(() => packageBloc.state).thenReturn(const PackageRequestState());
    when(() => packageBloc.stream)
        .thenAnswer((_) => const Stream<PackageRequestState>.empty());
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream)
        .thenAnswer((_) => const Stream<BidState>.empty());
    when(() => negoListBloc.state).thenReturn(const NegotiationListState());
    when(() => negoListBloc.stream)
        .thenAnswer((_) => const Stream<NegotiationListState>.empty());
    when(() => negoRepo.findMine()).thenAnswer((_) async => []);

    if (getIt.isRegistered<PackageRequestBloc>()) {
      getIt.unregister<PackageRequestBloc>();
    }
    if (getIt.isRegistered<BidBloc>()) {
      getIt.unregister<BidBloc>();
    }
    if (getIt.isRegistered<NegotiationListBloc>()) {
      getIt.unregister<NegotiationListBloc>();
    }
    if (getIt.isRegistered<NegotiationRepository>()) {
      getIt.unregister<NegotiationRepository>();
    }
    getIt.registerFactory<PackageRequestBloc>(() => packageBloc);
    getIt.registerFactory<BidBloc>(() => bidBloc);
    getIt.registerFactory<NegotiationListBloc>(() => negoListBloc);
    getIt.registerLazySingleton<NegotiationRepository>(() => negoRepo);
  });

  tearDown(() async {
    if (getIt.isRegistered<PackageRequestBloc>()) {
      getIt.unregister<PackageRequestBloc>();
    }
    if (getIt.isRegistered<BidBloc>()) {
      getIt.unregister<BidBloc>();
    }
    if (getIt.isRegistered<NegotiationListBloc>()) {
      getIt.unregister<NegotiationListBloc>();
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
      expect(find.text('Aucune demande active'), findsOneWidget);
    });

    testWidgets('rend les 3 onglets Demandes / Envois / Négos',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Les labels incluent un compteur, ex. "Demandes 0"
      expect(find.textContaining('Demandes'), findsWidgets);
      expect(find.textContaining('Envois'), findsWidgets);
      expect(find.textContaining('Négos'), findsWidgets);
    });

    testWidgets('rend le bouton Publier (icône +)', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Le "+" est intégré dans le header (pas un FAB)
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
    });
  });
}
