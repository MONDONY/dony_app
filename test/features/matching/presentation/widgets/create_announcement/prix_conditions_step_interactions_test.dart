// Tests complémentaires de couverture pour PrixConditionsStep :
// - Tap sur chip prix prédéfini (change l'index sélectionné)
// - Tap sur "Autre prix" (affiche le champ prix custom)
// - Saisie dans le champ prix custom (met à jour customPriceNotifier)
// - Tap sur chip de contenu (add/remove dans selectedContentNotifier)
// - Ajout d'un type custom "Ce que j'accepte" via CaInlineAddRow
// - Ajout d'un type refusé via CaInlineAddRow
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
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

class _MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class _MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

final _stripeConfiguredState = StripeAccountReady(
  const ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
);

const _validCard = CommissionMethod(
  brand: 'visa',
  last4: '4242',
  expMonth: 12,
  expYear: 2028,
  expirationStatus: ExpirationStatus.valid,
);

Widget _host({
  StripeAccountState? stripeState,
  CommissionMethodState? commissionState,
  ValueNotifier<int>? priceOption,
  ValueNotifier<double>? customPrice,
  ValueNotifier<double>? availableKg,
  ValueNotifier<bool>? cashEnabled,
  ValueNotifier<bool>? kgPriceEnabled,
  ValueNotifier<Set<String>>? selectedContent,
  ValueNotifier<Set<String>>? customAccepted,
  ValueNotifier<Set<String>>? refusedTypes,
  TextEditingController? descriptionCtrl,
  TextEditingController? customAcceptedCtrl,
  TextEditingController? refusedCtrl,
  TextEditingController? customPriceCtrl,
  bool lockPrice = false,
  double? lockedTotalPriceEur,
  bool showPaymentMethods = true,
}) {
  final mockStripeBloc = _MockStripeAccountBloc();
  final resolvedStripeState = stripeState ?? _stripeConfiguredState;
  when(() => mockStripeBloc.state).thenReturn(resolvedStripeState);
  when(() => mockStripeBloc.stream).thenAnswer((_) => const Stream.empty());

  final mockCommissionBloc = _MockCommissionMethodBloc();
  final resolvedCommissionState = commissionState ?? CommissionMethodNotConfigured();
  when(() => mockCommissionBloc.state).thenReturn(resolvedCommissionState);
  when(() => mockCommissionBloc.stream).thenAnswer((_) => const Stream.empty());

  return MaterialApp(
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<AnnouncementFormBloc>(create: (_) => AnnouncementFormBloc()),
          BlocProvider<StripeAccountBloc>.value(value: mockStripeBloc),
          BlocProvider<CommissionMethodBloc>.value(value: mockCommissionBloc),
        ],
        child: SingleChildScrollView(
          child: PrixConditionsStep(
            priceOptionNotifier: priceOption ?? ValueNotifier<int>(0),
            customPriceNotifier: customPrice ?? ValueNotifier<double>(0),
            availableKgNotifier: availableKg ?? ValueNotifier<double>(10),
            cashEnabledNotifier: cashEnabled ?? ValueNotifier<bool>(false),
            kgPriceEnabledNotifier: kgPriceEnabled ?? ValueNotifier<bool>(true),
            selectedContentNotifier:
                selectedContent ?? ValueNotifier<Set<String>>({}),
            customAcceptedNotifier:
                customAccepted ?? ValueNotifier<Set<String>>({}),
            refusedTypesNotifier:
                refusedTypes ?? ValueNotifier<Set<String>>({}),
            descriptionCtrl: descriptionCtrl ?? TextEditingController(),
            customAcceptedCtrl: customAcceptedCtrl ?? TextEditingController(),
            refusedCtrl: refusedCtrl ?? TextEditingController(),
            customPriceCtrl: customPriceCtrl ?? TextEditingController(),
            lockPrice: lockPrice,
            lockedTotalPriceEur: lockedTotalPriceEur,
            showPaymentMethods: showPaymentMethods,
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, {
  StripeAccountState? stripeState,
  CommissionMethodState? commissionState,
  ValueNotifier<int>? priceOption,
  ValueNotifier<double>? customPrice,
  ValueNotifier<double>? availableKg,
  ValueNotifier<bool>? cashEnabled,
  ValueNotifier<Set<String>>? selectedContent,
  ValueNotifier<Set<String>>? customAccepted,
  ValueNotifier<Set<String>>? refusedTypes,
  TextEditingController? descriptionCtrl,
  TextEditingController? customAcceptedCtrl,
  TextEditingController? refusedCtrl,
  TextEditingController? customPriceCtrl,
}) async {
  await tester.pumpWidget(_host(
    stripeState: stripeState,
    commissionState: commissionState,
    priceOption: priceOption,
    customPrice: customPrice,
    availableKg: availableKg,
    cashEnabled: cashEnabled,
    selectedContent: selectedContent,
    customAccepted: customAccepted,
    refusedTypes: refusedTypes,
    descriptionCtrl: descriptionCtrl,
    customAcceptedCtrl: customAcceptedCtrl,
    refusedCtrl: refusedCtrl,
    customPriceCtrl: customPriceCtrl,
  ));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
}

void main() {
  group('PrixConditionsStep — interactions prix', () {
    testWidgets('tap sur chip 7€ change le notifier priceOption', (tester) async {
      final priceOption = ValueNotifier<int>(0);
      await _pump(tester, priceOption: priceOption);

      // Chip "7€" est le 3ème chip (index 2)
      await tester.tap(find.text('7€'));
      await tester.pump();

      expect(priceOption.value, 2);
    });

    testWidgets('tap sur "Autre prix" affiche le champ prix custom', (tester) async {
      final priceOption = ValueNotifier<int>(0);
      final customPriceCtrl = TextEditingController();
      await _pump(tester, priceOption: priceOption, customPriceCtrl: customPriceCtrl);

      // Avant le tap, le champ custom n'existe pas
      expect(find.text('ex: 12'), findsNothing);

      // Tap sur "Autre prix"
      await tester.tap(find.text('Autre prix'));
      await tester.pump();
      await tester.pump();

      // Le champ custom apparaît
      expect(find.text('ex: 12'), findsOneWidget);
    });

    testWidgets('saisie dans le champ custom prix met à jour customPriceNotifier',
        (tester) async {
      final priceOption = ValueNotifier<int>(4); // 4 = kPriceOptions.length = "Autre"
      final customPrice = ValueNotifier<double>(0.0);
      final customPriceCtrl = TextEditingController();

      await _pump(
        tester,
        priceOption: priceOption,
        customPrice: customPrice,
        customPriceCtrl: customPriceCtrl,
      );

      // Le champ custom est visible car priceOption == kPriceOptions.length
      expect(find.text('ex: 12'), findsOneWidget);

      // Taper "12" dans le champ
      await tester.enterText(
        find.byWidgetPredicate((w) =>
          w is TextField && w.decoration?.hintText == 'ex: 12'),
        '12',
      );
      await tester.pump();

      expect(customPrice.value, 12.0);
    });
  });

  group('PrixConditionsStep — section "Ce que j\'accepte"', () {
    testWidgets('tap sur chip de contenu le sélectionne', (tester) async {
      final selected = ValueNotifier<Set<String>>({});
      await _pump(tester, selectedContent: selected);

      // Tap sur "Vêtements"
      await tester.tap(find.text('Vêtements'));
      await tester.pump();

      expect(selected.value.contains('Vêtements'), isTrue);
    });

    testWidgets('tap sur chip déjà sélectionné le désélectionne', (tester) async {
      final selected = ValueNotifier<Set<String>>({'Vêtements'});
      await _pump(tester, selectedContent: selected);

      // Tap sur "Vêtements" déjà sélectionné
      await tester.tap(find.text('Vêtements'));
      await tester.pump();

      expect(selected.value.contains('Vêtements'), isFalse);
    });

    testWidgets('les chips de contenu custom sont affichés quand customAccepted est non vide',
        (tester) async {
      final customAccepted = ValueNotifier<Set<String>>({'Mon article custom'});
      await _pump(tester, customAccepted: customAccepted);

      expect(find.text('Mon article custom'), findsOneWidget);
    });
  });

  group('PrixConditionsStep — section "Ce que je refuse"', () {
    testWidgets('les chips de refus sont affichés quand refusedTypes est non vide',
        (tester) async {
      final refused = ValueNotifier<Set<String>>({'Liquides'});
      await _pump(tester, refusedTypes: refused);

      expect(find.text('Liquides'), findsOneWidget);
    });

    testWidgets('ajout via CaInlineAddRow met à jour refusedTypesNotifier',
        (tester) async {
      final refused = ValueNotifier<Set<String>>({});
      final refCtrl = TextEditingController();
      await _pump(tester, refusedTypes: refused, refusedCtrl: refCtrl);

      // Faire défiler jusqu'au bas pour voir la section "Ce que je refuse"
      await tester.dragUntilVisible(
        find.text('Ce que je refuse'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pump();

      // Utiliser le contrôleur directement pour simuler la saisie
      refCtrl.text = 'Explosifs';
      await tester.pump();

      // Taper sur l'icône d'ajout (Icons.add_rounded) dans la section refus
      await tester.tap(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.add_rounded).last,
      );
      await tester.pump();

      expect(refused.value.contains('Explosifs'), isTrue);
    });

    testWidgets('suppression d\'un chip refused met à jour refusedTypesNotifier',
        (tester) async {
      final refused = ValueNotifier<Set<String>>({'Armes'});
      await _pump(tester, refusedTypes: refused);

      // Faire défiler jusqu'au bas
      await tester.dragUntilVisible(
        find.text('Armes'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pump();

      expect(find.text('Armes'), findsOneWidget);

      // Tap sur la croix du chip
      await tester.tap(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.close_rounded).last,
      );
      await tester.pump();

      expect(refused.value.contains('Armes'), isFalse);
    });
  });

  group('PrixConditionsStep — section "Ce que j\'accepte" — ajout/suppression custom',
      () {
    testWidgets('ajout via CaInlineAddRow customAccepted met à jour le notifier',
        (tester) async {
      // Grand viewport pour que la section "Ce que j'accepte" soit dans le rendu
      // après l'ajout du toggle KG/MIXED qui pousse le contenu vers le bas.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final customAccepted = ValueNotifier<Set<String>>({});
      final customCtrl = TextEditingController();
      await _pump(
          tester, customAccepted: customAccepted, customAcceptedCtrl: customCtrl);

      // Utiliser le contrôleur directement
      customCtrl.text = 'Bijoux';
      await tester.pump();

      // Taper sur l'icône d'ajout — le premier add_rounded dans le tree
      // appartient à la section "Ce que j'accepte"
      await tester.tap(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.add_rounded).first,
        warnIfMissed: false,
      );
      await tester.pump();

      expect(customAccepted.value.contains('Bijoux'), isTrue);
    });

    testWidgets('suppression d\'un chip customAccepted met à jour le notifier',
        (tester) async {
      // Grand viewport pour que la section "Ce que j'accepte" soit dans le rendu
      // après l'ajout du toggle KG/MIXED qui pousse le contenu vers le bas.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final customAccepted = ValueNotifier<Set<String>>({'Bijoux'});
      await _pump(tester, customAccepted: customAccepted);

      expect(find.text('Bijoux'), findsOneWidget);

      // Tap sur la croix du chip
      await tester.tap(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.close_rounded).first,
        warnIfMissed: false,
      );
      await tester.pump();

      expect(customAccepted.value.contains('Bijoux'), isFalse);
    });
  });

  group('PrixConditionsStep — switch Espèces', () {
    testWidgets('switch espèces peut être activé quand carte commission valide',
        (tester) async {
      final cashEnabled = ValueNotifier<bool>(false);
      await _pump(
        tester,
        commissionState: CommissionMethodLoaded(_validCard),
        cashEnabled: cashEnabled,
      );

      // Trouver le switch espèces via la Key
      final cashSwitchFinder = find.byKey(const Key('payment-method-cash'));
      expect(cashSwitchFinder, findsOneWidget);

      // Le switch est activable
      final sw = tester.widget<Switch>(
        find.descendant(of: cashSwitchFinder, matching: find.byType(Switch)).last,
      );
      expect(sw.onChanged, isNotNull);
    });

    testWidgets('toggle du switch espèces met à jour cashEnabledNotifier',
        (tester) async {
      final cashEnabled = ValueNotifier<bool>(false);
      await _pump(
        tester,
        commissionState: CommissionMethodLoaded(_validCard),
        cashEnabled: cashEnabled,
      );

      final cashSwitchFinder = find.byKey(const Key('payment-method-cash'));
      await tester.tap(
        find.descendant(of: cashSwitchFinder, matching: find.byType(Switch)).last,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // settle notice fadeIn

      expect(cashEnabled.value, isTrue);
    });
  });

  group('PrixConditionsStep — note aux expéditeurs', () {
    testWidgets('le compteur de caractères est mis à jour en saisie', (tester) async {
      final descCtrl = TextEditingController();
      await _pump(tester, descriptionCtrl: descCtrl);

      // Initialement 0/500
      expect(find.text('0/500'), findsOneWidget);

      // Saisir "hello"
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.maxLines == 4 && w.maxLength == 500,
        ),
        'hello',
      );
      await tester.pump();

      // Maintenant 5/500
      expect(find.text('5/500'), findsOneWidget);
    });
  });

  group('verrouillage du prix (lockPrice)', () {
    testWidgets('lockPrice masque la section prix et affiche la note', (tester) async {
      await tester.pumpWidget(_host(lockPrice: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('locked-price-note')), findsOneWidget);
      // La section "Prix par kg" éditable est masquée.
      expect(find.text('Prix par kg'), findsNothing);
    });

    testWidgets('sans lockPrice, la section prix est visible (pas de note)',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('locked-price-note')), findsNothing);
      expect(find.text('Prix par kg'), findsWidgets);
    });

    testWidgets(
        'lockPrice + lockedTotalPriceEur → carte « Prix total convenu » (et pas la note)',
        (tester) async {
      await tester.pumpWidget(
          _host(lockPrice: true, lockedTotalPriceEur: 150));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('locked-agreed-price-card')), findsOneWidget);
      expect(find.text('Prix total convenu'), findsOneWidget);
      expect(find.text('150 €'), findsOneWidget);
      // La note générique n'est PAS affichée quand un montant convenu existe.
      expect(find.byKey(const Key('locked-price-note')), findsNothing);
    });
  });

  group('section paiement (showPaymentMethods)', () {
    testWidgets('showPaymentMethods=false masque la section paiement',
        (tester) async {
      await tester.pumpWidget(_host(showPaymentMethods: false));
      await tester.pumpAndSettle();
      expect(find.text('Modes de paiement acceptés'), findsNothing);
      expect(find.byKey(const Key('payment-method-stripe')), findsNothing);
      expect(find.byKey(const Key('payment-method-cash')), findsNothing);
    });

    testWidgets('par défaut, la section paiement est visible', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(find.text('Modes de paiement acceptés'), findsOneWidget);
    });
  });
}
