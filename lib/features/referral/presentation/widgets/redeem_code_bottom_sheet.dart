import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract final class RedeemCodeBottomSheet {
  /// Opens a bottom sheet for the user to enter a parrain's referral code.
  /// Returns [true] if the code was applied successfully, [null] if dismissed.
  static Future<bool?> show(BuildContext context) {
    // Pre-create the bloc so it survives MediaQuery rebuilds (keyboard open/close)
    // without being re-instantiated. Closed manually in whenComplete().
    final bloc = ReferralBloc(getIt<ReferralRepository>(), getIt<AnalyticsService>());
    final notifier = ValueNotifier<bool>(false);
    final ctrl = TextEditingController();
    ctrl.addListener(() => notifier.value = ctrl.text.trim().isNotEmpty);

    return DonyBottomSheet.show<bool>(
      context,
      title: 'Entrer un code parrain',
      subtitle:
          'Tu as été invité par un ami ? Entre son code pour qu\'il soit récompensé à ta première livraison.',
      wrapper: (child) => BlocProvider<ReferralBloc>.value(
        value: bloc,
        child: child,
      ),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: notifier,
        builder: (context, hasText, _) =>
            BlocBuilder<ReferralBloc, ReferralState>(
          builder: (context, state) => DonyButton(
            label: 'Appliquer',
            isLoading: state is ReferralRedeemLoading,
            onPressed: hasText && state is! ReferralRedeemLoading
                ? () => context.read<ReferralBloc>().add(
                      ReferralRedeemRequested(
                        ctrl.text.trim().toUpperCase(),
                      ),
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
            label: 'Code parrain',
            hint: 'Ex : JEAN0234',
          ),
        ),
      ),
    ).whenComplete(() {
      ctrl.dispose();
      notifier.dispose();
      bloc.close();
    });
  }
}
