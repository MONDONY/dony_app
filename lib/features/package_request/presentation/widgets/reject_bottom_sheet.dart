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
  }) async {
    final reasonCtrl = TextEditingController();

    await DonyBottomSheet.show<void>(
      context,
      title: 'Rejeter la négociation',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: BlocBuilder<NegotiationBloc, NegotiationState>(
        bloc: bloc,
        builder: (ctx, state) {
          final loading = state is NegotiationActionInProgress ||
              state is NegotiationLoading;
          return DonyButton(
            label: loading ? 'Envoi…' : 'Confirmer le rejet',
            variant: DonyButtonVariant.destructive,
            isLoading: loading,
            onPressed: () {
              bloc.add(NegotiationRejectRequested(
                threadId: threadId,
                reason: reasonCtrl.text.trim().isEmpty
                    ? null
                    : reasonCtrl.text.trim(),
              ));
              Navigator.of(ctx, rootNavigator: true).pop();
            },
          );
        },
      ),
      child: TextField(
        controller: reasonCtrl,
        maxLines: 3,
        maxLength: 280,
        decoration: const InputDecoration(
          labelText: 'Raison (optionnel)',
        ),
      ),
    ).whenComplete(reasonCtrl.dispose);
  }
}
