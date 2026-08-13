import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/matching/presentation/widgets/map_camera_math.dart';
import 'package:dony/features/matching/presentation/widgets/map_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Sélecteur de « zone de remise » : carte avec un centre déplaçable + un cercle,
/// et un slider de rayon. Émet `(lat, lng, radiusKm, label)` à chaque changement
/// via [onChanged].
///
/// Le centre se déplace par tap sur la carte ou par drag du marqueur. Le label
/// (nom de lieu) est résolu par reverse-geocoding (best-effort, débouncé).
class ZonePickerField extends StatefulWidget {
  const ZonePickerField({
    super.key,
    this.initialCenter,
    this.initialRadiusKm = 25,
    this.initialLabel,
    required this.onChanged,
    Future<String?> Function(double lat, double lng)? reverseGeocode,
  }) : reverseGeocode = reverseGeocode ?? _defaultReverseGeocode;

  /// Centre initial (ex. ville de départ). À défaut → [_fallbackCenter].
  final LatLng? initialCenter;
  final int initialRadiusKm;
  final String? initialLabel;

  /// Appelé à chaque changement de centre / rayon / label.
  final void Function(double lat, double lng, int radiusKm, String? label)
  onChanged;

  /// Injectable pour les tests (par défaut : `geocoding`).
  final Future<String?> Function(double lat, double lng) reverseGeocode;

  static const int minRadiusKm = 5;
  static const int maxRadiusKm = 300;
  static const LatLng _fallbackCenter = LatLng(48.8566, 2.3522); // Paris

  static Future<String?> _defaultReverseGeocode(double lat, double lng) async {
    try {
      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isEmpty) return null;
      final p = places.first;
      final city = p.locality;
      if (city != null && city.isNotEmpty) return city;
      final area = p.subAdministrativeArea;
      return (area != null && area.isNotEmpty) ? area : null;
    } catch (_) {
      return null;
    }
  }

  @override
  State<ZonePickerField> createState() => _ZonePickerFieldState();
}

class _ZonePickerFieldState extends State<ZonePickerField> {
  late LatLng _center;
  late int _radiusKm;
  String? _label;
  GoogleMapController? _map;
  Timer? _geocodeDebounce;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter ?? ZonePickerField._fallbackCenter;
    _radiusKm = widget.initialRadiusKm.clamp(
      ZonePickerField.minRadiusKm,
      ZonePickerField.maxRadiusKm,
    );
    _label = widget.initialLabel;
    // Émet la zone initiale dès l'ouverture pour que le cubit la connaisse.
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
    if (_label == null) _scheduleGeocode();
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _map?.dispose();
    super.dispose();
  }

  void _emit() =>
      widget.onChanged(_center.latitude, _center.longitude, _radiusKm, _label);

  void _setCenter(LatLng c) {
    setState(() => _center = c);
    _emit();
    _scheduleGeocode();
    _fitCamera();
  }

  /// Recentre avec un label connu (ex. ville choisie) — pas de reverse-geocoding.
  void _setCenterWithLabel(LatLng c, String label) {
    _geocodeDebounce?.cancel();
    setState(() {
      _center = c;
      _label = label;
    });
    _emit();
    _fitCamera();
  }

  void _setRadius(int km) {
    setState(() => _radiusKm = km);
    _emit();
    _fitCamera();
  }

  void _scheduleGeocode() {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 500), () async {
      final label = await widget.reverseGeocode(
        _center.latitude,
        _center.longitude,
      );
      if (!mounted || label == null) return;
      setState(() => _label = label);
      _emit();
    });
  }

  Future<void> _fitCamera() async {
    final map = _map;
    if (map == null) return;
    try {
      await map.animateCamera(
        CameraUpdate.newLatLngBounds(
          boundsAround(_center, _radiusKm * 1.4),
          40,
        ),
      );
    } catch (_) {
      // Bounds peut échouer avant le layout — sans gravité (zoom initial gardé).
    }
  }

  Future<void> _useMyLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _setCenter(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      // best-effort
    }
  }

  double _zoomForRadius(int km) {
    if (km <= 10) return 11;
    if (km <= 30) return 10;
    if (km <= 80) return 8.5;
    if (km <= 150) return 7.5;
    return 6.5;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Définir le centre sans ambiguïté : par ville OU par position GPS.
        BlocProvider(
          create: (_) => getIt<CitySearchBloc>(),
          child: CityAutocompleteField(
            label: 'Centrer la zone sur une ville',
            fieldKey: const Key('zone-city-field'),
            prefixIcon: const Icon(Icons.place_outlined),
            onSelected: (CityModel c) =>
                _setCenterWithLabel(LatLng(c.lat, c.lng), c.name),
          ),
        ),
        const SizedBox(height: DonySpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('zone-locate-me'),
            onPressed: _useMyLocation,
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('Utiliser ma position'),
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(DonyRadius.card),
          child: SizedBox(
            height: 190,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: _zoomForRadius(_radiusKm),
              ),
              style: resolveMapStyle(Theme.of(context).brightness),
              onMapCreated: (c) {
                _map = c;
                _fitCamera();
              },
              onTap: _setCenter,
              markers: {
                Marker(
                  markerId: const MarkerId('zone-center'),
                  position: _center,
                  draggable: true,
                  onDragEnd: _setCenter,
                ),
              },
              circles: {
                Circle(
                  circleId: const CircleId('zone-radius'),
                  center: _center,
                  radius: _radiusKm * 1000.0,
                  strokeColor: cs.primary,
                  strokeWidth: 2,
                  fillColor: cs.primary.withValues(alpha: 0.13),
                ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Row(
          children: [
            DonyIcon('map-pin', size: 16, color: cs.primary),
            const SizedBox(width: DonySpacing.xs),
            Expanded(
              child: Text(
                _label ?? 'Point de remise sélectionné',
                key: const Key('zone-label'),
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              'Rayon',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const Spacer(),
            Text(
              '$_radiusKm km',
              key: const Key('zone-radius-label'),
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          key: const Key('zone-radius-slider'),
          value: _radiusKm.toDouble(),
          min: ZonePickerField.minRadiusKm.toDouble(),
          max: ZonePickerField.maxRadiusKm.toDouble(),
          activeColor: cs.primary,
          onChanged: (v) => _setRadius(v.round()),
        ),
      ],
    );
  }
}
