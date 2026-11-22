import 'package:dony/features/recipients/data/datasources/recipient_invitation_datasource.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';

class RecipientInvitationRepository {
  RecipientInvitationRepository(this._datasource);

  final RecipientInvitationDatasource _datasource;

  /// Le back connecté ne connaît pas la recherche par identifiant (route
  /// absente : 404, ou 405 sur l'ancien contrôleur). Le verdict vaut pour la
  /// session : le dépôt est un singleton, l'onglet « Identifiant » reste
  /// masqué à chaque ouverture de la feuille sans refaire d'appel.
  bool usernameChannelUnsupported = false;

  /// Le back connecté trouve les comptes mais ne sait pas désigner un
  /// destinataire de colis par identifiant (`parcelDesignation` absent ou
  /// faux dans la recherche) : il ignorerait l'identifiant en silence. Le
  /// choix « Un utilisateur Yadony » d'un colis reste masqué pour la session.
  bool parcelDesignationUnavailable = false;

  /// Le choix « Un utilisateur Yadony » d'un colis est-il offert ?
  bool get parcelDesignationOffered =>
      !usernameChannelUnsupported && !parcelDesignationUnavailable;

  Future<void> sendToPhone(String phoneE164, {String? name}) =>
      _datasource.send(phone: phoneE164, name: name);

  Future<void> sendToEmail(String email, {String? name}) =>
      _datasource.send(email: email, name: name);

  Future<void> sendToUsername(String username, {String? name}) =>
      _datasource.send(username: username, name: name);

  Future<UsernameLookup> lookupUsername(String username) =>
      _datasource.lookupUsername(username);

  Future<List<SentRecipientInvitation>> getSent() => _datasource.fetchSent();

  Future<List<IncomingRecipientInvitation>> getIncoming() =>
      _datasource.fetchIncoming();

  Future<void> accept(String id) => _datasource.accept(id);

  Future<void> decline(String id) => _datasource.decline(id);

  Future<void> revoke(String id) => _datasource.revoke(id);
}
