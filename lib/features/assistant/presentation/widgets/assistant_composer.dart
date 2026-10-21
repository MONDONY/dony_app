import 'package:dony/core/widgets/dony_voice_action_button.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Longueur maximale d'une question : `AssistantAskRequest.question` côté
/// yadony-back est `@Size(max = 500)`, compté en unités UTF-16 (`String.length`
/// Java), pas en caractères affichés.
const int kAssistantQuestionMax = 500;

/// Seuil d'affichage du compteur.
const int kAssistantCounterFrom = 450;

/// Coupe le texte à [kAssistantQuestionMax] unités UTF-16 sans scinder une
/// paire de substitution (emoji) : le plafond de Flutter compte les
/// graphèmes, qui sous-estiment la longueur vue par le back.
class Utf16LengthLimiter extends TextInputFormatter {
  const Utf16LengthLimiter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.length <= max) return newValue;
    var end = max;
    // Un substitut haut en dernière position : sa moitié basse serait coupée.
    final last = text.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end -= 1;
    // Curseur : là où il était (après un collage au milieu), ramené à la coupe
    // s'il tombait dans la partie supprimée.
    final cursor = newValue.selection.baseOffset;
    return TextEditingValue(
      text: text.substring(0, end),
      selection: TextSelection.collapsed(
        offset: cursor < 0 || cursor > end ? end : cursor,
      ),
    );
  }
}

/// Zone de saisie de l'assistant. Le contrôleur appartient à l'écran (disposé
/// dans son `State`) ; [busy] grise l'envoi pendant qu'une question est en
/// cours.
class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    super.key,
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onMic,
    this.listening = false,
    this.micAvailable = true,
  });

  final TextEditingController controller;
  final bool busy;

  /// Dictée en cours : le bouton de droite devient « arrêter et envoyer » et
  /// le champ passe en bleu, le texte reconnu s'y affiche en direct.
  final bool listening;

  /// Faux sans micro (permission refusée, reconnaissance absente) : il ne
  /// reste que l'envoi.
  final bool micAvailable;

  /// Démarre la dictée, ou l'arrête quand elle est en cours.
  final VoidCallback onMic;

  /// Reçoit le texte déjà nettoyé des espaces de bord, jamais vide.
  final ValueChanged<String> onSend;

  void _submit() {
    final text = controller.text.trim();
    if (busy || text.isEmpty) return;
    onSend(text);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: color),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('assistant-input'),
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  // Plusieurs lignes à l'écran, mais la touche d'action du
                  // clavier envoie au lieu d'insérer un retour à la ligne.
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: kAssistantQuestionMax,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  inputFormatters: const [
                    Utf16LengthLimiter(kAssistantQuestionMax),
                  ],
                  style: tt.bodyLarge!.copyWith(fontSize: 15),
                  // Garde le clavier ouvert après l'envoi.
                  onEditingComplete: () {},
                  onSubmitted: (_) => _submit(),
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) {
                        final length = controller.text.length;
                        if (length < kAssistantCounterFrom) return null;
                        return Text(
                          l.assistantCharCount(length),
                          style: tt.bodySmall!.copyWith(
                            color: length >= kAssistantQuestionMax
                                ? cs.error
                                : cs.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        );
                      },
                  decoration: InputDecoration(
                    hintText: listening
                        ? l.assistantMicListening
                        : l.assistantInputHint,
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    border: border(listening ? cs.primary : cs.outline),
                    enabledBorder: border(listening ? cs.primary : cs.outline),
                    focusedBorder: border(cs.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => DonyVoiceActionButton(
                  hasText: value.text.trim().isNotEmpty,
                  listening: listening,
                  micAvailable: micAvailable,
                  enabled: !busy,
                  onMic: onMic,
                  onSend: _submit,
                  micTooltip: l.assistantMicTooltipStart,
                  stopTooltip: l.assistantMicTooltipStop,
                  sendTooltip: l.assistantSend,
                  micKey: const Key('assistant-mic'),
                  stopKey: const Key('assistant-mic'),
                  sendKey: const Key('assistant-send'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
