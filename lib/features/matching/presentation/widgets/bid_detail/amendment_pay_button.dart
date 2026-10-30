import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ouverture de l'écran d'attente mobile money de la modification
/// (`context.push<bool>(route)` par défaut) ; rend son résultat de `pop`.
typedef AmendmentMobileMoneyOpener =
    Future<bool?> Function(BuildContext context, String route);

/// Lancement du paiement par un appelant qui choisit le contexte : reçoit le
/// paiement à lancer avec ce contexte (écran d'attente poussé, colis relu
/// avec le `BidBloc` qu'il voit).
typedef AmendmentPayLauncher =
    void Function(Future<void> Function(BuildContext context) pay);

/// Bouton « Payer {brut} » de la barre du bas de l'expéditeur, tant qu'une
/// modification de colis payée en mobile money attend son dépôt : le voyageur
/// l'a acceptée (`PAYMENT_PENDING`). Le dépôt se fait dans les
/// `pawapay.depositDeadlineMinutes` qui suivent l'acceptation.
///
/// Aucun argent ne bouge au tap : le bouton ouvre seulement l'écran d'attente
/// de la modification (choix du payeur, initiation, sondage). C'est cet écran
/// qui demande la vérification locale avant chaque dépôt et qui annonce
/// l'issue. À son retour, le colis est relu, quelle que soit l'issue : une
/// modification expirée ou close entre-temps se voit alors sur la fiche.
class AmendmentPayButton extends StatelessWidget {
  const AmendmentPayButton({
    super.key,
    required this.bid,
    this.openMobileMoney,
    this.analytics,
    this.launcher,
  });

  final BidModel bid;

  /// Dans le sheet d'une tuile « À traiter » : ferme d'abord le sheet, puis
  /// lance le paiement avec le contexte de l'écran. `null` dans la barre du
  /// bas, qui paie avec son propre contexte.
  final AmendmentPayLauncher? launcher;

  /// Injectables pour les tests ; `null` en usage réel.
  final AmendmentMobileMoneyOpener? openMobileMoney;
  final AnalyticsService? analytics;

  /// Modification à payer maintenant : acceptée par le voyageur, en attente du
  /// dépôt mobile money de l'expéditeur. `null` sinon.
  static BidAmendment? payable(BidModel bid) {
    for (final a in bid.amendments) {
      if (a.status == BidAmendmentStatus.paymentPending &&
          a.rail == BidAmendment.railPawapay) {
        return a;
      }
    }
    return null;
  }

  static bool canPay(BidModel bid) => payable(bid) != null;

  @override
  Widget build(BuildContext context) {
    final amendment = payable(bid)!;
    final gross = formatSupplementAmount(
      amendment.grossAmount,
      amendment.currency,
    );
    return DonyButton(
      key: const Key('amendment-pay-btn'),
      label: context.l10n.amendmentPay(gross),
      iconAsset: 'smartphone',
      onPressed: () {
        final launch = launcher;
        if (launch == null) {
          unawaited(_pay(context, amendment));
        } else {
          launch((screenContext) => _pay(screenContext, amendment));
        }
      },
    );
  }

  Future<void> _pay(BuildContext context, BidAmendment amendment) async {
    final route = MobileMoneyScope.amendment(
      bidId: bid.id,
      amendmentId: amendment.id,
    ).awaitingRoute;
    // Sans `BidBloc` (bouton hors de l'écran de détail) : rien à relire.
    final bloc = maybeRead<BidBloc>(context);
    unawaited(
      (analytics ?? getIt<AnalyticsService>()).logEvent(
        AnalyticsEvents.bidAmendmentPaymentStarted,
        properties: const {'method': 'mobile_money'},
      ),
    );
    await (openMobileMoney ?? _defaultOpenMobileMoney)(context, route);
    // Relu même si le résultat est `null` ou `false` : la demande a pu
    // expirer ou être close pendant l'attente. `bloc` est lu avant l'`await`.
    bloc?.add(BidDetailRequested(bid.id));
  }

  static Future<bool?> _defaultOpenMobileMoney(
    BuildContext context,
    String route,
  ) => context.push<bool>(route);
}
