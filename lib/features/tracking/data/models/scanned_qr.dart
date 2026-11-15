import 'package:equatable/equatable.dart';

/// QR Yadony lu par la caméra : le colis qu'il désigne et, pour un colis payé
/// au dépôt (bateau), le jeton `?k=` de l'expéditeur. Ce jeton prouve que le
/// dépôt est fait devant l'expéditeur : il part tel quel avec l'étape DEPART
/// (`qrToken`), sans jamais être affiché ni journalisé.
class ScannedQr extends Equatable {
  const ScannedQr(this.bidId, {this.qrToken});

  final String bidId;

  /// Jeton du QR de dépôt ; `null` pour tout autre QR (avion, route).
  final String? qrToken;

  @override
  List<Object?> get props => [bidId, qrToken];
}
