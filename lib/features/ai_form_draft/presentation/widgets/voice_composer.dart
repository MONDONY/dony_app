import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_voice_action_button.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_bloc.dart';
import 'package:dony/features/ai_form_draft/data/speech_service.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Champ de saisie avec, à droite, le bouton micro / envoyer / arrêter (le même
/// que l'assistant, FLUTTER-RE), dans le `stickyBottom` de la feuille. Le micro
/// ne prend plus de bande à lui : il remplace l'envoi tant que rien n'est écrit.
class AiVoiceComposer extends StatefulWidget {
  const AiVoiceComposer({
    super.key,
    required this.enabled,
    required this.listening,
    required this.micUnavailable,
  });

  /// Faux pendant un envoi.
  final bool enabled;
  final bool listening;

  /// Permission refusée ou reconnaissance indisponible : écrit seulement.
  final bool micUnavailable;

  @override
  State<AiVoiceComposer> createState() => _AiVoiceComposerState();
}

class _AiVoiceComposerState extends State<AiVoiceComposer> {
  final _controller = TextEditingController();
  late final SpeechService _speech = getIt<SpeechService>();

  @override
  void dispose() {
    unawaited(_speech.cancel());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    final bloc = context.read<AiFormDraftBloc>();
    final localeId = context.l10n.localeName == 'en' ? 'en_US' : 'fr_FR';
    final available = await _speech.initialize();
    if (!mounted || bloc.isClosed) return;
    if (!available) {
      bloc.add(const AiFormDraftMicUnavailable());
      return;
    }
    bloc.add(const AiFormDraftMicPressed());
    try {
      await _speech.start(
        localeId: localeId,
        onResult: (text, {required isFinal}) {
          if (bloc.isClosed) return;
          bloc.add(AiFormDraftSpeechPartial(text));
          if (isFinal) bloc.add(const AiFormDraftMicStopped());
        },
        onDone: () {
          if (!bloc.isClosed) bloc.add(const AiFormDraftMicStopped());
        },
      );
    } on Object {
      if (!bloc.isClosed) bloc.add(const AiFormDraftMicUnavailable());
    }
  }

  Future<void> _stopListening() async {
    final bloc = context.read<AiFormDraftBloc>();
    await _speech.stop();
    if (!bloc.isClosed) bloc.add(const AiFormDraftMicStopped());
  }

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<AiFormDraftBloc>().add(AiFormDraftTextSubmitted(text));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final listening = widget.listening;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(DonyRadius.xl),
      borderSide: BorderSide(color: color),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.micUnavailable)
          Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.sm),
            child: Text(
              l.aiFormDraftMicUnavailable,
              key: const Key('ai-mic-unavailable'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: DonyReplayMask(
                child: TextField(
                  key: const Key('ai-text-input'),
                  controller: _controller,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: AiFormDraftBloc.maxMessageLength,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendText(),
                  decoration: InputDecoration(
                    hintText: listening
                        ? l.aiFormDraftListening
                        : l.aiFormDraftInputHint,
                    counterText: '',
                    border: border(listening ? cs.primary : cs.outline),
                    enabledBorder: border(listening ? cs.primary : cs.outline),
                    focusedBorder: border(cs.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) => DonyVoiceActionButton(
                hasText: value.text.trim().isNotEmpty,
                listening: listening,
                micAvailable: !widget.micUnavailable,
                enabled: widget.enabled,
                onMic: () =>
                    unawaited(listening ? _stopListening() : _startListening()),
                onSend: _sendText,
                micTooltip: l.aiFormDraftMicStart,
                stopTooltip: l.aiFormDraftListening,
                sendTooltip: l.aiFormDraftSend,
                micKey: const Key('ai-mic-start'),
                stopKey: const Key('ai-mic-stop'),
                sendKey: const Key('ai-send'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
