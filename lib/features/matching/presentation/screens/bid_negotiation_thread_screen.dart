import 'dart:async';

import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/data/confirm_bid_payment.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/presentation/activity_refresh.dart';
import 'package:dony/features/package_request/data/models/nego_entry.dart';
import 'package:dony/features/package_request/presentation/widgets/nego_archive_actions.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_hero_card.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Fil de négociation du prix d'un trajet.
///
/// Les deux parties voient le même colis mais pas le même montant : le backend
/// n'envoie `netEur` qu'au voyageur. La vue rendue ici suit le champ `role`
/// qu'il expose, et non la présence de ce montant — un fil sans proposition tait
/// les deux montants, ce qui faisait passer un voyageur pour un expéditeur.
class BidNegotiationThreadScreen extends StatefulWidget {
  const BidNegotiationThreadScreen({
    super.key,
    required this.bidId,
    this.archived = false,
    this.viewerUserId,
  });

  final String bidId;

  /// Utilisateur courant, pour poser chaque bulle du bon côté. Absent, le fil
  /// le déduit du rôle et de l'auteur de la première proposition.
  final String? viewerUserId;

  /// Ouvert depuis le filtre « Archivées » : le détail de trajet ne porte pas
  /// toujours `archived`, la route le transmet pour proposer « Désarchiver ».
  final bool archived;

  @override
  State<BidNegotiationThreadScreen> createState() =>
      _BidNegotiationThreadScreenState();
}

