import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/presentation/widgets/commission_card_empty_state.dart';
import 'package:dony/features/payments/cash/presentation/widgets/commission_card_expiration_banner.dart';
import 'package:dony/features/payments/cash/presentation/widgets/commission_card_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class CommissionMethodScreen extends StatelessWidget {
  const CommissionMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte commission'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: BlocConsumer<CommissionMethodBloc, CommissionMethodState>(
        listener: (ctx, state) async {
          if (state is CommissionMethodSetupInProgress) {
            try {
              await Stripe.instance.confirmSetupIntent(
                paymentIntentClientSecret: state.clientSecret,
                params: const PaymentMethodParams.card(
                    paymentMethodData: PaymentMethodData()),
              );
              ctx.read<CommissionMethodBloc>().add(CommissionMethodSetupCompleted());
            } on StripeException {
              ctx.read<CommissionMethodBloc>().add(CommissionMethodSetupCancelled());
            }
          }
        },
        builder: (ctx, state) {
          if (state is CommissionMethodLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CommissionMethodNotConfigured) {
            return CommissionCardEmptyState(
              onAdd: () =>
                  ctx.read<CommissionMethodBloc>().add(CommissionMethodSetupRequested()),
            );
          }
          if (state is CommissionMethodLoaded) {
            return ListView(
              padding: const EdgeInsets.all(DonySpacing.lg),
              children: [
                CommissionCardPreview(card: state.card),
                CommissionCardExpirationBanner(
                  status: state.card.expirationStatus,
                  formattedExpiry: state.card.formattedExpiry,
                ),
                const SizedBox(height: DonySpacing.base),
                Text(
                  'Cette carte sera débitée de la commission (12 %, min. 1 €) à chaque bid cash accepté.',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: DonySpacing.xl),
                DonyButton(
                  label: 'Remplacer la carte',
                  onPressed: () => ctx
                      .read<CommissionMethodBloc>()
                      .add(CommissionMethodSetupRequested()),
                ),
                const SizedBox(height: DonySpacing.md),
                DonyButton(
                  label: 'Supprimer la carte',
                  variant: DonyButtonVariant.secondary,
                  onPressed: () => _confirmDelete(ctx),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    DonyBottomSheet.show(
      context,
      stickyBottom: Row(
        children: [
          Expanded(
            child: DonyButton(
              label: 'Annuler',
              variant: DonyButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: DonyButton(
              label: 'Supprimer',
              variant: DonyButtonVariant.destructive,
              onPressed: () {
                context
                    .read<CommissionMethodBloc>()
                    .add(CommissionMethodDeleteRequested());
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.all(DonySpacing.xl),
        child: Text(
          'Supprimer cette carte ? Vous ne pourrez plus accepter de bids cash tant que vous n\'aurez pas enregistré une nouvelle carte.',
        ),
      ),
    );
  }
}
