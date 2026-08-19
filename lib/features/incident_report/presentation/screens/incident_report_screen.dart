import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/incident_report/bloc/incident_photo_upload.dart';
import 'package:dony/features/incident_report/bloc/incident_photos_cubit.dart';
import 'package:dony/features/incident_report/bloc/incident_report_cubit.dart';
import 'package:dony/features/incident_report/data/report_reasons.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/incident_report/presentation/widgets/incident_photo_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Écran « Signaler un problème » : motif + description + captures (max 4).
class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({
    super.key,
    this.targetType = IncidentTargetType.app,
    this.targetId,
  });

  /// Cible du signalement — APP par défaut (entrée réglages) ; les points
  /// d'entrée contextuels (profil utilisateur, colis…) passent leur cible.
  final IncidentTargetType targetType;
  final String? targetId;

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _descriptionController = TextEditingController();
  ReportReason? _reason;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final photos = context.read<IncidentPhotosCubit>();
    context.read<IncidentReportCubit>().submit(
      targetType: widget.targetType,
      targetId: widget.targetId,
      reason: _reason!.apiValue,
      description: _descriptionController.text.trim(),
      photoKeys: photos.readyKeys,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocListener<IncidentReportCubit, IncidentReportState>(
      listener: (context, state) {
        if (state is IncidentReportSuccess) {
          DonySnackbar.show(
            context,
            message: 'Signalement envoyé. Notre équipe va l\'examiner.',
            type: DonySnackbarType.success,
          );
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          }
        } else if (state is IncidentReportError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Signaler un problème')),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(DonySpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Motif', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: DonySpacing.sm),
                Wrap(
                  spacing: DonySpacing.sm,
                  runSpacing: DonySpacing.sm,
                  children: [
                    for (final reason in reportReasonsFor(widget.targetType))
                      ChoiceChip(
                        label: Text(reason.label),
                        selected: _reason == reason,
                        onSelected: (_) => setState(() => _reason = reason),
                      ),
                  ],
                ),
                const SizedBox(height: DonySpacing.lg),
                DonyTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Décrivez le problème rencontré…',
                  maxLines: 5,
                ),
                const SizedBox(height: DonySpacing.lg),
                Text(
                  'Captures d\'écran (optionnel)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Jusqu\'à 4 images pour aider notre équipe à comprendre.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.sm),
                const IncidentPhotoSection(),
                const SizedBox(height: DonySpacing.xl),
                BlocBuilder<IncidentPhotosCubit, List<IncidentPhotoUpload>>(
                  builder: (context, photos) {
                    return BlocBuilder<
                      IncidentReportCubit,
                      IncidentReportState
                    >(
                      builder: (context, state) {
                        final photosCubit = context.read<IncidentPhotosCubit>();
                        final canSubmit =
                            _reason != null &&
                            !photosCubit.hasUploading &&
                            state is! IncidentReportSubmitting;
                        return SizedBox(
                          width: double.infinity,
                          child: DonyButton(
                            label: 'Envoyer le signalement',
                            isLoading: state is IncidentReportSubmitting,
                            onPressed: canSubmit
                                ? () => _submit(context)
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
