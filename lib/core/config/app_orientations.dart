import 'package:flutter/services.dart';

/// Orientations autorisées dans toute l'application : portrait seul.
///
/// Les écrans ne sont pas conçus pour le paysage, et la revue Apple teste
/// l'app en la tournant. Info.plist garde le paysage, sans quoi le plein écran
/// des tutoriels YouTube ne pourrait plus pivoter : le verrou est posé ici, au
/// démarrage, et le lecteur y revient en quittant le plein écran.
const List<DeviceOrientation> appOrientations = [DeviceOrientation.portraitUp];
