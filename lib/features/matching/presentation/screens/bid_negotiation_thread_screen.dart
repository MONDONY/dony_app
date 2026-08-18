import 'dart:async';

import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Fil de négociation du prix d'un trajet.
///
/// Les deux parties voient le même colis mais pas le même montant : le
/// backend n'envoie `netEur` qu'au voyageur, et c'est ce champ, lui seul, qui
/// décide de la vue rendue ici.
class BidNegotiationThreadScreen extends StatefulWidget {
  const BidNegotiationThreadScreen({super.key, required this.bidId});

  final String bidId;

  @override
  State<BidNegotiationThreadScreen> createState() =>
      _BidNegotiationThreadScreenState();
}

class _BidNegotiationThreadScreenState
    extends State<BidNegotiationThreadScreen> {
  /// Le paiement d'un accord carte emprunte EXACTEMENT le parcours du checkout
  /// direct : `PaymentBloc` transforme le `clientSecret` en feuille prête, la
  /// `DonyPaymentSheet` encaisse, puis `BidBloc` confirme côté serveur. Les
  /// deux blocs appartiennent à l'écran, comme dans `CreateBidScreen`.
  late final PaymentBloc _paymentBloc;
  late final BidBloc _bidBloc;

  @override
  void initState() {
    super.initState();
    _paymentBloc = getIt<PaymentBloc>();
    _bidBloc = getIt<BidBloc>();
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
    unawaited(_bidBloc.close());
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
        context.pop(true);
      case BidNegotiationAction.rejected:
      case BidNegotiationAction.cancelled:
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
        message: 'Paiement non confirmé, réessayez',
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
      contextLabel: 'Prix négocié de votre colis',
      onSuccess: () {
        if (!context.mounted) return;
        _bidBloc.add(BidConfirmPaymentRequested(state.bidId));
        // Le fil n'a plus rien à montrer : l'appelant recharge sa liste et y
        // verra le colis passé en payé.
        context.pop(true);
      },
    );
  }

  /// Fil connu de l'état courant, quel qu'il soit : une erreur ou un checkout
  /// en portent un, et c'est lui qui décide de tout le rendu (corps ET barre
  /// d'actions). Le lire une fois évite de réénumérer les états deux fois.
  static BidNegotiation? _threadOf(BidNegotiationState state) => switch (state) {
    BidNegotiationLoaded(:final negotiation) => negotiation,
    // Le checkout est parti : le fil reste affiché sous la feuille de paiement
    // qui s'ouvre par-dessus.
    BidNegotiationCheckoutReady(:final negotiation) => negotiation,
    BidNegotiationError(:final negotiation) => negotiation,
    BidNegotiationInitial() || BidNegotiationLoading() => null,
  };

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PaymentBloc>.value(value: _paymentBloc),
        BlocProvider<BidBloc>.value(value: _bidBloc),
      ],
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
              title: 'Discussion de prix',
              onBack: () => context.pop(),
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
                  ? _ThreadBody(negotiation: negotiation)
                  : switch (state) {
                      BidNegotiationError(:final error) => DonyEmptyState(
                        key: const Key('nego-error'),
                        title: 'Discussion indisponible',
                        description: ErrorPresenter.resolve(error).message,
                        type: DonyEmptyStateType.error,
                        actionLabel: 'Réessayer',
                        onAction: () => context.read<BidNegotiationBloc>().add(
                          BidNegotiationFetchRequested(widget.bidId),
                        ),
                      ),
                      _ => const Center(
                        key: Key('nego-loading'),
                        child: CircularProgressIndicator(),
                      ),
                    },
            );
          },
        ),
      ),
    );
  }
}

class _ThreadBody extends StatelessWidget {
  const _ThreadBody({required this.negotiation});

  final BidNegotiation negotiation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AmountHeader(negotiation: negotiation),
        const SizedBox(height: DonySpacing.xl),
        _ParcelSummary(negotiation: negotiation),
        const SizedBox(height: DonySpacing.xl),
        _MessagesTimeline(negotiation: negotiation),
      ],
    );
  }
}

/// Montant en tête. Le voyageur lit ce qu'il touchera, l'expéditeur ce qu'il
/// paiera : deux nombres différents, jamais affichés ensemble.
class _AmountHeader extends StatelessWidget {
  const _AmountHeader({required this.negotiation});

