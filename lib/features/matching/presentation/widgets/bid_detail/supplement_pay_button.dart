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
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

/// Ouverture de l'écran d'attente mobile money du supplément
/// (`context.push<bool>(route)` par défaut) ; rend son résultat de `pop`.
typedef SupplementMobileMoneyOpener =
    Future<bool?> Function(BuildContext context, String route);

/// Bouton « Payer {brut} » de la barre du bas de l'expéditeur, tant qu'un
/// supplément d'un colis payé par carte ou en mobile money attend son
/// paiement (`PROPOSED` ou `PAYMENT_PENDING`). « Refuser » reste dans
/// l'encart du supplément.
///
/// Carte : `requirePaymentAuth`, `POST …/accept`, feuille de paiement
/// (`context: bid_supplement`), `POST …/confirm-payment` attendu dans
/// `onSuccess`, puis relecture du colis. Feuille fermée sans payer : rien ne
/// change, le bouton reste « Payer ».
///
/// Mobile money : `requirePaymentAuth`, `POST …/accept` (`PAYMENT_PENDING`),
/// puis l'écran d'attente du supplément (choix de l'opérateur, numéro,
/// initiation, sondage) ; à son retour, relecture du colis et message selon
/// l'issue.
///
/// Espèces (PR A4) : « Accepter {brut} » ouvre une feuille de confirmation
/// (« Vous remettrez {brut} en espèces »), sans vérification locale ni
/// paiement en ligne : rien n'est débité. `POST …/accept` rend le
/// supplément `PAID` ; l'expéditeur remet le complément en main propre.
class SupplementPayButton extends StatelessWidget {
  const SupplementPayButton({
    super.key,
    required this.bid,
    this.authorize,
    this.presentSheet,
    this.openMobileMoney,
  });

  final BidModel bid;

  /// Injectables pour les tests ; `null` en usage réel.
  final SupplementPaymentAuthorizer? authorize;
  final SupplementPaymentSheetPresenter? presentSheet;
  final SupplementMobileMoneyOpener? openMobileMoney;

  /// Rail du supplément : celui rendu par le back, sinon déduit du moyen de
  /// paiement du colis (le supplément suit toujours le rail du colis).
  static String? railOf(BidModel bid) =>
      bid.supplement?.rail ??
      switch (bid.paymentMethod) {
        BidPaymentMethod.stripe => SupplementCheckout.railStripe,
        BidPaymentMethod.mobileMoney => SupplementCheckout.railPawapay,
        BidPaymentMethod.cash => SupplementCheckout.railCash,
        _ => null,
      };

