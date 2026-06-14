import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/delete_otp_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeleteConfirmationSheet extends StatefulWidget {
  final ValueNotifier<bool> checkboxNotifier;
  final void Function(VoidCallback)? onSubmitReady;

  const DeleteConfirmationSheet({
    super.key,
    required this.checkboxNotifier,
    this.onSubmitReady,
  });

  static Future<void> show(BuildContext context, AccountDeletionBloc bloc) {
    final checkboxNotifier = ValueNotifier<bool>(false);
    VoidCallback? submit;

    return DonyBottomSheet.show(
      context,
      isDanger: true,
      title: 'Dernière étape',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: checkboxNotifier,
        builder: (context, checked, child) =>
            BlocBuilder<AccountDeletionBloc, AccountDeletionState>(
          builder: (ctx, state) => DonyButton(
            label: 'Envoyer le code SMS',
            variant: DonyButtonVariant.destructive,
            isLoading: state is AccountDeletionLoading,
            onPressed: !checked || state is AccountDeletionLoading
                ? null
                : () => submit?.call(),
          ),
        ),
      ),
      child: DeleteConfirmationSheet(
        checkboxNotifier: checkboxNotifier,
        onSubmitReady: (fn) => submit = fn,
      ),
    ).whenComplete(checkboxNotifier.dispose);
  }

  @override
  State<DeleteConfirmationSheet> createState() =>
      _DeleteConfirmationSheetState();
}

class _DeleteConfirmationSheetState extends State<DeleteConfirmationSheet> {
  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_confirm);
  }

  void _confirm() {
    context
        .read<AccountDeletionBloc>()
        .add(const RequestOtpForImmediateDeletion());
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocListener<AccountDeletionBloc, AccountDeletionState>(
      listener: (context, state) {
        if (state is DeletionOtpSent) {
          final deletionBloc = context.read<AccountDeletionBloc>();
          Navigator.of(context, rootNavigator: true).pop();
          DeleteOtpSheet.show(
            context,
            deletionBloc,
            verificationId: state.verificationId,
            phoneHint: state.phoneHint,
          );
        } else if (state is AccountDeletionError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: cs.errorLight,
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(
                color: cs.error.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonyIcon(
                  'triangle-alert',
                  color: cs.error,
                  size: 18,
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    'Toutes vos données personnelles seront effacées immédiatement et définitivement. Cette action est irréversible.',
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.lg),
          ValueListenableBuilder<bool>(
            valueListenable: widget.checkboxNotifier,
            builder: (context, checked, child) => GestureDetector(
              onTap: () =>
                  widget.checkboxNotifier.value = !widget.checkboxNotifier.value,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: checked,
                    activeColor: cs.error,
                    onChanged: (v) =>
                        widget.checkboxNotifier.value = v ?? false,
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: DonySpacing.md),
                      child: Text(
                        'Je comprends que cette suppression est définitive et irréversible.',
                        style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.xl),
        ],
      ),
    );
  }
}
