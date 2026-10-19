import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/connect_onboarding/bloc/bank_account_link_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Route de « Recevoir mes paiements » (inscription et compte Stripe).
const kPayoutsRoute = '/payments/onboarding';

/// Bouton « Changer de compte bancaire » : demande un lien vers l'espace
/// Stripe Express du voyageur (jamais mis en cache) puis l'ouvre dans le
/// navigateur. Porte son propre [BankAccountLinkCubit].
class ChangeBankAccountButton extends StatelessWidget {
  const ChangeBankAccountButton({
    super.key,
    required this.source,
    this.variant = DonyButtonVariant.secondary,
    this.onOnboardingRequired,
    this.createCubit,
  });

  final BankAccountLinkSource source;
  final DonyButtonVariant variant;

  /// 409 `stripe-onboarding-incomplete` : par défaut, ouvre « Recevoir mes
  /// paiements », qui reprend l'inscription Stripe.
  final VoidCallback? onOnboardingRequired;

  /// Tests : cubit fourni à la place de celui de la DI.
  final BankAccountLinkCubit Function()? createCubit;

  @override
  Widget build(BuildContext context) => BlocProvider<BankAccountLinkCubit>(
    create: (_) => createCubit?.call() ?? getIt<BankAccountLinkCubit>(),
    child: BlocConsumer<BankAccountLinkCubit, BankAccountLinkState>(
      listener: _onState,
      builder: (context, state) {
        final loading = state is BankAccountLinkLoading;
        return DonyButton(
          key: const Key('change-bank-account'),
          label: context.l10n.bankAccountChangeButton,
          iconAsset: 'landmark', // i18n-ignore : nom d'icône
          variant: variant,
          isLoading: loading,
          onPressed: loading
              ? null
              : () => context.read<BankAccountLinkCubit>().request(source),
        );
      },
    ),
  );

  Future<void> _onState(
    BuildContext context,
    BankAccountLinkState state,
  ) async {
    final l = context.l10n;
    switch (state) {
      case BankAccountLinkReady(:final url):
        final cubit = context.read<BankAccountLinkCubit>()..handled();
        // Navigateur du système, comme le lien d'inscription Stripe : Stripe
        // exclut ses pages hébergées des vues web embarquées.
        var opened = false;
        try {
          opened = await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        } on Object {
          opened = false;
        }
        if (!opened) cubit.launchFailed();
      case BankAccountLinkFailed(:final failure, :final error):
        switch (failure) {
          case BankAccountLinkFailure.accountMissing:
            DonySnackbar.show(
              context,
              message: l.bankAccountChangeMissing,
              type: DonySnackbarType.warning,
            );
          case BankAccountLinkFailure.onboardingIncomplete:
            DonySnackbar.show(
              context,
              message: l.bankAccountChangeOnboardingIncomplete,
              type: DonySnackbarType.warning,
            );
            final onRequired = onOnboardingRequired;
            if (onRequired != null) {
              onRequired();
            } else {
              unawaited(context.push(kPayoutsRoute));
            }
          case BankAccountLinkFailure.unavailable:
            DonySnackbar.show(context, message: l.bankAccountChangeUnavailable);
          case BankAccountLinkFailure.launch:
            DonySnackbar.show(
              context,
              message: l.payoutBrowserLaunchFailed,
              type: DonySnackbarType.error,
            );
          case BankAccountLinkFailure.error:
            unawaited(ErrorPresenter.show(context, error));
        }
      case BankAccountLinkIdle() || BankAccountLinkLoading():
        break;
    }
  }
}
