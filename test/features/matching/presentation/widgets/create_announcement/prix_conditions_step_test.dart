// Tests de PrixConditionsStep — étape 2 du formulaire "Publier un trajet".
//
// Structure miroir de lieux_capacite_step_test.dart et trajet_step_test.dart.
//
// Dépendances BLoC requises par le widget :
//   - AnnouncementFormBloc  : priceWarning / pricePerKg / cities
//   - AuthBloc              : stripeAccountStatus → section paiement
//   - CommissionMethodBloc  : état carte commission → switch espèces
//
// Tous les ValueNotifier et TextEditingController sont créés localement dans
// le host, en copie fidèle de la signature du widget (11 paramètres).
// Les animations flutter_animate sont drainées via pump(200 ms).

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_create_announcement_constants.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class _MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

class _MockAnnouncementFormBloc
    extends MockBloc<AnnouncementFormEvent, AnnouncementFormState>
    implements AnnouncementFormBloc {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// StripeAccountState quand Stripe est configuré (onboarding complet).
final _stripeConfiguredState = StripeAccountReady(
  const ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
);

/// StripeAccountState quand Stripe n'est pas encore configuré.
const _stripeNotConfiguredState = StripeAccountInitial();

const _validCard = CommissionMethod(
  brand: 'visa',
  last4: '4242',
  expMonth: 12,
  expYear: 2028,
  expirationStatus: ExpirationStatus.valid,
);

// ── Host builder ──────────────────────────────────────────────────────────────

/// Construit l'arbre minimal pour tester PrixConditionsStep :
/// MaterialApp – Scaffold – MultiBlocProvider – SingleChildScrollView –
/// PrixConditionsStep.
///
/// [stripeState] contrôle la section paiement (Stripe configuré ou non).
/// [commissionState] contrôle le switch "Espèces".
Widget _host({
  StripeAccountState? stripeState,
  CommissionMethodState? commissionState,
  double initialAvailableKg = 10,
}) {
  final mockStripeBloc = _MockStripeAccountBloc();
  final resolvedStripeState = stripeState ?? _stripeConfiguredState;
  when(() => mockStripeBloc.state).thenReturn(resolvedStripeState);
  when(() => mockStripeBloc.stream).thenAnswer((_) => const Stream.empty());

  final mockCommissionBloc = _MockCommissionMethodBloc();
  final resolvedCommissionState =
      commissionState ?? CommissionMethodNotConfigured();
  when(() => mockCommissionBloc.state).thenReturn(resolvedCommissionState);
  when(() => mockCommissionBloc.stream)
      .thenAnswer((_) => const Stream.empty());

  // Contrôleurs / notifiers (cycle de vie géré par le StatefulWidget parent
  // en production ; ici on les crée dans le host et on les laisse se disposer
  // en fin de test — accepté dans un contexte de test unitaire).
  final priceOptionNotifier = ValueNotifier<int>(0);
  final customPriceNotifier = ValueNotifier<double>(0);
  final availableKgNotifier = ValueNotifier<double>(initialAvailableKg);
  final cashEnabledNotifier = ValueNotifier<bool>(false);
  final kgPriceEnabledNotifier = ValueNotifier<bool>(true);
  final selectedContentNotifier = ValueNotifier<Set<String>>({});
  final customAcceptedNotifier = ValueNotifier<Set<String>>({});
  final refusedTypesNotifier = ValueNotifier<Set<String>>({});
  final catalogLabelsNotifier = ValueNotifier<List<String>>(
    fallbackCatalog.map((c) => c.label).toList(),
  );
  final descriptionCtrl = TextEditingController();
  final customAcceptedCtrl = TextEditingController();
  final refusedCtrl = TextEditingController();
  final customPriceCtrl = TextEditingController();

  return MaterialApp(
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<AnnouncementFormBloc>(
            create: (_) => AnnouncementFormBloc(),
          ),
          BlocProvider<StripeAccountBloc>.value(value: mockStripeBloc),
          BlocProvider<CommissionMethodBloc>.value(value: mockCommissionBloc),
        ],
        child: SingleChildScrollView(
          child: PrixConditionsStep(
            priceOptionNotifier: priceOptionNotifier,
            customPriceNotifier: customPriceNotifier,
            availableKgNotifier: availableKgNotifier,
            cashEnabledNotifier: cashEnabledNotifier,
            kgPriceEnabledNotifier: kgPriceEnabledNotifier,
            selectedContentNotifier: selectedContentNotifier,
            customAcceptedNotifier: customAcceptedNotifier,
            refusedTypesNotifier: refusedTypesNotifier,
            catalogLabelsNotifier: catalogLabelsNotifier,
            descriptionCtrl: descriptionCtrl,
            customAcceptedCtrl: customAcceptedCtrl,
            refusedCtrl: refusedCtrl,
            customPriceCtrl: customPriceCtrl,
          ),
        ),
      ),
    ),
  );
}

