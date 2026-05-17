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
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_create_announcement_constants.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// Utilisateur avec Stripe configuré (section paiement complète visible).
final _stripeConfiguredUser = UserModel(
  id: 'u1',
  roles: const [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  stripeAccountStatus: 'ONBOARDING_COMPLETE',
);

/// Utilisateur sans Stripe (section paiement en mode "bannière warning").
final _stripeNotConfiguredUser = UserModel(
  id: 'u2',
  roles: const [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  stripeAccountStatus: 'NOT_CREATED',
);

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
/// [authState] contrôle la section paiement (Stripe configuré ou non).
/// [commissionState] contrôle le switch "Espèces".
Widget _host({
  AuthState? authState,
  CommissionMethodState? commissionState,
}) {
  final mockAuthBloc = _MockAuthBloc();
  final resolvedAuthState =
      authState ?? AuthAuthenticated(_stripeConfiguredUser);
  when(() => mockAuthBloc.state).thenReturn(resolvedAuthState);
  when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());

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
  final availableKgNotifier = ValueNotifier<double>(10);
  final cashEnabledNotifier = ValueNotifier<bool>(false);
  final selectedContentNotifier = ValueNotifier<Set<String>>({});
  final customAcceptedNotifier = ValueNotifier<Set<String>>({});
  final refusedTypesNotifier = ValueNotifier<Set<String>>({});
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
          BlocProvider<AuthBloc>.value(value: mockAuthBloc),
          BlocProvider<CommissionMethodBloc>.value(value: mockCommissionBloc),
        ],
        child: SingleChildScrollView(
          child: PrixConditionsStep(
            priceOptionNotifier: priceOptionNotifier,
            customPriceNotifier: customPriceNotifier,
            availableKgNotifier: availableKgNotifier,
            cashEnabledNotifier: cashEnabledNotifier,
            selectedContentNotifier: selectedContentNotifier,
            customAcceptedNotifier: customAcceptedNotifier,
            refusedTypesNotifier: refusedTypesNotifier,
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
Future<void> _pump(WidgetTester tester, {AuthState? authState, CommissionMethodState? commissionState}) async {
  await tester.pumpWidget(_host(authState: authState, commissionState: commissionState));
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

    testWidgets('ligne estimation brute/nette est affichée', (tester) async {
      await _pump(tester);
      // availableKg=10, prix sélectionné index 0 → 5€/kg
      // estimation = 50€ brut, 44€ net (×0.88)
      expect(
        find.textContaining('Estimation'),
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
        'switch Espèces désactivé quand aucune carte commission configurée',
        (tester) async {
      await _pump(
        tester,
        commissionState: CommissionMethodNotConfigured(),
      );
      final cashSwitch = find.byKey(const Key('payment-method-cash'));
      expect(cashSwitch, findsOneWidget);
      final sw = tester.widget<Switch>(
        find.descendant(of: cashSwitch, matching: find.byType(Switch)).last,
      );
      expect(sw.onChanged, isNull,
          reason:
              'CASH switch doit être désactivé sans carte commission');
    });

    testWidgets(
        'switch Espèces activé quand carte commission valide disponible',
        (tester) async {
      await _pump(
        tester,
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
        authState: AuthAuthenticated(_stripeNotConfiguredUser),
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

    testWidgets('les chips de types de contenu prédéfinis sont affichés',
        (tester) async {
      await _pump(tester);
      for (final type in kContentTypes) {
        expect(
          find.text(type),
          findsOneWidget,
          reason: 'Chip "$type" doit être présent dans Ce que j\'accepte',
        );
      }
    });

    // ── Section CE QUE JE REFUSE ──────────────────────────────────────────────

    testWidgets('label de section Ce que je refuse est affiché',
        (tester) async {
      await _pump(tester);
      expect(find.text('Ce que je refuse'), findsOneWidget);
    });

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
  });
}
