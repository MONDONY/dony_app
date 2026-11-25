import 'package:dony/features/video_modal/data/models/parcel_role.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// Variables qu'un texte de modal d'étape peut contenir, remplies par l'app à
/// l'ouverture (le back ne connaît pas le colis). Liste fermée, la même que
/// celle que l'admin accepte : toute autre accolade reste telle quelle. Le
/// code de retrait n'en fait jamais partie.
enum ParcelModalVariable {
  recipient('destinataire'),
  traveler('voyageur'),
  sender('expéditeur'), // i18n-ignore (clé de variable, jamais affichée)
  arrivalCity('ville_arrivee');

  const ParcelModalVariable(this.key);

  /// Nom entre accolades dans le texte (`{destinataire}`), et clé de la table
  /// des valeurs du moment.
  final String key;
}

final _variablePattern = RegExp(
  '\\{(${ParcelModalVariable.values.map((v) => RegExp.escape(v.key)).join('|')})\\}',
);

/// Remplace les quatre variables connues de [text], en un seul passage : un
/// nom qui contient lui-même une accolade n'est pas réinterprété. Valeur vide
/// ou faite d'espaces : le repli de [fallbacks] (« votre destinataire »…),
/// avec une majuscule quand la variable ouvre une phrase. Les noms gardent
/// leur casse.
String fillParcelVariables(
  String text, {
  required Map<String, String> values,
  required Map<String, String> fallbacks,
}) {
  return text.replaceAllMapped(_variablePattern, (match) {
    final key = match.group(1)!;
    final value = values[key]?.trim() ?? '';
    if (value.isNotEmpty) return value;
    final fallback = fallbacks[key] ?? '';
    return _opensSentence(text, match.start) ? _capitalize(fallback) : fallback;
  });
}

/// Vrai si rien, ou seulement des espaces après une fin de phrase, précède
/// [index].
bool _opensSentence(String text, int index) {
  final before = text.substring(0, index).trimRight();
  if (before.isEmpty) return true;
  final last = before[before.length - 1];
  return last == '.' || last == '!' || last == '?' || last == '\n';
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s.substring(0, 1).toUpperCase()}${s.substring(1)}';

/// Ouvre une fenêtre propre au colis (QR, « Prévenir », suivi) depuis le
/// [context] où le modal était affiché.
typedef ParcelActionOpener = Future<void> Function(BuildContext context);

/// Ce que l'écran du colis sait ouvrir pour un bouton `PARCEL_*` : `null`
/// quand il ne le sait pas (bouton alors masqué).
class ParcelActionOpeners {
  const ParcelActionOpeners({this.qr, this.sendCode, this.tracking});

  /// `QrSheet` du colis.
  final ParcelActionOpener? qr;

  /// Feuille « Prévenir » en mode code.
  final ParcelActionOpener? sendCode;

  /// Suivi du colis (le même geste que le bouton du bas « Suivi du colis »).
  final ParcelActionOpener? tracking;
}

/// Contexte d'un modal d'étape : le colis, les rôles de la personne sur ce
/// colis et ce que l'écran sait ouvrir. Décide quels boutons `PARCEL_*` sont
/// affichés (un bouton qui ne s'applique pas n'est pas montré).
class ParcelActionContext extends Equatable {
  const ParcelActionContext({
    required this.bidId,
    required this.roles,
    this.canSendCode = false,
    this.openers = const ParcelActionOpeners(),
  });

  final String bidId;

  /// Rôles de la personne : l'expéditeur qui est son propre destinataire a
  /// les deux.
  final Set<ParcelRole> roles;

  /// Le code de retrait existe et peut partir vers un destinataire tiers
  /// (mêmes règles que le bouton du bas « Envoyer le code à … »).
  final bool canSendCode;
  final ParcelActionOpeners openers;

  bool get _isSender => roles.contains(ParcelRole.sender);

  /// Fiche du colis pour cette personne : la réception pour le seul
  /// destinataire, la fiche colis sinon.
  String get detailRoute => _isSender || roles.contains(ParcelRole.traveler)
      ? '/bids/$bidId'
      : '/receptions/$bidId';

  /// Le bouton qui ouvre [screen] a un sens pour cette personne et ce colis.
  /// Les écrans qui ne sont pas des écrans de colis restent toujours possibles.
  ///
  /// - QR : l'expéditeur seulement (le back le refuse au voyageur ; jamais
  ///   pour le destinataire dans un modal d'étape).
  /// - « Prévenir » en mode code : l'expéditeur seulement, code présent.
  /// - Suivi : tout rôle, si l'écran sait l'ouvrir. Détail : toujours.
  bool canRun(InfoScreen screen) => switch (screen) {
    InfoScreen.parcelDetail => true,
    InfoScreen.parcelQr => _isSender && openers.qr != null,
    InfoScreen.parcelSendCode =>
      _isSender && canSendCode && openers.sendCode != null,
    InfoScreen.parcelTracking => openers.tracking != null,
    _ => true,
  };

  /// Ouvreur du bouton [screen], `null` pour le détail (une route) et les
  /// écrans hors colis.
  ParcelActionOpener? openerFor(InfoScreen screen) => switch (screen) {
    InfoScreen.parcelQr => openers.qr,
    InfoScreen.parcelSendCode => openers.sendCode,
    InfoScreen.parcelTracking => openers.tracking,
    _ => null,
  };

  /// Les ouvreurs sont des fonctions : seule leur présence compte dans
  /// l'égalité (deux ouvertures du même colis sont le même moment).
  @override
  List<Object?> get props => [
    bidId,
    roles,
    canSendCode,
    openers.qr != null,
    openers.sendCode != null,
    openers.tracking != null,
  ];
}
