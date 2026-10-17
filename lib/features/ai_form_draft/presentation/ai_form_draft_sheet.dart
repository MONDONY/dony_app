import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_bloc.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/chat_bubble.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/draft_summary.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/quick_replies.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/understood_chips.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/voice_composer.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feuille « Créer avec l'IA ». Rend le brouillon résolu au toucher de
/// « Remplir », `null` si elle est fermée avant.
///
/// Règle `stickyBottom` : `wrapper` fournit le BLoC à tout le contenu ; le
/// composer (micro, champ, envoyer) et les boutons vivent dans
/// [AiFormDraftStickyBottom], jamais dans le contenu qui défile.
abstract final class AiFormDraftSheet {
  static Future<AiResolvedDraft?> show(
    BuildContext context, {
    required AiFormDraftSession session,
  }) {
    final l = context.l10n;
    return DonyBottomSheet.show<AiResolvedDraft>(
      context,
      title: session.kind == AiFormKind.trip
          ? l.aiFormDraftSheetTitleTrip
          : l.aiFormDraftSheetTitlePackage,
      heightFraction: 0.9,
      wrapper: (content) => BlocProvider<AiFormDraftBloc>(
        create: (_) =>
            getIt<AiFormDraftBloc>(param1: session)
              ..add(const AiFormDraftOpened()),
        child: content,
      ),
      stickyBottom: const AiFormDraftStickyBottom(),
      child: const AiFormDraftSheetBody(),
    );
  }
}

/// Contenu défilant : accueil, « Déjà compris », dialogue, état.
class AiFormDraftSheetBody extends StatelessWidget {
  const AiFormDraftSheetBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AiFormDraftBloc, AiFormDraftState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == AiFormDraftStatus.applied,
      listener: (context, state) => Navigator.of(context).pop(state.resolved),
      builder: (context, state) {
        final l = context.l10n;
        final resolved = state.resolved;
        if (state.status == AiFormDraftStatus.ready && resolved != null) {
          return DraftSummary(
            kind: state.kind,
            resolved: resolved,
            turnLimitReached: state.turnLimitReached,
            fallbackCurrency: context.read<AiFormDraftBloc>().defaultCurrency,
          );
        }
        final kind = state.kind;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.understood.isNotEmpty || state.missing.isNotEmpty) ...[
              UnderstoodChips(
                kind: kind,
                understood: state.understood,
                missing: state.missing,
                draft: state.draft,
                fallbackCurrency: context
                    .read<AiFormDraftBloc>()
                    .defaultCurrency,
              ),
              const SizedBox(height: DonySpacing.md),
            ],
            AiChatBubble.assistant(
              text: kind == AiFormKind.trip
                  ? l.aiFormDraftWelcomeTrip
                  : l.aiFormDraftWelcomePackage,
            ),
            for (final message in state.messages)
              message.role == AiChatRole.user
                  ? AiChatBubble.user(text: message.text)
                  : AiChatBubble.assistant(text: message.text),
            if (state.correcting)
              AiChatBubble.assistant(text: l.aiFormDraftCorrectPrompt),
            if (state.status == AiFormDraftStatus.asking &&
                state.question == null &&
                !state.correcting &&
                state.messages.isNotEmpty)
              AiChatBubble.assistant(text: l.aiFormDraftQuestionFallback),
            if (state.status == AiFormDraftStatus.listening)
              AiChatBubble.live(
                text: state.partialText,
                label: l.aiFormDraftLiveTranscript,
              ),
            if (state.status == AiFormDraftStatus.sending)
              const Padding(
                key: Key('ai-sending'),
                padding: EdgeInsets.all(DonySpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (state.status == AiFormDraftStatus.asking &&
                state.quickReplies.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.sm),
              QuickReplies(
                replies: state.quickReplies,
                onSelected: (reply) => context.read<AiFormDraftBloc>().add(
                  AiFormDraftQuickReplyTapped(reply),
                ),
              ),
            ],
            if (switch (state.status) {
                  AiFormDraftStatus.degraded => l.aiFormDraftDegradedMessage,
                  AiFormDraftStatus.quotaExceeded => l.aiFormDraftQuotaMessage,
                  AiFormDraftStatus.error => l.aiFormDraftNetworkError,
                  _ => null,
                }
                case final message?)
              Padding(
                padding: const EdgeInsets.only(top: DonySpacing.md),
                child: Text(
                  message,
                  key: Key('ai-${state.status.name}-message'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// `stickyBottom` : composer pendant le dialogue, boutons ensuite.
class AiFormDraftStickyBottom extends StatelessWidget {
  const AiFormDraftStickyBottom({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiFormDraftBloc, AiFormDraftState>(
      buildWhen: (a, b) =>
          a.status != b.status ||
          a.micUnavailable != b.micUnavailable ||
          a.hasDraft != b.hasDraft ||
          a.turnLimitReached != b.turnLimitReached ||
          a.turns != b.turns,
      builder: (context, state) {
        final bloc = context.read<AiFormDraftBloc>();
        final l = context.l10n;
        switch (state.status) {
          case AiFormDraftStatus.ready:
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!state.turnLimitReached &&
                    state.turns < AiFormDraftBloc.maxTurns) ...[
                  DonyButton(
                    key: const Key('ai-correct'),
                    label: l.aiFormDraftCorrect,
                    variant: DonyButtonVariant.ghost,
                    onPressed: () =>
                        bloc.add(const AiFormDraftCorrectRequested()),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                ],
                DonyButton(
                  key: const Key('ai-apply'),
                  label: l.aiFormDraftApply,
                  onPressed: () => bloc.add(const AiFormDraftApplyRequested()),
                ),
              ],
            );
          case AiFormDraftStatus.degraded || AiFormDraftStatus.quotaExceeded:
            return DonyButton(
              key: const Key('ai-apply-partial'),
              label: l.aiFormDraftApplyPartial,
              onPressed: state.hasDraft
                  ? () => bloc.add(const AiFormDraftApplyRequested())
                  : null,
            );
          case AiFormDraftStatus.error:
            return DonyButton(
              key: const Key('ai-retry'),
              label: l.aiFormDraftRetry,
              onPressed: () => bloc.add(const AiFormDraftRetryRequested()),
            );
          case AiFormDraftStatus.applied:
            return const SizedBox.shrink();
          case AiFormDraftStatus.idle ||
              AiFormDraftStatus.listening ||
              AiFormDraftStatus.sending ||
              AiFormDraftStatus.asking:
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pendant une question : remplir avec ce qui est déjà compris
                // (par exemple après « Reparler » pour un seul champ).
                if (state.status == AiFormDraftStatus.asking &&
                    state.hasDraft) ...[
                  DonyButton(
                    key: const Key('ai-apply-partial'),
                    label: l.aiFormDraftApplyPartial,
                    variant: DonyButtonVariant.ghost,
                    onPressed: () =>
                        bloc.add(const AiFormDraftApplyRequested()),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                ],
                // Clé : le composer garde son état (saisie, mode écrit)
                // quand le bouton apparaît au-dessus de lui.
                AiVoiceComposer(
                  key: const ValueKey('ai-composer'),
                  enabled: state.status != AiFormDraftStatus.sending,
                  listening: state.status == AiFormDraftStatus.listening,
                  micUnavailable: state.micUnavailable,
                ),
              ],
            );
        }
      },
    );
  }
}
