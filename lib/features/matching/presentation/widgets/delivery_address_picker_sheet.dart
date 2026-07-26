import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
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

  static Future<AddressData?> show(BuildContext context,
      {AddressData? current}) {
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
  Timer? _debounce;
  List<AddressSuggestion> _suggestions = [];
  bool _searching = false;
  bool _resolving = false;
  bool _offline = false;
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
        _searching = false;
      });
      return;
    }
    setState(() {}); // bascule en mode recherche
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetch(text));
  }

  Future<void> _fetch(String query) async {
    if (!mounted) return;
    setState(() {
      _searching = true;
      _offline = false;
    });
    try {
      final token = _getOrCreateToken();
      final results = await _service.search(query, token);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    } on DioException {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _offline = true;
        _suggestions = [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _offline = true;
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
      if (!mounted) return;
      Navigator.of(context).pop(addr);
    } catch (_) {
      _sessionToken = null;
      _sessionTokenAt = null;
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _offline = true;
      });
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
      _showInfoSheet(
          permanent: permission == LocationPermission.deniedForever);
      return;
    }
    setState(() => _resolving = true);
    try {
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
        _showInfoSheet(gpsDisabled: true);
        return;
      }
      final position = pos;
      final addr = await _service
          .reverseGeocode(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      Navigator.of(context).pop(addr ??
          AddressData(
            label:
                'Position GPS (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})',
            lat: position.latitude,
            lng: position.longitude,
          ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _resolving = false);
      _showInfoSheet(gpsDisabled: true);
    }
  }

  void _showInfoSheet({bool permanent = false, bool gpsDisabled = false}) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(DonySpacing.lg, DonySpacing.lg,
            DonySpacing.lg, MediaQuery.of(ctx).padding.bottom + DonySpacing.lg),
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
                  Geolocator.openAppSettings();
                },
                child: const Text('Ouvrir les paramètres'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelOf(DeliveryAddress a) => [
        a.label,
        if (a.street != null) a.street!,
        a.city,
      ].join(', ');

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
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DonyRadius.sheet)),
          ),
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
                        horizontal: DonySpacing.lg, vertical: DonySpacing.md),
                    child: Row(
                      children: [
                        Text('🗺️  Adresse de livraison',
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Fermer',
                          icon: const DonyIcon('x'),
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                              backgroundColor: cs.surfaceContainerHighest),
                        ),
                      ],
                    ),
                  ),
                  // ── Champ de recherche (toujours visible) ─────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        DonySpacing.lg, 0, DonySpacing.lg, DonySpacing.md),
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
                        padding: const EdgeInsets.fromLTRB(DonySpacing.lg,
                            DonySpacing.sm, DonySpacing.lg, DonySpacing.md),
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
        );
      },
    );
  }

  // ── Liste des suggestions (mode recherche) ──────────────────────────────
  Widget _buildSuggestions(
      ScrollController controller, ColorScheme cs, TextTheme tt) {
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
          bottom: MediaQuery.paddingOf(context).bottom + DonySpacing.lg),
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
          title: Text(s.mainText,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: s.secondaryText.isEmpty
              ? null
              : Text(s.secondaryText,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          trailing: DonyIcon('chevron-right', color: cs.onSurfaceVariant),
        );
      },
    );
  }

  // ── Vue par défaut (adresses + GPS + ajouter) ───────────────────────────
  Widget _buildDefault(ScrollController controller, DeliveryAddressState state,
      ColorScheme cs, TextTheme tt) {
    if (state.status == DeliveryAddressStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      children: [
        // GPS — accès rapide tout en haut
        _GpsTile(onTap: _onGps),
        const Divider(indent: 20, endIndent: 20, height: 1),
        if (state.addresses.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg, DonySpacing.md, DonySpacing.lg, 4),
            child: Text('MES ADRESSES ENREGISTRÉES',
                style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant, letterSpacing: 0.08)),
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
          title: Text('Ajouter une adresse',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text('Enregistrer pour la prochaine fois',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
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
              left: DonySpacing.md, right: DonySpacing.sm),
          child: DonyIcon('search', size: 18, color: cs.onSurfaceVariant),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40),
        suffixIcon: loading
            ? Padding(
                padding: const EdgeInsets.all(DonySpacing.md),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.secondary),
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
      title: Text('Utiliser ma position actuelle',
          style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600, color: cs.secondary)),
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
            Text(title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: DonySpacing.xs),
            Text(subtitle,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
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
        child: DonyIcon('house',
            color: isSelected ? activeColor : cs.onSurfaceVariant),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(address.label,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (address.isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('Par défaut',
                  style: tt.labelSmall?.copyWith(
                      color: activeColor, fontWeight: FontWeight.w600)),
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
          border:
              Border.all(color: isSelected ? activeColor : cs.outline, width: 2),
        ),
        child: isSelected
            ? const DonyIcon('check', color: Colors.white, size: 12)
            : null,
      ),
    );
  }
}
