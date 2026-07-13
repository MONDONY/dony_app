import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/intl.dart';

/// Bottom sheet de paiement custom dony (carte + cartes enregistrées +
/// Apple Pay/Google Pay + PayPal), Stripe restant le seul processeur.
///
/// PCI : la saisie carte passe exclusivement par [CardFormField] natif Stripe.
abstract final class DonyPaymentSheet {
  static Future<void> show(
    BuildContext context, {
    required PaymentSheetConfig config,
    required String contextLabel,
    required VoidCallback onSuccess,
    // Injectable pour les tests widget — en usage réel, laissé à null (résolu via getIt).
    PaymentSheetBloc? bloc,
  }) {
    return DonyBottomSheet.show<void>(
      context,
      isDismissible: false,
      wrapper: (child) => BlocProvider<PaymentSheetBloc>(
        create: (_) => (bloc ??
            PaymentSheetBloc(
              gateway: getIt<PaymentGateway>(),
              repository: getIt<PaymentRepository>(),
              config: config,
            ))
          ..add(const PaymentSheetStarted()),
        child: child,
      ),
      stickyBottom: _StickyBottom(onSuccess: onSuccess),
      child: _Body(contextLabel: contextLabel),
    );
  }
}

String _formatAmount(double amountEur) =>
    NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(amountEur);

enum _ViewKind { loading, main, newCard, success }

_ViewKind _resolveView(PaymentSheetState state) {
  if (state is PaymentSheetSuccess) return _ViewKind.success;
  final ready = switch (state) {
    final PaymentSheetResolved s => s,
    PaymentSheetProcessing(:final ready) => ready,
    PaymentSheetFailure(:final ready) => ready,
    _ => null,
  };
  if (ready == null) return _ViewKind.loading;
  return ready.cardChoice is NewCardChoice ? _ViewKind.newCard : _ViewKind.main;
}

class _Body extends StatelessWidget {
  const _Body({required this.contextLabel});

  final String contextLabel;

