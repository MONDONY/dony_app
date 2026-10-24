import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';

/// Enveloppe d'une bulle de conversation, partagée par le chat des messages et
/// le fil d'un ticket de support.
///
/// - Ma bulle : aplat `primary`, sans bordure ni ombre. L'appelant colore son
///   texte en `onPrimary`.
/// - Bulle de l'autre : `surface` avec un contour fin `outlineVariant`.
/// - [tail] : coin « queue » (petit rayon) en bas, côté de l'expéditeur.
/// - [meta] : heure, coches, « modifié »… rendus sous le contenu, alignés à
///   droite, dans la bulle.
class DonyChatBubbleShell extends StatelessWidget {
  const DonyChatBubbleShell({
    super.key,
    required this.isMe,
    required this.child,
    this.tail = true,
    this.meta,
  });

  final bool isMe;
  final bool tail;
  final Widget child;
  final Widget? meta;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const full = Radius.circular(DonyRadius.card);
    final small = tail ? const Radius.circular(DonyRadius.xs) : full;
    final radius = BorderRadius.only(
      topLeft: full,
      topRight: full,
      bottomLeft: isMe ? full : small,
      bottomRight: isMe ? small : full,
    );
    return Container(
      key: const Key('chat-bubble-shell'),
      decoration: BoxDecoration(
        color: isMe ? cs.primary : cs.surface,
        borderRadius: radius,
        border: isMe ? null : Border.all(color: cs.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: radius,
        // Largeur intrinsèque : sans elle, `stretch` donne à la colonne toute la
        // largeur autorisée par l'écran et chaque bulle (même « ok », même une
        // photo de 200 px) s'étire à 72 % de l'écran.
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              if (meta != null)
                Padding(
                  key: const Key('chat-bubble-meta'),
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  child: Align(alignment: Alignment.centerRight, child: meta),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
