import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/publish_gate/data/models/publish_commitments.dart';
import 'package:dony/features/publish_gate/data/models/publish_draft_entry.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Réponse de la feuille des brouillons. `null` : feuille fermée sans choix.
sealed class PublishDraftsSheetResult {
  const PublishDraftsSheetResult();
}

/// Terminer ce brouillon.
class ResumePublishDraft extends PublishDraftsSheetResult {
  const ResumePublishDraft(this.entry);
  final PublishDraftEntry entry;
}

/// Partir d'un modèle de trajet : formulaire prérempli, sans les dates.
class UsePublishTemplate extends PublishDraftsSheetResult {
  const UsePublishTemplate(this.template);
  final TripTemplate template;
}

/// Partir d'un formulaire vide.
class CreateNewPublication extends PublishDraftsSheetResult {
  const CreateNewPublication();
}

/// « Terminer ce trajet ou en créer un nouveau ? », avant le formulaire de
/// publication, quand il reste des brouillons.
abstract final class PublishDraftsSheet {
  /// Étapes du formulaire, pour situer un brouillon local.
  static const totalSteps = 3;

  static Future<PublishDraftsSheetResult?> show(
    BuildContext context, {
    required PublishCommitmentRole role,
    required List<PublishDraftEntry> drafts,
    List<TripTemplate> templates = const [],
  }) {
    final l10n = context.l10n;
    final isTrip = role == PublishCommitmentRole.traveler;
    return DonyBottomSheet.show<PublishDraftsSheetResult>(
      context,
      analyticsName: 'publish/drafts',
      title: drafts.isEmpty
          ? l10n.publishTemplatesTitle
          : isTrip
          ? l10n.publishDraftsTitleTrip
          : l10n.publishDraftsTitleParcel,
      subtitle: drafts.isEmpty
          ? l10n.publishTemplatesSubtitle
          : l10n.publishDraftsSubtitle,
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          key: const Key('publish-drafts-new'),
          label: isTrip
              ? l10n.publishDraftsNewTrip
              : l10n.publishDraftsNewParcel,
          iconAsset: 'plus',
          variant: DonyButtonVariant.secondary,
          onPressed: () => Navigator.of(ctx).pop(const CreateNewPublication()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (drafts.isNotEmpty && templates.isNotEmpty)
            _SectionLabel(l10n.publishSectionDrafts),
          for (final (i, d) in drafts.indexed) ...[
            if (i > 0) const SizedBox(height: DonySpacing.sm),
            _DraftRow(entry: d, isTrip: isTrip),
          ],
          if (templates.isNotEmpty) ...[
            if (drafts.isNotEmpty) const SizedBox(height: DonySpacing.lg),
            _SectionLabel(l10n.publishSectionTemplates),
            for (final (i, t) in templates.indexed) ...[
              if (i > 0) const SizedBox(height: DonySpacing.sm),
              _TemplateRow(template: t),
            ],
          ],
        ],
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({required this.entry, required this.isTrip});

  final PublishDraftEntry entry;
  final bool isTrip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final local = entry is LocalPublishDraft;
    final route = l10n.publishDraftRoute(
      entry.departureCity ?? l10n.publishDraftNoCity,
      entry.arrivalCity ?? l10n.publishDraftNoCity,
    );
    final date = entry.date;
    final series = entry is ServerTripDraftSeries
        ? entry as ServerTripDraftSeries
        : null;
    final title = series != null
        ? l10n.publishDraftSeriesTitle(
            series.departureCity,
            series.arrivalCity,
            series.announcements.length,
          )
        : date == null
        ? route
        : '$route · ${DateFormat.MMMd(l10n.localeName).format(date)}';
    final status = switch (entry) {
      ServerTripDraftSeries() => l10n.publishDraftSeriesStatus,
      final LocalPublishDraft d => l10n.publishDraftLocalStatus(
        d.draft.step.clamp(0, PublishDraftsSheet.totalSteps - 1) + 1,
        PublishDraftsSheet.totalSteps,
        DateFormat.MMMd(
          l10n.localeName,
        ).add_Hm().format(d.draft.savedAt.toLocal()),
      ),
      _ => l10n.publishDraftServerStatus,
    };
    final radius = BorderRadius.circular(DonyRadius.card);
    return Material(
      color: cs.surface,
      borderRadius: radius,
      child: InkWell(
        key: Key(
          local
              ? 'publish-draft-local'
              : series != null
              ? 'publish-draft-series'
              : 'publish-draft-server',
        ),
        borderRadius: radius,
        onTap: () => Navigator.of(context).pop(ResumePublishDraft(entry)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: DonyIcon(
                  local
                      ? 'notebook-pen'
                      : series != null
                      ? 'calendar-sync'
                      : (isTrip ? 'route' : 'package'),
                  size: 20,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              DonyIcon('chevron-right', size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: tt.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.template});

  final TripTemplate template;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final radius = BorderRadius.circular(DonyRadius.card);
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: radius,
      child: InkWell(
        key: Key('publish-template-${template.id}'),
        borderRadius: radius,
        onTap: () => Navigator.of(context).pop(UsePublishTemplate(template)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(DonySpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: DonyIcon('bookmark', size: 20, color: cs.primary),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.publishDraftRoute(
                        template.departureCity,
                        template.arrivalCity,
                      ),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Text(
                l10n.publishTemplateUse,
                style: tt.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
