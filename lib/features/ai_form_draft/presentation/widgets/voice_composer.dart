import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_mic_button.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_bloc.dart';
import 'package:dony/features/ai_form_draft/data/speech_service.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Gros micro rond centré (le même que l'assistant, FLUTTER-RE) au-dessus du
/// champ écrit + envoyer, dans le `stickyBottom` de la feuille.
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
    // Lu sur la vue : la feuille retire le clavier des marges de son contenu.
    final keyboardOpen = View.of(context).viewInsets.bottom > 0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final listening = widget.listening;
    final Widget mic;
    if (widget.micUnavailable) {
      mic = Padding(
        padding: const EdgeInsets.only(bottom: DonySpacing.sm),
        child: Text(
          l.aiFormDraftMicUnavailable,
          key: const Key('ai-mic-unavailable'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    } else if (keyboardOpen && !listening) {
      // Clavier ouvert : le champ reste visible, le micro s'efface.
      mic = const SizedBox(width: double.infinity);
    } else {
      mic = Padding(
        padding: const EdgeInsets.only(bottom: DonySpacing.xs),
        child: Center(
          child: DonyMicButton(
            tapKey: Key(listening ? 'ai-mic-stop' : 'ai-mic-start'),
            discKey: const Key('ai-mic-disc'),
            captionKey: const Key('ai-mic-caption'),
            listeningCaption: l.aiFormDraftListening,
            idleTooltip: l.aiFormDraftMicStart,
            listeningTooltip: l.aiFormDraftListening,
            listening: listening,
            enabled: widget.enabled,
            onTap: () =>
                unawaited(listening ? _stopListening() : _startListening()),
          ),
        ),
      );
    }
    final dock = SizedBox(width: double.infinity, child: mic);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Animations réduites : la place change d'un coup.
        if (reduceMotion)
          dock
        else
          AnimatedSize(
            duration: DonyDuration.base,
            curve: DonyCurve.enter,
            alignment: Alignment.bottomCenter,
            child: dock,
          ),
        Row(
          children: [
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
        ),
      ],
    );
  }
}
