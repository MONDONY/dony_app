import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photo_upload.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';

/// Photo déjà envoyée, gardée dans un brouillon : sa clé suffit à la
/// publication, le chemin local à son affichage.
typedef DraftPhoto = ({String key, String localPath});

/// Reprise d'un brouillon local, choisie dans la feuille des brouillons :
/// passée au formulaire de création (`extra` de `/package-requests/new`).
class PackageRequestDraftResume {
  const PackageRequestDraftResume(this.data);

  /// Contenu du brouillon, au format [PackageRequestFormDraft].
  final Map<String, dynamic> data;
}

/// Format du brouillon local d'une demande d'envoi (FormDraftStore).
///
/// Garde la saisie telle qu'elle est, même incomplète : chaque champ peut
/// manquer. Les clés sont figées, un brouillon enregistré par une version de
/// l'app doit rester lisible par la suivante.
abstract final class PackageRequestFormDraft {
  /// Brouillon de [state], complété par [stepInput] : la saisie de l'étape
  /// affichée, que l'étape ne remonte au bloc qu'à sa validation. Les clés de
  /// [stepInput] sont celles du brouillon et priment sur l'état du bloc.
  static Map<String, dynamic> encode(
    PackageRequestFormState state, {
    Map<String, dynamic> stepInput = const {},
    List<PackageRequestPhotoUpload> photos = const [],
  }) => {
    'step': state.currentStep,
    'departureCity': state.departureCity,
    'arrivalCity': state.arrivalCity,
    'desiredDate': encodeDate(state.desiredDate),
    'dateToleranceDays': state.dateToleranceDays,
    'transportMode': state.transportMode == null
        ? null
        : transportModeToWire(state.transportMode!),
    'weightKg': state.weightKg,
    'parcelSize': state.parcelSize?.wireName,
    'categories': state.categories,
    'description': state.description,
    'pickupNeighborhood': state.pickupNeighborhood,
    'deliveryNeighborhood': state.deliveryNeighborhood,
    'negotiable': state.negotiable,
    'acceptedPaymentMethods': [
      for (final m in state.acceptedPaymentMethods) m.wireName,
    ],
    'totalBudgetEur': state.totalBudgetEur,
    'targetPriceEur': state.targetPriceEur,
    'promoCode': state.promoCode,
    'currency': state.currency?.code,
    'photos': [
      for (final p in photos)
        if (p.status == PackageRequestPhotoUploadStatus.ready &&
            p.remoteKey != null &&
            p.localPath.isNotEmpty)
          {'key': p.remoteKey, 'localPath': p.localPath},
    ],
    ...stepInput,
  };

  /// État du formulaire à la reprise. La date étant facultative, une date
  /// souhaitée passée est seulement retirée (avec sa souplesse) : la demande
  /// devient « Date flexible » sans renvoyer à la première étape.
  static PackageRequestFormState decode(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    var date = decodeDate(json['desiredDate']);
    var tolerance = (json['dateToleranceDays'] as num?)?.toInt();
    final step = ((json['step'] as num?)?.toInt() ?? 0).clamp(0, 2);
    if (date != null && date.isBefore(today)) {
      date = null;
      tolerance = null;
    }
    final methods = <PaymentMethod>{
      for (final w in _strings(json['acceptedPaymentMethods']))
        ?PaymentMethod.tryFromWire(w),
    };
    final size = json['parcelSize'] as String?;
    return PackageRequestFormState(
      currentStep: step,
      departureCity: json['departureCity'] as String?,
      arrivalCity: json['arrivalCity'] as String?,
      desiredDate: date,
      dateToleranceDays: tolerance,
      transportMode: transportModeFromWire(json['transportMode'] as String?),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      parcelSize: size == null
          ? null
          : ParcelSize.values.where((e) => e.wireName == size).firstOrNull,
      categories: _strings(json['categories']),
      description: json['description'] as String?,
      pickupNeighborhood: json['pickupNeighborhood'] as String?,
      deliveryNeighborhood: json['deliveryNeighborhood'] as String?,
      negotiable: json['negotiable'] as bool? ?? true,
      acceptedPaymentMethods: methods.isEmpty
          ? const {PaymentMethod.stripe}
          : methods,
      totalBudgetEur: (json['totalBudgetEur'] as num?)?.toDouble(),
      targetPriceEur: (json['targetPriceEur'] as num?)?.toDouble(),
      promoCode: json['promoCode'] as String?,
      currency: SupportedCurrency.fromCode(json['currency'] as String?),
    );
  }

  /// Photos gardées par le brouillon, dans l'ordre d'ajout.
  static List<DraftPhoto> decodePhotos(Map<String, dynamic> json) => [
    for (final raw in (json['photos'] as List?) ?? const [])
      if (raw is Map &&
          raw['key'] is String &&
          raw['localPath'] is String &&
          (raw['localPath'] as String).isNotEmpty)
        (key: raw['key'] as String, localPath: raw['localPath'] as String),
  ];

  /// Jour seul, `yyyy-MM-dd` : un brouillon ne se décale pas d'un jour en
  /// changeant de fuseau.
  static String? encodeDate(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';

  static DateTime? decodeDate(Object? raw) {
    if (raw is! String) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? null : _dateOnly(parsed);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static List<String> _strings(Object? raw) => [
    for (final e in (raw as List?) ?? const [])
      if (e is String) e,
  ];
}
