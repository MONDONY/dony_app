import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/matching/data/models/search_params.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';

/// Presets de date partagés par les deux modes. Remplace l'ancien `_DatePreset`
/// privé de home_screen et le `showDateRangePicker` du mode colis.
enum DonyDatePreset { none, today, thisWeek, thisMonth, custom }

/// Paramètres de recherche de demandes, produits par [HomeSearchFilters].
/// Porteur nommé plutôt qu'un tuple : les champs sont nombreux et homogènes en
/// type, une inversion d'arguments positionnels passerait inaperçue.
class PackageRequestQuery {
  const PackageRequestQuery({
    this.departure,
    this.arrival,
    this.dateFrom,
    this.dateTo,
    this.maxWeight,
    this.parcelSize,
    this.userLat,
    this.userLng,
    this.radiusKm,
    this.urgent,
    this.matchingMyTrips,
  });

  final String? departure;
  final String? arrival;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? maxWeight;
  final ParcelSize? parcelSize;
  final double? userLat;
  final double? userLng;
  final double? radiusKm;
  final bool? urgent;
  final bool? matchingMyTrips;
}

/// Paramètres de recherche de trajets envoyés au serveur via
/// `AnnouncementSearchRequested` (voir
/// `lib/features/matching/bloc/announcement_event.dart`), produits par
/// [HomeSearchFilters]. Porte exactement les champs filtres de cet événement
/// (hors `sortBy`/`sortDir`, qui ne sont pas des filtres) : c'est ce porteur,
/// et non [SearchParams], qui reflète le vrai payload envoyé au serveur.
class AnnouncementQuery {
  const AnnouncementQuery({
    this.departureCity,
    this.arrivalCity,
    this.departureDateFrom,
    this.departureDateTo,
    this.minAvailableKg,
    this.maxAvailableKg,
    this.maxPricePerKg,
    this.kiloProOnly,
    this.minRating,
    this.weekendOnly,
    this.transportMode,
    this.kycVerifiedOnly,
    this.contentType,
    this.userLat,
    this.userLng,
    this.radiusKm,
    this.urgent,
  });

  final String? departureCity;
  final String? arrivalCity;
  final DateTime? departureDateFrom;
  final DateTime? departureDateTo;
  final double? minAvailableKg;
  final double? maxAvailableKg;
  final double? maxPricePerKg;
  final bool? kiloProOnly;
  final double? minRating;
  final bool? weekendOnly;
  final TransportMode? transportMode;
  final bool? kycVerifiedOnly;
  final String? contentType;
  final double? userLat;
  final double? userLng;
  final double? radiusKm;
  final bool? urgent;
}

/// État de recherche de l'écran Rechercher, immuable et sans dépendance Flutter.
///
/// Trois familles de champs : les communs, partagés par les deux modes et
/// conservés lors d'une bascule ; les spécifiques aux trajets ; les spécifiques
/// aux colis. C'est le partage des communs qui corrige la perte du corridor au
/// changement de mode.
class HomeSearchFilters {
  const HomeSearchFilters({
    // Communs
    this.departureCity,
    this.arrivalCity,
    this.datePreset = DonyDatePreset.none,
    this.customDate,
    this.urgentOnly = false,
    this.nearMeActive = false,
    this.nearMeRadiusKm,
    this.userLat,
    this.userLng,
    // Trajets
    this.maxPricePerKg,
    this.weightMin,
    this.weightMax,
    this.kiloProOnly = false,
    this.minRating,
    this.weekendOnly = false,
    this.transportMode,
    this.kycVerifiedOnly = false,
    this.contentType,
    this.urgencyFilter,
    // Colis
    this.maxWeight,
    this.parcelSize,
    this.matchingMyTrips = false,
  });

  // ── Communs ────────────────────────────────────────────────────────────────
  final String? departureCity;
  final String? arrivalCity;
  final DonyDatePreset datePreset;
  final DateTime? customDate;
  final bool urgentOnly;
  final bool nearMeActive;
  final double? nearMeRadiusKm;
  final double? userLat;
  final double? userLng;

  // ── Trajets ────────────────────────────────────────────────────────────────
  final double? maxPricePerKg;

  /// Capacité minimale attendue du voyageur, en kg. À ne pas confondre avec
  /// [maxWeight] : sémantiques opposées, jamais propagées l'une vers l'autre.
  final double? weightMin;
  final double? weightMax;
  final bool kiloProOnly;
  final double? minRating;
  final bool weekendOnly;
  final TransportMode? transportMode;
  final bool kycVerifiedOnly;
  final String? contentType;
  final UrgencyFilter? urgencyFilter;

  // ── Colis ──────────────────────────────────────────────────────────────────
  /// Poids maximal des demandes recherchées, en kg. Voir [weightMin].
  final double? maxWeight;
  final ParcelSize? parcelSize;
  final bool matchingMyTrips;

