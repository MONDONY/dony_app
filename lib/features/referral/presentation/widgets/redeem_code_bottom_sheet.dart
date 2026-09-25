import 'dart:async';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract final class RedeemCodeBottomSheet {
  /// Opens a bottom sheet for the user to enter a parrain's referral code.
  /// Returns [true] if the code was applied successfully, [null] if dismissed.
  static Future<bool?> show(BuildContext context) {
    // Pre-create the bloc so it survives MediaQuery rebuilds (keyboard open/close)
    // without being re-instantiated. Closed manually in whenComplete().
    final bloc = ReferralBloc(
      getIt<ReferralRepository>(),
      getIt<AnalyticsService>(),
    );
    final notifier = ValueNotifier<bool>(false);
    final ctrl = TextEditingController();
    ctrl.addListener(() => notifier.value = ctrl.text.trim().isNotEmpty);
    final l = context.l10n;

    return DonyBottomSheet.show<bool>(
      context,
      title: l.referralRedeemTitle,
      subtitle: l.referralRedeemSubtitle,
      wrapper: (child) =>
          BlocProvider<ReferralBloc>.value(value: bloc, child: child),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: notifier,
        builder: (context, hasText, _) =>
            BlocBuilder<ReferralBloc, ReferralState>(
              builder: (context, state) => DonyButton(
                label: l.commonApply,
                isLoading: state is ReferralRedeemLoading,
                onPressed: hasText && state is! ReferralRedeemLoading
                    ? () => context.read<ReferralBloc>().add(
                        ReferralRedeemRequested(ctrl.text.trim().toUpperCase()),
                      )
                    : null,
              ),
            ),
      ),
      child: BlocListener<ReferralBloc, ReferralState>(
        listener: (context, state) {
          if (state is ReferralRedeemed) {
            Navigator.of(context, rootNavigator: true).pop(true);
          } else if (state is ReferralRedeemError) {
            ErrorPresenter.show(context, state.error);
          }
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.sm),
          child: DonyTextField(
            controller: ctrl,
            label: l.referralRedeemCodeFieldLabel,
            hint: l.referralRedeemCodeHint(
              'JEAN0234', // i18n-ignore: exemple de saisie
            ),
          ),
        ),
      ),
    ).whenComplete(() async {
      // showModalBottomSheet résout sa Future dès que pop() est appelé, mais
      // l'animation de fermeture tourne encore ~300ms. On diffère le dispose
      // pour éviter un TextEditingController used-after-dispose.
      await Future.delayed(const Duration(milliseconds: 350));
      ctrl.dispose();
      notifier.dispose();
      unawaited(bloc.close());
    });
  }
}
