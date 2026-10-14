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
  ///
  /// [initialCode] pré-remplit le champ (code venu d'un lien d'invitation) :
  /// il n'est jamais envoyé sans que la personne touche « Appliquer ».
  static Future<bool?> show(BuildContext context, {String? initialCode}) {
    // Pre-create the bloc so it survives MediaQuery rebuilds (keyboard open/close)
    // without being re-instantiated. Closed manually in whenComplete().
    final bloc = ReferralBloc(
      getIt<ReferralRepository>(),
      getIt<AnalyticsService>(),
    );
    // Seule la saisie y écrit (listener du contrôleur, propriété du `State`
    // du formulaire) : libéré au `whenComplete`, après l'animation.
    final hasText = ValueNotifier<bool>(
      initialCode != null && initialCode.trim().isNotEmpty,
    );
    String Function()? readCode;
    final l = context.l10n;

    return DonyBottomSheet.show<bool>(
      context,
      title: l.referralRedeemTitle,
      subtitle: l.referralRedeemSubtitle,
      wrapper: (child) =>
          BlocProvider<ReferralBloc>.value(value: bloc, child: child),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: hasText,
        builder: (context, filled, _) =>
            BlocBuilder<ReferralBloc, ReferralState>(
              builder: (context, state) => DonyButton(
                label: l.commonApply,
                isLoading: state is ReferralRedeemLoading,
                onPressed: filled && state is! ReferralRedeemLoading
                    ? () {
                        final code = readCode?.call() ?? '';
                        if (code.isEmpty) return;
                        context.read<ReferralBloc>().add(
                          ReferralRedeemRequested(code),
                        );
                      }
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
        child: _RedeemCodeForm(
          initialCode: initialCode,
          hasText: hasText,
          onCodeReaderReady: (reader) => readCode = reader,
        ),
      ),
    ).whenComplete(() async {
      // showModalBottomSheet résout sa Future dès que pop() est appelé, mais
      // l'animation de fermeture tourne encore ~300ms : le notifier et le
      // bloc vivent jusqu'à sa fin.
      await Future.delayed(const Duration(milliseconds: 350));
      hasText.dispose();
      unawaited(bloc.close());
    });
  }
}

/// Champ de saisie. Le contrôleur vit dans ce `State` (jamais libéré au
/// `whenComplete` : le clavier qui se replie pendant l'animation de sortie
/// rebâtit le champ, FLUTTER-18).
class _RedeemCodeForm extends StatefulWidget {
  const _RedeemCodeForm({
    required this.initialCode,
    required this.hasText,
    required this.onCodeReaderReady,
  });

  final String? initialCode;
  final ValueNotifier<bool> hasText;
  final void Function(String Function() reader) onCodeReaderReady;

  @override
  State<_RedeemCodeForm> createState() => _RedeemCodeFormState();
}

class _RedeemCodeFormState extends State<_RedeemCodeForm> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialCode,
  );

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    widget.onCodeReaderReady(() => _ctrl.text.trim().toUpperCase());
  }

  void _onChanged() => widget.hasText.value = _ctrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: DonyTextField(
        controller: _ctrl,
        label: l.referralRedeemCodeFieldLabel,
        hint: l.referralRedeemCodeHint(
          'JEAN0234', // i18n-ignore: exemple de saisie
        ),
      ),
    );
  }
}
