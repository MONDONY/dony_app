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
    return DonyBottomSheet.show<void>(
      context,
      title: 'Rejeter la négociation',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      child: _RejectContent(bloc: bloc, threadId: threadId),
    );
  }
}

class _RejectContent extends StatefulWidget {
  const _RejectContent({required this.bloc, required this.threadId});
  final NegotiationBloc bloc;
  final String threadId;

  @override
  State<_RejectContent> createState() => _RejectContentState();
}

class _RejectContentState extends State<_RejectContent> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    widget.bloc.add(NegotiationRejectRequested(
      threadId: widget.threadId,
      reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
    ));
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _reasonCtrl,
          maxLines: 3,
          maxLength: 280,
          decoration: const InputDecoration(
            labelText: 'Raison (optionnel)',
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<NegotiationBloc, NegotiationState>(
          bloc: widget.bloc,
          builder: (ctx, state) {
            final loading = state is NegotiationActionInProgress ||
                state is NegotiationLoading;
            return DonyButton(
              label: loading ? 'Envoi…' : 'Confirmer le rejet',
              variant: DonyButtonVariant.destructive,
              isLoading: loading,
              onPressed: loading ? null : _submit,
            );
          },
        ),
      ],
    );
  }
}
