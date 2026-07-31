import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/core/services/recent_addresses_store.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_bloc.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_event.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_state.dart';
import 'package:dony/features/delivery_addresses/data/models/delivery_address.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/address_suggestion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class DeliveryAddressPickerSheet extends StatefulWidget {
  const DeliveryAddressPickerSheet({super.key, this.current});

  final AddressData? current;

  static Future<AddressData?> show(
    BuildContext context, {
    AddressData? current,
  }) {
    return showModalBottomSheet<AddressData>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) =>
            getIt<DeliveryAddressBloc>()..add(const DeliveryAddressLoaded()),
        child: DeliveryAddressPickerSheet(current: current),
      ),
    );
  }

  @override
  State<DeliveryAddressPickerSheet> createState() =>
      _DeliveryAddressPickerSheetState();
}

class _DeliveryAddressPickerSheetState
    extends State<DeliveryAddressPickerSheet> {
  String? _selectedId;

  // ── Recherche inline ───────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _service = getIt<AddressAutocompleteService>();
  final _recents = RecentAddressesStore(
    getIt<HiveService>(),
    'recent_delivery_addresses',
  );
  Timer? _debounce;
  List<AddressSuggestion> _suggestions = [];
  bool _searching = false;
  bool _resolving = false;
  bool _offline = false;
  bool _error = false;
  String _lastQuery = '';
  String? _sessionToken;
  DateTime? _sessionTokenAt;

  bool get _isSearchMode => _searchCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _getOrCreateToken() {
    final now = DateTime.now();
    if (_sessionToken == null ||
        _sessionTokenAt == null ||
        now.difference(_sessionTokenAt!) > const Duration(minutes: 3)) {
      _sessionToken = const Uuid().v4();
      _sessionTokenAt = now;
    }
    return _sessionToken!;
  }

  void _onSearchChanged() {
    final text = _searchCtrl.text;
    if (text == _lastQuery) return;
    _lastQuery = text;
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      _sessionToken = null;
      _sessionTokenAt = null;
      setState(() {
        _suggestions = [];
        _offline = false;
        _error = false;
        _searching = false;
      });
      return;
    }
    setState(() {}); // bascule en mode recherche
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetch(text));
  }

  // La connectivité réelle est la seule chose qui doit déclencher l'état
  // « Connexion requise » : une erreur backend (401, 500, timeout) sur un
  // device bien connecté n'est pas un problème réseau.
  Future<bool> _isOffline() async {
    final results = await Connectivity().checkConnectivity();
    return results.every((r) => r == ConnectivityResult.none);
  }

  Future<void> _fetch(String query) async {
    if (!mounted) return;
    setState(() {
      _searching = true;
      _offline = false;
      _error = false;
    });
    try {
      final token = _getOrCreateToken();
      final results = await _service.search(query, token);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    } catch (_) {
      final offline = await _isOffline();
      if (!mounted) return;
      setState(() {
        _searching = false;
        _offline = offline;
        _error = !offline;
        _suggestions = [];
      });
    }
  }

  Future<void> _selectSuggestion(AddressSuggestion s) async {
    setState(() => _resolving = true);
    try {
      final token = _sessionToken ?? _getOrCreateToken();
      final addr = await _service.resolvePlace(s.placeId, token);
      _sessionToken = null;
      _sessionTokenAt = null;
      unawaited(_recents.add(addr));
      if (!mounted) return;
      Navigator.of(context).pop(addr);
    } catch (_) {
      _sessionToken = null;
      _sessionTokenAt = null;
      if (!mounted) return;
      setState(() => _resolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de sélectionner cette adresse. Réessayez.'),
        ),
      );
    }
  }

  Future<void> _onGps() async {
    // Service localisation coupé → sheet d'info immédiat (pas de hang).
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      _showInfoSheet(gpsDisabled: true);
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      _showInfoSheet(permanent: permission == LocationPermission.deniedForever);
      return;
    }
    setState(() => _resolving = true);
    // [timeLimit] borne l'attente : sans fix GPS (ex: simulateur sans
    // position) getCurrentPosition ne renvoie jamais → chargement infini.
    // En cas d'échec/timeout on retombe sur la dernière position connue.
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    }
    if (pos == null) {
      if (!mounted) return;
      setState(() => _resolving = false);
      // Le GPS est bien actif (vérifié plus haut) — c'est juste qu'aucun fix
      // n'est encore disponible, distinct d'un GPS désactivé.
      _showInfoSheet(positionUnavailable: true);
      return;
    }
    final position = pos;
    // 3 tentatives avant d'abandonner : un rate-limit ou un raté réseau
    // ponctuel ne doit jamais se traduire par des coordonnées brutes à la
    // place de la vraie adresse — seul un vrai 404 Google (reverseGeocode
    // renvoie null sans exception) justifie ce repli.
    AddressData? addr;
    var failed = false;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        addr = await _service
            .reverseGeocode(position.latitude, position.longitude)
            .timeout(const Duration(seconds: 12));
        failed = false;
        break;
      } catch (_) {
        failed = true;
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
    }
    if (!mounted) return;
    if (failed) {
      setState(() => _resolving = false);
      _showInfoSheet(reverseGeocodeFailed: true);
      return;
    }
    if (addr != null) {
      unawaited(_recents.add(addr));
    }
    Navigator.of(context).pop(
      addr ??
          AddressData(
            label:
                'Position GPS (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})',
            lat: position.latitude,
            lng: position.longitude,
          ),
    );
  }

  void _showInfoSheet({
    bool permanent = false,
    bool gpsDisabled = false,
    bool positionUnavailable = false,
    bool reverseGeocodeFailed = false,
  }) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.lg,
          DonySpacing.lg,
          MediaQuery.of(ctx).padding.bottom + DonySpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.warningLight,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: DonyIcon('map-pin-off', color: cs.warning),
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              gpsDisabled
                  ? 'GPS désactivé'
                  : positionUnavailable
                  ? 'Position indisponible'
                  : reverseGeocodeFailed
                  ? 'Adresse introuvable'
                  : permanent
                  ? 'Localisation définitivement refusée'
                  : 'Localisation refusée',
              style: tt.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              gpsDisabled
                  ? 'Activez la géolocalisation dans vos paramètres système.'
                  : positionUnavailable
                  ? 'Impossible de récupérer votre position pour le moment. Réessayez.'
                  : reverseGeocodeFailed
                  ? 'Impossible de convertir votre position en adresse. Réessayez.'
                  : 'Activez la localisation dans vos paramètres pour utiliser cette fonctionnalité.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (positionUnavailable || reverseGeocodeFailed) {
                    _onGps();
                  } else {
                    Geolocator.openAppSettings();
                  }
                },
                child: Text(
                  positionUnavailable || reverseGeocodeFailed
                      ? 'Réessayer'
                      : 'Ouvrir les paramètres',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelOf(DeliveryAddress a) =>
      [a.label, if (a.street != null) a.street!, a.city].join(', ');

  bool _isSelected(DeliveryAddress a) {
    if (_selectedId != null) return _selectedId == a.id;
    final current = widget.current;
    if (current != null) return _labelOf(a) == current.label;
    return a.isDefault;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DonyRadius.sheet),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: BlocBuilder<DeliveryAddressBloc, DeliveryAddressState>(
              builder: (context, state) {
                return Column(
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.lg,
                        vertical: DonySpacing.md,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '🗺️  Adresse de livraison',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Fermer',
                            icon: const DonyIcon('x'),
                            onPressed: () => Navigator.of(context).pop(),
                            style: IconButton.styleFrom(
                              backgroundColor: cs.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Champ de recherche (toujours visible) ─────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DonySpacing.lg,
                        0,
                        DonySpacing.lg,
                        DonySpacing.md,
                      ),
                      child: _SearchField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        loading: _searching || _resolving,
                      ),
                    ),
                    const Divider(height: 1),
                    // ── Corps ─────────────────────────────────────────────
                    Expanded(
                      child: _isSearchMode
                          ? _buildSuggestions(scrollController, cs, tt)
                          : _buildDefault(scrollController, state, cs, tt),
                    ),
                    // ── Bouton confirmer (hors mode recherche) ────────────
                    if (!_isSearchMode)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            DonySpacing.lg,
                            DonySpacing.sm,
                            DonySpacing.lg,
                            DonySpacing.md,
                          ),
                          child: DonyButton(
                            label: 'Confirmer cette adresse',
                            onPressed: state.addresses.isEmpty
                                ? null
                                : () {
                                    final address = state.addresses.firstWhere(
                                      _isSelected,
                                      orElse: () => state.addresses.first,
                                    );
                                    Navigator.of(context).pop(
                                      AddressData(
                                        label: _labelOf(address),
                                        lat: address.latitude ?? 0.0,
                                        lng: address.longitude ?? 0.0,
                                      ),
                                    );
                                  },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ── Liste des suggestions (mode recherche) ──────────────────────────────
  Widget _buildSuggestions(
    ScrollController controller,
    ColorScheme cs,
    TextTheme tt,
  ) {
    if (_searching && _suggestions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_offline) {
      return _EmptyState(
        icon: 'wifi-off',
        color: cs.warning,
        title: 'Connexion requise',
        subtitle: 'Vérifiez votre connexion pour rechercher une adresse.',
      );
    }
    if (_error) {
      return _EmptyState(
        icon: 'circle-alert',
        color: cs.error,
        title: 'Erreur',
        subtitle: 'Impossible de rechercher une adresse. Réessayez.',
      );
    }
    if (_suggestions.isEmpty) {
      return _EmptyState(
        icon: 'map-pin-off',
        color: cs.onSurfaceVariant,
        title: 'Aucun résultat',
        subtitle: 'Essayez « Utiliser ma position actuelle ».',
        action: _GpsTile(onTap: _onGps),
      );
    }
    return ListView.separated(
      controller: controller,
      padding: EdgeInsets.only(
        top: DonySpacing.sm,
        bottom: MediaQuery.paddingOf(context).bottom + DonySpacing.lg,
      ),
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 64, endIndent: 20),
      itemBuilder: (_, i) {
        final s = _suggestions[i];
        return ListTile(
          onTap: _resolving ? null : () => _selectSuggestion(s),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: DonyIcon('map-pin', size: 18, color: cs.secondary),
          ),
          title: Text(
            s.mainText,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: s.secondaryText.isEmpty
              ? null
              : Text(
                  s.secondaryText,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: DonyIcon('chevron-right', color: cs.onSurfaceVariant),
        );
      },
    );
  }

  // ── Vue par défaut (adresses + GPS + ajouter) ───────────────────────────
  Widget _buildDefault(
    ScrollController controller,
    DeliveryAddressState state,
    ColorScheme cs,
    TextTheme tt,
  ) {
    if (state.status == DeliveryAddressStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final recents = _recents.getAll();
    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      children: [
        // GPS — accès rapide tout en haut
        _GpsTile(onTap: _onGps),
        const Divider(indent: 20, endIndent: 20, height: 1),
        if (recents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.md,
              DonySpacing.lg,
              4,
            ),
            child: Text(
              'RECHERCHES RÉCENTES',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.08,
              ),
            ),
          ),
          ...recents.map(
            (address) => _RecentAddressRow(
              address: address,
              color: cs.secondary,
              onTap: () => Navigator.of(context).pop(address),
            ),
          ),
          const Divider(indent: 20, endIndent: 20),
        ],
        if (state.addresses.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.md,
              DonySpacing.lg,
              4,
            ),
            child: Text(
              'MES ADRESSES ENREGISTRÉES',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.08,
              ),
            ),
          ),
          ...state.addresses.map((address) {
            return _DeliveryAddressRow(
              address: address,
              isSelected: _isSelected(address),
              activeColor: cs.secondary,
              onTap: () => setState(() => _selectedId = address.id),
            );
          }),
          const Divider(indent: 20, endIndent: 20),
        ],
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: const DonyIcon('plus'),
          ),
          title: Text(
            'Ajouter une adresse',
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Enregistrer pour la prochaine fois',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          onTap: () async {
            Navigator.of(context).pop();
            // ignore: use_build_context_synchronously
            await context.push<bool>('/profile/addresses/delivery/new');
          },
        ),
      ],
    );
  }
}

