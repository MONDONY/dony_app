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
    if (_cache.containsKey(key)) return _cache[key]!;

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

    if (_cache.length >= 5) _cache.remove(_cache.keys.first);
    _cache[key] = suggestions;
    return suggestions;
  }

  /// Step 2 — closes the Google session; billed as 1 session with all
  /// preceding autocomplete calls sharing the same [sessionToken].
  Future<AddressData> resolvePlace(String placeId, String sessionToken) async {
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
      label: raw['label'] as String,
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
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
