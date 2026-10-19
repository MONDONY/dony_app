import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_payment_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Vérification locale avant paiement (`requirePaymentAuth` par défaut).
typedef SupplementPaymentAuthorizer = Future<bool> Function(BuildContext);

/// Ouverture de la feuille de paiement (`DonyPaymentSheet.show` par défaut).
typedef SupplementPaymentSheetPresenter =
    Future<void> Function(
      BuildContext context, {
      required PaymentSheetConfig config,
      required String contextLabel,
      required VoidCallback onSuccess,
    });

/// Bouton « Payer {brut} » de la barre du bas de l'expéditeur, tant qu'un
/// supplément d'un colis payé par carte attend son paiement (`PROPOSED` ou
/// `PAYMENT_PENDING`). « Refuser » reste dans l'encart du supplément.
///
/// Parcours : `requirePaymentAuth`, `POST …/accept`, feuille de paiement
/// (`context: bid_supplement`), `POST …/confirm-payment` attendu dans
/// `onSuccess`, puis relecture du colis. Feuille fermée sans payer : rien ne
/// change, le bouton reste « Payer ». Mobile money et espèces arrivent avec
/// leurs rails (PR A3, A4).
class SupplementPayButton extends StatelessWidget {
  const SupplementPayButton({
    super.key,
    required this.bid,
    this.authorize,
    this.presentSheet,
  });

  final BidModel bid;

  /// Injectables pour les tests ; `null` en usage réel.
  final SupplementPaymentAuthorizer? authorize;
  final SupplementPaymentSheetPresenter? presentSheet;

  /// Supplément payable par carte maintenant.
  static bool canPay(BidModel bid) {
    final s = bid.supplement;
    if (s == null) return false;
    if (s.status != BidSupplementStatus.proposed &&
        s.status != BidSupplementStatus.paymentPending) {
      return false;
    }
    final rail =
        s.rail ??
        (bid.paymentMethod == BidPaymentMethod.stripe
            ? SupplementCheckout.railStripe
            : null);
    return rail == SupplementCheckout.railStripe;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SupplementPaymentCubit>(),
      child: _PayButtonView(
        bid: bid,
        supplement: bid.supplement!,
        authorize: authorize ?? _defaultAuthorize,
        presentSheet: presentSheet ?? DonyPaymentSheet.show,
      ),
    );
  }

  static Future<bool> _defaultAuthorize(BuildContext context) =>
      requirePaymentAuth(
        context,
        authService: getIt<LocalAuthService>(),
        userPrefs: getIt<HiveService>().userPrefs,
      );
}

class _PayButtonView extends StatelessWidget {
  const _PayButtonView({
    required this.bid,
    required this.supplement,
    required this.authorize,
    required this.presentSheet,
  });

  final BidModel bid;
  final BidSupplement supplement;
  final SupplementPaymentAuthorizer authorize;
  final SupplementPaymentSheetPresenter presentSheet;

  @override
  Widget build(BuildContext context) {
    final gross = formatSupplementAmount(
      supplement.grossAmount,
      supplement.currency,
    );
    return BlocConsumer<SupplementPaymentCubit, SupplementPaymentState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: _onState,
      builder: (context, state) => DonyButton(
        key: const Key('supplement-pay-btn'),
        label: context.l10n.supplementPay(gross),
        iconAsset: 'lock',
        isLoading: state.isBusy,
        onPressed: state.isBusy ? null : () => _pay(context),
      ),
    );
  }

  Future<void> _pay(BuildContext context) async {
    final cubit = context.read<SupplementPaymentCubit>();
    // Bouton désactivé pendant l'invite : un double tap n'en ouvre pas deux.
    if (!cubit.beginAuthorization()) return;
    final authenticated = await authorize(context);
    if (!context.mounted) {
      cubit.authorizationDenied();
      return;
    }
    if (!authenticated) {
      cubit.authorizationDenied();
      DonySnackbar.show(
        context,
        message: context.l10n.paymentNotConfirmedSnackbar,
        type: DonySnackbarType.error,
      );
      return;
    }
    await cubit.pay(bid, supplement);
  }

  void _onState(BuildContext context, SupplementPaymentState state) {
    switch (state.status) {
      case SupplementPaymentStatus.readyToPay:
        unawaited(_presentSheet(context, state.checkout!));
      case SupplementPaymentStatus.paid:
        _reloadBid(context);
        DonySnackbar.show(
          context,
          message: context.l10n.supplementPaidSnackbar,
          type: DonySnackbarType.success,
        );
      case SupplementPaymentStatus.confirmationPending:
        // Pas de succès annoncé : le serveur n'a pas encore vu le paiement
        // payé. La fiche relue montre l'état réel.
        _reloadBid(context);
        DonySnackbar.show(
          context,
          message: context.l10n.supplementPaymentConfirming,
        );
      case SupplementPaymentStatus.failure:
        ErrorPresenter.show(context, state.error);
        // Demande refusée, expirée ou retirée entre-temps : la fiche montre
        // le vrai état.
        _reloadBid(context);
      case SupplementPaymentStatus.idle ||
          SupplementPaymentStatus.authorizing ||
          SupplementPaymentStatus.accepting ||
          SupplementPaymentStatus.confirming:
        break;
    }
  }

  Future<void> _presentSheet(
    BuildContext context,
    SupplementCheckout checkout,
  ) async {
    final cubit = context.read<SupplementPaymentCubit>();
    await presentSheet(
      context,
      config: PaymentSheetConfig(
        clientSecret: checkout.clientSecret!,
        amountEur: checkout.amount,
        currencyCode: checkout.currency,
        paymentMethodTypes: checkout.paymentMethodTypes,
        analyticsContext: AnalyticsPaymentContext.bidSupplement,
      ),
      contextLabel: context.l10n.supplementPaymentContextLabel,
      // AUCUNE garde de montage : la confirmation ne dépend d'aucun
      // BuildContext et doit partir même si l'écran se ferme (motif de
      // `confirmBidPaymentSafely`).
      onSuccess: () async => cubit.confirmPayment(bid, supplement),
    );
    // Après un succès, `onSuccess` a déjà fait passer l'état à
    // « confirmation » : sans effet. Sinon, la feuille a été fermée.
    cubit.sheetClosed();
  }

  void _reloadBid(BuildContext context) {
    try {
      context.read<BidBloc>().add(BidDetailRequested(bid.id));
    } on ProviderNotFoundException {
      // Bouton hors de l'écran de détail (tests) : rien à relire.
    }
  }
}
