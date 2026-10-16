import 'package:cloud_firestore/cloud_firestore.dart';

/// Document Firestore `config/maintenance`, réécrit par le back à chaque
/// bascule depuis le back-office (dony-back `MaintenanceChangedListener`).
/// Lisible sans session (règle dony-functions) : l'écoute prévient l'app en
/// une ou deux secondes, sans attendre une requête de l'utilisateur.
class MaintenanceLiveDatasource {
  MaintenanceLiveDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Émet `enabled` à chaque changement du document (faux s'il n'existe pas).
  Stream<bool> watchEnabled() => _firestore
      .collection('config')
      .doc('maintenance')
      .snapshots()
      .map((snap) => snap.data()?['enabled'] == true);
}
