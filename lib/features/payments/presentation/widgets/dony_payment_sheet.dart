import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Bottom sheet de paiement custom Yadony (Apple Pay/Google Pay + PayPal +
/// bouton « Carte »), Stripe restant le seul processeur.
///
/// PCI : la saisie carte est intégralement déléguée à la PaymentSheet native
/// Stripe (bouton « Carte » → [PaymentGateway.initPaymentSheet] +
/// [PaymentGateway.presentPaymentSheet]) — aucun champ de saisie carte custom
/// dans Yadony.
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
        create: (_) =>
            (bloc ??
                  PaymentSheetBloc(
                    gateway: getIt<PaymentGateway>(),
                    repository: getIt<PaymentRepository>(),
                    config: config,
                    errorReporter: getIt<ErrorReportingService>(),
                  ))
              ..add(const PaymentSheetStarted()),
        child: child,
      ),
      stickyBottom: _StickyBottom(onSuccess: onSuccess),
      child: _Body(contextLabel: contextLabel),
    );
  }
}

enum _ViewKind { loading, main, success }

_ViewKind _resolveView(PaymentSheetState state) {
  if (state is PaymentSheetSuccess) return _ViewKind.success;
  final ready = switch (state) {
    final PaymentSheetResolved s => s,
    PaymentSheetProcessing(:final ready) => ready,
    PaymentSheetFailure(:final ready) => ready,
    _ => null,
  };
  return ready == null ? _ViewKind.loading : _ViewKind.main;
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
        DonySnackbar.show(
          context,
          message: failure.message,
          type: DonySnackbarType.error,
        );
      },
      child: BlocBuilder<PaymentSheetBloc, PaymentSheetState>(
        builder: (context, state) {
          switch (_resolveView(state)) {
            case _ViewKind.loading:
              return const _LoadingView();
            case _ViewKind.main:
              return _MainView(contextLabel: contextLabel);
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
    final config = bloc.config;
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
        Text(
          contextLabel,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          CurrencyFormatter.format(config.amountEur, config.currency),
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
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
          _SheetMethodButton(
            key: const Key('paymentSheetPayPalButton'),
            background: _payPalGold,
            foreground: Colors.black87,
            enabled: !processing,
            onPressed: () => bloc.add(const PaymentSheetPayPalPressed()),
            child: const Text('PayPal', style: _methodLabelStyle),
          ),
          const SizedBox(height: DonySpacing.md),
        ],
        // Ouvre la PaymentSheet native Stripe : spinner quand c'est SA chaîne
        // qui tourne (clé éphémère → initPaymentSheet → presentPaymentSheet).
        _SheetMethodButton(
          key: const Key('paymentSheetCardButton'),
          background: cs.primary,
          foreground: cs.onPrimary,
          enabled: !processing,
          isLoading:
              state is PaymentSheetProcessing &&
              state.method == PaymentMethodKind.card,
          spinnerKey: const Key('paymentSheetCardButtonSpinner'),
          onPressed: () => bloc.add(const PaymentSheetCardPressed()),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DonyIcon('credit-card', size: 18, color: cs.onPrimary),
              const SizedBox(width: DonySpacing.xs),
              const Text('Carte', style: _methodLabelStyle),
            ],
          ),
        ),
      ],
    );
  }
}

// Charte or officielle PayPal.
const _payPalGold = Color(0xFFFFC439);

const _methodLabelStyle = TextStyle(fontWeight: FontWeight.w800, fontSize: 16);

/// Gabarit commun des boutons de moyen de paiement (PayPal, Carte) : même
/// hauteur, rayon et pleine largeur que le bouton Apple Pay/Google Pay.
/// Désactivé dès qu'un moyen est en traitement ; [isLoading] remplace le
/// label par un spinner quand c'est la chaîne de CE bouton qui tourne.
class _SheetMethodButton extends StatelessWidget {
  const _SheetMethodButton({
    super.key,
    required this.background,
    required this.foreground,
    required this.enabled,
    this.isLoading = false,
    this.spinnerKey,
    required this.onPressed,
    required this.child,
  });

  final Color background;
  final Color foreground;
  final bool enabled;
  final bool isLoading;
  final Key? spinnerKey;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
        ),
        child: isLoading
            ? SizedBox(
                key: spinnerKey,
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : child,
      ),
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

        // Chaque moyen de paiement (Apple/Google Pay, PayPal, Carte) est
        // auto-suffisant : plus de bouton « Payer » générique à activer via
        // un choix de carte — la note de sécurité reste seule en sticky.
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DonyIcon(
              'shield',
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: DonySpacing.xxs),
            Text(
              'Paiement sécurisé par Stripe',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}
