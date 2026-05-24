import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/presentation/widgets/commission_card_empty_state.dart';
import 'package:dony/features/payments/cash/presentation/widgets/commission_card_expiration_banner.dart';
import 'package:dony/features/payments/cash/presentation/widgets/commission_card_preview.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class CommissionMethodScreen extends StatefulWidget {
  const CommissionMethodScreen({super.key});

  @override
  State<CommissionMethodScreen> createState() => _CommissionMethodScreenState();
}

class _CommissionMethodScreenState extends State<CommissionMethodScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<CommissionMethodBloc>().add(CommissionMethodLoadRequested());
    }
  }

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
        listener: (ctx, state) {
          if (state is CommissionMethodSetupInProgress) {
            _runPaymentSheet(ctx, state.clientSecret);
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
          if (state is CommissionMethodError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(DonySpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Une erreur est survenue. Veuillez réessayer.',
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: DonySpacing.lg),
                    DonyButton(
                      label: 'Réessayer',
                      onPressed: () => ctx
                          .read<CommissionMethodBloc>()
                          .add(CommissionMethodLoadRequested()),
                    ),
                  ],
                ),
              ),
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

  Future<void> _runPaymentSheet(BuildContext context, String clientSecret) async {
    final authenticated = await requirePaymentAuth(
      context,
      authService: getIt<LocalAuthService>(),
      userPrefs: getIt<HiveService>().userPrefs,
    );
    if (!context.mounted) return;
    if (!authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentification requise pour effectuer le paiement'),
        ),
      );
      context.read<CommissionMethodBloc>().add(CommissionMethodSetupCancelled());
      return;
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: clientSecret,
          merchantDisplayName: 'Dony',
          style: ThemeMode.system,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      if (context.mounted) {
        // L'ID du SetupIntent est le préfixe du clientSecret avant "_secret_"
        final siId = clientSecret.split('_secret_').first;
        context.read<CommissionMethodBloc>().add(
          CommissionMethodSetupCompleted(siId),
        );
      }
    } on StripeException catch (e) {
      if (!context.mounted) {
        return;
      }
      if (e.error.code != FailureCode.Canceled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.error.localizedMessage ??
                  'Erreur lors de l\'ajout de la carte.',
            ),
          ),
        );
      }
      context.read<CommissionMethodBloc>().add(CommissionMethodSetupCancelled());
    }
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
