import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/next_action.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Carte « prochaine action » : une consigne courte (titre + texte), bleue
/// pour une information, orange quand quelqu'un doit agir. Aucun bouton :
/// l'action est la barre collante du bas.
class NextActionCard extends StatelessWidget {
  const NextActionCard({required this.action, super.key});

  final NextAction action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final isAction = action.tone == NextActionTone.action;
    final accent = isAction ? cs.warning : cs.info;
    final background = isAction ? cs.warningLight : cs.infoLight;
    final (title, body) = _resolve(l, action);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            body,
            style: tt.bodyMedium?.copyWith(color: cs.onSurface, height: 1.4),
          ),
        ],
      ),
    );
  }
}

String _cap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Titre et texte d'une [NextAction] : clé inconnue = texte vide (la carte ne
/// plante jamais sur une clé qu'elle ne connaît pas).
(String, String) _resolve(AppLocalizations l, NextAction a) {
  String arg(String name, String fallback, {bool start = false}) {
    final v = a.args[name]?.trim() ?? '';
    final s = v.isEmpty ? fallback : v;
    return start ? _cap(s) : s;
  }

  final travelerKnown = (a.args['traveler']?.trim() ?? '').isNotEmpty;
  final traveler = arg('traveler', l.nextActionFallbackTraveler);
  final sender = arg('sender', l.nextActionFallbackSender);
  final recipientYour = arg('recipient', l.nextActionFallbackRecipientYour);
  final recipientYourStart = _cap(recipientYour);
  final recipientKnown = (a.args['recipient']?.trim() ?? '').isNotEmpty;
  final city = arg('city', l.nextActionFallbackCity);

  String text(String key) => switch (key) {
    'nextActionSenderAcceptedTitle' => l.nextActionSenderAcceptedTitle(
      traveler,
    ),
    'nextActionSenderAcceptedBody' => l.nextActionSenderAcceptedBody(
      recipientYour,
    ),
    'nextActionSenderCodeTitle' => l.nextActionSenderCodeTitle(recipientYour),
    'nextActionSenderCodeBody' => l.nextActionSenderCodeBody(traveler),
    'nextActionSenderArrivedTitle' => l.nextActionSenderArrivedTitle(city),
    'nextActionSenderArrivedBody' => l.nextActionSenderArrivedBody(
      recipientYourStart,
    ),
    'nextActionSelfAcceptedBody' => l.nextActionSelfAcceptedBody,
    'nextActionSelfKeepCodeTitle' => l.nextActionSelfKeepCodeTitle,
    'nextActionSelfKeepCodeBody' => l.nextActionSelfKeepCodeBody(traveler),
    'nextActionSelfWithdrawTitle' => l.nextActionSelfWithdrawTitle,
    'nextActionSelfWithdrawBody' =>
      travelerKnown
          ? l.nextActionSelfWithdrawBody(traveler)
          : l.nextActionSelfWithdrawBodyNoName,
    'nextActionTravelerAcceptedTitle' => l.nextActionTravelerAcceptedTitle(
      sender,
    ),
    'nextActionTravelerAcceptedBody' => l.nextActionTravelerAcceptedBody,
    'nextActionTravelerTransitTitle' => l.nextActionTravelerTransitTitle,
    'nextActionTravelerTransitBody' => l.nextActionTravelerTransitBody,
    'nextActionTravelerArrivedTitle' => l.nextActionTravelerArrivedTitle,
    'nextActionTravelerArrivedBody' =>
      recipientKnown
          ? l.nextActionTravelerArrivedBody(a.args['recipient']!.trim(), sender)
          : l.nextActionTravelerArrivedBodyNoName(sender),
    'nextActionTravelerArrivedBodyContact' =>
      recipientKnown
          ? l.nextActionTravelerArrivedBodyContact(
              a.args['recipient']!.trim(),
              sender,
            )
          : l.nextActionTravelerArrivedBodyNoNameContact(sender),
    'nextActionRecipientArrivedTitle' => l.nextActionRecipientArrivedTitle,
    'nextActionRecipientArrivedBody' =>
      travelerKnown
          ? l.nextActionRecipientArrivedBody(traveler)
          : l.nextActionRecipientArrivedBodyNoName,
    _ => '',
  };

  return (text(a.titleKey), text(a.bodyKey));
}
