import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/widgets/dony_pressable.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Actions photo de la barre de saisie : « + » (choix galerie / appareil
/// photo) et raccourci appareil photo.
///
/// [locked] : les photos ne sont pas (encore) permises, les deux boutons sont
/// grisés et leur tap appelle [onLocked] pour expliquer pourquoi.
class DonyComposerAttach {
  const DonyComposerAttach({
    required this.onPlus,
    required this.onCamera,
    required this.onLocked,
    this.locked = false,
  });

  final VoidCallback onPlus;
  final VoidCallback onCamera;
  final VoidCallback onLocked;
  final bool locked;
}

/// Barre de saisie façon WhatsApp, partagée par le chat des messages et le fil
/// d'un ticket de support : « + » à gauche, champ au milieu, appareil photo à
/// l'intérieur à droite (masqué dès qu'un texte est saisi), bouton rond
/// d'envoi.
///
/// [canSend] est évaluée avec le texte courant à chaque frappe : l'appelant
/// décide (le support autorise l'envoi d'images sans texte). Aucun état local :
/// tout passe par un [ValueListenableBuilder] sur [controller].
class DonyChatComposer extends StatelessWidget {
  const DonyChatComposer({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onSend,
    required this.canSend,
    this.focusNode,
    this.sending = false,
    this.attach,
    this.above,
    this.maxLength,
    this.onSubmitted,
    this.showTopBorder = true,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSend;
  final bool Function(String draft) canSend;
  final FocusNode? focusNode;
  final bool sending;

  /// `null` : ni « + » ni appareil photo.
  final DonyComposerAttach? attach;

  /// Contenu posé au-dessus de la pilule (vignettes d'images en attente).
  final Widget? above;
  final int? maxLength;

  /// Action du clavier (touche de validation) : le support y envoie le message.
  final ValueChanged<String>? onSubmitted;

  /// Faux sous une barre qui porte déjà le filet supérieur (barre de réponse).
  final bool showTopBorder;

  static const double _hit = 44;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final attach = this.attach;
    final animation = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 160);

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottom),
      duration: animation,
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: showTopBorder
              ? Border(top: BorderSide(color: cs.outlineVariant))
              : null,
        ),
        padding: EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.sm,
          DonySpacing.lg,
          DonySpacing.sm + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?above,
            Container(
              key: const Key('chat-composer-pill'),
              constraints: const BoxConstraints(maxHeight: 132),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(DonyRadius.xl),
                border: Border.all(color: cs.outlineVariant),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (attach != null)
                        _IconAction(
                          key: const Key('chat-attach-button'),
                          icon: Icons.add_rounded,
                          semanticsLabel: attach.locked
                              ? context.l10n.chatPhotoLockedSemantics
                              : context.l10n.chatAttachPhotoTooltip,
                          dimmed: attach.locked,
                          onTap: attach.locked
                              ? attach.onLocked
                              : attach.onPlus,
                        )
                      else
                        const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: TextField(
                          key: const Key('chat-composer-field'),
                          controller: controller,
                          focusNode: focusNode,
                          maxLines: null,
                          minLines: 1,
                          maxLength: maxLength,
                          onSubmitted: onSubmitted,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 11,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      if (attach != null && !hasText)
                        _IconAction(
                          key: const Key('chat-camera-button'),
                          icon: Icons.photo_camera_outlined,
                          semanticsLabel: attach.locked
                              ? context.l10n.chatPhotoLockedSemantics
                              : context.l10n.commonTakePhoto,
                          dimmed: attach.locked,
                          onTap: attach.locked
                              ? attach.onLocked
                              : attach.onCamera,
                        ),
                      _SendButton(
                        key: const Key('chat-send-button'),
                        enabled: canSend(value.text) && !sending,
                        sending: sending,
                        onTap: onSend,
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 150),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icône seule de la pilule : zone tactile de 44 pt, nom accessible.
class _IconAction extends StatelessWidget {
  const _IconAction({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
    this.dimmed = false,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticsLabel,
      container: true,
      excludeSemantics: true,
      child: DonyPressable(
        onTap: onTap,
        child: SizedBox(
          width: DonyChatComposer._hit,
          height: DonyChatComposer._hit,
          child: Opacity(
            opacity: dimmed ? 0.4 : 1,
            child: Icon(icon, size: 24, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Bouton rond d'envoi : primaire quand [enabled], grisé sinon, spinner
/// pendant l'envoi.
class _SendButton extends StatelessWidget {
  const _SendButton({
    super.key,
    required this.enabled,
    required this.sending,
    required this.onTap,
    required this.duration,
  });

  final bool enabled;
  final bool sending;
  final VoidCallback onTap;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (sending) {
      return const SizedBox(
        width: DonyChatComposer._hit,
        height: DonyChatComposer._hit,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    // Zone tactile de 44 pt (opaque jusqu'aux bords), disque visuel de 38 pt
    // dont l'InkWell porte l'ondulation.
    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.chatSendMessageSemantics,
      container: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: DonyChatComposer._hit,
          height: DonyChatComposer._hit,
          child: Center(
            child: AnimatedScale(
              scale: enabled ? 1.0 : 0.85,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: Material(
                color: enabled ? cs.primary : cs.outlineVariant,
                shape: const CircleBorder(),
                // Ondulation seulement : le tap et le nom accessible sont portés
                // par le GestureDetector et le Semantics englobants.
                child: InkResponse(
                  customBorder: const CircleBorder(),
                  onTap: enabled ? onTap : null,
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: DonyIcon('send', color: cs.onPrimary, size: 18),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
