import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
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
  @override
  void initState() {
    super.initState();
    // L'accusé de lecture éteint la pastille de non-lus. Il ne dépend pas du
    // chargement du fil : arriver sur l'écran suffit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BidNegotiationBloc>().add(
        BidNegotiationReadRequested(widget.bidId),
      );
    });
  }

  void _onState(BuildContext context, BidNegotiationState state) {
    if (state is BidNegotiationError) {
      unawaited(ErrorPresenter.show(context, state.error));
      return;
    }
    if (state is! BidNegotiationLoaded) return;
    switch (state.action) {
      // L'appelant (liste des discussions, détail du colis) doit recharger :
      // le fil vient de changer d'état pour de bon.
      case BidNegotiationAction.accepted:
      case BidNegotiationAction.rejected:
      case BidNegotiationAction.cancelled:
        context.pop(true);
      case BidNegotiationAction.fetched:
      case BidNegotiationAction.proposed:
      case BidNegotiationAction.countered:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: DonyAppBar(
        title: 'Discussion de prix',
        onBack: () => context.pop(),
      ),
      body: BlocConsumer<BidNegotiationBloc, BidNegotiationState>(
        listener: _onState,
        builder: (context, state) => switch (state) {
          BidNegotiationInitial() || BidNegotiationLoading() => const Center(
            key: Key('nego-loading'),
            child: CircularProgressIndicator(),
          ),
          BidNegotiationError(:final negotiation) when negotiation != null =>
            _ThreadBody(negotiation: negotiation, bidId: widget.bidId),
          BidNegotiationError(:final error) => _ErrorView(
            message: ErrorPresenter.resolve(error).message,
            onRetry: () => context.read<BidNegotiationBloc>().add(
              BidNegotiationFetchRequested(widget.bidId),
            ),
          ),
          BidNegotiationLoaded(:final negotiation) => _ThreadBody(
            negotiation: negotiation,
            bidId: widget.bidId,
          ),
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      key: const Key('nego-error'),
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: cs.onSurfaceVariant),
            const SizedBox(height: DonySpacing.base),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: 'Réessayer',
              fullWidth: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadBody extends StatelessWidget {
  const _ThreadBody({required this.negotiation, required this.bidId});

  final BidNegotiation negotiation;
  final String bidId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AmountHeader(negotiation: negotiation),
                const SizedBox(height: DonySpacing.xl),
                _ParcelSummary(negotiation: negotiation),
                const SizedBox(height: DonySpacing.xl),
                _MessagesTimeline(negotiation: negotiation),
              ],
            ),
          ),
        ),
        _ThreadActions(negotiation: negotiation, bidId: bidId),
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
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    Widget shell(Widget child) => Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.md,
        DonySpacing.lg,
        bottomInset + DonySpacing.md,
      ),
      child: child,
    );

    if (negotiation.isClosed) {
      return shell(
        Text(
          _closedLabel(negotiation.status),
          key: const Key('nego-closed-hint'),
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    if (!negotiation.isMyTurn) {
      return shell(
        Text(
          'En attente de la réponse de ${negotiation.counterpartyName ?? 'votre interlocuteur'}.',
          key: const Key('nego-waiting-hint'),
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    final bloc = context.read<BidNegotiationBloc>();
    return shell(
      Column(
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
      ),
    );
  }

  static String _closedLabel(String status) => switch (status) {
    'ACCEPTED' => 'Prix accepté. Rendez-vous sur votre colis pour la suite.',
    'REJECTED' => 'Proposition refusée.',
    'CANCELLED' => 'Négociation annulée.',
    'EXPIRED' => 'Proposition expirée.',
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
      subtitle:
          'Indiquez le montant total que vous proposez, en euros. Votre interlocuteur pourra l\'accepter ou répondre à son tour.',
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
    required this.onSubmitReady,
  });

  final BidNegotiationBloc bloc;
  final String bidId;
  final double initialAmount;
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

  double? _read() {
    final raw = _amountCtrl.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

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
          label: 'Montant proposé (€)',
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
