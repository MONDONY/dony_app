import 'package:dony/features/settings/data/datasources/user_language_remote_datasource.dart';

/// Façade au-dessus de [UserLanguageRemoteDatasource], sur le modèle de
/// `BusinessPrefsRepository`.
class UserLanguageRepository {
  final UserLanguageRemoteDatasource _datasource;

  const UserLanguageRepository(this._datasource);

  /// `true` si le serveur a pris en compte le changement de langue, `false`
  /// sur un backend qui ne connaît pas encore la route (compatibilité).
  Future<bool> update(String languageCode) => _datasource.update(languageCode);
}
