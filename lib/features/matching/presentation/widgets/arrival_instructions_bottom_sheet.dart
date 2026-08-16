import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bottom sheet « Arrivé à destination » : le voyageur marque son trajet
/// comme arrivé et peut renseigner en une fois des instructions de retrait
/// optionnelles (lieu/heure de récupération du colis).
class ArrivalInstructionsBottomSheet extends StatefulWidget {
  const ArrivalInstructionsBottomSheet({
    super.key,
    required this.announcementId,
    this.initialInstructions,
    this.onSubmitReady,
  });

  final String announcementId;
  final String? initialInstructions;
  final void Function(VoidCallback)? onSubmitReady;

  static Future<void> show(
    BuildContext context, {
    required String announcementId,
    String? initialInstructions,
  }) {
    final announcementBloc = context.read<AnnouncementBloc>();
    VoidCallback? submit;
    return DonyBottomSheet.show(
      context,
      title: 'Arrivé à destination',
      subtitle: 'Indiquez où et comment récupérer le colis',
      wrapper: (child) =>
          BlocProvider.value(value: announcementBloc, child: child),
      stickyBottom: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (ctx, state) => DonyButton(
          label: "Confirmer l'arrivée",
          isLoading: state is AnnouncementLoading,
          onPressed: state is AnnouncementLoading ? null : () => submit?.call(),
        ),
      ),
      child: ArrivalInstructionsBottomSheet(
        announcementId: announcementId,
        initialInstructions: initialInstructions,
        onSubmitReady: (fn) => submit = fn,
      ),
    );
  }

  @override
  State<ArrivalInstructionsBottomSheet> createState() =>
      _ArrivalInstructionsBottomSheetState();
}

class _ArrivalInstructionsBottomSheetState
    extends State<ArrivalInstructionsBottomSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialInstructions,
  );

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_submit);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final bloc = context.read<AnnouncementBloc>();
    final text = _ctrl.text.trim();
    bloc.add(
      AnnouncementTripMarkArrivedRequested(
        announcementId: widget.announcementId,
        arrivalInstructions: text.isEmpty ? null : text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AnnouncementBloc, AnnouncementState>(
      listener: (context, state) {
        if (state is AnnouncementTripArrived) {
          Navigator.of(context, rootNavigator: true).pop();
          DonySnackbar.show(
            context,
            message: 'Trajet marqué comme arrivé',
            type: DonySnackbarType.success,
          );
        } else if (state is AnnouncementError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Instructions de retrait',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyTextField(
            controller: _ctrl,
            label: 'Instructions (optionnel)',
            hint: 'Ex : Métro Châtelet, sortie 3',
            maxLines: 3,
          ),
          const SizedBox(height: DonySpacing.xl),
        ],
      ),
    );
  }
}
