import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bottom sheet de saisie de la raison du refus d'un trajet lié.
///
/// La raison est obligatoire : le bouton « Confirmer le refus » reste
/// désactivé tant que le champ est vide.
class RefuseTripBottomSheet {
  const RefuseTripBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required NegotiationBloc bloc,
    required String threadId,
  }) {
    final canSubmit = ValueNotifier<bool>(false);
    VoidCallback? submitFn;

    return DonyBottomSheet.show<void>(
      context,
      title: 'Refuser ce trajet',
      isDanger: true,
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      child: _RefuseTripContent(
        bloc: bloc,
        threadId: threadId,
        canSubmit: canSubmit,
        onSubmitReady: (fn) => submitFn = fn,
      ),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canSubmit,
        builder: (ctx, enabled, _) {
          return BlocBuilder<NegotiationBloc, NegotiationState>(
            bloc: bloc,
            builder: (ctx, state) {
              final loading = state is NegotiationActionInProgress ||
                  state is NegotiationLoading;
              return DonyButton(
                label: loading ? 'Envoi…' : 'Confirmer le refus',
                variant: DonyButtonVariant.destructive,
                isLoading: loading,
                onPressed:
                    (!enabled || loading) ? null : () => submitFn?.call(),
              );
            },
          );
        },
      ),
    ).whenComplete(canSubmit.dispose);
  }
}

class _RefuseTripContent extends StatefulWidget {
  const _RefuseTripContent({
    required this.bloc,
    required this.threadId,
    required this.canSubmit,
    required this.onSubmitReady,
  });
  final NegotiationBloc bloc;
  final String threadId;
  final ValueNotifier<bool> canSubmit;
  final void Function(VoidCallback) onSubmitReady;

  @override
  State<_RefuseTripContent> createState() => _RefuseTripContentState();
}

class _RefuseTripContentState extends State<_RefuseTripContent> {
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady(_submit);
    _reasonCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    widget.canSubmit.value = _reasonCtrl.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _reasonCtrl.removeListener(_onChanged);
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      return;
    }
    widget.bloc.add(NegotiationRefuseTripRequested(
      threadId: widget.threadId,
      reason: reason,
    ));
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Explique au voyageur pourquoi ce trajet ne convient pas. '
          'Il pourra ensuite en proposer un autre.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: kTextSecondary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: DonySpacing.base),
        TextField(
          controller: _reasonCtrl,
          maxLines: 3,
          maxLength: 280,
          decoration: const InputDecoration(
            labelText: 'Raison du refus',
            hintText: 'Ex. la date est trop tardive pour mon colis…',
          ),
        ),
      ],
    );
  }
}
