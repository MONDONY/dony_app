import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Plateau Google Maps de test : la carte native n'existe pas sous
/// `flutter test`. Ce faux garde les canaux d'événements de l'implémentation
/// par défaut, remplace tout ce qui parle à la plateforme par des relevés, et
/// permet de piloter la région visible et l'événement « caméra immobile ».
class FakeGoogleMapsPlatform extends MethodChannelGoogleMapsFlutter {
  /// Région renvoyée par `getVisibleRegion`.
  LatLngBounds visibleRegion = LatLngBounds(
    southwest: const LatLng(-80, -170),
    northeast: const LatLng(80, 170),
  );

  /// Déplacements de caméra demandés par l'app, dans l'ordre.
  final List<CameraUpdate> cameraUpdates = [];

  final _idle = StreamController<CameraIdleEvent>.broadcast();
  final _created = <int>{};

  /// Simule la fin d'un mouvement de caméra de toutes les cartes créées (le
  /// compteur d'identifiants du plugin est global : la carte d'un test n'a pas
  /// toujours l'identifiant 0).
  void emitCameraIdle() {
    for (final id in _created) {
      _idle.add(CameraIdleEvent(id));
    }
  }

  /// L'implémentation par défaut attend la vue native via un canal : sans
  /// elle, la carte ne signalerait jamais sa création.
  @override
  Future<void> init(int mapId) async {}

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) =>
      _idle.stream.where((e) => e.mapId == mapId);

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    // `build` repasse à chaque reconstruction : la vue n'est créée qu'une fois.
    if (_created.add(creationId)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onPlatformViewCreated(creationId),
      );
    }
    return const SizedBox.expand(key: Key('fake-google-map'));
  }

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration configuration, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateMarkers(
    MarkerUpdates markerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateCircles(
    CircleUpdates circleUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolygons(
    PolygonUpdates polygonUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolylines(
    PolylineUpdates polylineUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {}

  @override
  Future<void> updateClusterManagers(
    ClusterManagerUpdates clusterManagerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateHeatmaps(
    HeatmapUpdates heatmapUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates groundOverlayUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async => cameraUpdates.add(cameraUpdate);

  @override
  Future<void> moveCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async => cameraUpdates.add(cameraUpdate);

  @override
  Future<LatLngBounds> getVisibleRegion({required int mapId}) async =>
      visibleRegion;

  @override
  void dispose({required int mapId}) {}
}
