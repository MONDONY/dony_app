import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bottom sheet « Arrivé à destination » / « Instructions de retrait ».
///
/// Deux modes, pilotés par [isEditing] :
///   * `false` (premier passage, trajet pas encore ARRIVED) : le voyageur
///     marque son trajet comme arrivé et peut renseigner en une fois des
///     instructions de retrait optionnelles →
///     [AnnouncementTripMarkArrivedRequested].
///   * `true` (trajet déjà ARRIVED) : le voyageur corrige seulement ses
///     instructions → [AnnouncementArrivalInstructionsUpdateRequested]. Le
///     texte y est obligatoire (l'event porte un `String` non nullable), donc
///     le bouton reste désactivé tant que le champ est vide.
class ArrivalInstructionsBottomSheet extends StatefulWidget {
  const ArrivalInstructionsBottomSheet({
    super.key,
    required this.announcementId,
    this.initialInstructions,
    this.isEditing = false,
    this.onSubmitReady,
    this.onCanSubmitChanged,
  });

  final String announcementId;
  final String? initialInstructions;

  /// `true` quand le trajet est déjà ARRIVED : édition des instructions.
  final bool isEditing;

  final void Function(VoidCallback)? onSubmitReady;

  /// Notifie le bouton collant de la validité du formulaire (mode édition).
  final ValueChanged<bool>? onCanSubmitChanged;

  static Future<void> show(
    BuildContext context, {
    required String announcementId,
    String? initialInstructions,
    bool isEditing = false,
  }) {
    final announcementBloc = context.read<AnnouncementBloc>();
    VoidCallback? submit;
    final canSubmit = ValueNotifier<bool>(
      !isEditing || (initialInstructions?.trim().isNotEmpty ?? false),
    );
    return DonyBottomSheet.show(
      context,
      title: isEditing ? 'Instructions de retrait' : 'Arrivé à destination',
      subtitle: 'Indiquez où et comment récupérer le colis',
      wrapper: (child) =>
          BlocProvider.value(value: announcementBloc, child: child),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canSubmit,
        builder: (ctx, enabled, _) =>
            BlocBuilder<AnnouncementBloc, AnnouncementState>(
              builder: (ctx, state) {
                final loading = state is AnnouncementLoading;
                return DonyButton(
                  label: isEditing ? 'Enregistrer' : "Confirmer l'arrivée",
                  isLoading: loading,
                  onPressed: (loading || !enabled)
                      ? null
                      : () => submit?.call(),
                );
              },
            ),
      ),
      child: ArrivalInstructionsBottomSheet(
        announcementId: announcementId,
        initialInstructions: initialInstructions,
        isEditing: isEditing,
        onSubmitReady: (fn) => submit = fn,
        onCanSubmitChanged: (v) => canSubmit.value = v,
      ),
    ).whenComplete(canSubmit.dispose);
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
    _ctrl.addListener(_notifyValidity);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_notifyValidity);
    _ctrl.dispose();
    super.dispose();
  }

  /// En mode édition, le texte est obligatoire ; à la création il reste
  /// optionnel (le bouton n'est jamais bloqué).
  void _notifyValidity() {
    widget.onCanSubmitChanged?.call(
      !widget.isEditing || _ctrl.text.trim().isNotEmpty,
    );
  }

  void _submit() {
    final bloc = context.read<AnnouncementBloc>();
    final text = _ctrl.text.trim();
    if (widget.isEditing) {
      if (text.isEmpty) {
        return;
      }
      bloc.add(
        AnnouncementArrivalInstructionsUpdateRequested(
          announcementId: widget.announcementId,
          arrivalInstructions: text,
        ),
      );
      return;
    }
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
        } else if (state is AnnouncementArrivalInstructionsUpdated) {
          Navigator.of(context, rootNavigator: true).pop();
          DonySnackbar.show(
            context,
            message: 'Instructions mises à jour',
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
            label: widget.isEditing
                ? 'Instructions'
                : 'Instructions (optionnel)',
            hint: 'Ex : Métro Châtelet, sortie 3',
            maxLines: 3,
          ),
          const SizedBox(height: DonySpacing.xl),
        ],
      ),
    );
  }
}
