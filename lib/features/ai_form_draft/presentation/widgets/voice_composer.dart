import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_bloc.dart';
import 'package:dony/features/ai_form_draft/data/speech_service.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Micro, ou champ écrit + envoyer, dans le `stickyBottom` de la feuille.
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
  final _typing = ValueNotifier<bool>(false);
  late final SpeechService _speech = getIt<SpeechService>();

  @override
  void dispose() {
    unawaited(_speech.cancel());
    _controller.dispose();
    _typing.dispose();
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
    return ValueListenableBuilder<bool>(
      valueListenable: _typing,
      builder: (context, typing, _) {
        final textMode = typing || widget.micUnavailable;
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            if (textMode)
              Row(
                children: [
                  if (!widget.micUnavailable)
                    IconButton(
                      key: const Key('ai-switch-voice'),
                      tooltip: l.aiFormDraftMicStart,
                      onPressed: widget.enabled
                          ? () => _typing.value = false
                          : null,
                      icon: const Icon(Icons.mic_rounded),
                    ),
                  Expanded(
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
                        hintText: l.aiFormDraftInputHint,
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('ai-send'),
                    tooltip: l.aiFormDraftSend,
                    onPressed: widget.enabled ? _sendText : null,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: widget.listening
                        ? DonyButton(
                            key: const Key('ai-mic-stop'),
                            label: l.aiFormDraftListening,
                            icon: Icons.stop_rounded,
                            onPressed: () => unawaited(_stopListening()),
                          )
                        : DonyButton(
                            key: const Key('ai-mic-start'),
                            label: l.aiFormDraftMicStart,
                            icon: Icons.mic_rounded,
                            onPressed: widget.enabled
                                ? () => unawaited(_startListening())
                                : null,
                          ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  IconButton(
                    key: const Key('ai-switch-keyboard'),
                    tooltip: l.aiFormDraftKeyboard,
                    onPressed: widget.listening
                        ? null
                        : () => _typing.value = true,
                    icon: const Icon(Icons.keyboard_rounded),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
