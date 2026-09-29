import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';

/// Lit le code du SMS de connexion sans que l'utilisateur ouvre Messages
/// (API SMS Retriever de Google, Android seulement, sans permission SMS).
///
/// Google ne remet à l'app que les SMS qui contiennent son empreinte de
/// 11 caractères, calculée sur l'identifiant et le certificat de signature.
/// C'est le backend qui l'ajoute (`ANDROID_SMS_APP_HASHES`), jamais l'app :
/// une empreinte fournie par le client permettrait à une app malveillante
/// installée sur le téléphone de lire le code d'un autre compte.
///
/// Sans empreinte reconnue (build signé par une autre clé, SMS Twilio Verify),
/// l'écoute expire en silence au bout de cinq minutes : la suggestion du
/// clavier (`AutofillHints.oneTimeCode`) reste disponible.
class AndroidSmsCodeRetriever implements SmsRetriever {
  AndroidSmsCodeRetriever({SmartAuth? smartAuth})
    : _smartAuth = smartAuth ?? SmartAuth.instance;

  final SmartAuth _smartAuth;

  /// Le code yadony : exactement six chiffres. Une empreinte peut contenir des
  /// chiffres, jamais six d'affilée entourés de non-chiffres.
  static const codeMatcher = r'(?<!\d)\d{6}(?!\d)';

  @override
  bool get listenForMultipleSms => false;

  @override
  Future<String?> getSmsCode() async {
    final result = await _smartAuth.getSmsWithRetrieverApi(
      matcher: codeMatcher,
    );
    return result.data?.code;
  }

  @override
  Future<void> dispose() async {
    await _smartAuth.removeSmsRetrieverApiListener();
  }
}
