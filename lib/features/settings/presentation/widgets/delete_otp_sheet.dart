import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/delete_confirmation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';

class DeleteOtpSheet extends StatefulWidget {
  final String verificationId;
  final String phoneHint;
  final ValueNotifier<String> codeNotifier;
  final void Function(VoidCallback)? onSubmitReady;

  const DeleteOtpSheet({
    super.key,
    required this.verificationId,
    required this.phoneHint,
    required this.codeNotifier,
    this.onSubmitReady,
  });

  static Future<void> show(
    BuildContext context,
    AccountDeletionBloc bloc, {
    required String verificationId,
    required String phoneHint,
  }) {
    final codeNotifier = ValueNotifier<String>('');
    VoidCallback? submit;

    return DonyBottomSheet.show(
      context,
      isDanger: true,
      title: 'Code de vérification',
      subtitle: 'Envoyé au $phoneHint',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: ValueListenableBuilder<String>(
        valueListenable: codeNotifier,
        builder: (context, code, child) =>
            BlocBuilder<AccountDeletionBloc, AccountDeletionState>(
          builder: (ctx, state) => DonyButton(
            label: 'Confirmer la suppression définitive',
            variant: DonyButtonVariant.destructive,
            isLoading: state is AccountDeletionLoading,
            onPressed: code.length < 6 || state is AccountDeletionLoading
                ? null
                : () => submit?.call(),
          ),
        ),
      ),
      child: DeleteOtpSheet(
        verificationId: verificationId,
        phoneHint: phoneHint,
        codeNotifier: codeNotifier,
        onSubmitReady: (fn) => submit = fn,
      ),
    ).whenComplete(codeNotifier.dispose);
  }

  @override
  State<DeleteOtpSheet> createState() => _DeleteOtpSheetState();
}

class _DeleteOtpSheetState extends State<DeleteOtpSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_confirm);
  }

  void _confirm() {
    context.read<AccountDeletionBloc>().add(
          ConfirmImmediateDeletion(
            verificationId: widget.verificationId,
            smsCode: _controller.text,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.error, width: 2),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: cs.error, width: 2.5),
    );

    return BlocListener<AccountDeletionBloc, AccountDeletionState>(
      listener: (context, state) {
        if (state is AccountDeletionImmediate) {
          final authBloc = context.read<AuthBloc>();
          Navigator.of(context, rootNavigator: true).pop();
          authBloc.add(const AuthLogoutRequested());
        } else if (state is AccountDeletionError && state.isReauthRequired) {
          final deletionBloc = context.read<AccountDeletionBloc>();
          Navigator.of(context, rootNavigator: true).pop();
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
          DeleteConfirmationSheet.show(context, deletionBloc);
        } else if (state is AccountDeletionError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      child: Column(
        children: [
          Pinput(
            controller: _controller,
            length: 6,
            autofocus: true,
            onChanged: (value) => widget.codeNotifier.value = value,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
          ),
          const SizedBox(height: DonySpacing.xl),
        ],
      ),
    );
  }
}
