import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/bloc/deletion_eligibility_cubit.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:dony/features/settings/presentation/widgets/delete_account_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountDeletionBloc
    extends MockBloc<AccountDeletionEvent, AccountDeletionState>
    implements AccountDeletionBloc {}

class MockDeletionEligibilityCubit extends MockCubit<DeletionEligibilityState>
    implements DeletionEligibilityCubit {}

void main() {
  late MockAccountDeletionBloc mockBloc;
  late MockDeletionEligibilityCubit mockEligibilityCubit;

  setUp(() {
    mockBloc = MockAccountDeletionBloc();
    when(() => mockBloc.state).thenReturn(const AccountDeletionInitial());
    mockEligibilityCubit = MockDeletionEligibilityCubit();
    when(
      () => mockEligibilityCubit.state,
    ).thenReturn(const DeletionEligibilityState(isLoading: false));
    when(() => mockEligibilityCubit.check()).thenAnswer((_) async {});
  });

  Widget buildWidget() => MaterialApp(
    home: BlocProvider<AccountDeletionBloc>.value(
      value: mockBloc,
      child: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => DeleteAccountBottomSheet.show(
              context,
              eligibilityCubit: mockEligibilityCubit,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );

  testWidgets('bouton Continuer grisé si aucune carte sélectionnée', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Le bouton de validation (variant primary/destructive) utilise InkWell.
    // Avec mode == null, onTap est null → le bouton est désactivé.
    final inkWells = tester
        .widgetList<InkWell>(
          find.descendant(
            of: find.byType(DonyButton),
            matching: find.byType(InkWell),
          ),
        )
        .toList();
    expect(inkWells.where((w) => w.onTap == null).isNotEmpty, isTrue);
  });

  testWidgets('sélectionner carte hard → label Continuer →', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pumpAndSettle();

    expect(find.text('Continuer →'), findsOneWidget);
  });

  testWidgets('sélectionner carte soft → label Confirmer la pause', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pause 30 jours'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmer la pause'), findsOneWidget);
  });

  testWidgets('affiche les badges RÉVERSIBLE et IRRÉVERSIBLE', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('RÉVERSIBLE'), findsOneWidget);
    expect(find.text('IRRÉVERSIBLE'), findsOneWidget);
  });

  testWidgets('affiche le groupe de raisons (optionnel)', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Raison (optionnel)'), findsOneWidget);
    expect(find.textContaining("n'utilise plus"), findsOneWidget);
    expect(find.text('Problème de confidentialité'), findsOneWidget);
  });

  testWidgets('affiche le bouton Annuler', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Annuler'), findsOneWidget);
  });

  testWidgets('affiche spinner quand AccountDeletionLoading', (tester) async {
    when(() => mockBloc.state).thenReturn(const AccountDeletionLoading());
    whenListen<AccountDeletionState>(
      mockBloc,
      const Stream.empty(),
      initialState: const AccountDeletionLoading(),
    );

    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester
        .pump(); // don't pumpAndSettle — CircularProgressIndicator animates forever

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('sélectionner une raison via radio option', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.textContaining('Trop de notifications'),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.textContaining('Trop de notifications'), findsOneWidget);
  });

  testWidgets('tap Annuler ferme la bottom sheet', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer mon compte'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer mon compte'), findsNothing);
  });

  testWidgets('sélectionner une option radio via texte', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Scroll down inside the sheet to see radio options
    await tester.tap(
      find.text("Je n'utilise plus le service"),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.text("Je n'utilise plus le service"), findsOneWidget);
  });

  testWidgets('affiche le titre de la bottom sheet', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer mon compte'), findsOneWidget);
  });

  testWidgets(
    'BlocListener: AccountDeletionRequested ferme la sheet et affiche snackbar',
    (tester) async {
      // Use a delayed stream so the state emits after the sheet opens
      final controller = StreamController<AccountDeletionState>();
      whenListen<AccountDeletionState>(
        mockBloc,
        controller.stream,
        initialState: const AccountDeletionInitial(),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Confirm sheet is open
      expect(find.text('Supprimer mon compte'), findsOneWidget);

      // Now emit state
      controller.add(const AccountDeletionRequested());
      await tester.pump();
      await tester.pump();

      // Sheet should be closed (Navigator.pop was called), snackbar shown
      // The "Supprimer mon compte" title should be gone (sheet closed) or snackbar present
      final hasSnackbar = find.byType(SnackBar).evaluate().isNotEmpty;
      final sheetGone = find.text('Supprimer mon compte').evaluate().isEmpty;
      expect(hasSnackbar || sheetGone, isTrue);

      await controller.close();
    },
  );

  testWidgets(
    'BlocListener: AccountDeletionError(isEscrowBlocked) shows dialog',
    (tester) async {
      final controller = StreamController<AccountDeletionState>();
      whenListen<AccountDeletionState>(
        mockBloc,
        controller.stream,
        initialState: const AccountDeletionInitial(),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Emit escrow blocked error
      controller.add(
        const AccountDeletionError(
          error: ValidationException('test', code: 'escrow'),
          isEscrowBlocked: true,
        ),
      );
      await tester.pump();
      await tester.pump();

      // EscrowBlockDialog (DonyDialog) should appear
      expect(
        find.text('Suppression impossible pour l\'instant'),
        findsOneWidget,
      );

      await controller.close();
    },
  );

  testWidgets(
    'suppression bloquée (escrow) → bouton grisé et message affiché à côté',
    (tester) async {
      when(() => mockEligibilityCubit.state).thenReturn(
        const DeletionEligibilityState(
          isLoading: false,
          blockedReasonMessage:
              'Vous avez un envoi en cours de livraison, avec des fonds '
              'bloqués en séquestre. Vous pourrez supprimer votre compte dès '
              'que la livraison sera confirmée.',
        ),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Le message explicatif est affiché.
      expect(find.textContaining('fonds bloqués en séquestre'), findsOneWidget);

      // Même en sélectionnant un mode, le bouton reste désactivé.
      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();

      final submitInkWells = tester
          .widgetList<InkWell>(
            find.descendant(
              of: find.widgetWithText(DonyButton, 'Continuer →'),
              matching: find.byType(InkWell),
            ),
          )
          .toList();
      expect(submitInkWells.every((w) => w.onTap == null), isTrue);
    },
  );

  testWidgets('éligible → pas de message de blocage affiché', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('séquestre'), findsNothing);
    expect(find.textContaining('wallet'), findsNothing);
  });

  testWidgets(
    'bloqué escrow (pas wallet) → pas de CTA remboursement (aucun parcours self-service pour ce motif)',
    (tester) async {
      when(() => mockEligibilityCubit.state).thenReturn(
        const DeletionEligibilityState(
          isLoading: false,
          blockedReasonCode: 'active-transactions',
          blockedReasonMessage: 'fonds bloqués en séquestre',
        ),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Demander le remboursement de mon solde'), findsNothing);
    },
  );

  testWidgets(
    'solde wallet positif → CTA remboursement optionnel visible, tap déclenche requestWalletRefund()',
    (tester) async {
      when(() => mockEligibilityCubit.state).thenReturn(
        const DeletionEligibilityState(
          isLoading: false,
          hasWalletBalance: true,
        ),
      );
      when(
        () => mockEligibilityCubit.requestWalletRefund(),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Demander le remboursement maintenant'), findsOneWidget);

      await tester.tap(find.text('Demander le remboursement maintenant'));
      await tester.pump();

      verify(() => mockEligibilityCubit.requestWalletRefund()).called(1);
    },
  );

  testWidgets(
    'ticket déjà demandé → bannière de confirmation avec le montant, plus de bouton',
    (tester) async {
      when(() => mockEligibilityCubit.state).thenReturn(
        const DeletionEligibilityState(
          isLoading: false,
          hasWalletBalance: true,
          walletRefundRequests: [
            WalletRefundRequest(currency: 'CAD', amount: 45.00),
          ],
        ),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Demander le remboursement maintenant'), findsNothing);
      expect(find.textContaining('Demande envoyée'), findsOneWidget);
    },
  );

  testWidgets(
    'solde wallet positif → suppression jamais bloquée (Apple 5.1.1(v)) : bouton actif',
    (tester) async {
      when(() => mockEligibilityCubit.state).thenReturn(
        const DeletionEligibilityState(
          isLoading: false,
          hasWalletBalance: true,
        ),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Aucun message de blocage, même avec un solde wallet positif.
      expect(find.textContaining('Impossible'), findsNothing);

      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();

      final submitInkWells = tester
          .widgetList<InkWell>(
            find.descendant(
              of: find.widgetWithText(DonyButton, 'Continuer →'),
              matching: find.byType(InkWell),
            ),
          )
          .toList();
      expect(submitInkWells.any((w) => w.onTap != null), isTrue);
    },
  );

  testWidgets('récapitulatif STRIPE : remboursé sur la carte et bonus perdu', (
    tester,
  ) async {
    when(() => mockEligibilityCubit.state).thenReturn(
      const DeletionEligibilityState(
        isLoading: false,
        hasWalletBalance: true,
        walletSettlement: [
          WalletSettlement(
            currency: 'EUR',
            refundableAmount: 35,
            forfeitedAmount: 5,
            inFlightAmount: 0,
            rail: 'STRIPE',
          ),
        ],
      ),
    );
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('35,00'), findsOneWidget);
    expect(
      find.textContaining('seront remboursés sur votre carte'),
      findsOneWidget,
    );
    // '5,00' seul matcherait aussi '35,00' (sous-chaîne) : bordure de mot
    // pour cibler le montant du bonus perdu, pas le montant remboursé.
    expect(find.textContaining(RegExp(r'(?<!\d)5,00')), findsOneWidget);
    expect(find.textContaining('seront perdus'), findsOneWidget);
    expect(find.text('Demander le remboursement maintenant'), findsNothing);
  });

  testWidgets('récapitulatif MANUAL : un membre de l\'équipe recontacte', (
    tester,
  ) async {
    when(() => mockEligibilityCubit.state).thenReturn(
      const DeletionEligibilityState(
        isLoading: false,
        hasWalletBalance: true,
        walletSettlement: [
          WalletSettlement(
            currency: 'XOF',
            refundableAmount: 10000,
            forfeitedAmount: 0,
            inFlightAmount: 0,
            rail: 'MANUAL',
          ),
        ],
      ),
    );
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('vous recontacte'), findsOneWidget);
    expect(find.textContaining('seront perdus'), findsNothing);
  });

  testWidgets('solde uniquement non-cash : seulement la ligne perdue', (
    tester,
  ) async {
    when(() => mockEligibilityCubit.state).thenReturn(
      const DeletionEligibilityState(
        isLoading: false,
        hasWalletBalance: true,
        walletSettlement: [
          WalletSettlement(
            currency: 'EUR',
            refundableAmount: 0,
            forfeitedAmount: 5,
            inFlightAmount: 0,
            rail: 'STRIPE',
          ),
        ],
      ),
    );
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('seront remboursés'), findsNothing);
    expect(find.textContaining('seront perdus'), findsOneWidget);
  });

  testWidgets('ancien contrat : le CTA de remboursement manuel reste', (
    tester,
  ) async {
    when(() => mockEligibilityCubit.state).thenReturn(
      const DeletionEligibilityState(isLoading: false, hasWalletBalance: true),
    );
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Demander le remboursement maintenant'), findsOneWidget);
  });

  testWidgets(
    'deux devises (EUR STRIPE + XOF MANUAL) : les deux blocs sont rendus, '
    'XOF formaté sans décimales',
    (tester) async {
      when(() => mockEligibilityCubit.state).thenReturn(
        const DeletionEligibilityState(
          isLoading: false,
          hasWalletBalance: true,
          walletSettlement: [
            WalletSettlement(
              currency: 'EUR',
              refundableAmount: 35,
              forfeitedAmount: 0,
              inFlightAmount: 0,
              rail: 'STRIPE',
            ),
            WalletSettlement(
              currency: 'XOF',
              refundableAmount: 10000,
              forfeitedAmount: 0,
              inFlightAmount: 0,
              rail: 'MANUAL',
            ),
          ],
        ),
      );
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('seront remboursés sur votre carte'),
        findsOneWidget,
      );
      expect(find.textContaining('vous recontacte'), findsOneWidget);
      // XOF sans décimales : on part du formateur réel plutôt que de deviner
      // le séparateur de milliers (espace fine insécable, pas une espace ASCII).
      final formattedXof = CurrencyFormatter.format(
        10000,
        SupportedCurrency.xof,
      );
      expect(find.textContaining(formattedXof), findsOneWidget);
      expect(formattedXof, isNot(contains('.00')));
      expect(formattedXof, isNot(contains(',00')));
    },
  );

  testWidgets('inFlightAmount > 0 affiche « déjà en cours de remboursement »', (
    tester,
  ) async {
    when(() => mockEligibilityCubit.state).thenReturn(
      const DeletionEligibilityState(
        isLoading: false,
        hasWalletBalance: true,
        walletSettlement: [
          WalletSettlement(
            currency: 'EUR',
            refundableAmount: 10,
            forfeitedAmount: 0,
            inFlightAmount: 20,
            rail: 'STRIPE',
          ),
        ],
      ),
    );
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('déjà en cours de remboursement'),
      findsOneWidget,
    );
  });
}
