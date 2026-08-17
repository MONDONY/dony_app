import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/trip_poster_screen.dart';
import 'package:dony/features/matching/presentation/widgets/poster/trip_poster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

AnnouncementModel _announcement() => AnnouncementModel.fromJson({
  'id': 'a1',
  'travelerId': 't1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': DateTime(2026, 8, 20).toIso8601String(),
  'availableKg': 12.0,
  'totalKg': 23.0,
  'pricePerKg': 6.0,
  'pricePerKgDisplay': 8.0,
  'currency': 'EUR',
  'status': 'ACTIVE',
  'createdAt': DateTime(2026, 8).toIso8601String(),
  'updatedAt': DateTime(2026, 8).toIso8601String(),
});

Future<void> _pump(
  WidgetTester tester,
  AnnouncementState state, {
  AnnouncementModel? initial,
}) async {
  final bloc = _MockAnnouncementBloc();
  whenListen(
    bloc,
    const Stream<AnnouncementState>.empty(),
    initialState: state,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AnnouncementBloc>.value(
        value: bloc,
        child: TripPosterRoute(initial: initial),
      ),
    ),
  );
}

void main() {
  setUpAll(() async => initializeDateFormatting('fr'));

  /// Les deux entrées actuelles tiennent déjà le trajet : l'affiche doit
  /// s'ouvrir sans attendre le réseau, c'est l'instant où elle est postée.
  testWidgets('rend immédiatement quand le trajet est fourni', (tester) async {
    await _pump(tester, AnnouncementLoading(), initial: _announcement());

    expect(find.byType(TripPosterCard), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  /// La route est adressée par identifiant : elle doit savoir se résoudre sans
  /// que l'appelant fournisse le trajet.
  testWidgets('résout le trajet depuis le bloc sans extra', (tester) async {
    await _pump(tester, AnnouncementDetailLoaded(_announcement()));

    expect(find.byType(TripPosterCard), findsOneWidget);
  });

  testWidgets('patiente pendant le chargement', (tester) async {
    await _pump(tester, AnnouncementLoading());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TripPosterCard), findsNothing);
  });

  testWidgets('montre un état d\'erreur exploitable', (tester) async {
    await _pump(tester, AnnouncementError(const NetworkException('boom')));

    expect(find.text('Trajet introuvable'), findsOneWidget);
    // DonyEmptyState anime sa mascotte : laisser l'animation se terminer, sinon
    // un timer reste en vol au demontage de l'arbre et fait echouer le test.
    await tester.pumpAndSettle();
  });
}