  final BidNegotiation negotiation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isTraveler = negotiation.isTravelerView;
    final amount = isTraveler
        ? (negotiation.netEur ?? 0)
        : negotiation.proposedGrossEur;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.lg),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTraveler ? 'Vous recevriez' : 'Vous paieriez',
            style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            formatPriceIn(amount, negotiation.currency),
            key: Key(isTraveler ? 'nego-net-amount' : 'nego-total-amount'),
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Tour ${negotiation.round} sur ${negotiation.maxRounds}',
            style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer),
          ),
        ],
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Le colis',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.md),
        if (weight != null && weight > 0)
          _SummaryLine(
            icon: Icons.inventory_2_rounded,
            label: '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg',
          ),
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
          const SizedBox(height: DonySpacing.md),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: negotiation.photoUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: DonySpacing.sm),
              itemBuilder: (context, i) => ClipRRect(
                key: Key('nego-photo-$i'),
                borderRadius: BorderRadius.circular(DonyRadius.md),
                child: DonyImage(
                  url: negotiation.photoUrls[i],
                  width: 72,
                  height: 72,
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
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _MessagesTimeline extends StatelessWidget {
  const _MessagesTimeline({required this.negotiation});

  final BidNegotiation negotiation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (negotiation.messages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Échanges',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.md),
        for (final message in negotiation.messages)
          Container(
            margin: const EdgeInsets.only(bottom: DonySpacing.sm),
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kindLabel(message.kind),
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (message.proposedGrossEur != null) ...[
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    formatPriceIn(
                      message.proposedGrossEur!,
                      negotiation.currency,
                    ),
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
                if (message.body != null && message.body!.isNotEmpty) ...[
                  const SizedBox(height: DonySpacing.xxs),
                  Text(message.body!, style: tt.bodyMedium),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static String _kindLabel(BidNegotiationMessageKind kind) => switch (kind) {
    BidNegotiationMessageKind.proposal => 'Proposition',
    BidNegotiationMessageKind.counter => 'Contre-offre',
    BidNegotiationMessageKind.accept => 'Acceptée',
    BidNegotiationMessageKind.reject => 'Refusée',
  };
}

class _ThreadActions extends StatelessWidget {
  const _ThreadActions({required this.negotiation, required this.bidId});

  final BidNegotiation negotiation;
  final String bidId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget hint(String message, String key) => Text(
      message,
      key: Key(key),
      textAlign: TextAlign.center,
      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
    );

    // ── Après accord ────────────────────────────────────────────────────────
    // Le `status` distingue les deux aval, et lui seul : `AWAITING_PAYMENT`
    // pour un accord réglé par carte, `PENDING` pour un accord en espèces où
    // c'est le voyageur qui règle la commission Yadony.
    if (negotiation.isAwaitingCardPayment) {
      if (negotiation.needsMyPayment) {
        final bloc = context.read<BidNegotiationBloc>();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            hint(
              'Prix accepté. Réglez maintenant pour réserver votre place, '
                  'le montant reste bloqué jusqu\'à la livraison.',
              'nego-pay-hint',
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('nego-pay-btn'),
              label: 'Payer',
              onPressed: () => bloc.add(BidNegotiationCheckoutRequested(bidId)),
            ),
          ],
        );
      }
      return hint(
        'Prix accepté. En attente du paiement de l\'expéditeur.',
        'nego-awaiting-payment-hint',
      );
    }

    if (negotiation.isAwaitingCashSettlement) {
      return hint(
        negotiation.isTravelerView
            ? 'Prix accepté. Paiement en espèces, il vous reste à régler la '
                  'commission Yadony.'
            : 'Prix accepté. Paiement en espèces, en attente du voyageur, '
                  'vous n\'avez rien à régler ici.',
        'nego-awaiting-traveler-hint',
      );
    }

    if (negotiation.isClosed) {
      return hint(_closedLabel(negotiation), 'nego-closed-hint');
    }

    if (!negotiation.myTurn) {
      return hint(
        'En attente de la réponse de ${negotiation.counterpartyName ?? 'votre interlocuteur'}.',
        'nego-waiting-hint',
      );
    }

    final bloc = context.read<BidNegotiationBloc>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          key: const Key('nego-accept-btn'),
          label: 'Accepter',
          onPressed: () => bloc.add(BidNegotiationAcceptRequested(bidId)),
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: const Key('nego-counter-btn'),
          label: 'Contre-proposer',
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
          label: 'Refuser',
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
  static String _closedLabel(BidNegotiation negotiation) => switch (negotiation
      .status) {
    'ACCEPTED' => 'Prix accepté. Rendez-vous sur votre colis pour la suite.',
    'NEGOTIATION_CLOSED' =>
      negotiation.messages.any(
            (m) => m.kind == BidNegotiationMessageKind.reject,
          )
          ? 'Proposition refusée.'
          : 'Proposition expirée.',
    _ => 'Négociation terminée.',
  };
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
    final submitNotifier = ValueNotifier<VoidCallback?>(null);

    return DonyBottomSheet.show<void>(
      context,
      title: 'Contre-proposer',
      // Jamais « en euros » : la devise est celle du trajet, figée à sa
      // publication, et le champ la porte déjà dans son libellé.
      subtitle:
          'Indiquez le montant total que vous proposez. Votre interlocuteur pourra l\'accepter ou répondre à son tour.',
      stickyBottom: ValueListenableBuilder<VoidCallback?>(
        valueListenable: submitNotifier,
        builder: (_, submit, _) => DonyButton(
          key: const Key('nego-counter-submit'),
          label: 'Envoyer ma contre-offre',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DonyTextField(
          key: const Key('nego-counter-amount'),
          controller: _amountCtrl,
          label:
              'Montant proposé (${SupportedCurrency.symbolOf(widget.currencyCode)})',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          requiredLabel: true,
        ),
        const SizedBox(height: DonySpacing.base),
        DonyTextField(
          key: const Key('nego-counter-body'),
          controller: _bodyCtrl,
          label: 'Message (facultatif)',
          hint: 'Expliquez votre proposition',
          maxLines: 3,
          minLines: 2,
        ),
      ],
    );
  }
}
