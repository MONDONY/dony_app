import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TripTemplatesScreen extends StatelessWidget {
  const TripTemplatesScreen({super.key});

  Future<void> _openEditor(BuildContext context, {TripTemplate? template}) async {
    final bloc = context.read<TripTemplateBloc>();
    final changed = await context.push<bool>(
      '/trip-templates/edit',
      extra: template,
    );
    if ((changed ?? false) && context.mounted) {
      bloc.add(const TripTemplateLoaded());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DonyPageScaffold(
      title: 'Mes modèles de trajet',
      scrollable: false,
      padding: EdgeInsets.zero,
      appBarActions: [
        IconButton(
          icon: DonyIcon('plus', color: Theme.of(context).colorScheme.onSurface),
          tooltip: 'Nouveau modèle',
          onPressed: () => _openEditor(context),
        ),
      ],
      body: BlocBuilder<TripTemplateBloc, TripTemplateState>(
        builder: (context, state) {
          if (state.status == TripTemplateStatus.loading && state.templates.isEmpty) {
            return const DonyEmptyState(type: DonyEmptyStateType.loading, title: '');
          }
          if (state.status == TripTemplateStatus.error && state.templates.isEmpty) {
            return DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              type: DonyEmptyStateType.error,
              iconAsset: 'circle-alert',
              title: 'Erreur de chargement',
              description: state.error ?? 'Une erreur est survenue.',
              actionLabel: 'Réessayer',
              onAction: () =>
                  context.read<TripTemplateBloc>().add(const TripTemplateLoaded()),
            );
          }
          if (state.templates.isEmpty) {
            return DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucun modèle',
              description:
                  'Crée des modèles de trajet réutilisables pour publier tes annonces en quelques secondes.',
              actionLabel: 'Créer un modèle',
              onAction: () => _openEditor(context),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              MediaQuery.paddingOf(context).bottom + 100,
            ),
            itemCount: state.templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: DonySpacing.sm),
            itemBuilder: (context, i) {
              final t = state.templates[i];
              return _TripTemplateCard(
                template: t,
                onEdit: () => _openEditor(context, template: t),
              )
                  .animate()
                  .fadeIn(delay: (i * 60).ms, duration: 280.ms)
                  .slideY(begin: 0.03, curve: Curves.easeOutCubic);
            },
          );
        },
      ),
    );
  }
}

class _TripTemplateCard extends StatelessWidget {
  const _TripTemplateCard({required this.template, required this.onEdit});

  final TripTemplate template;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(DonySpacing.sm),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: template.emoji != null
                    ? Text(template.emoji!, style: const TextStyle(fontSize: 20))
                    : DonyIcon('bookmark', color: cs.primary, size: 20),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.label,
                        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      '${template.departureCity} → ${template.arrivalCity} · ${_trimPrice(template.pricePerKg)}€/kg',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _KebabMenu(template: template, onEdit: onEdit),
            ],
          ),
        ),
      ),
    );
  }

  String _trimPrice(double p) =>
      p == p.roundToDouble() ? p.toInt().toString() : p.toString();
}

enum _TemplateAction { edit, recurrence, delete }

class _KebabMenu extends StatelessWidget {
  const _KebabMenu({required this.template, required this.onEdit});

  final TripTemplate template;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<_TemplateAction>(
      icon: DonyIcon('ellipsis-vertical', color: cs.onSurfaceVariant, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DonyRadius.md)),
      onSelected: (action) async {
        switch (action) {
          case _TemplateAction.edit:
            onEdit();
          case _TemplateAction.recurrence:
            context.push('/trip-recurrences/new', extra: template);
          case _TemplateAction.delete:
            final confirmed = await DonyDialog.show(
              context,
              title: 'Supprimer le modèle',
              message:
                  'Es-tu sûr de vouloir supprimer "${template.label}" ? Cette action est irréversible.',
              iconAsset: 'trash-2',
              confirmLabel: 'Supprimer',
              variant: DonyDialogVariant.destructive,
            );
            if ((confirmed ?? false) && context.mounted) {
              context.read<TripTemplateBloc>().add(TripTemplateDeleted(template.id));
            }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _TemplateAction.edit,
          child: Row(children: [
            DonyIcon('square-pen', size: 18, color: cs.onSurface),
            const SizedBox(width: DonySpacing.sm),
            const Text('Modifier'),
          ]),
        ),
        PopupMenuItem(
          value: _TemplateAction.recurrence,
          child: Row(children: [
            DonyIcon('calendar-sync', size: 18, color: cs.onSurface),
            const SizedBox(width: DonySpacing.sm),
            const Text('Programmer la récurrence'),
          ]),
        ),
        PopupMenuItem(
          value: _TemplateAction.delete,
          child: Row(children: [
            DonyIcon('trash-2', size: 18, color: cs.error),
            const SizedBox(width: DonySpacing.sm),
            Text('Supprimer',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ],
    );
  }
}