/// Pompe le widget et draine les animations flutter_animate (delay ≤ 180 ms).
Future<void> _pump(WidgetTester tester, {StripeAccountState? stripeState, CommissionMethodState? commissionState}) async {
  await tester.pumpWidget(_host(stripeState: stripeState, commissionState: commissionState));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('PrixConditionsStep', () {
    // ── Construction ──────────────────────────────────────────────────────────

    testWidgets('se construit sans exception avec les providers requis',
        (tester) async {
      await _pump(tester);
      expect(find.byType(PrixConditionsStep), findsOneWidget);
    });

    // ── Section PRIX PAR KG ───────────────────────────────────────────────────

    testWidgets('label de section Prix par kg est affiché', (tester) async {
      await _pump(tester);
      expect(find.text('Prix par kg'), findsOneWidget);
    });

    testWidgets('les 4 chips de prix prédéfinis sont affichés',
        (tester) async {
      await _pump(tester);
      // kPriceOptions = [5.0, 6.0, 7.0, 8.0] → "5€", "6€", "7€", "8€"
      for (final price in kPriceOptions) {
        expect(
          find.text('${price.toStringAsFixed(0)}€'),
          findsOneWidget,
          reason: 'Chip ${price.toStringAsFixed(0)}€ doit être présent',
        );
      }
    });

    testWidgets('chip "Autre prix" est affiché', (tester) async {
      await _pump(tester);
      expect(find.text('Autre prix'), findsOneWidget);
    });

    testWidgets('ligne « vous touchez / l\'expéditeur paie » est affichée', (tester) async {
      await _pump(tester);
      // availableKg=10, prix index 0 → 5€/kg : vous touchez 50€ (net entier),
      // l'expéditeur paie 56€ (net × 1,12).
      expect(
        find.textContaining('Vous touchez'),
        findsOneWidget,
      );
    });

    // ── Section MODES DE PAIEMENT ─────────────────────────────────────────────

    testWidgets(
        'label de section Modes de paiement acceptés est affiché',
        (tester) async {
      await _pump(tester);
      expect(find.text('Modes de paiement acceptés'), findsOneWidget);
    });

    testWidgets(
        'switch Stripe visible et désactivé (toujours ON, non éditable)',
        (tester) async {
      await _pump(
        tester,
        stripeState: _stripeConfiguredState,
        commissionState: CommissionMethodNotConfigured(),
      );
      final stripeSwitch = find.byKey(const Key('payment-method-stripe'));
      expect(stripeSwitch, findsOneWidget);
      final sw = tester.widget<Switch>(
        find.descendant(of: stripeSwitch, matching: find.byType(Switch)).last,
      );
      expect(sw.value, isTrue,
          reason: 'Stripe est toujours activé (verrouillé)');
      expect(sw.onChanged, isNull,
          reason: 'Stripe switch ne doit pas être modifiable');
    });

    testWidgets(
        'switch Espèces activé même sans carte commission (vérif. reportée à l\'acceptation)',
        (tester) async {
      await _pump(
        tester,
        stripeState: _stripeConfiguredState,
        commissionState: CommissionMethodNotConfigured(),
      );
      final cashSwitch = find.byKey(const Key('payment-method-cash'));
      expect(cashSwitch, findsOneWidget);
      final sw = tester.widget<Switch>(
        find.descendant(of: cashSwitch, matching: find.byType(Switch)).last,
      );
      // La carte de commission n'est plus requise à la publication :
      // la capacité de prélèvement (wallet/carte) est vérifiée à l'acceptation du bid.
      expect(sw.onChanged, isNotNull,
          reason:
              'CASH switch doit rester activable sans carte commission configurée');
      // L'ancien lien "Ajouter une carte commission →" ne doit plus exister.
      expect(find.byKey(const Key('add-commission-card-link')), findsNothing);
    });

    testWidgets(
        'switch Espèces activé quand carte commission valide disponible',
        (tester) async {
      await _pump(
        tester,
        stripeState: _stripeConfiguredState,
        commissionState: CommissionMethodLoaded(_validCard),
      );
      final cashSwitch = find.byKey(const Key('payment-method-cash'));
      expect(cashSwitch, findsOneWidget);
      final sw = tester.widget<Switch>(
        find.descendant(of: cashSwitch, matching: find.byType(Switch)).last,
      );
      expect(sw.onChanged, isNotNull,
          reason:
              'CASH switch doit être activable avec une carte commission valide');
    });

    testWidgets(
        'bannière Stripe non configuré visible quand stripeAccountStatus != ONBOARDING_COMPLETE',
        (tester) async {
      await _pump(
        tester,
        stripeState: _stripeNotConfiguredState,
      );
      // La bannière contient "Connectez Stripe"
      expect(find.textContaining('Connectez Stripe'), findsOneWidget);
    });

    // ── Section CE QUE J'ACCEPTE ──────────────────────────────────────────────

    testWidgets("label de section Ce que j'accepte est affiché",
        (tester) async {
      await _pump(tester);
      expect(find.text("Ce que j'accepte"), findsOneWidget);
    });

    testWidgets(
      'les chips du catalogue (repository) sont affichées — pas une liste figée',
      (tester) async {
        await _pump(tester);
        for (final category in fallbackCatalog) {
          // Chaque libellé du catalogue apparaît deux fois : une fois comme
          // chip « Ce que j'accepte », une fois comme chip « Ce que je
          // refuse » — les deux sections proposent désormais le catalogue
          // complet.
          expect(
            find.text(category.label),
            findsNWidgets(2),
            reason:
                'Chip "${category.label}" doit être présente dans les deux sections',
          );
        }
      },
    );

    testWidgets(
      'saisie libre dans "Ce que j\'accepte" ajoute un élément custom',
      (tester) async {
        await _pump(tester);
        final acceptField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Ajouter un autre type…',
        );
        await tester.enterText(acceptField, 'Poissons');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(find.text('Poissons'), findsOneWidget);
      },
    );

    // ── Section CE QUE JE REFUSE ──────────────────────────────────────────────

    testWidgets('label de section Ce que je refuse est affiché',
        (tester) async {
      await _pump(tester);
      expect(find.text('Ce que je refuse'), findsOneWidget);
    });

    testWidgets(
      'saisie libre dans "Ce que je refuse" ajoute un élément custom',
      (tester) async {
        await _pump(tester);
        final refuseField = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Ex: Liquides, Denrées périssables…',
        );
        await tester.enterText(refuseField, 'Alcool');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(find.text('Alcool'), findsOneWidget);
      },
    );

    // ── Section NOTE AUX EXPÉDITEURS ─────────────────────────────────────────

    testWidgets('label de section Note aux expéditeurs est affiché',
        (tester) async {
      await _pump(tester);
      expect(find.text('Note aux expéditeurs'), findsOneWidget);
    });

    testWidgets('le champ note aux expéditeurs (TextField) est présent',
        (tester) async {
      await _pump(tester);
      // Le TextField de la note a un hintText caractéristique
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.maxLines == 4 &&
              w.maxLength == 500,
        ),
        findsOneWidget,
      );
    });

    testWidgets('compteur de caractères 0/500 est affiché', (tester) async {
      await _pump(tester);
      expect(find.text('0/500'), findsOneWidget);
    });

    // ── Régression P6 — aucune flèche texte résiduelle ───────────────────────

    testWidgets('aucun texte visible ne contient le caractère flèche →',
        (tester) async {
      // Teste à la fois l'état sans Stripe et sans carte commission (cas où
      // les deux liens/boutons incriminés sont rendus).
      await _pump(
        tester,
        stripeState: _stripeNotConfiguredState,
        commissionState: CommissionMethodNotConfigured(),
      );
      // Aucun widget Text (ou RichText) ne doit afficher le glyphe →.
      expect(
        find.textContaining('→'),
        findsNothing,
        reason:
            'P6 : les flèches → doivent être des Icon(DonyIcons.arrowRight), '
            'jamais des caractères Unicode dans les libellés.',
      );
    });

    // ── kgFree — estimation illimitée ─────────────────────────────────────────

    testWidgets(
        'kgFree (availableKg=0) → affiche "Capacité illimitée" et non "Estimation"',
        (tester) async {
      await tester.pumpWidget(_host(initialAvailableKg: 0));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.textContaining('illimitée'), findsOneWidget);
      expect(find.textContaining('Estimation'), findsNothing);
    });
  });

  group('Mode MIXED — toggle et aperçu grille', () {
    testWidgets('tap "Grille + kilo" affiche le SwitchListTile kg-price-toggle',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Grille + kilo'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.byKey(const Key('kg-price-toggle')), findsOneWidget);
      expect(find.text('Tarif au kilo'), findsOneWidget);
      expect(find.text('Optionnel en mode grille'), findsOneWidget);
    });

    testWidgets('tap "Grille + kilo" puis "Au kilo" masque le toggle kg',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Grille + kilo'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      await tester.tap(find.text('Au kilo'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.byKey(const Key('kg-price-toggle')), findsNothing);
    });

    testWidgets('mode MIXED sans items — affiche "Aucun article configuré"',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Grille + kilo'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.text('Aucun article configuré'), findsOneWidget);
    });

    testWidgets('mode MIXED avec items — affiche les labels et prix',
        (tester) async {
      // Utilise un MockBloc synchrone pour éviter les problèmes d'async avec runAsync.
      final mockBloc = _MockAnnouncementFormBloc();
      final mixedWithItemsState = const AnnouncementFormState(
        pricingMode: PricingMode.mixed,
        gridPreviewItems: [
          GridPreviewItem(id: 'a1', label: 'Petit colis', unitPriceDisplay: 5.0),
          GridPreviewItem(id: 'a2', label: 'Grand colis', unitPriceDisplay: 10.0),
        ],
      );
      when(() => mockBloc.state).thenReturn(mixedWithItemsState);
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());

      final mockStripe = _MockStripeAccountBloc();
      when(() => mockStripe.state).thenReturn(_stripeConfiguredState);
      when(() => mockStripe.stream).thenAnswer((_) => const Stream.empty());
      final mockComm = _MockCommissionMethodBloc();
      when(() => mockComm.state).thenReturn(CommissionMethodNotConfigured());
      when(() => mockComm.stream).thenAnswer((_) => const Stream.empty());

      final priceOpt = ValueNotifier<int>(0);
      final customPrice = ValueNotifier<double>(0);
      final availKg = ValueNotifier<double>(10);
      final cash = ValueNotifier<bool>(false);
      final kgEnabled = ValueNotifier<bool>(true);
      final selContent = ValueNotifier<Set<String>>({});
      final custAccepted = ValueNotifier<Set<String>>({});
      final refused = ValueNotifier<Set<String>>({});
      final catalogLabels = ValueNotifier<List<String>>(
        fallbackCatalog.map((c) => c.label).toList(),
      );
      final descCtrl = TextEditingController();
      final custAccCtrl = TextEditingController();
      final refCtrl = TextEditingController();
      final custPriceCtrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<AnnouncementFormBloc>.value(value: mockBloc),
                BlocProvider<StripeAccountBloc>.value(value: mockStripe),
                BlocProvider<CommissionMethodBloc>.value(value: mockComm),
              ],
              child: SingleChildScrollView(
                child: PrixConditionsStep(
                  priceOptionNotifier: priceOpt,
                  customPriceNotifier: customPrice,
                  availableKgNotifier: availKg,
                  cashEnabledNotifier: cash,
                  kgPriceEnabledNotifier: kgEnabled,
                  selectedContentNotifier: selContent,
                  customAcceptedNotifier: custAccepted,
                  refusedTypesNotifier: refused,
                  catalogLabelsNotifier: catalogLabels,
                  descriptionCtrl: descCtrl,
                  customAcceptedCtrl: custAccCtrl,
                  refusedCtrl: refCtrl,
                  customPriceCtrl: custPriceCtrl,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Petit colis'), findsOneWidget);
      expect(find.text('Grand colis'), findsOneWidget);
      expect(find.textContaining('5.00 €'), findsOneWidget);
      expect(find.textContaining('10.00 €'), findsOneWidget);
    });
  });
}