// ── Champ de recherche ────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.loading,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Rechercher une adresse…',
        hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(
            left: DonySpacing.md,
            right: DonySpacing.sm,
          ),
          child: DonyIcon('search', size: 18, color: cs.onSurfaceVariant),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: loading
            ? Padding(
                padding: const EdgeInsets.all(DonySpacing.md),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.secondary,
                  ),
                ),
              )
            : controller.text.isNotEmpty
            ? IconButton(
                tooltip: 'Fermer',
                icon: const DonyIcon('x', size: 16),
                onPressed: () => controller.clear(),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.secondary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
      ),
    );
  }
}

// ── Tuile « position actuelle » ───────────────────────────────────────────
class _GpsTile extends StatelessWidget {
  const _GpsTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
        child: DonyIcon('locate-fixed', size: 18, color: cs.secondary),
      ),
      title: Text(
        'Utiliser ma position actuelle',
        style: tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.secondary,
        ),
      ),
    );
  }
}

// ── État vide / erreur ─────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon(icon, size: 40, color: color),
            const SizedBox(height: DonySpacing.md),
            Text(
              title,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              subtitle,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: DonySpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── Ligne « adresse récente » (cache local, aucun appel API) ───────────────
class _RecentAddressRow extends StatelessWidget {
  const _RecentAddressRow({
    required this.address,
    required this.color,
    required this.onTap,
  });

  final AddressData address;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final subtitle = [
      address.street,
      address.postalCode,
      address.city,
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
        child: DonyIcon('history', size: 18, color: color),
      ),
      title: Text(
        address.label,
        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

class _DeliveryAddressRow extends StatelessWidget {
  const _DeliveryAddressRow({
    required this.address,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final DeliveryAddress address;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      tileColor: isSelected ? activeColor.withValues(alpha: 0.05) : null,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
        child: DonyIcon(
          'house',
          color: isSelected ? activeColor : cs.onSurfaceVariant,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              address.label,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (address.isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'Par défaut',
                style: tt.labelSmall?.copyWith(
                  color: activeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        [
          if (address.street != null && address.street!.isNotEmpty)
            address.street!,
          address.city,
          address.country,
        ].join(', '),
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? activeColor : Colors.transparent,
          border: Border.all(
            color: isSelected ? activeColor : cs.outline,
            width: 2,
          ),
        ),
        child: isSelected
            ? const DonyIcon('check', color: Colors.white, size: 12)
            : null,
      ),
    );
  }
}
