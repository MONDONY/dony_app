import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RejectBottomSheet {
  const RejectBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required NegotiationBloc bloc,
    required String threadId,
  }) {
    VoidCallback? submitFn;

    return DonyBottomSheet.show<void>(
      context,
      title: 'Rejeter la négociation',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      child: _RejectContent(
        bloc: bloc,
        threadId: threadId,
        onSubmitReady: (fn) => submitFn = fn,
      ),
      stickyBottom: BlocBuilder<NegotiationBloc, NegotiationState>(
        bloc: bloc,
        builder: (ctx, state) {
          final loading =
              state is NegotiationActionInProgress ||
              state is NegotiationLoading;
          return DonyButton(
            label: loading ? 'Envoi…' : 'Confirmer le rejet',
            variant: DonyButtonVariant.destructive,
            isLoading: loading,
            onPressed: loading ? null : () => submitFn?.call(),
          );
        },
      ),
    );
  }
}

class _RejectContent extends StatefulWidget {
  const _RejectContent({
    required this.bloc,
    required this.threadId,
    required this.onSubmitReady,
  });
  final NegotiationBloc bloc;
  final String threadId;
  final void Function(VoidCallback) onSubmitReady;

  @override
  State<_RejectContent> createState() => _RejectContentState();
}

class _RejectContentState extends State<_RejectContent> {
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady(_submit);
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    widget.bloc.add(
      NegotiationRejectRequested(
        threadId: widget.threadId,
        reason: _reasonCtrl.text.trim().isEmpty
            ? null
            : _reasonCtrl.text.trim(),
      ),
    );
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _reasonCtrl,
      maxLines: 3,
      maxLength: 280,
      decoration: const InputDecoration(labelText: 'Raison (optionnel)'),
    );
  }
}
