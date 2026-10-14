import 'dart:ui' show Rect;

import 'package:dony/features/referral/data/models/referee.dart';

abstract class ReferralEvent {
  const ReferralEvent();
}

class ReferralLoadRequested extends ReferralEvent {
  const ReferralLoadRequested({this.includeReferees = false});

  /// Charge aussi la première page des filleuls (écran Parrainage). Le profil,
  /// qui ne lit que `hasBeenReferred`, s'en passe.
  final bool includeReferees;
}

/// Page suivante des filleuls (« Voir plus »), ou relecture de la première
/// page après une erreur ([reset]).
class ReferralRefereesRequested extends ReferralEvent {
  const ReferralRefereesRequested({this.reset = false});
  final bool reset;
}

/// Le parrain choisit la récompense d'une invitation débloquée.
class ReferralRewardChosen extends ReferralEvent {
  const ReferralRewardChosen(this.invitationId, this.choice);
  final String invitationId;
  final RewardChoice choice;
}

class ReferralCodeCopied extends ReferralEvent {
  const ReferralCodeCopied();
}

/// Copie du lien d'invitation (`channel: copy_link`).
class ReferralLinkCopied extends ReferralEvent {
  const ReferralLinkCopied();
}

/// Canal de partage du lien d'invitation, propriété `channel` de
/// `referral_shared`.
enum ReferralShareChannel {
  whatsapp('whatsapp'),
  shareSheet('share_sheet'),
  copyLink('copy_link');

  const ReferralShareChannel(this.wire);
  final String wire;
}

class ReferralShared extends ReferralEvent {
  const ReferralShared(
    this.message, {
    this.sharePositionOrigin,
    this.channel = ReferralShareChannel.shareSheet,
  });

  /// Texte réellement partagé, construit par l'écran (`referralShareMessage`)
  /// — le bloc ne construit plus de texte lui-même.
  final String message;

  /// Ancre de la popover de partage iOS (`sharePositionOriginFor`) —
  /// obligatoire sur iOS, calculée depuis le `BuildContext` du bouton, donc
  /// transportée jusqu'ici plutôt que recalculée dans le bloc.
  final Rect? sharePositionOrigin;

  /// [ReferralShareChannel.whatsapp] ouvre WhatsApp directement, avec repli
  /// sur la feuille de partage si l'application ne s'ouvre pas.
  final ReferralShareChannel channel;
}

class ReferralRedeemRequested extends ReferralEvent {
  const ReferralRedeemRequested(this.code);
  final String code;
}
