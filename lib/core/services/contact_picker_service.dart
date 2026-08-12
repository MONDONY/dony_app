import 'package:flutter/foundation.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

/// Contact minimal ramené par le picker natif : nom complet + premier
/// numéro de téléphone déjà normalisé.
@immutable
class PickedContact {
  const PickedContact({this.fullName, this.phone});

  final String? fullName;
  final String? phone;
}

/// Normalise un numéro issu du carnet d'adresses : retire les séparateurs
/// usuels (espaces, tirets, points, parenthèses) et convertit le préfixe
/// international `00` en `+`. Ne valide pas le format E.164 — la validation
/// métier reste dans le repository/BLoC appelant.
String normalizePhone(String raw) {
  var p = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  if (p.startsWith('00')) {
    p = '+${p.substring(2)}';
  }
  return p;
}

/// Ouvre le picker de contact natif de l'OS.
///
/// iOS : `CNContactPickerViewController`. Android : `ACTION_PICK`.
/// Aucune permission manifeste (`READ_CONTACTS`) n'est requise — l'OS médie
/// l'accès et ne restitue que le contact unique choisi par l'utilisateur.
///
/// [pick] ne lance jamais d'exception : annulation utilisateur, contact sans
/// numéro ou erreur de plateforme retournent toutes `null` (ou un
/// [PickedContact] avec `phone: null`), à charge de l'appelant de gérer le
/// cas "rien de récupéré".
class ContactPickerService {
  ContactPickerService({FlutterNativeContactPicker? picker})
    : _picker = picker ?? FlutterNativeContactPicker();

  final FlutterNativeContactPicker _picker;

  Future<PickedContact?> pick() async {
    try {
      final contact = await _picker.selectContact();
      if (contact == null) {
        return null;
      }
      final phones = contact.phoneNumbers;
      return PickedContact(
        fullName: contact.fullName,
        phone: (phones != null && phones.isNotEmpty)
            ? normalizePhone(phones.first)
            : null,
      );
    } on Exception {
      // Annulation utilisateur ou erreur de plateforme (ex. PlatformException,
      // qui implémente Exception) → pas d'erreur bloquante pour l'appelant.
      return null;
    }
  }
}
