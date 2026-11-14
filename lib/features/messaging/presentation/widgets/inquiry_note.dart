import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Prénom de l'interlocuteur d'une question avant réservation (le voyageur),
/// repris par la note d'accueil et la barre du plafond atteint.
String inquiryCounterpartFirstName(
  AppLocalizations l,
  ConversationModel conversation,
) {
  final name = conversation.otherParticipant.name.trim();
  return name.isEmpty ? l.tripTravelerFallbackName : name.split(' ').first;
}

/// Note d'accueil d'une question avant réservation : quota du demandeur et
/// réponses libres du voyageur.
String inquiryIntroText(AppLocalizations l, ConversationModel conversation) =>
    l.inquiryIntroNote(
      conversation.inquiryMessageLimit ??
          ConversationModel.defaultInquiryMessageLimit,
      inquiryCounterpartFirstName(l, conversation),
    );

/// Note centrée dans le fil d'une question avant réservation (consigne de
/// départ, limite atteinte) : discrète, hors bulle.
class InquiryNote extends StatelessWidget {
  final String text;

  const InquiryNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Container(
        key: const Key('inquiry-note'),
        margin: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
