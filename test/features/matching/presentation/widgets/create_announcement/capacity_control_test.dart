import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/capacity_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _host() {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<AnnouncementFormBloc>(
        create: (_) => AnnouncementFormBloc(),
        child: const SingleChildScrollView(child: CapacityControl()),
      ),
    ),
  );
}

Widget _hostWithBloc(AnnouncementFormBloc bloc) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<AnnouncementFormBloc>.value(
        value: bloc,
        child: const SingleChildScrollView(child: CapacityControl()),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('CapacityControl', () {
    // ── Structure générale ──────────────────────────────────────────────────

    testWidgets('titre "Capacité disponible" affiché', (tester) async {
      await tester.pumpWidget(_host());
      expect(find.text('Capacité disponible'), findsOneWidget);
    });

    testWidgets('4 chips affichés', (tester) async {
      await tester.pumpWidget(_host());
      expect(find.text('1 valise 23 kg'), findsOneWidget);
      expect(find.text('1 valise 32 kg'), findsOneWidget);
      expect(find.text('Kg libre'), findsOneWidget);
      expect(find.text('Personnalisé'), findsOneWidget);
    });

    testWidgets(
      'état initial : chip suitcase23kg sélectionné — pas de Slider',
      (tester) async {
        await tester.pumpWidget(_host());
        expect(find.text('1 valise 23 kg'), findsOneWidget);
        // Aucun Slider dans le nouveau design
        expect(find.byType(Slider), findsNothing);
      },
    );

    // ── Mode kgFree ─────────────────────────────────────────────────────────

    testWidgets(
      'Kg libre → PAS de champ de saisie kg — carte info "Capacité illimitée" affichée',
      (tester) async {
        await tester.pumpWidget(_host());
        await tester.tap(find.text('Kg libre'));
        await tester.pump();
        // Aucun champ de saisie de poids pour kgFree
        expect(
          find.byType(TextField),
          findsNothing,
          reason: 'kgFree ne doit PAS afficher de TextField',
        );
        // Carte info présente
        expect(
          find.textContaining('Capacité illimitée'),
          findsOneWidget,
          reason: 'kgFree doit afficher une carte info "Capacité illimitée"',
        );
        expect(find.byType(Slider), findsNothing);
      },
    );

    testWidgets('Kg libre → le sous-titre "Vendu au kilo" est affiché', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.tap(find.text('Kg libre'));
      await tester.pump();
      expect(
        find.textContaining('kilo'),
        findsOneWidget,
        reason: 'kgFree doit mentionner la tarification au kilo',
      );
    });

    testWidgets(
      'Kg libre → le BLoC reçoit availableKg=1.0 automatiquement (pas de AvailableKgChanged)',
      (tester) async {
        final bloc = AnnouncementFormBloc();
        addTearDown(bloc.close);

        await tester.pumpWidget(_hostWithBloc(bloc));
        await tester.tap(find.text('Kg libre'));
        await tester.pump();

        expect(bloc.state.capacityUnit, CapacityUnit.kgFree);
        expect(
          bloc.state.availableKg,
          1.0,
          reason: 'kgFree doit auto-fixer la valeur sentinelle 1.0',
        );
      },
    );

    // ── Mode Personnalisé — champ de saisie libre ────────────────────────────

    testWidgets(
      'Personnalisé → champ de saisie libre visible (pas de Slider)',
      (tester) async {
        await tester.pumpWidget(_host());
        await tester.tap(find.text('Personnalisé'));
        await tester.pump();

        // Le champ libre doit être présent
        expect(find.byType(TextFormField), findsOneWidget);
        // Toujours aucun Slider
        expect(find.byType(Slider), findsNothing);
      },
    );

    testWidgets(
      'Personnalisé → saisir une valeur valide dispatche AvailableKgChanged',
      (tester) async {
        final bloc = AnnouncementFormBloc();
        addTearDown(bloc.close);

        await tester.pumpWidget(_hostWithBloc(bloc));
        bloc.add(const CapacityUnitChanged(CapacityUnit.custom));
        await tester.pump();

        // Saisir "15" dans le champ
        await tester.enterText(find.byType(TextFormField), '15');
        await tester.pump();

        expect(bloc.state.capacityUnit, CapacityUnit.custom);
        expect(bloc.state.availableKg, 15.0);
      },
    );

    testWidgets(
      'Personnalisé → saisie vide ou invalide ne dispatche pas de valeur garbage',
      (tester) async {
        final bloc = AnnouncementFormBloc();
        addTearDown(bloc.close);

        await tester.pumpWidget(_hostWithBloc(bloc));
        bloc.add(const CapacityUnitChanged(CapacityUnit.custom));
        await tester.pump();

        // Saisir "15" puis effacer
        await tester.enterText(find.byType(TextFormField), '15');
        await tester.pump();
        expect(bloc.state.availableKg, 15.0);

        // Effacer le champ — ne doit pas changer availableKg
        await tester.enterText(find.byType(TextFormField), '');
        await tester.pump();
        // La valeur reste 15 (on n'a pas dispatché de garbage)
        expect(bloc.state.availableKg, 15.0);
      },
    );

    testWidgets(
      'Personnalisé → saisie "0" ne dispatche pas (valeur < 1 interdite)',
      (tester) async {
        final bloc = AnnouncementFormBloc();
        addTearDown(bloc.close);

        await tester.pumpWidget(_hostWithBloc(bloc));
        bloc.add(const CapacityUnitChanged(CapacityUnit.custom));
        await tester.pump();

        // D'abord mettre une valeur valide
        await tester.enterText(find.byType(TextFormField), '10');
        await tester.pump();
        expect(bloc.state.availableKg, 10.0);

        // Saisir "0" — doit être ignoré
        await tester.enterText(find.byType(TextFormField), '0');
        await tester.pump();
        expect(bloc.state.availableKg, 10.0);
      },
    );

    testWidgets('Personnalisé → aide textuelle affichée', (tester) async {
      await tester.pumpWidget(_host());
      await tester.tap(find.text('Personnalisé'));
      await tester.pump();
      expect(find.textContaining('capacité totale'), findsOneWidget);
    });

    testWidgets(
      'Personnalisé (KG_EXACT) → champ "Capacité (kg)" toujours présent (régression)',
      (tester) async {
        await tester.pumpWidget(_host());
        await tester.tap(find.text('Personnalisé'));
        await tester.pump();
        // Le TextField doit toujours être présent pour le mode exact
        expect(
          find.byType(TextField),
          findsAtLeastNWidgets(1),
          reason: 'le mode Personnalisé doit conserver son champ de saisie kg',
        );
      },
    );

    // ── Mode preset valise — compteur ± ─────────────────────────────────────

    testWidgets(
      'preset valise 23 kg — carte de confirmation affiche 23 kg (quantité 1)',
      (tester) async {
        await tester.pumpWidget(_host());
        await tester.tap(find.text('1 valise 23 kg'));
        await tester.pump();
        // Doit afficher "23 kg" quelque part (total)
        expect(find.textContaining('23 kg'), findsWidgets);
        // Quantité = 1 valise
        expect(find.textContaining('1 valise de 23 kg'), findsOneWidget);
        expect(find.byType(Slider), findsNothing);
      },
    );

    testWidgets(
      'preset valise 32 kg — carte de confirmation affiche 32 kg (quantité 1)',
      (tester) async {
        await tester.pumpWidget(_host());
        await tester.tap(find.text('1 valise 32 kg'));
        await tester.pump();
        expect(find.textContaining('32 kg'), findsWidgets);
        expect(find.textContaining('1 valise de 32 kg'), findsOneWidget);
        expect(find.byType(Slider), findsNothing);
      },
    );

    testWidgets('compteur + (suitcase23kg) → availableKg passe à 46 (2×23)', (
      tester,
    ) async {
      final bloc = AnnouncementFormBloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(_hostWithBloc(bloc));
      // Sélectionner 23 kg (déjà par défaut, mais on force pour être explicite)
      bloc.add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
      await tester.pump();

      // Taper le bouton + via Semantics label
      await tester.tap(
        find.bySemanticsLabel('Augmenter la quantité'),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(bloc.state.availableKg, 46.0);
      expect(bloc.state.capacityUnit, CapacityUnit.suitcase23kg);
    });

    testWidgets(
      'compteur + deux fois (suitcase23kg) → availableKg passe à 69 (3×23)',
      (tester) async {
        final bloc = AnnouncementFormBloc();
        addTearDown(bloc.close);

        await tester.pumpWidget(_hostWithBloc(bloc));
        bloc.add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
        await tester.pump();

        // Taper + deux fois via Semantics
        await tester.tap(
          find.bySemanticsLabel('Augmenter la quantité'),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.tap(
          find.bySemanticsLabel('Augmenter la quantité'),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(bloc.state.availableKg, 69.0);
      },
    );

    testWidgets('compteur − depuis 2 → availableKg revient à 23 (1×23)', (
      tester,
    ) async {
      final bloc = AnnouncementFormBloc();
      addTearDown(bloc.close);

      // Départ : 2 valises (46 kg)
      bloc.add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
      bloc.add(const AvailableKgChanged(46.0));
      await tester.pumpWidget(_hostWithBloc(bloc));
      await tester.pump();

      // Taper −
      await tester.tap(
        find.bySemanticsLabel('Diminuer la quantité'),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(bloc.state.availableKg, 23.0);
    });

    testWidgets('compteur − désactivé/inopérant à quantité 1 (suitcase23kg)', (
      tester,
    ) async {
      final bloc = AnnouncementFormBloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(_hostWithBloc(bloc));
      bloc.add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
      await tester.pump();

      // Avant tap : quantité = 1, availableKg = 23
      expect(bloc.state.availableKg, 23.0);

      // Tenter de tapper − (bouton disabled, le onPressed est null)
      await tester.tap(
        find.bySemanticsLabel('Diminuer la quantité'),
        warnIfMissed: false,
      );
      await tester.pump();

      // availableKg ne doit pas changer
      expect(bloc.state.availableKg, 23.0);
    });

    testWidgets(
      'compteur affiche le bon label "N valises" (pluriel) pour 2 valises',
      (tester) async {
        final bloc = AnnouncementFormBloc();
        addTearDown(bloc.close);

        bloc.add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
        bloc.add(const AvailableKgChanged(46.0));
        await tester.pumpWidget(_hostWithBloc(bloc));
        await tester.pump();

        expect(find.textContaining('2 valises de 23 kg'), findsOneWidget);
        expect(find.textContaining('Vous offrez 46 kg'), findsOneWidget);
      },
    );

    testWidgets('compteur affiche "1 valise" (singulier) pour quantité 1', (
      tester,
    ) async {
      final bloc = AnnouncementFormBloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(_hostWithBloc(bloc));
      bloc.add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
      await tester.pump();

      expect(find.textContaining('1 valise de 23 kg'), findsOneWidget);
    });

    testWidgets(
      'changer de preset suitcase23kg → suitcase32kg remet la quantité à 1',
      (tester) async {
        final bloc = AnnouncementFormBloc();
        addTearDown(bloc.close);

        // Passer à 2 valises de 23 kg
        bloc.add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
        bloc.add(const AvailableKgChanged(46.0));
        await tester.pumpWidget(_hostWithBloc(bloc));
        await tester.pump();

        // Changer pour 32 kg → bloc remet availableKg = 32 (quantité 1)
        await tester.tap(find.text('1 valise 32 kg'));
        await tester.pump();

        expect(bloc.state.availableKg, 32.0);
        expect(bloc.state.capacityUnit, CapacityUnit.suitcase32kg);
        expect(find.textContaining('1 valise de 32 kg'), findsOneWidget);
      },
    );

    // ── Aucun Slider dans toute l'app ────────────────────────────────────────

    testWidgets('aucun Slider dans aucun mode', (tester) async {
      final bloc = AnnouncementFormBloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(_hostWithBloc(bloc));

      for (final unit in CapacityUnit.values) {
        bloc.add(CapacityUnitChanged(unit));
        await tester.pump();
        expect(
          find.byType(Slider),
          findsNothing,
          reason: 'Slider trouvé pour $unit — il ne devrait pas exister',
        );
      }
    });
  });
}
