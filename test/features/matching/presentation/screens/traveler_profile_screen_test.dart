import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/presentation/screens/traveler_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

Future<void> _pump(WidgetTester tester, AnnouncementState state) async {
  final bloc = _MockAnnouncementBloc();
  whenListen(
    bloc,
    const Stream<AnnouncementState>.empty(),
    initialState: state,
  );
  // TravelerProfileLoaderScreen crée lui-même son bloc via getIt (il n'écoute
  // pas un ancêtre) : on l'y substitue plutôt que de le fournir par Provider.
  if (getIt.isRegistered<AnnouncementBloc>()) {
    getIt.unregister<AnnouncementBloc>();
  }
  getIt.registerFactory<AnnouncementBloc>(() => bloc);
  await tester.pumpWidget(
    const MaterialApp(home: TravelerProfileLoaderScreen(announcementId: 'a1')),
  );
}

void main() {
  tearDown(() {
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
  });

  testWidgets('affiche le squelette de chargement', (tester) async {
    await _pump(tester, AnnouncementLoading());

    expect(find.byType(DonyDetailSkeleton), findsOneWidget);
  });

  testWidgets('erreur réseau : message résolu par ErrorPresenter', (
    tester,
  ) async {
    await _pump(tester, AnnouncementError(const NetworkException('boom')));

    expect(find.text('Erreur de chargement'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  // AnnouncementNotFound n'a pas de champ error : c'est la seule branche qui
  // affiche encore le message de repli en dur.
  testWidgets('état inattendu sans erreur portée : description de repli', (
    tester,
  ) async {
    await _pump(tester, AnnouncementNotFound());

    expect(find.text('Erreur de chargement'), findsOneWidget);
    expect(find.text('Impossible de charger le détail'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('en anglais : titre et description traduits', (tester) async {
    useEnglish();
    await _pump(tester, AnnouncementNotFound());

    expect(find.text('Loading error'), findsOneWidget);
    expect(find.text('Unable to load details'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
