import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_code_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_code_redemption_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Saisie d'un code de recharge fourni par l'équipe Yadony. Le contrôleur de
/// texte et [canSubmit] vivent dans le State du contenu (FLUTTER-18, FLUTTER-1C) :
/// jamais disposés au `whenComplete`, qui part dès le pop.
class WalletTopupCodeSheet extends StatefulWidget {
  const WalletTopupCodeSheet({
    super.key,
    required this.canSubmit,
    this.onSubmitReady,
  });

  final ValueNotifier<bool> canSubmit;
  final void Function(VoidCallback)? onSubmitReady;

  static Future<WalletTopupCodeRedemptionModel?> show(BuildContext context) {
    VoidCallback? submit;
    // Disposé par le State du contenu.
    final canSubmit = ValueNotifier<bool>(false);
    final l = context.l10n;
    return DonyBottomSheet.show<WalletTopupCodeRedemptionModel>(
      context,
      title: l.walletTopupCodeSheetTitle,
      wrapper: (child) => BlocProvider(
        create: (_) => getIt<WalletTopupCodeCubit>(),
        child: child,
      ),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canSubmit,
        builder: (ctx, enabled, _) =>
            BlocBuilder<WalletTopupCodeCubit, WalletTopupCodeState>(
              builder: (ctx, state) {
                final loading = state is WalletTopupCodeSubmitting;
                return DonyButton(
                  label: l.walletTopupCodeSubmit,
                  isLoading: loading,
                  onPressed: (loading || !enabled)
                      ? null
                      : () => submit?.call(),
                );
              },
            ),
      ),
      child: WalletTopupCodeSheet(
        canSubmit: canSubmit,
        onSubmitReady: (fn) => submit = fn,
      ),
    );
  }

  @override
  State<WalletTopupCodeSheet> createState() => _WalletTopupCodeSheetState();
}

class _WalletTopupCodeSheetState extends State<WalletTopupCodeSheet> {
  final TextEditingController _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_submit);
    _codeCtrl.addListener(_notifyValidity);
  }

  @override
  void dispose() {
    _codeCtrl.removeListener(_notifyValidity);
    _codeCtrl.dispose();
    widget.canSubmit.dispose();
    super.dispose();
  }

  void _notifyValidity() {
    widget.canSubmit.value = _codeCtrl.text.trim().isNotEmpty;
  }

  void _submit() {
    if (!widget.canSubmit.value) return;
    context.read<WalletTopupCodeCubit>().submit(_codeCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return BlocListener<WalletTopupCodeCubit, WalletTopupCodeState>(
      listener: (context, state) {
        switch (state) {
          case WalletTopupCodeSuccess(:final redemption):
            Navigator.of(context).pop(redemption);
          case WalletTopupCodeFailure(:final error):
            ErrorPresenter.show(context, error);
          case WalletTopupCodeIdle() || WalletTopupCodeSubmitting():
            break;
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyTextField(
              controller: _codeCtrl,
              label: l.walletTopupCodeFieldLabel,
              hint: l.walletTopupCodeFieldHint,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              l.walletTopupCodeNotice,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
