class Recipient {
  final String id;
  final String fullName;
  final String? relationship;
  final String phoneE164;
  final String? whatsappE164;
  final String? street;
  final String? city;
  final String country;
  final String? notes;
  final bool isDefault;

  const Recipient({
    required this.id,
    required this.fullName,
    this.relationship,
    required this.phoneE164,
    this.whatsappE164,
    this.street,
    this.city,
    required this.country,
    this.notes,
    this.isDefault = false,
  });

  factory Recipient.fromJson(Map<String, dynamic> json) => Recipient(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    relationship: json['relationship'] as String?,
    phoneE164: json['phoneE164'] as String,
    whatsappE164: json['whatsappE164'] as String?,
    street: json['street'] as String?,
    city: json['city'] as String?,
    country: json['country'] as String,
    notes: json['notes'] as String?,
    isDefault: json['isDefault'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    if (relationship != null) 'relationship': relationship,
    'phoneE164': phoneE164,
    if (whatsappE164 != null) 'whatsappE164': whatsappE164,
    if (street != null) 'street': street,
    if (city != null) 'city': city,
    'country': country,
    if (notes != null) 'notes': notes,
    'isDefault': isDefault,
  };

  Recipient copyWith({bool? isDefault}) => Recipient(
    id: id,
    fullName: fullName,
    relationship: relationship,
    phoneE164: phoneE164,
    whatsappE164: whatsappE164,
    street: street,
    city: city,
    country: country,
    notes: notes,
    isDefault: isDefault ?? this.isDefault,
  );
}
