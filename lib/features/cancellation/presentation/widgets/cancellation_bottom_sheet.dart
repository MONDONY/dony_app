import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

const _reasons = [
  'Vol annulé',
  'Urgence personnelle',
  'Problème de santé',
  "Changement d'itinéraire",
  'Autre',
];

class CancellationBottomSheet extends StatefulWidget {
  const CancellationBottomSheet({super.key, required this.announcementId});

  final String announcementId;

  static Future<void> show(
    BuildContext context, {
    required String announcementId,
  }) {
    return DonyBottomSheet.show(
      context,
      isDanger: true,
      title: 'Annuler ce trajet ?',
      subtitle: 'Cette action est irréversible',
      child: BlocProvider.value(
        value: context.read<CancellationBloc>(),
        child: CancellationBottomSheet(announcementId: announcementId),
      ),
    );
  }

  @override
  State<CancellationBottomSheet> createState() =>
      _CancellationBottomSheetState();
}

class _CancellationBottomSheetState extends State<CancellationBottomSheet> {
  String? _selectedReason;
  final _otherCtrl = TextEditingController();

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  String? get _finalReason {
    if (_selectedReason == null) {
      return null;
    }
    if (_selectedReason == 'Autre' && _otherCtrl.text.trim().isNotEmpty) {
      return _otherCtrl.text.trim();
    }
    if (_selectedReason == 'Autre') {
      return null; // require text when "Autre"
    }
    return _selectedReason;
  }

  void _confirm(BuildContext context) {
    final reason = _finalReason;
    if (reason == null) {
      DonySnackbar.show(
        context,
        message: _selectedReason == null
            ? 'Veuillez sélectionner une raison'
            : 'Veuillez préciser votre raison',
        type: DonySnackbarType.error,
      );
      return;
    }
    final bloc = context.read<CancellationBloc>();
    Navigator.of(context, rootNavigator: true).pop();
    DonyDialog.show(
      context,
      title: "Confirmer l'annulation",
      message:
          'Cette action annulera votre trajet et remboursera automatiquement tous les expéditeurs concernés.',
      variant: DonyDialogVariant.destructive,
      icon: Icons.warning_amber_rounded,
    ).then((confirmed) {
      if (confirmed == true) {
        bloc.add(CancellationTripRequested(
          announcementId: widget.announcementId,
          reason: reason,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocListener<CancellationBloc, CancellationState>(
      listener: (context, state) {
        if (state is CancellationSuccess) {
          DonySnackbar.show(
            context,
            message: 'Trajet annulé',
            type: DonySnackbarType.success,
          );
          context.go('/announcements');
        } else if (state is CancellationError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(color: cs.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: cs.error, size: 18),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    'Tous les expéditeurs liés seront remboursés automatiquement.',
                    style:
                        tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.base),

          // Radio group label
          Text('Raison', style: tt.titleSmall),
          const SizedBox(height: DonySpacing.sm),

          // Radio options
          DonyRadioGroup<String>(
            value: _selectedReason,
            onChanged: (v) => setState(() => _selectedReason = v),
            options: _reasons
                .map((r) => DonyRadioOption(value: r, label: r))
                .toList(),
          ),

          // "Autre" text field
          if (_selectedReason == 'Autre') ...[
            const SizedBox(height: DonySpacing.md),
            DonyTextField(
              controller: _otherCtrl,
              label: 'Précisez...',
              hint: 'Décrivez votre raison',
            ),
          ],

          const SizedBox(height: DonySpacing.xl),

          // Confirm button
          BlocBuilder<CancellationBloc, CancellationState>(
            builder: (context, state) => DonyButton(
              label: "Confirmer l'annulation",
              variant: DonyButtonVariant.destructive,
              isLoading: state is CancellationLoading,
              onPressed: state is CancellationLoading
                  ? null
                  : () => _confirm(context),
            ),
          ),
        ],
      ),
    );
  }
}