class _BidNegotiationThreadScreenState
    extends State<BidNegotiationThreadScreen> {
  /// Le paiement d'un accord carte emprunte EXACTEMENT le parcours du checkout
  /// direct : `PaymentBloc` transforme le `clientSecret` en feuille prête, la
  /// `DonyPaymentSheet` encaisse, puis `confirmBidPaymentSafely` confirme côté
  /// serveur. La confirmation ne passe volontairement PAS par un BLoC détenu
  /// par l'écran : celui-ci se ferme dans `dispose()` au moment même où l'on
  /// quitte l'écran après paiement, et emportait la requête avec lui.
  late final PaymentBloc _paymentBloc;

  @override
  void initState() {
    super.initState();
    _paymentBloc = getIt<PaymentBloc>();
    // L'accusé de lecture éteint la pastille de non-lus. Il ne dépend pas du
    // chargement du fil : arriver sur l'écran suffit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BidNegotiationBloc>().add(
        BidNegotiationReadRequested(widget.bidId),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_paymentBloc.close());
    super.dispose();
  }

  void _onState(BuildContext context, BidNegotiationState state) {
    if (state is BidNegotiationCheckoutReady) {
      _paymentBloc.add(
        BidCheckoutPaymentRequested(
          clientSecret: state.checkout.clientSecret,
          publishableKey: state.checkout.publishableKey,
          bidId: state.checkout.bidId,
          // Le montant affiché à l'expéditeur est le total brut figé à
          // l'acceptation : le client n'en recalcule aucune part.
          amountEur: state.negotiation?.proposedGrossEur ?? 0,
          currencyCode: state.checkout.currency,
          paymentMethodTypes: state.checkout.paymentMethodTypes,
        ),
      );
      return;
    }
    if (state is BidNegotiationError) {
      unawaited(ErrorPresenter.show(context, state.error));
      return;
    }
    if (state is! BidNegotiationLoaded) return;
    switch (state.action) {
      // L'appelant (liste des discussions, détail du colis) doit recharger :
      // le fil vient de changer d'état pour de bon. Seule exception, l'accord
      // carte côté expéditeur : le fil reste ouvert, il lui reste à payer.
      case BidNegotiationAction.accepted:
        if (state.negotiation.needsMyPayment) break;
        refreshActivityAfterBidChange(context);
        context.pop(true);
      case BidNegotiationAction.rejected:
      case BidNegotiationAction.cancelled:
        refreshActivityAfterBidChange(context);
        context.pop(true);
      case BidNegotiationAction.fetched:
      case BidNegotiationAction.proposed:
      case BidNegotiationAction.countered:
        break;
    }
  }

  Future<void> _onPaymentState(BuildContext context, PaymentState state) async {
    if (state is CheckoutPaymentSheetReady) {
      await _presentPaymentSheet(context, state);
    }
  }

  /// Motif repris tel quel de `CreateBidScreen._presentPaymentSheet` :
  /// `requirePaymentAuth` d'abord, la feuille ensuite. C'est lui qui décide si
  /// biométrie ou PIN s'appliquent, jamais l'appelant.
  Future<void> _presentPaymentSheet(
    BuildContext context,
    CheckoutPaymentSheetReady state,
  ) async {
    final authenticated = await requirePaymentAuth(
      context,
      authService: getIt<LocalAuthService>(),
      userPrefs: getIt<HiveService>().userPrefs,
    );
    if (!context.mounted) return;
    if (!authenticated) {
      DonySnackbar.show(
        context,
        message: context.l10n.negotiationThreadPaymentNotConfirmed,
        type: DonySnackbarType.error,
      );
      return;
    }

    await DonyPaymentSheet.show(
      context,
      config: PaymentSheetConfig(
        clientSecret: state.clientSecret,
        amountEur: state.amountEur,
        currencyCode: state.currencyCode,
        paymentMethodTypes: state.paymentMethodTypes,
      ),
      contextLabel: context.l10n.negotiationThreadPaymentContextLabel,
      onSuccess: () async {
        // AUCUNE garde `context.mounted` avant la confirmation : elle ne
        // dépend d'aucun BuildContext, et la subordonner au montage de l'écran
        // rejouerait le bug corrigé ici (bid resté AWAITING_PAYMENT côté
        // serveur alors que l'escrow Stripe est actif, expéditeur bloqué sur
        // « à payer »). Seul le `pop` est conditionné au montage, plus bas.
        await confirmBidPaymentSafely(state.bidId);
        // Hors garde de montage, comme la confirmation : les listes doivent
        // voir le colis payé même si l'écran est déjà démonté.
        if (!context.mounted) {
          refreshActivityAfterBidChange();
          return;
        }
        refreshActivityAfterBidChange(context);
        // Le fil n'a plus rien à montrer : l'appelant recharge sa liste et y
        // verra le colis passé en payé.
        context.pop(true);
      },
    );
  }

  /// Fil connu de l'état courant, quel qu'il soit : une erreur ou un checkout
  /// en portent un, et c'est lui qui décide de tout le rendu (corps ET barre
  /// d'actions). Le lire une fois évite de réénumérer les états deux fois.
  static BidNegotiation? _threadOf(
    BidNegotiationState state,
  ) => switch (state) {
    BidNegotiationLoaded(:final negotiation) => negotiation,
    // Le checkout est parti : le fil reste affiché sous la feuille de paiement
    // qui s'ouvre par-dessus.
    BidNegotiationCheckoutReady(:final negotiation) => negotiation,
    BidNegotiationError(:final negotiation) => negotiation,
    BidNegotiationInitial() || BidNegotiationLoading() => null,
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PaymentBloc>.value(
      value: _paymentBloc,
      child: NegoArchiveDetailListener(
        kind: NegoEntryKind.trip,
        id: widget.bidId,
        child: BlocListener<PaymentBloc, PaymentState>(
          listener: (ctx, state) => unawaited(_onPaymentState(ctx, state)),
          // Le `BlocConsumer` est AU-DESSUS du scaffold : la barre d'actions
          // change avec l'état du fil, et `stickyBottom` doit pouvoir en changer
          // avec lui.
          child: BlocConsumer<BidNegotiationBloc, BidNegotiationState>(
            listener: _onState,
            builder: (context, state) {
              final negotiation = _threadOf(state);
              return DonyPageScaffold(
                title: context.l10n.negotiationThreadTitle,
                onBack: () => context.pop(),
                // Fil terminé (FLUTTER-EJ) : on peut le ranger ou le retirer de
                // sa liste, pour soi seulement.
                appBarActions: negotiation != null && negotiation.isFinished
                    ? [
                        NegoArchiveMenuButton(
                          kind: NegoEntryKind.trip,
                          id: widget.bidId,
                          archived: widget.archived || negotiation.archived,
                        ),
                      ]
                    : null,
                // Le fil défile et garde l'inset clavier ; un chargement ou une
                // erreur, eux, doivent occuper toute la hauteur pour rester
                // centrés.
                scrollable: negotiation != null,
                stickyBottom: negotiation == null
                    ? null
                    : _ThreadActions(
                        negotiation: negotiation,
                        bidId: widget.bidId,
                      ),
                body: negotiation != null
                    ? _ThreadBody(
                        negotiation: negotiation,
                        viewerUserId: widget.viewerUserId,
                      )
                    : switch (state) {
                        BidNegotiationError(:final error) => DonyEmptyState(
                          key: const Key('nego-error'),
                          title: context.l10n.negotiationThreadErrorTitle,
                          description: ErrorPresenter.resolve(
                            error,
                            l10n: context.l10n,
                          ).message,
                          type: DonyEmptyStateType.error,
                          actionLabel: context.l10n.commonRetry,
                          onAction: () => context
                              .read<BidNegotiationBloc>()
                              .add(BidNegotiationFetchRequested(widget.bidId)),
                        ),
                        _ => const DonyChatSkeleton(key: Key('nego-loading')),
                      },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ThreadBody extends StatelessWidget {
  const _ThreadBody({required this.negotiation, this.viewerUserId});

  final BidNegotiation negotiation;
  final String? viewerUserId;

  @override
  Widget build(BuildContext context) {
    // Entrée en cascade, par blocs de sens (héros, contexte, colis, échanges),
    // jouée une seule fois au chargement du fil.
    Widget enter(Widget child, int step) => child
        .animate()
        .fadeIn(duration: 220.ms, delay: (60 * step).ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        enter(_TripNegoHero(negotiation: negotiation), 0),
        const SizedBox(height: DonySpacing.base),
        enter(_TripContextCard(negotiation: negotiation), 1),
        const SizedBox(height: DonySpacing.md),
        enter(_ParcelSummary(negotiation: negotiation), 2),
        const SizedBox(height: DonySpacing.xl),
        _MessagesTimeline(negotiation: negotiation, viewerUserId: viewerUserId),
      ],
    );
  }
}

/// Variante visuelle (dégradé, icône, pastille) du fil de trajet, reprise du
/// fil « demande de colis » pour que les deux discussions de prix se lisent de
/// la même façon.
@visibleForTesting
ThreadStatusVariant tripNegoVariant(BidNegotiation n) {
  if (n.isAwaitingMobileMoneyPayment) {
    return ThreadStatusVariant.awaitingDeposit;
  }
  if (n.isAwaitingCardPayment) return ThreadStatusVariant.awaitingPayment;
  if (n.isAwaitingCashSettlement) {
    return ThreadStatusVariant.awaitingCommission;
  }
  return switch (n.status) {
    'NEGOTIATING' => ThreadStatusVariant.open,
    'ACCEPTED' => ThreadStatusVariant.accepted,
    _ => ThreadStatusVariant.terminal,
  };
}

/// Montant en tête. Le voyageur lit ce qu'il touchera, l'expéditeur ce qu'il
/// paiera : deux nombres différents, jamais affichés ensemble.
class _TripNegoHero extends StatelessWidget {
  const _TripNegoHero({required this.negotiation});

  final BidNegotiation negotiation;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isTraveler = negotiation.isTravelerView;
    final amount = isTraveler
        ? (negotiation.netEur ?? 0)
        : negotiation.proposedGrossEur;
    final variant = tripNegoVariant(negotiation);
    final negotiating = negotiation.status == 'NEGOTIATING';

    return DonyNegoHeroCard(
      key: const Key('nego-hero'),
      margin: EdgeInsets.zero,
      gradient: variant.gradient,
      shadowColor: variant.shadowColor,
      iconAsset: variant.iconAsset,
      caption: isTraveler
          ? l.negotiationThreadYouWouldReceive
          : l.negotiationThreadYouWouldPay,
      amount: formatPriceIn(amount, negotiation.currency),
      amountKey: Key(isTraveler ? 'nego-net-amount' : 'nego-total-amount'),
      badgeLabel: variant.badge(l),
      roundLabel: l.negotiationThreadRoundLabel(
        negotiation.round,
        negotiation.maxRounds,
      ),
      roundsCount: negotiation.round,
      maxRounds: negotiation.maxRounds,
      // Au plafond, seuls l'acceptation et le refus restent possibles : on le
      // dit avant que le bouton grisé ne le fasse deviner.
      warning: negotiating && negotiation.myTurn && !negotiation.canCounter
          ? l.negotiationLastRoundWarning
          : null,
      turnLabel: !negotiating
          ? null
          : negotiation.myTurn
          ? l.negotiationThreadYourTurn
          : l.negotiationThreadTheirTurn(
              negotiation.counterpartyName ??
                  l.negotiationTripCardCounterpartyFallback,
            ),
      myTurn: negotiation.myTurn,
    );
  }
}

/// Avec qui l'on négocie, et sur quel trajet.
class _TripContextCard extends StatelessWidget {
  const _TripContextCard({required this.negotiation});

  final BidNegotiation negotiation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final name =
        negotiation.counterpartyName ??
        l.negotiationTripCardCounterpartyFallback;
    final dep = negotiation.departureCity;
    final arr = negotiation.arrivalCity;
    final route = dep != null && arr != null
        ? '$dep → $arr'
        : l.requestCreateRecapTrip;
    final date = negotiation.departureDate;

    return _Surface(
      key: const Key('nego-trip-context'),
      child: Row(
        children: [
          DonyAvatar(name: name),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleLarge?.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  date == null
                      ? route
                      : '$route · ${DateFormat.MMMd(l.localeName).format(date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          Container(
            padding: const EdgeInsets.all(DonySpacing.sm),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: DonyIcon('plane', color: cs.primary, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Fond de carte commun aux blocs du fil : surface, ombre douce plutôt
/// qu'un trait dur, rayon des cartes.
class _Surface extends StatelessWidget {
  const _Surface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(
            color: DonyColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ParcelSummary extends StatelessWidget {
  const _ParcelSummary({required this.negotiation});

  final BidNegotiation negotiation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final weight = negotiation.weightKg;

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyIcon('package', color: cs.onSurfaceVariant, size: 16),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  negotiation.contentCategory?.isNotEmpty ?? false
                      ? '${context.l10n.negotiationThreadParcelSectionTitle} · ${negotiation.contentCategory}'
                      : context.l10n.negotiationThreadParcelSectionTitle,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (weight != null && weight > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg',
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
          if (negotiation.gridItems.isNotEmpty ||
              negotiation.customItems.isNotEmpty)
            const SizedBox(height: DonySpacing.md),
          for (final line in negotiation.gridItems)
            _SummaryLine(
              icon: Icons.category_rounded,
              label: line.label,
              trailing:
                  '${line.quantity} × ${formatPriceIn(line.unitPriceDisplayEur, negotiation.currency)}',
            ),
          for (final item in negotiation.customItems)
            _SummaryLine(
              icon: Icons.add_box_rounded,
              label: item.label,
              trailing:
                  '${item.quantity} × ${formatPriceIn(item.amountEur, negotiation.currency)}',
            ),
          if (negotiation.photoUrls.isNotEmpty) ...[
            const SizedBox(height: DonySpacing.sm),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: negotiation.photoUrls.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: DonySpacing.sm),
                itemBuilder: (context, i) => Container(
                  key: Key('nego-photo-$i'),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    // Liseré neutre : la photo garde un bord net sur
                    // n'importe quel fond (noir en clair, blanc en sombre).
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    child: DonyImage(
                      url: negotiation.photoUrls[i],
                      width: 72,
                      height: 72,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (negotiation.description != null &&
              negotiation.description!.isNotEmpty) ...[
            const SizedBox(height: DonySpacing.md),
            Text(
              negotiation.description!,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.label, this.trailing});

  final IconData icon;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.sm),
          Expanded(child: Text(label, style: tt.bodyMedium)),
          if (trailing != null)
            Text(
              trailing!,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

/// Échanges en bulles de chat, comme le fil « demande de colis ».
///
/// Le montant de chaque message est le TOTAL proposé (brut) : c'est le seul
/// que porte un message de trajet, et c'est ce qu'affichait déjà la liste
/// d'échanges. Le net du voyageur reste en tête, dans la carte héros.
class _MessagesTimeline extends StatelessWidget {
  const _MessagesTimeline({required this.negotiation, this.viewerUserId});

  final BidNegotiation negotiation;
  final String? viewerUserId;

  /// Auteur côté expéditeur : seul l'expéditeur propose sur un trajet, le
  /// premier message PROPOSAL est donc le sien. Sert de repli quand l'écran
  /// ne connaît pas l'utilisateur courant.
  String? get _senderId {
    for (final m in negotiation.messages) {
      if (m.kind == BidNegotiationMessageKind.proposal) return m.authorId;
    }
    return null;
  }

  bool _isMine(BidNegotiationMessage m) {
    final me = viewerUserId;
    if (me != null && me.isNotEmpty) return m.authorId == me;
    final sender = _senderId;
    if (sender == null) return false;
    return (m.authorId == sender) != negotiation.isTravelerView;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final messages = negotiation.messages;
    if (messages.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('nego-timeline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.negotiationThreadExchangesTitle,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.md),
        for (var i = 0; i < messages.length; i++)
          Builder(
            builder: (context) {
              final m = messages[i];
              final mine = _isMine(m);
              final isLast = i == messages.length - 1;
              // Dernière offre reçue, à traiter : c'est à moi de jouer.
              final highlight =
                  isLast &&
                  !mine &&
                  negotiation.myTurn &&
                  negotiation.status == 'NEGOTIATING' &&
                  (m.kind == BidNegotiationMessageKind.proposal ||
                      m.kind == BidNegotiationMessageKind.counter);
              return DonyNegoBubble(
                    key: Key('nego-bubble-${m.id}'),
                    kindLabel: _kindLabel(l, m.kind),
                    mine: mine,
                    highlight: highlight,
                    priceText: m.proposedGrossEur == null
                        ? null
                        : formatPriceIn(
                            m.proposedGrossEur!,
                            negotiation.currency,
                          ),
                    body: m.body,
                    sentAt: m.createdAt?.toLocal(),
                  )
                  .animate()
                  .fadeIn(duration: 200.ms, delay: (40 * i).ms)
                  .slideY(begin: 0.05);
            },
          ),
      ],
    );
  }

  /// Mêmes capitales que les bulles du fil « demande de colis ».
  static String _kindLabel(
    AppLocalizations l,
    BidNegotiationMessageKind kind,
  ) => switch (kind) {
    BidNegotiationMessageKind.proposal => l.negotiationMessageKindProposalBadge,
    BidNegotiationMessageKind.counter => l.negotiationMessageKindCounterBadge,
    BidNegotiationMessageKind.accept => l.negotiationStatusBadgeAccepted,
    BidNegotiationMessageKind.reject => l.negotiationMessageKindRejectedBadge,
  };
}

class _ThreadActions extends StatelessWidget {
  const _ThreadActions({required this.negotiation, required this.bidId});

  final BidNegotiation negotiation;
  final String bidId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Même bandeau d'état que le fil « demande de colis » : icône et teinte
    // disent l'étape d'un coup d'œil, la phrase la détaille.
    Widget hint(
      String message,
      String key, {
      required String icon,
      required Color tint,
    }) => DonyNegoStateBanner(
      key: Key(key),
      message: message,
      iconAsset: icon,
      tint: tint,
    );

    // ── Après accord ────────────────────────────────────────────────────────
    // `AWAITING_PAYMENT` pour un accord réglé en ligne (carte ou mobile money,
    // départagés par le mode figé à la proposition), `PENDING` pour un accord
    // en espèces où c'est le voyageur qui règle la commission Yadony.
    final l = context.l10n;

    if (negotiation.isAwaitingMobileMoneyPayment) {
      if (negotiation.needsMyPayment) {
        final bloc = context.read<BidNegotiationBloc>();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            hint(
              l.negotiationThreadPayHint,
              'nego-pay-hint',
              icon: 'smartphone',
              tint: DonyColors.threadStatusViolet,
            ),
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              key: const Key('nego-pay-mobile-money-btn'),
              label: l.bidDetailPayByMobileMoney,
              iconAsset: 'smartphone',
              // Même écran que le détail du colis (choix de l'opérateur puis
              // confirmation sur le téléphone). Payé : le fil n'a plus rien à
              // montrer, l'appelant recharge. Sinon le fil est relu, le serveur
              // a pu annuler l'accord à l'échéance du dépôt.
              onPressed: () async {
                final paid = await context.push<bool>(
                  '/bids/$bidId/mobile-money/awaiting',
                );
                if (!context.mounted) return;
                if (paid ?? false) {
                  refreshActivityAfterBidChange(context);
                  context.pop(true);
                } else {
                  bloc.add(BidNegotiationFetchRequested(bidId));
                }
              },
            ),
          ],
        );
      }
      return hint(
        l.negotiationThreadAwaitingSenderPaymentHint,
        'nego-awaiting-payment-hint',
        icon: 'clock',
        tint: cs.warning,
      );
    }

    if (negotiation.isAwaitingCardPayment) {
      if (negotiation.needsMyPayment) {
        final bloc = context.read<BidNegotiationBloc>();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            hint(
              l.negotiationThreadPayHint,
              'nego-pay-hint',
              icon: 'credit-card',
              tint: DonyColors.threadStatusViolet,
            ),
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              key: const Key('nego-pay-btn'),
              label: l.negotiationThreadPayButton,
              onPressed: () => bloc.add(BidNegotiationCheckoutRequested(bidId)),
            ),
          ],
        );
      }
      return hint(
        l.negotiationThreadAwaitingSenderPaymentHint,
        'nego-awaiting-payment-hint',
        icon: 'clock',
        tint: cs.warning,
      );
    }

    if (negotiation.isAwaitingCashSettlement) {
      return hint(
        negotiation.isTravelerView
            ? l.negotiationThreadCashTravelerHint
            : l.negotiationThreadCashSenderHint,
        'nego-awaiting-traveler-hint',
        icon: 'banknote',
        tint: negotiation.isTravelerView
            ? DonyColors.threadStatusOrange
            : cs.success,
      );
    }

    if (negotiation.isClosed) {
      final accepted = negotiation.status == 'ACCEPTED';
      return hint(
        _closedLabel(l, negotiation),
        'nego-closed-hint',
        icon: accepted ? 'circle-check' : 'circle-x',
        tint: accepted ? cs.success : cs.onSurfaceVariant,
      );
    }

    if (!negotiation.myTurn) {
      // FLUTTER-EQ : sans ce bouton, l'auteur d'une proposition restait
      // bloqué jusqu'à la réponse ou l'expiration. L'endpoint d'annulation
      // clôt tout le fil (pour les deux parties), d'où « Annuler la
      // négociation » plutôt que « Retirer ma proposition ».
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          hint(
            l.negotiationThreadWaitingForReply(
              negotiation.counterpartyName ??
                  l.negotiationThreadCounterpartyFallback,
            ),
            'nego-waiting-hint',
            icon: 'hourglass',
            tint: cs.primary,
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            key: const Key('nego-cancel-btn'),
            label: l.negotiationThreadCancelButton,
            variant: DonyButtonVariant.secondary,
            onPressed: () => unawaited(
              CancelNegotiationSheet.show(
                context,
                bloc: context.read<BidNegotiationBloc>(),
                bidId: bidId,
                // Seul l'expéditeur propose sur un trajet ; un fil clos ne
                // bloque plus sa nouvelle offre côté serveur (seul un fil
                // NEGOTIATING compte comme « demande existante »).
                canReoffer: !negotiation.isTravelerView,
              ),
            ),
          ),
        ],
      );
    }

    final bloc = context.read<BidNegotiationBloc>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          key: const Key('nego-accept-btn'),
          label: l.negotiationThreadAcceptButton,
          onPressed: () => bloc.add(BidNegotiationAcceptRequested(bidId)),
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: const Key('nego-counter-btn'),
          label: l.negotiationThreadCounterButton,
          variant: DonyButtonVariant.secondary,
          // Au plafond de tours, seules l'acceptation et le refus restent
          // ouverts : le serveur refuserait toute nouvelle contre-offre.
          onPressed: negotiation.canCounter
              ? () => unawaited(
                  CounterProposalSheet.show(
                    context,
                    bloc: bloc,
                    bidId: bidId,
                    negotiation: negotiation,
                  ),
                )
              : null,
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: const Key('nego-reject-btn'),
          label: l.negotiationThreadRejectButton,
          variant: DonyButtonVariant.ghost,
          onPressed: () => bloc.add(BidNegotiationRejectRequested(bidId)),
        ),
      ],
    );
  }

  /// Un fil éteint porte toujours le même statut, `NEGOTIATION_CLOSED` : le
  /// serveur ne recycle plus les statuts de colis (REJECTED, CANCELLED,
  /// EXPIRED), qui faisaient réapparaître la discussion en demande refusée.
  ///
  /// La nuance perdue par le statut se relit sur le fil : un message REJECT
  /// n'est posé que lorsqu'une des deux parties ferme, jamais par le balayage
  /// d'expiration. Son absence signe donc une péremption. On teste sa présence
  /// plutôt que le dernier message, pour ne dépendre d'aucun ordre de tri.
  static String _closedLabel(AppLocalizations l, BidNegotiation negotiation) =>
      switch (negotiation.status) {
        'ACCEPTED' => l.negotiationThreadClosedAccepted,
        'NEGOTIATION_CLOSED' =>
          negotiation.messages.any(
                (m) => m.kind == BidNegotiationMessageKind.reject,
              )
              ? l.negotiationThreadClosedRejected
              : l.negotiationThreadClosedExpired,
        _ => l.negotiationThreadClosedDefault,
      };
}

/// Confirmation de l'annulation du fil (FLUTTER-EQ). Les deux boutons vivent
/// dans `stickyBottom` ; aucun état local, rien à disposer. Le bloc est passé
/// explicitement : la feuille s'ouvre sur le navigateur racine, hors de portée
/// du `BlocProvider` de l'écran.
abstract final class CancelNegotiationSheet {
  static Future<void> show(
    BuildContext context, {
    required BidNegotiationBloc bloc,
    required String bidId,
    required bool canReoffer,
  }) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    void close(BuildContext ctx) =>
        Navigator.of(ctx, rootNavigator: true).pop();

    return DonyBottomSheet.show<void>(
      context,
      title: l.negotiationThreadCancelSheetTitle,
      isDanger: true,
      stickyBottom: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              key: const Key('nego-cancel-confirm'),
              label: l.negotiationThreadCancelSheetConfirm,
              variant: DonyButtonVariant.destructive,
              onPressed: () {
                bloc.add(BidNegotiationCancelRequested(bidId));
                close(sheetContext);
              },
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('nego-cancel-keep'),
              label: l.negotiationThreadCancelSheetKeep,
              variant: DonyButtonVariant.ghost,
              onPressed: () => close(sheetContext),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.negotiationThreadCancelSheetBody,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (canReoffer) ...[
            const SizedBox(height: DonySpacing.sm),
            Text(
              l.negotiationThreadCancelSheetReofferNote,
              key: const Key('nego-cancel-reoffer-note'),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Feuille de contre-offre. Le `DonyButton` vit dans `stickyBottom`, les
/// contrôleurs appartiennent au contenu (les champs survivent à l'animation
/// de fermeture), seul le notifier du bouton se dispose en `whenComplete`.
abstract final class CounterProposalSheet {
  static Future<void> show(
    BuildContext context, {
    required BidNegotiationBloc bloc,
    required String bidId,
    required BidNegotiation negotiation,
  }) {
    final l = context.l10n;
    final submitNotifier = ValueNotifier<VoidCallback?>(null);

    return DonyBottomSheet.show<void>(
      context,
      title: l.negotiationThreadCounterButton,
      // Jamais « en euros » : la devise est celle du trajet, figée à sa
      // publication, et le champ la porte déjà dans son libellé.
      subtitle: l.negotiationThreadCounterSubtitle,
      stickyBottom: ValueListenableBuilder<VoidCallback?>(
        valueListenable: submitNotifier,
        builder: (_, submit, _) => DonyButton(
          key: const Key('nego-counter-submit'),
          label: l.negotiationThreadCounterSubmitButton,
          onPressed: submit,
        ),
      ),
      child: _CounterProposalForm(
        bloc: bloc,
        bidId: bidId,
        initialAmount: negotiation.proposedGrossEur,
        currencyCode: negotiation.currency,
        onSubmitReady: (fn) => WidgetsBinding.instance.addPostFrameCallback(
          (_) => submitNotifier.value = fn,
        ),
      ),
    ).whenComplete(submitNotifier.dispose);
  }
}

class _CounterProposalForm extends StatefulWidget {
  const _CounterProposalForm({
    required this.bloc,
    required this.bidId,
    required this.initialAmount,
    required this.currencyCode,
    required this.onSubmitReady,
  });

  final BidNegotiationBloc bloc;
  final String bidId;
  final double initialAmount;
  final String currencyCode;
  final void Function(VoidCallback?) onSubmitReady;

  @override
  State<_CounterProposalForm> createState() => _CounterProposalFormState();
}

class _CounterProposalFormState extends State<_CounterProposalForm> {
  late final TextEditingController _amountCtrl;
  final _bodyCtrl = TextEditingController();
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.initialAmount.toStringAsFixed(2),
    );
    _amountCtrl.addListener(_validate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _validate());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  double? _read() => parsePriceInput(_amountCtrl.text);

  void _validate() {
    final isValid = _read() != null;
    if (isValid == _valid) return;
    _valid = isValid;
    widget.onSubmitReady(isValid ? _submit : null);
  }

  void _submit() {
    final amount = _read();
    if (amount == null) return;
    final body = _bodyCtrl.text.trim();
    widget.bloc.add(
      BidNegotiationCounterRequested(
        widget.bidId,
        proposedTotalEur: amount,
        body: body.isEmpty ? null : body,
      ),
    );
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DonyTextField(
          key: const Key('nego-counter-amount'),
          controller: _amountCtrl,
          label: l.negotiationThreadCounterAmountLabel(
            SupportedCurrency.symbolOf(widget.currencyCode),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          requiredLabel: true,
        ),
        const SizedBox(height: DonySpacing.base),
        DonyTextField(
          key: const Key('nego-counter-body'),
          controller: _bodyCtrl,
          label: l.negotiationThreadCounterMessageLabel,
          hint: l.negotiationThreadCounterMessageHint,
          maxLines: 3,
          minLines: 2,
        ),
      ],
    );
  }
}
