import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/capacity_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';
import '../../../../../helpers/mock_analytics_backend.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _host() {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<AnnouncementFormBloc>(
        create: (_) => AnnouncementFormBloc(
          analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        ),
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
        final bloc = AnnouncementFormBloc(
          analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        );
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
        final bloc = AnnouncementFormBloc(
          analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        );
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
        final bloc = AnnouncementFormBloc(
          analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        );
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
        final bloc = AnnouncementFormBloc(
          analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        );
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
      final bloc = AnnouncementFormBloc(
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
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
        final bloc = AnnouncementFormBloc(
          analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        );
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
      final bloc = AnnouncementFormBloc(
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
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
      final bloc = AnnouncementFormBloc(
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
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
        final bloc = AnnouncementFormBloc(
          analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        );
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
      final bloc = AnnouncementFormBloc(
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
      addTearDown(bloc.close);

      await tester.pumpWidget(_hostWithBloc(bloc));
      bloc.add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
      await tester.pump();

      expect(find.textContaining('1 valise de 23 kg'), findsOneWidget);
    });

    testWidgets(
      'changer de preset suitcase23kg → suitcase32kg remet la quantité à 1',
      (tester) async {
        final bloc = AnnouncementFormBloc(
          analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        );
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
      final bloc = AnnouncementFormBloc(
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
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

  // ── Group: English (i18n) ─────────────────────────────────────────────────

  group('CapacityControl — English', () {
    testWidgets('2 valises devient "2 suitcases" en anglais', (tester) async {
      useEnglish();
      final bloc = AnnouncementFormBloc(
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
      addTearDown(bloc.close);

      bloc.add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
      bloc.add(const AvailableKgChanged(46.0));
      await tester.pumpWidget(_hostWithBloc(bloc));
      await tester.pump();

      expect(find.text('2 suitcases of 23 kg'), findsOneWidget);
    });

    testWidgets('1 valise reste "1 suitcase" (singulier) en anglais', (
      tester,
    ) async {
      useEnglish();
      final bloc = AnnouncementFormBloc(
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
      addTearDown(bloc.close);

      await tester.pumpWidget(_hostWithBloc(bloc));
      bloc.add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
      await tester.pump();

      expect(find.text('1 suitcase of 23 kg'), findsOneWidget);
    });
  });

  group('CapacityControl — route (T3)', () {
    Future<AnnouncementFormBloc> pumpWithMode(
      WidgetTester tester,
      TransportMode mode, {
      CapacityUnit unit = CapacityUnit.custom,
      double kg = 23,
    }) async {
      final bloc = AnnouncementFormBloc(
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
      addTearDown(bloc.close);
      bloc
        ..add(TransportModeChanged(mode))
        ..add(CapacityUnitChanged(unit))
        ..add(AvailableKgChanged(kg));
      await tester.pumpWidget(_hostWithBloc(bloc));
      await tester.pump();
      return bloc;
    }

    testWidgets(
      'route : pas de puce valise, taille max visible et facultative',
      (tester) async {
        final bloc = await pumpWithMode(tester, TransportMode.car);
        expect(find.text('1 valise 23 kg'), findsNothing);
        expect(find.text('1 valise 32 kg'), findsNothing);
        expect(find.text('Kg libre'), findsOneWidget);
        expect(find.text('Personnalisé'), findsOneWidget);
        expect(find.text("Taille max d'un colis (facultatif)"), findsOneWidget);
        expect(
          find.text('Poids max par colis (kg, facultatif)'),
          findsOneWidget,
        );
        expect(bloc.state.isCapacityStepValid, isTrue);

        await tester.tap(find.byKey(const Key('item-size-L')));
        await tester.pump();
        expect(bloc.state.maxItemSize, ItemSize.l);
        // Second tap : désélection (taille facultative).
        await tester.tap(find.byKey(const Key('item-size-L')));
        await tester.pump();
        expect(bloc.state.maxItemSize, isNull);
      },
    );

    testWidgets('avion : valises proposées, pas de taille max', (tester) async {
      await pumpWithMode(
        tester,
        TransportMode.plane,
        unit: CapacityUnit.suitcase23kg,
      );
      expect(find.text('1 valise 23 kg'), findsOneWidget);
      expect(find.byKey(const Key('capacity-road-limits')), findsNothing);
    });

    testWidgets('route : 2 500 kg acceptés, avion : 1 000 kg en erreur', (
      tester,
    ) async {
      final road = await pumpWithMode(tester, TransportMode.car);
      await tester.enterText(
        find.byKey(const Key('capacity-kg-field')),
        '2500',
      );
      await tester.pump();
      expect(road.state.availableKg, 2500);
      expect(find.byKey(const Key('capacity-kg-error')), findsNothing);
      expect(road.state.isCapacityStepValid, isTrue);

      final plane = await pumpWithMode(tester, TransportMode.plane);
      await tester.enterText(
        find.byKey(const Key('capacity-kg-field')),
        '1000',
      );
      await tester.pump();
      expect(plane.state.availableKg, 1000);
      expect(find.text('Au plus 999 kg pour ce mode'), findsOneWidget);
      expect(plane.state.isCapacityStepValid, isFalse);
    });

    testWidgets('route 1 200 kg puis avion : message « Au plus 999 kg »', (
      tester,
    ) async {
      final bloc = await pumpWithMode(tester, TransportMode.car, kg: 1200);
      expect(find.byKey(const Key('capacity-kg-error')), findsNothing);
      bloc.add(const TransportModeChanged(TransportMode.plane));
      await tester.pump();
      await tester.pump();
      expect(find.text('Au plus 999 kg pour ce mode'), findsOneWidget);
      // Toujours « Personnalisé » : les valises ne reviennent pas d'office.
      expect(bloc.state.capacityUnit, CapacityUnit.custom);
      expect(bloc.state.isCapacityStepValid, isFalse);
    });

    testWidgets('poids max par colis : 20 accepté, 0,2 et 5 000 en erreur', (
      tester,
    ) async {
      final bloc = await pumpWithMode(tester, TransportMode.car, kg: 1200);
      final field = find.byKey(const Key('max-parcel-weight-field'));
      await tester.enterText(field, '20');
      await tester.pump();
      expect(bloc.state.maxParcelWeightKg, 20);
      expect(find.byKey(const Key('max-parcel-weight-error')), findsNothing);

      await tester.enterText(field, '0,2');
      await tester.pump();
      expect(bloc.state.maxParcelWeightKg, 0.2);
      expect(
        find.text('Entre 0,5 kg et la capacité du trajet'),
        findsOneWidget,
      );

      await tester.enterText(field, '5000');
      await tester.pump();
      expect(bloc.state.isMaxParcelWeightValid, isFalse);

      await tester.enterText(field, '');
      await tester.pump();
      expect(bloc.state.maxParcelWeightKg, isNull);
      expect(bloc.state.isCapacityStepValid, isTrue);
    });

    testWidgets('poids max effacé par le passage en avion : champ retiré', (
      tester,
    ) async {
      final bloc = await pumpWithMode(tester, TransportMode.car, kg: 1200);
      await tester.enterText(
        find.byKey(const Key('max-parcel-weight-field')),
        '20',
      );
      await tester.pump();
      bloc.add(const TransportModeChanged(TransportMode.plane));
      await tester.pump();
      expect(bloc.state.maxParcelWeightKg, isNull);
      expect(find.byKey(const Key('max-parcel-weight-field')), findsNothing);
      bloc.add(const TransportModeChanged(TransportMode.car));
      await tester.pump();
      final text = tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('max-parcel-weight-field')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text;
      expect(text, isEmpty);
    });

    testWidgets('avion en valises : + grisé au plafond de 999 kg', (
      tester,
    ) async {
      final bloc = await pumpWithMode(
        tester,
        TransportMode.plane,
        unit: CapacityUnit.suitcase23kg,
      );
      bloc.add(const AvailableKgChanged(43 * 23));
      await tester.pump();
      await tester.pump();
      expect(find.text('43'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Augmenter la quantité'));
      await tester.pump();
      expect(bloc.state.availableKg, 43 * 23);
    });
  });
}
