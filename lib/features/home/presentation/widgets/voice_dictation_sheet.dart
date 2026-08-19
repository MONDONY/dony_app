// Feuille de dictée vocale — geste du vocal WhatsApp : appui maintenu sur le
// micro pour parler, relâchement pour valider. `speech_to_text` fait tourner
// la reconnaissance entièrement sur l'appareil, aucun son n'est envoyé à un
// serveur. Ce geste supprime tout état « est-ce que ça écoute encore » côté
// utilisateur : la main sait déjà quand elle parle.
//
// Si `initialize()` échoue (reconnaissance indisponible) ou si la permission
// micro/reconnaissance vocale est refusée, la feuille ne s'ouvre jamais et
// `show()` renvoie `null` : l'appelant (`SearchComposerScreen`) se contente
// alors de masquer le bouton micro, la saisie au clavier reste utilisable.

import 'dart:async';
import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

abstract final class VoiceDictationSheet {
  /// Ouvre la feuille de dictée et renvoie le texte reconnu, ou `null` si
  /// l'utilisateur annule, si rien n'a été reconnu, ou si la reconnaissance
  /// vocale est indisponible sur l'appareil.
  static Future<String?> show(BuildContext context) async {
    final speech = stt.SpeechToText();
    var available = false;
    try {
      available = await speech.initialize();
    } catch (_) {
      // Micro absent, permission refusée, service indisponible… toutes ces
      // causes se traitent de la même façon : pas de feuille, pas de crash.
      available = false;
    }
    if (!available || !context.mounted) {
      return null;
    }

    final controller = _DictationController(speech);

    return DonyBottomSheet.show<String>(
      context,
      title: 'Dicter votre recherche',
      stickyBottom: _DictationMicButton(controller: controller),
      child: _DictationTranscript(controller: controller),
    ).whenComplete(() {
      // Filet de sécurité : couvre aussi la fermeture par balayage ou tap sur
      // le fond, chemins qui ne passent pas par le relâchement du micro.
      unawaited(speech.cancel());
      controller.dispose();
    });
  }
}

/// Un résultat de reconnaissance : texte + statut. `speech_to_text` distingue
/// les résultats partiels des définitifs (`SpeechRecognitionResult
/// .finalResult`) — voir [_DictationTranscript].
class _DictationResult {
  const _DictationResult({this.text = '', this.isFinal = false});

  final String text;
  final bool isFinal;
}

/// État local pur de la feuille — deux `ValueNotifier`, jamais de BLoC : seul
/// le texte final remonte à l'appelant, via la valeur renvoyée par
/// `VoiceDictationSheet.show`.
class _DictationController {
  _DictationController(this._speech);

  final stt.SpeechToText _speech;

  final isListening = ValueNotifier<bool>(false);
  final result = ValueNotifier<_DictationResult>(const _DictationResult());

  void dispose() {
    isListening.dispose();
    result.dispose();
  }

  /// Doigt posé sur le micro : démarre l'écoute.
  Future<void> start() async {
    result.value = const _DictationResult();
    isListening.value = true;
    await _speech.listen(
      onResult: _onResult,
      onSoundLevelChange: (_) {},
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        localeId: 'fr_FR',
        cancelOnError: true,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    result.value = _DictationResult(
      text: r.recognizedWords,
      isFinal: r.finalResult,
    );
  }

  /// Relâchement du micro : arrête l'écoute et renvoie le texte reconnu
  /// jusque-là, ou `null` si rien n'a été dit.
  Future<String?> release() async {
    if (!isListening.value) return null;
    await _speech.stop();
    isListening.value = false;
    final text = result.value.text.trim();
    return text.isEmpty ? null : text;
  }

  /// Appui interrompu sans relâchement propre (ex : la feuille se ferme
  /// autrement) : on annule sans qu'aucun texte ne remonte.
  Future<void> abandon() async {
    if (!isListening.value) return;
    await _speech.cancel();
    isListening.value = false;
    result.value = const _DictationResult();
  }
}

/// Zone scrollable de la feuille : instruction, onde animée, transcription
/// en direct. Le bouton d'action vit dans `stickyBottom`, jamais ici.
class _DictationTranscript extends StatelessWidget {
  const _DictationTranscript({required this.controller});