  /// Vrai si le compteur de résultats de l'autre mode (segment inactif du
  /// sélecteur) est informatif plutôt qu'un simple total plateforme.
  ///
  /// Le critère n'est pas « un filtre commun est posé » mais « ce filtre
  /// restreint-il le jeu de résultats de façon géographique ou temporelle ? »
  /// Un corridor, une date ou « près de moi » réduisent effectivement le
  /// périmètre recherché : le compteur de l'autre mode prend alors du sens.
  /// `urgentOnly` en est volontairement exclu : il ne restreint ni la zone ni
  /// la période, afficher un compteur sous son seul effet montrerait un total
  /// plateforme sans rapport avec le filtre posé.
  bool get otherModeCountIsMeaningful =>
      departureCity != null ||
      arrivalCity != null ||
      datePreset != DonyDatePreset.none ||
      nearMeActive;

  DateTime? get dateFrom {
    final now = DateTime.now();
    switch (datePreset) {
      case DonyDatePreset.today:
        return DateTime(now.year, now.month, now.day);
      case DonyDatePreset.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case DonyDatePreset.thisMonth:
        return DateTime(now.year, now.month);
      case DonyDatePreset.custom:
        return customDate;
      case DonyDatePreset.none:
        return null;
    }
  }

  DateTime? get dateTo {
    final now = DateTime.now();
    switch (datePreset) {
      case DonyDatePreset.today:
        return DateTime(now.year, now.month, now.day);
      case DonyDatePreset.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return DateTime(sunday.year, sunday.month, sunday.day);
      case DonyDatePreset.thisMonth:
        return DateTime(now.year, now.month + 1, 0);
      case DonyDatePreset.custom:
        return customDate;
      case DonyDatePreset.none:
        return null;
    }
  }

  /// Sert uniquement à pré-remplir la sheet de filtres (valeurs par défaut des
  /// champs affichés) : ce n'est PAS le payload envoyé au serveur pour la
  /// recherche de trajets, voir [toAnnouncementQuery] pour cela. « Près de
  /// moi » neutralise le corridor : on veut tous les voyageurs autour de
  /// l'utilisateur, pas ceux d'un corridor.
  SearchParams toSearchParams() {
    final ignoreCorridor = nearMeActive;
    return SearchParams(
      departureCity: ignoreCorridor ? null : departureCity,
      arrivalCity: ignoreCorridor ? null : arrivalCity,
      date: customDate,
      weightKg: weightMin ?? 6,
      maxPricePerKg: maxPricePerKg ?? 25,
      kiloProOnly: kiloProOnly,
      ratingFilter: minRating != null,
      weekendFilter: weekendOnly,
      priceFilter: maxPricePerKg != null,
      transportMode: transportMode,
      kycVerifiedOnly: kycVerifiedOnly,
      contentType: contentType,
      urgencyFilter: urgencyFilter,
    );
  }

  /// Payload de recherche de demandes réellement envoyé au serveur. Les
  /// booléens serveur ne partent jamais à `false` explicitement, même
  /// convention que le back : présent ou absent.
  PackageRequestQuery toPackageRequestQuery() => PackageRequestQuery(
        departure: departureCity,
        arrival: arrivalCity,
        dateFrom: dateFrom,
        dateTo: dateTo,
        maxWeight: maxWeight,
        parcelSize: parcelSize,
        userLat: nearMeActive ? userLat : null,
        userLng: nearMeActive ? userLng : null,
        radiusKm: nearMeActive ? nearMeRadiusKm : null,
        urgent: urgentOnly ? true : null,
        matchingMyTrips: matchingMyTrips ? true : null,
      );

  /// Payload de recherche de trajets réellement envoyé au serveur, porté par
  /// `AnnouncementSearchRequested`. C'est cette méthode, et non
  /// [toSearchParams], qu'il faut consulter/étendre pour tout filtre trajets
  /// destiné au serveur. « Près de moi » neutralise le corridor comme pour
  /// [toSearchParams]. Les booléens serveur ne partent jamais à `false`
  /// explicitement, même convention que [toPackageRequestQuery].
  AnnouncementQuery toAnnouncementQuery() {
    final ignoreCorridor = nearMeActive;
    return AnnouncementQuery(
      departureCity: ignoreCorridor ? null : departureCity,
      arrivalCity: ignoreCorridor ? null : arrivalCity,
      departureDateFrom: dateFrom,
      departureDateTo: dateTo,
      minAvailableKg: weightMin,
      maxAvailableKg: weightMax,
      maxPricePerKg: maxPricePerKg,
      kiloProOnly: kiloProOnly ? true : null,
      minRating: minRating,
      weekendOnly: weekendOnly ? true : null,
      transportMode: transportMode,
      kycVerifiedOnly: kycVerifiedOnly ? true : null,
      contentType: contentType,
      userLat: nearMeActive ? userLat : null,
      userLng: nearMeActive ? userLng : null,
      radiusKm: nearMeActive ? nearMeRadiusKm : null,
      urgent: urgentOnly ? true : null,
    );
  }

