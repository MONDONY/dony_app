import 'dart:ui' show Rect;

abstract class ReferralEvent {
  const ReferralEvent();
}

class ReferralLoadRequested extends ReferralEvent {
  const ReferralLoadRequested();
}

class ReferralCodeCopied extends ReferralEvent {
  const ReferralCodeCopied();
}

class ReferralShared extends ReferralEvent {
  const ReferralShared(this.message, {this.sharePositionOrigin});

  /// Texte réellement partagé, construit par l'écran (`referralShareMessage`)
  /// — le bloc ne construit plus de texte lui-même.
  final String message;

  /// Ancre de la popover de partage iOS (`sharePositionOriginFor`) —
  /// obligatoire sur iOS, calculée depuis le `BuildContext` du bouton, donc
  /// transportée jusqu'ici plutôt que recalculée dans le bloc.
  final Rect? sharePositionOrigin;
}

class ReferralRedeemRequested extends ReferralEvent {
  const ReferralRedeemRequested(this.code);
  final String code;
}
