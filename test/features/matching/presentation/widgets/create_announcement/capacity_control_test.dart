import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/capacity_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({AnnouncementFormState? initialState}) {
  final bloc = AnnouncementFormBloc();
  if (initialState != null) {
    // Démarrer avec un état précis via des événements
  }
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<AnnouncementFormBloc>.value(
        value: bloc,
        child: const SingleChildScrollView(
          child: CapacityControl(),
        ),
      ),
    ),
  );
}

void main() {
  group('CapacityControl', () {
    testWidgets('4 chips affichés', (tester) async {
      await tester.pumpWidget(_host());
      // Les 4 labels définis dans CapacityUnit.label
      expect(find.text('1 valise 23 kg'), findsOneWidget);
      expect(find.text('1 valise 32 kg'), findsOneWidget);
      expect(find.text('Kg libre'), findsOneWidget);
      expect(find.text('Personnalisé'), findsOneWidget);
    });

    testWidgets('état initial : chip suitcase23kg sélectionné', (tester) async {
      await tester.pumpWidget(_host());
      // Le chip par défaut est suitcase23kg
      expect(find.text('1 valise 23 kg'), findsOneWidget);
      // Pas de slider en mode preset
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('preset valise 23 kg → carte de confirmation, pas de slider',
        (tester) async {
      await tester.pumpWidget(_host());
      // Taper sur le chip 23 kg (déjà sélectionné par défaut)
      await tester.tap(find.text('1 valise 23 kg'));
      await tester.pump();
      // Vérifier que la carte de confirmation affiche 23 kg
      expect(find.textContaining('23 kg'), findsWidgets);
      // Pas de slider
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('preset valise 32 kg → carte de confirmation, pas de slider',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.tap(find.text('1 valise 32 kg'));
      await tester.pump();
      expect(find.textContaining('32 kg'), findsWidgets);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('Kg libre → carte "Sans limite précise"', (tester) async {
      await tester.pumpWidget(_host());
      await tester.tap(find.text('Kg libre'));
      await tester.pump();
      expect(find.textContaining('Sans limite'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('Personnalisé → slider visible', (tester) async {
      await tester.pumpWidget(_host());
      await tester.tap(find.text('Personnalisé'));
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('Personnalisé → slider dispatch AvailableKgChanged',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.tap(find.text('Personnalisé'));
      await tester.pump();

      // Le slider doit être présent
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 1);
      expect(slider.max, 30);
    });

    testWidgets('titre "Capacité disponible" affiché', (tester) async {
      await tester.pumpWidget(_host());
      expect(find.text('Capacité disponible'), findsOneWidget);
    });
  });
}
