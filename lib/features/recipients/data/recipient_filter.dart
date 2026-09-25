import 'package:dony/features/recipients/data/models/recipient.dart';

/// Filtre local insensible à la casse et aux accents sur
/// nom, lien, ville et téléphone.
List<Recipient> filterRecipients(List<Recipient> recipients, String query) {
  final q = _fold(query.trim());
  if (q.isEmpty) return recipients;
  return recipients.where((r) {
    final haystack = _fold(
      '${r.fullName} ${r.relationship ?? ''} ${r.city ?? ''} ${r.phoneE164}', // i18n-ignore: texte de recherche composé de données
    );
    return haystack.contains(q);
  }).toList();
}

String _fold(String s) {
  const from = 'àâäéèêëîïôöùûüç'; // i18n-ignore: table d'accents
  const to = 'aaaeeeeiioouuuc'; // i18n-ignore: table d'accents
  var out = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}
