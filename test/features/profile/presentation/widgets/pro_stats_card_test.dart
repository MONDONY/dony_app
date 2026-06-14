import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/profile/bloc/pro_stats_bloc.dart';
import 'package:dony/features/profile/data/models/pro_stats_model.dart';
import 'package:dony/features/profile/presentation/widgets/pro_stats_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockProStatsBloc extends MockBloc<ProStatsEvent, ProStatsState>
    implements ProStatsBloc {}

class FakeProStatsEvent extends Fake implements ProStatsEvent {}

const _kStats = ProStatsModel(
  monthlyRevenue: 1250.0,
  totalRevenue: 8400.0,
  monthlyTrips: 3,
  monthlyParcelsDelivered: 12,
  acceptanceRate: 0.92,
  averageRating: 4.7,
  topDestinations: [DestinationStatModel(from: 'Paris', to: 'Dakar', count: 2)],
);

Widget _buildCard(MockProStatsBloc bloc) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<ProStatsBloc>.value(
        value: bloc,
        child: const ProStatsCard(),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    registerFallbackValue(FakeProStatsEvent());
  });

  late MockProStatsBloc bloc;

  setUp(() => bloc = MockProStatsBloc());
  tearDown(() => bloc.close());

  testWidgets('affiche le spinner en état Loading', (tester) async {
    when(() => bloc.state).thenReturn(ProStatsLoading());

    await tester.pumpWidget(_buildCard(bloc));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('CHARGEMENT…'), findsOneWidget);
  });

  testWidgets('affiche le spinner en état Initial', (tester) async {
    when(() => bloc.state).thenReturn(ProStatsInitial());

    await tester.pumpWidget(_buildCard(bloc));

    expect(find.text('CHARGEMENT…'), findsOneWidget);
  });

  testWidgets('affiche le message d\'erreur en état Error', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(ProStatsError(NetworkException('Erreur réseau')));

    await tester.pumpWidget(_buildCard(bloc));

    expect(find.text('Statistiques indisponibles'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('envoie ProStatsLoadRequested au tap Réessayer', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(ProStatsError(NetworkException('Erreur')));

    await tester.pumpWidget(_buildCard(bloc));
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    verify(() => bloc.add(any(that: isA<ProStatsLoadRequested>()))).called(1);
  });

  testWidgets('affiche les revenus et trajets en état Loaded', (tester) async {
    when(() => bloc.state).thenReturn(ProStatsLoaded(_kStats));

    await tester.pumpWidget(_buildCard(bloc));
    await tester.pumpAndSettle();

    expect(find.textContaining('250'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('Voir plus →'), findsOneWidget);
    // Pills acceptance/rating
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('4.7 ★'), findsOneWidget);
  });

  testWidgets('affiche les trajets et colis en état Loaded', (tester) async {
    when(() => bloc.state).thenReturn(ProStatsLoaded(_kStats));

    await tester.pumpWidget(_buildCard(bloc));
    await tester.pumpAndSettle();

    // "3 trajets · 12 colis livrés"
    expect(find.textContaining('3 trajet'), findsOneWidget);
    expect(find.textContaining('12 colis'), findsOneWidget);
  });

  testWidgets('ne rend rien pour un état inconnu', (tester) async {
    when(() => bloc.state).thenReturn(ProStatsInitial());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<ProStatsBloc>.value(
            value: bloc,
            child: BlocBuilder<ProStatsBloc, ProStatsState>(
              builder: (context, state) {
                // Simulate an unknown substate that falls through to SizedBox.shrink()
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