  /// Nombre de filtres actifs pour le badge de la barre corridor : communs
  /// plus ceux du mode courant. Un filtre spécifique à l'autre mode ne compte pas.
  int activeCountFor(SearchMode mode) {
    var n = 0;
    if (departureCity != null || arrivalCity != null) {
      n++;
    }
    if (datePreset != DonyDatePreset.none) {
      n++;
    }
    if (urgentOnly) {
      n++;
    }
    if (nearMeActive) {
      n++;
    }

    if (mode.isTrips) {
      if (kiloProOnly) {
        n++;
      }
      if (minRating != null) {
        n++;
      }
      if (weightMin != null || weightMax != null) {
        n++;
      }
      if (maxPricePerKg != null) {
        n++;
      }
      if (weekendOnly) {
        n++;
      }
      if (transportMode != null) {
        n++;
      }
      if (kycVerifiedOnly) {
        n++;
      }
      if (contentType != null) {
        n++;
      }
      if (urgencyFilter != null) {
        n++;
      }
    } else {
      if (maxWeight != null) {
        n++;
      }
      if (parcelSize != null) {
        n++;
      }
      if (matchingMyTrips) {
        n++;
      }
    }
    return n;
  }

  /// Les drapeaux `clearXxx` permettent de remettre un champ à null, ce qu'un
  /// paramètre optionnel seul ne sait pas exprimer.
  HomeSearchFilters copyWith({
    String? departureCity,
    String? arrivalCity,
    DonyDatePreset? datePreset,
    DateTime? customDate,
    bool? urgentOnly,
    bool? nearMeActive,
    double? nearMeRadiusKm,
    double? userLat,
    double? userLng,
    double? maxPricePerKg,
    double? weightMin,
    double? weightMax,
    bool? kiloProOnly,
    double? minRating,
    bool? weekendOnly,
    TransportMode? transportMode,
    bool? kycVerifiedOnly,
    String? contentType,
    UrgencyFilter? urgencyFilter,
    double? maxWeight,
    ParcelSize? parcelSize,
    bool? matchingMyTrips,
    bool clearCorridor = false,
    bool clearCustomDate = false,
    bool clearMaxPricePerKg = false,
    bool clearWeight = false,
    bool clearMinRating = false,
    bool clearTransportMode = false,
    bool clearContentType = false,
    bool clearUrgencyFilter = false,
    bool clearMaxWeight = false,
    bool clearParcelSize = false,
    bool clearNearMe = false,
  }) {
    return HomeSearchFilters(
      departureCity: clearCorridor ? null : (departureCity ?? this.departureCity),
      arrivalCity: clearCorridor ? null : (arrivalCity ?? this.arrivalCity),
      datePreset: datePreset ?? this.datePreset,
      customDate: clearCustomDate ? null : (customDate ?? this.customDate),
      urgentOnly: urgentOnly ?? this.urgentOnly,
      nearMeActive: clearNearMe ? false : (nearMeActive ?? this.nearMeActive),
      nearMeRadiusKm: clearNearMe ? null : (nearMeRadiusKm ?? this.nearMeRadiusKm),
      userLat: clearNearMe ? null : (userLat ?? this.userLat),
      userLng: clearNearMe ? null : (userLng ?? this.userLng),
      maxPricePerKg:
          clearMaxPricePerKg ? null : (maxPricePerKg ?? this.maxPricePerKg),
      weightMin: clearWeight ? null : (weightMin ?? this.weightMin),
      weightMax: clearWeight ? null : (weightMax ?? this.weightMax),
      kiloProOnly: kiloProOnly ?? this.kiloProOnly,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      weekendOnly: weekendOnly ?? this.weekendOnly,
      transportMode:
          clearTransportMode ? null : (transportMode ?? this.transportMode),
      kycVerifiedOnly: kycVerifiedOnly ?? this.kycVerifiedOnly,
      contentType: clearContentType ? null : (contentType ?? this.contentType),
      urgencyFilter:
          clearUrgencyFilter ? null : (urgencyFilter ?? this.urgencyFilter),
      maxWeight: clearMaxWeight ? null : (maxWeight ?? this.maxWeight),
      parcelSize: clearParcelSize ? null : (parcelSize ?? this.parcelSize),
      matchingMyTrips: matchingMyTrips ?? this.matchingMyTrips,
    );
  }
}