  final _DictationController controller;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: controller.isListening,
      builder: (context, listening, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            listening
                ? 'Je vous écoute…'
                : 'Maintenez le micro appuyé, parlez, relâchez pour valider.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.xl),
          Center(child: _DictationWave(isListening: controller.isListening)),
          const SizedBox(height: DonySpacing.xl),
          ValueListenableBuilder<_DictationResult>(
            valueListenable: controller.result,
            builder: (context, result, _) {
              if (result.text.isEmpty) {
                return const SizedBox(height: 28);
              }
              // Le partiel se rend en `cs.onSurfaceVariant`, moins appuyé que
              // le texte définitif : c'est le seul signal visuel de la
              // distinction partiel/final, il n'y a pas d'état « écoute »
              // séparé à afficher.
              return Text(
                result.text,
                style: tt.titleLarge?.copyWith(
                  color: result.isFinal ? cs.onSurface : cs.onSurfaceVariant,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Onde animée pendant l'écoute — quelques barres dont la hauteur respire en
/// boucle. Désactivée sous `MediaQuery.disableAnimations` : la rangée reste
/// alors figée à une hauteur moyenne plutôt que de disparaître, pour ne pas
/// faire sauter la mise en page entre les deux réglages.
class _DictationWave extends StatefulWidget {
  const _DictationWave({required this.isListening});

  final ValueNotifier<bool> isListening;

  @override
  State<_DictationWave> createState() => _DictationWaveState();
}

class _DictationWaveState extends State<_DictationWave>
    with SingleTickerProviderStateMixin {
  static const _barCount = 5;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    widget.isListening.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    final shouldAnimate =
        widget.isListening.value && !MediaQuery.disableAnimationsOf(context);
    if (shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    widget.isListening.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return ValueListenableBuilder<bool>(
      valueListenable: widget.isListening,
      builder: (context, listening, _) {
        if (!listening) {
          return const SizedBox(height: 36);
        }
        if (reduceMotion) {
          return _WaveBars(
            heights: List.filled(_barCount, 0.55),
            color: cs.primary,
          );
        }
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final heights = List<double>.generate(_barCount, (i) {
              final phase = _controller.value * 2 * math.pi + i * 0.9;
              return 0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase)).abs();
            });
            return _WaveBars(heights: heights, color: cs.primary);
          },
        );
      },
    );
  }
}

class _WaveBars extends StatelessWidget {
  const _WaveBars({required this.heights, required this.color});

  final List<double> heights;
  final Color color;

  static const _maxHeight = 36.0;
  static const _barWidth = 5.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _maxHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < heights.length; i++) ...[
            if (i > 0) const SizedBox(width: DonySpacing.xs),
            Container(
              width: _barWidth,
              height: (_maxHeight * heights[i]).clamp(6, _maxHeight),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bouton micro à appui maintenu — l'unique élément d'action de la feuille,
/// placé en `stickyBottom` (jamais dans le `child` scrollable).
class _DictationMicButton extends StatefulWidget {
  const _DictationMicButton({required this.controller});

  final _DictationController controller;

  @override
  State<_DictationMicButton> createState() => _DictationMicButtonState();
}

class _DictationMicButtonState extends State<_DictationMicButton> {
  Future<void> _onDown() async {
    await widget.controller.start();
  }

  Future<void> _onUp() async {
    final text = await widget.controller.release();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(text);
    }
  }

  void _onCancelPress() {
    unawaited(widget.controller.abandon());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.isListening,
      builder: (context, listening, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            listening ? 'Relâchez pour valider' : 'Maintenez pour parler',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
          GestureDetector(
            onTapDown: (_) => unawaited(_onDown()),
            onTapUp: (_) => unawaited(_onUp()),
            onTapCancel: _onCancelPress,
            child: Semantics(
              button: true,
              label: 'Maintenir enfoncé pour dicter, relâcher pour valider',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: listening ? cs.error : cs.primary,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: listening ? cs.onError : cs.onPrimary,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
