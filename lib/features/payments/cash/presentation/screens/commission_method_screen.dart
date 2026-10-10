import 'dart:async';

import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/pricing/pricing_labels.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/presentation/widgets/commission_card_empty_state.dart';
import 'package:dony/features/payments/cash/presentation/widgets/commission_card_expiration_banner.dart';
import 'package:dony/features/payments/cash/presentation/widgets/commission_card_preview.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/l10n/l10n.dart';
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        leading: const DonyAppBarBackButton(),
        title: Text(l.commissionCardScreenTitle),
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
            return const DonyDetailSkeleton();
          }
          if (state is CommissionMethodNotConfigured) {
            return CommissionCardEmptyState(
              onAdd: () => ctx.read<CommissionMethodBloc>().add(
                CommissionMethodSetupRequested(),
              ),
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
                      l.commissionCardLoadError,
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: DonySpacing.lg),
                    DonyButton(
                      label: l.commonRetry,
                      onPressed: () => ctx.read<CommissionMethodBloc>().add(
                        CommissionMethodLoadRequested(),
                      ),
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
                  // Le plancher de 1 € n'est vrai qu'en euros : ne pas
                  // l'afficher à un voyageur dont la commission est prélevée
                  // dans une autre devise. Le montant est toujours formaté en
                  // EUR (formatPriceIn) : il garde la locale de sa devise,
                  // jamais celle de la langue de l'app.
                  (ActiveCurrency.current ?? SupportedCurrency.eur) ==
                          SupportedCurrency.eur
                      ? l.commissionCardDebitNoticeMin(
                          commissionPercentLabel(l),
                          formatPriceIn(1, 'EUR'),
                        )
                      : l.commissionCardDebitNotice(commissionPercentLabel(l)),
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: DonySpacing.xl),
                DonyButton(
                  label: l.commissionCardReplaceButton,
                  onPressed: () => ctx.read<CommissionMethodBloc>().add(
                    CommissionMethodSetupRequested(),
                  ),
                ),
                const SizedBox(height: DonySpacing.md),
                DonyButton(
                  label: l.commissionCardDeleteButton,
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

  Future<void> _runPaymentSheet(
    BuildContext context,
    String clientSecret,
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
        message: context.l10n.paymentNotConfirmedSnackbar,
        type: DonySnackbarType.warning,
      );
      context.read<CommissionMethodBloc>().add(
        CommissionMethodSetupCancelled(),
      );
      return;
    }

    var opening = true;
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: yadonyPaymentSheetParameters(
          setupIntentClientSecret: clientSecret,
        ),
      );
      opening = false;
      await Stripe.instance.presentPaymentSheet();
      if (context.mounted) {
        // L'ID du SetupIntent est le préfixe du clientSecret avant "_secret_"
        final siId = clientSecret.split('_secret_').first;
        context.read<CommissionMethodBloc>().add(
          CommissionMethodSetupCompleted(siId),
        );
      }
    } on StripeException catch (e, stackTrace) {
      final mapped = mapStripeException(e);
      if (mapped is PaymentConfirmationException) {
        // Même traitement que la feuille de paiement (FLUTTER-CJ) : codes
        // Stripe vers Sentry, jamais le texte technique du SDK à l'écran.
        if (getIt.isRegistered<ErrorReportingService>()) {
          unawaited(
            getIt<ErrorReportingService>().report(
              mapped,
              operation: opening
                  ? 'commission.stripe_init'
                  : 'commission.stripe_setup',
              stackTrace: stackTrace,
              context: {
                'feature': 'payments',
                'method': 'commission_card',
                ...stripeFailureContext(mapped),
              },
            ),
          );
        }
      }
      if (!context.mounted) {
        return;
      }
      if (mapped is PaymentConfirmationException) {
        DonySnackbar.show(
          context,
          message: commissionSetupErrorMessage(
            context.l10n,
            mapped,
            opening: opening,
          ),
          type: DonySnackbarType.error,
        );
      }
      context.read<CommissionMethodBloc>().add(
        CommissionMethodSetupCancelled(),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    final l = context.l10n;
    DonyBottomSheet.show(
      context,
      stickyBottom: Row(
        children: [
          Expanded(
            child: DonyButton(
              label: l.commonCancel,
              variant: DonyButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: DonyButton(
              label: l.commonDelete,
              variant: DonyButtonVariant.destructive,
              onPressed: () {
                context.read<CommissionMethodBloc>().add(
                  CommissionMethodDeleteRequested(),
                );
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl),
        child: Text(l.commissionCardDeleteConfirmMessage),
      ),
    );
  }
}

/// Texte de l'échec d'enregistrement de la carte de commission : toujours un
/// libellé traduit, jamais le texte du SDK (FLUTTER-CJ, FLUTTER-G5).
@visibleForTesting
String commissionSetupErrorMessage(
  AppLocalizations l,
  PaymentConfirmationException e, {
  required bool opening,
}) => switch (classifyStripeFailure(e, opening: opening)) {
  StripeFailureKind.cardDeclined => e.message ?? l.paymentCardDeclined,
  StripeFailureKind.authenticationFailed => l.paymentAuthenticationFailed,
  StripeFailureKind.sheetUnavailable => l.paymentSheetOpenFailed,
  StripeFailureKind.generic => l.commissionCardAddErrorMessage,
};
