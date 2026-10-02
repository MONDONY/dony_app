import 'package:dony/features/recipients/data/datasources/recipient_invitation_datasource.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';

class RecipientInvitationRepository {
  RecipientInvitationRepository(this._datasource);

  final RecipientInvitationDatasource _datasource;

  Future<void> sendToPhone(String phoneE164, {String? name}) =>
      _datasource.send(phone: phoneE164, name: name);

  Future<void> sendToEmail(String email, {String? name}) =>
      _datasource.send(email: email, name: name);

  Future<List<SentRecipientInvitation>> getSent() => _datasource.fetchSent();

  Future<List<IncomingRecipientInvitation>> getIncoming() =>
      _datasource.fetchIncoming();

  Future<void> accept(String id) => _datasource.accept(id);

  Future<void> decline(String id) => _datasource.decline(id);

  Future<void> revoke(String id) => _datasource.revoke(id);
}
