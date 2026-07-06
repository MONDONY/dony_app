part of 'recipient_bloc.dart';

abstract class RecipientEvent {
  const RecipientEvent();
}

class RecipientLoaded extends RecipientEvent {
  const RecipientLoaded();
}

class RecipientCreated extends RecipientEvent {
  const RecipientCreated({
    required this.fullName,
    this.relationship,
    required this.phoneE164,
    this.whatsappE164,
    this.street,
    required this.city,
    required this.country,
    this.notes,
    this.isDefault = false,
  });

  final String fullName;
  final String? relationship;
  final String phoneE164;
  final String? whatsappE164;
  final String? street;
  final String city;
  final String country;
  final String? notes;
  final bool isDefault;
}

class RecipientUpdated extends RecipientEvent {
  const RecipientUpdated({
    required this.id,
    required this.fullName,
    this.relationship,
    required this.phoneE164,
    this.whatsappE164,
    this.street,
    required this.city,
    required this.country,
    this.notes,
    this.isDefault = false,
  });

  final String id;
  final String fullName;
  final String? relationship;
  final String phoneE164;
  final String? whatsappE164;
  final String? street;
  final String city;
  final String country;
  final String? notes;
  final bool isDefault;
}

class RecipientDeleted extends RecipientEvent {
  const RecipientDeleted(this.id);
  final String id;
}

class RecipientDefaultSet extends RecipientEvent {
  const RecipientDefaultSet(this.id);
  final String id;
}

/// Event analytics pur — tiré par le picker au moment de la confirmation.
class RecipientPicked extends RecipientEvent {
  const RecipientPicked(this.source); // 'saved' | 'phone_contact' | 'new'
  final String source;
}