  @override
  Widget build(BuildContext context) {
    return BlocListener<PaymentSheetBloc, PaymentSheetState>(
      listenWhen: (previous, current) => current is PaymentSheetFailure,
      listener: (context, state) {
        final failure = state as PaymentSheetFailure;
        DonySnackbar.show(context,
            message: failure.message, type: DonySnackbarType.error);
      },
      child: BlocBuilder<PaymentSheetBloc, PaymentSheetState>(
        builder: (context, state) {
          switch (_resolveView(state)) {
            case _ViewKind.loading:
              return const _LoadingView();
            case _ViewKind.main:
              return _MainView(contextLabel: contextLabel);
            case _ViewKind.newCard:
              return const _NewCardView();
            case _ViewKind.success:
              return _SuccessView(state: state as PaymentSheetSuccess);
          }
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: DonySpacing.xxl),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MainView extends StatelessWidget {
  const _MainView({required this.contextLabel});

  final String contextLabel;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bloc = context.read<PaymentSheetBloc>();
    final state = context.watch<PaymentSheetBloc>().state;
    final ready = switch (state) {
      final PaymentSheetResolved s => s,
      PaymentSheetProcessing(:final ready) => ready,
      PaymentSheetFailure(:final ready) => ready,
      _ => null,
    };
    if (ready == null) return const _LoadingView();

    final processing = state is PaymentSheetProcessing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Paiement', style: tt.headlineMedium),
        const SizedBox(height: DonySpacing.xs),
        Text(contextLabel,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: DonySpacing.lg),
        if (ready.walletAvailable) ...[
          SizedBox(
            key: const Key('paymentSheetWalletButton'),
            height: 48,
            child: PlatformPayButton(
              type: PlatformButtonType.pay,
              onPressed: processing
                  ? () {}
                  : () => bloc.add(const PaymentSheetWalletPressed()),
            ),
          ),
          const SizedBox(height: DonySpacing.md),
        ],
        if (ready.paypalAvailable) ...[
          _PayPalButton(
            enabled: !processing,
            onPressed: () => bloc.add(const PaymentSheetPayPalPressed()),
          ),
          const SizedBox(height: DonySpacing.lg),
        ],
        if (ready.savedCards.isNotEmpty) ...[
          Text('Cartes enregistrées', style: tt.titleSmall),
          const SizedBox(height: DonySpacing.sm),
          for (final card in ready.savedCards)
            _CardTile(
              key: Key('paymentSheetSavedCard_${card.id}'),
              label: card.displayLabel,
              selected: ready.cardChoice == SavedCardChoice(card),
              onTap: () => bloc.add(
                PaymentSheetCardChoiceChanged(SavedCardChoice(card)),
              ),
            ),
          const SizedBox(height: DonySpacing.sm),
        ],
        _CardTile(
          key: const Key('paymentSheetNewCardTile'),
          label: 'Nouvelle carte',
          icon: 'plus',
          selected: false,
          onTap: () => bloc.add(
            const PaymentSheetCardChoiceChanged(NewCardChoice()),
          ),
        ),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyPressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: DonySpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base, vertical: DonySpacing.md),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(DonyRadius.card),
        ),
        child: Row(
          children: [
            DonyIcon(icon ?? 'credit-card', size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.md),
            Expanded(child: Text(label, style: tt.bodyMedium)),
            if (selected)
              DonyIcon('circle-check', size: 20, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class _PayPalButton extends StatelessWidget {
  const _PayPalButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  // Charte or officielle PayPal.
  static const _payPalGold = Color(0xFFFFC439);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('paymentSheetPayPalButton'),
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _payPalGold,
          foregroundColor: Colors.black87,
          disabledBackgroundColor: _payPalGold.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
        ),
        child: const Text(
          'PayPal',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    );
  }
}

class _NewCardView extends StatefulWidget {
  const _NewCardView();

  @override
  State<_NewCardView> createState() => _NewCardViewState();
}

class _NewCardViewState extends State<_NewCardView> {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bloc = context.read<PaymentSheetBloc>();
    final state = context.watch<PaymentSheetBloc>().state;
    final ready = switch (state) {
      final PaymentSheetResolved s => s,
      PaymentSheetProcessing(:final ready) => ready,
      PaymentSheetFailure(:final ready) => ready,
      _ => null,
    };
    if (ready == null) return const _LoadingView();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('paymentSheetBackToMain'),
              onPressed: () => bloc.add(
                const PaymentSheetBackToMainPressed(),
              ),
              icon: const DonyIcon('x', size: 18),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: DonySpacing.xs),
            Text('Nouvelle carte', style: tt.headlineMedium),
          ],
        ),
        const SizedBox(height: DonySpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(DonyRadius.card),
          ),
          child: CardFormField(
            key: const Key('paymentSheetCardFormField'),
            style: CardFormStyle(
              backgroundColor: Colors.transparent,
              textColor: cs.onSurface,
              placeholderColor: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        Row(
          children: [
            DonyIcon('lock', size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.xs),
            Expanded(
              child: Text(
                'Champ sécurisé Stripe, dony ne stocke jamais votre numéro de carte',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.md),
        DonyCheckbox(
          key: const Key('paymentSheetSaveCardToggle'),
          label: 'Enregistrer cette carte',
          subtitle: 'Pour vos prochains paiements',
          value: ready.saveCard,
          onChanged: (v) =>
              bloc.add(PaymentSheetSaveCardToggled(v ?? true)),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.state});

  final PaymentSheetSuccess state;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            key: const Key('paymentSheetSuccessCheck'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: DonyIcon('circle-check', size: 40, color: cs.primary),
            ),
          ),
          const SizedBox(height: DonySpacing.lg),
          Text('Paiement confirmé', style: tt.headlineMedium),
          const SizedBox(height: DonySpacing.sm),
          Container(
            key: const Key('paymentSheetEscrowNote'),
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.card),
            ),
            child: Row(
              children: [
                DonyIcon('shield-check', size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    'Les fonds sont conservés en séquestre, le voyageur sera '
                    'payé après la remise du colis.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyBottom extends StatelessWidget {
  const _StickyBottom({required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentSheetBloc, PaymentSheetState>(
      listenWhen: (previous, current) => current is PaymentSheetSuccess,
      listener: (context, state) {
        // Laisse la vue succès s'afficher brièvement avant de fermer la sheet.
        Future.delayed(const Duration(milliseconds: 900), () {
          if (context.mounted) {
            Navigator.of(context).pop();
            onSuccess();
          }
        });
      },
      builder: (context, state) {
        if (state is PaymentSheetSuccess) {
          return DonyButton(
            key: const Key('paymentSheetDoneButton'),
            label: 'Terminé',
            onPressed: () {
              Navigator.of(context).pop();
              onSuccess();
            },
          );
        }

        final bloc = context.read<PaymentSheetBloc>();
        final ready = switch (state) {
          final PaymentSheetResolved s => s,
          PaymentSheetProcessing(:final ready) => ready,
          PaymentSheetFailure(:final ready) => ready,
          _ => null,
        };
        if (ready == null) {
          return const DonyButton(label: 'Payer', onPressed: null);
        }

        final amountLabel = _formatAmount(bloc.config.amountEur);
        final processing = state is PaymentSheetProcessing;
        final canPay = ready.cardChoice != null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              key: const Key('paymentSheetPayButton'),
              label: 'Payer $amountLabel',
              isLoading: processing,
              onPressed: canPay && !processing
                  ? () => bloc.add(const PaymentSheetPayPressed())
                  : null,
            ),
            const SizedBox(height: DonySpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DonyIcon('shield', size: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: DonySpacing.xxs),
                Text(
                  'Paiement sécurisé par Stripe',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