  /// Supplément à régler maintenant : payable par carte ou en mobile money
  /// (`PROPOSED` ou `PAYMENT_PENDING`), ou à accepter en espèces
  /// (`PROPOSED`).
  static bool canPay(BidModel bid) {
    final s = bid.supplement;
    if (s == null) return false;
    final rail = railOf(bid);
    if (rail == SupplementCheckout.railCash) {
      return s.status == BidSupplementStatus.proposed;
    }
    if (s.status != BidSupplementStatus.proposed &&
        s.status != BidSupplementStatus.paymentPending) {
      return false;
    }
    return rail == SupplementCheckout.railStripe ||
        rail == SupplementCheckout.railPawapay;
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
        openMobileMoney: openMobileMoney ?? _defaultOpenMobileMoney,
      ),
    );
  }

  static Future<bool?> _defaultOpenMobileMoney(
    BuildContext context,
    String route,
  ) => context.push<bool>(route);

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
    required this.openMobileMoney,
  });

  final BidModel bid;
  final BidSupplement supplement;
  final SupplementPaymentAuthorizer authorize;
  final SupplementPaymentSheetPresenter presentSheet;
  final SupplementMobileMoneyOpener openMobileMoney;

  @override
  Widget build(BuildContext context) {
    final gross = formatSupplementAmount(
      supplement.grossAmount,
      supplement.currency,
    );
    final rail = SupplementPayButton.railOf(bid);
    final cash = rail == SupplementCheckout.railCash;
    return BlocConsumer<SupplementPaymentCubit, SupplementPaymentState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: _onState,
      builder: (context, state) => DonyButton(
        key: const Key('supplement-pay-btn'),
        label: cash
            ? context.l10n.supplementCashAccept(gross)
            : context.l10n.supplementPay(gross),
        iconAsset: switch (rail) {
          SupplementCheckout.railPawapay => 'smartphone',
          SupplementCheckout.railCash => 'banknote',
          _ => 'lock',
        },
        isLoading: state.isBusy,
        onPressed: state.isBusy
            ? null
            : () => cash ? _acceptCash(context) : _pay(context),
      ),
    );
  }

  /// Espèces : la feuille de confirmation porte le bouton d'acceptation
  /// (`stickyBottom`) ; aucune vérification locale, rien n'est débité.
  Future<void> _acceptCash(BuildContext context) =>
      SupplementCashAcceptSheet.show(
        context,
        bid: bid,
        supplement: supplement,
        cubit: context.read<SupplementPaymentCubit>(),
      );

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
      case SupplementPaymentStatus.awaitingMobileMoney:
        unawaited(_openMobileMoney(context));
      case SupplementPaymentStatus.paid:
        _reloadBid(context);
        // Mobile money : l'écran d'attente a déjà annoncé le paiement en se
        // refermant, pas de second message.
        if (state.checkout?.isMobileMoney ?? false) break;
        DonySnackbar.show(
          context,
          message: (state.checkout?.isCash ?? false)
              ? context.l10n.supplementCashAcceptedSnackbar(
                  formatSupplementAmount(
                    supplement.grossAmount,
                    supplement.currency,
                  ),
                )
              : context.l10n.supplementPaidSnackbar,
          type: DonySnackbarType.success,
        );
      case SupplementPaymentStatus.mobileMoneyNotConfirmed:
        _reloadBid(context);
        DonySnackbar.show(
          context,
          message: context.l10n.supplementMobileMoneyNotConfirmed,
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

  /// Ouvre l'écran d'attente mobile money du supplément et rend son
  /// résultat au cubit, que l'écran soit encore monté ou non : le cubit
  /// ignore le retour s'il a été fermé entre-temps.
  Future<void> _openMobileMoney(BuildContext context) async {
    final cubit = context.read<SupplementPaymentCubit>();
    final scope = MobileMoneyScope.supplement(
      bidId: bid.id,
      supplementId: supplement.id,
    );
    final paid = await openMobileMoney(context, scope.awaitingRoute);
    cubit.mobileMoneyReturned(paid);
  }

  void _reloadBid(BuildContext context) {
    try {
      context.read<BidBloc>().add(BidDetailRequested(bid.id));
    } on ProviderNotFoundException {
      // Bouton hors de l'écran de détail (tests) : rien à relire.
    }
  }
}

/// Feuille de confirmation de l'expéditeur, colis payé en espèces :
/// « Vous remettrez {brut} en espèces au voyageur ». Le bouton « Je
/// remettrai {brut} en espèces » est dans le `stickyBottom` et lit l'état du
/// [SupplementPaymentCubit] du bouton de la barre (même instance, fournie
/// par `wrapper`). La feuille se referme dès l'issue (accepté ou refusé) ;
/// le bouton de la barre relit le colis et annonce le résultat.
class SupplementCashAcceptSheet extends StatelessWidget {
  const SupplementCashAcceptSheet({super.key, required this.gross});

  /// Brut formaté.
  final String gross;

  static Future<void> show(
    BuildContext context, {
    required BidModel bid,
    required BidSupplement supplement,
    required SupplementPaymentCubit cubit,
  }) {
    final l = context.l10n;
    final gross = formatSupplementAmount(
      supplement.grossAmount,
      supplement.currency,
    );
    return DonyBottomSheet.show<void>(
      context,
      analyticsName: 'bid/supplement-cash-accept',
      title: l.supplementCashConfirmTitle,
      wrapper: (child) => BlocProvider<SupplementPaymentCubit>.value(
        value: cubit,
        child: child,
      ),
      stickyBottom: BlocBuilder<SupplementPaymentCubit, SupplementPaymentState>(
        builder: (ctx, state) => DonyButton(
          key: const Key('supplement-cash-confirm-btn'),
          label: ctx.l10n.supplementCashConfirmButton(gross),
          iconAsset: 'banknote',
          isLoading: state.isBusy,
          onPressed: state.isBusy
              ? null
              : () => ctx.read<SupplementPaymentCubit>().pay(bid, supplement),
        ),
      ),
      child: SupplementCashAcceptSheet(gross: gross),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return BlocListener<SupplementPaymentCubit, SupplementPaymentState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          (curr.status == SupplementPaymentStatus.paid ||
              curr.status == SupplementPaymentStatus.failure),
      listener: (context, _) => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.supplementCashConfirmMessage(gross),
              style: tt.bodyLarge?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: DonySpacing.md),
            DonyStatusBanner(
              type: DonyStatusBannerType.info,
              message: l.supplementCashConfirmHelp,
            ),
          ],
        ),
      ),
    );
  }
}
