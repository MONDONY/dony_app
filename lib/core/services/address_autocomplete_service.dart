import 'package:dio/dio.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/address_suggestion.dart';

class AddressAutocompleteService {
  AddressAutocompleteService({required Dio dio}) : _dio = dio;

  final Dio _dio;
  final _cache = <String, List<AddressSuggestion>>{};

  /// Step 1 of the 2-step selection flow.
  /// [sessionToken] is managed by [_AddressPickerFieldState] — same UUID across
  /// all keystrokes until resolvePlace() or cancel resets it.
  Future<List<AddressSuggestion>> search(
    String query,
    String sessionToken, {
    double? lat,
    double? lng,
  }) async {
    final key = '${query.toLowerCase().trim()}:$sessionToken';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final body = <String, dynamic>{
      'query': query,
      'sessionToken': sessionToken,
      if (lat != null && lng != null) 'lat': lat,
      if (lat != null && lng != null) 'lng': lng,
    };

    final response = await _dio.post<dynamic>(
      '/addresses/autocomplete',
      data: body,
    );

    final suggestions = ((response.data as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AddressSuggestion.fromJson)
        .toList();

    if (_cache.length >= 5) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = suggestions;
    return suggestions;
  }

  /// Step 2 — closes the Google session; billed as 1 session with all
  /// preceding autocomplete calls sharing the same [sessionToken].
  ///
  /// [placeName] : nom de la suggestion touchée (`mainText`). Le back renvoie
  /// l'adresse postale de Google (`formattedAddress`), qui pour un lieu
  /// nommé (aéroport, gare, commerce) ne contient pas son nom : sans lui,
  /// « Aéroport International de Douala » s'affichait « Douala, Cameroun »
  /// (FLUTTER-4F). Le nom n'est pas redemandé à Google (champ facturé).
  Future<AddressData> resolvePlace(
    String placeId,
    String sessionToken, {
    String? placeName,
  }) async {
    final response = await _dio.post<dynamic>(
      '/addresses/details',
      data: {'placeId': placeId, 'sessionToken': sessionToken},
    );
    final raw = response.data;
    if (raw is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Invalid response for resolvePlace',
      );
    }
    return AddressData(
      label: labelWithPlaceName(placeName, raw['label'] as String),
      lat: (raw['lat'] as num).toDouble(),
      lng: (raw['lng'] as num).toDouble(),
      street: raw['street'] as String?,
      city: raw['city'] as String?,
      postalCode: raw['postalCode'] as String?,
      country: raw['country'] as String?,
    );
  }

  /// GPS reverse geocoding via backend proxy.
  /// Returns null if the backend returns 404 (no result at coordinates).
  Future<AddressData?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.post<dynamic>(
        '/addresses/reverse',
        data: {'lat': lat, 'lng': lng},
      );
      final data = response.data as Map<String, dynamic>;
      return AddressData(
        label: data['label'] as String,
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}

/// Libellé d'un lieu résolu : son nom en tête, sauf si l'adresse le contient
/// déjà (adresse de rue, où `mainText` est « 12 rue X » et l'adresse commence
/// par lui).
String labelWithPlaceName(String? placeName, String address) {
  final name = placeName?.trim() ?? '';
  if (name.isEmpty) return address;
  if (address.toLowerCase().contains(name.toLowerCase())) return address;
  return '$name, $address';
}
