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
import 'package:dony/features/matching/presentation/address_labels.dart';
import 'package:dony/features/matching/presentation/widgets/address_picker_empty_state.dart';
import 'package:dony/l10n/l10n.dart';
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
  // Sélection issue de la recherche, du GPS ou d'une adresse récente : ne
  // ferme jamais le sheet toute seule, seul le bouton « Confirmer » le fait.
  AddressData? _selectedAdHoc;

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

  // true seulement pendant une recherche active par l'utilisateur — pas
  // simplement parce que le champ contient du texte (il affiche aussi le
  // label de l'adresse sélectionnée, hors recherche).
  bool _isSearchMode = false;
  // Empêche _onSearchChanged de réagir quand on remplit le champ par code
  // (sélection) au lieu d'une saisie utilisateur.
  bool _suppressSearchListener = false;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    if (current != null) {
      _searchCtrl.text = current.label;
      _lastQuery = current.label;
    }
    _searchCtrl.addListener(_onSearchChanged);
  }

  // Affiche `label` dans le champ (sélection courante) sans déclencher de
  // nouvelle recherche ni repasser en mode recherche.
  void _setDisplayedLabel(String label) {
    _suppressSearchListener = true;
    _searchCtrl.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );
    _lastQuery = label;
    _suppressSearchListener = false;
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
    if (_suppressSearchListener) return;
    final text = _searchCtrl.text;
    if (text == _lastQuery) return;
    _lastQuery = text;
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      _sessionToken = null;
      _sessionTokenAt = null;
      setState(() {
        _isSearchMode = false;
        _suggestions = [];
        _offline = false;
        _error = false;
        _searching = false;
      });
      return;
    }
    setState(() => _isSearchMode = true);
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
      await _recents.add(addr);
      if (!mounted) return;
      // Pré-sélection uniquement : le sheet reste ouvert, seul le bouton
      // « Confirmer cette adresse » referme et renvoie le résultat. Le champ
      // garde le label choisi au lieu de se vider.
      _setDisplayedLabel(addr.label);
      setState(() {
        _selectedAdHoc = addr;
        _selectedId = null;
        _resolving = false;
        _isSearchMode = false;
        _suggestions = [];
        _offline = false;
        _error = false;
      });
    } catch (_) {
      _sessionToken = null;
      _sessionTokenAt = null;
      if (!mounted) return;
      setState(() => _resolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.addressSelectFailedMessage)),
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
      await _recents.add(addr);
    }
    if (!mounted) return;
    final resolved =
        addr ??
        AddressData(
          label: gpsPositionLabel(
            context.l10n,
            position.latitude,
            position.longitude,
          ),
          lat: position.latitude,
          lng: position.longitude,
        );
    // Pré-sélection uniquement : le sheet reste ouvert, seul le bouton
    // « Confirmer cette adresse » referme et renvoie le résultat. Le champ
    // affiche le label obtenu.
    _setDisplayedLabel(resolved.label);
    setState(() {
      _selectedAdHoc = resolved;
      _selectedId = null;
      _resolving = false;
    });
  }

  void _showInfoSheet({
    bool permanent = false,
    bool gpsDisabled = false,
    bool positionUnavailable = false,
    bool reverseGeocodeFailed = false,
  }) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
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
                  ? l10n.addressGpsDisabledTitle
                  : positionUnavailable
                  ? l10n.addressPositionUnavailableTitle
                  : reverseGeocodeFailed
                  ? l10n.addressReverseGeocodeFailedTitle
                  : permanent
                  ? l10n.addressLocationDeniedForeverTitle
                  : l10n.addressLocationDeniedTitle,
              style: tt.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              gpsDisabled
                  ? l10n.addressGpsDisabledMessage
                  : positionUnavailable
                  ? l10n.addressPositionUnavailableMessage
                  : reverseGeocodeFailed
                  ? l10n.addressReverseGeocodeFailedMessage
                  : l10n.addressLocationDeniedMessage,
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
                      ? l10n.commonRetry
                      : l10n.addressOpenSettingsButton,
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

  // La sélection à l'écran (recherche/GPS/récente/enregistrée choisie
  // explicitement) prime sur widget.current. Tant que rien n'a été retapé
  // dans ce sheet, widget.current (l'adresse déjà confirmée avant réouverture)
  // fait foi — y compris quand ce n'était pas une adresse enregistrée, pour
  // que l'utilisateur voie ce qu'il avait choisi et ne se retrompe pas.
  AddressData? _resolveEffectiveAdHoc(DeliveryAddressState state) {
    if (_selectedAdHoc != null) return _selectedAdHoc;
    if (_selectedId != null) return null;
    final current = widget.current;
    if (current == null) return null;
    final matchesSaved = state.addresses.any(
      (a) => _labelOf(a) == current.label,
    );
    return matchesSaved ? null : current;
  }

  bool _isSelected(DeliveryAddress a, AddressData? effectiveAdHoc) {
    // Une sélection recherche/GPS/récente prime : aucune adresse enregistrée
    // ne doit apparaître cochée en même temps.
    if (effectiveAdHoc != null) return false;
    if (_selectedId != null) return _selectedId == a.id;
    final current = widget.current;
    if (current != null) return _labelOf(a) == current.label;
    return a.isDefault;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
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
                final effectiveAdHoc = _resolveEffectiveAdHoc(state);
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
                          Expanded(
                            child: Text(
                              l10n.addressDeliverySheetTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.commonClose,
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
                          : _buildDefault(
                              scrollController,
                              state,
                              cs,
                              tt,
                              effectiveAdHoc,
                            ),
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
                            label: l10n.addressConfirmButton,
                            onPressed:
                                (effectiveAdHoc == null &&
                                    state.addresses.isEmpty)
                                ? null
                                : () {
                                    if (effectiveAdHoc != null) {
                                      Navigator.of(context).pop(effectiveAdHoc);
                                      return;
                                    }
                                    final address = state.addresses.firstWhere(
                                      (a) => _isSelected(a, effectiveAdHoc),
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
    final l10n = context.l10n;
    if (_offline) {
      return AddressPickerEmptyState(
        icon: 'wifi-off',
        color: cs.warning,
        title: l10n.addressOfflineTitle,
        subtitle: l10n.addressOfflineSubtitle,
      );
    }
    if (_error) {
      return AddressPickerEmptyState(
        icon: 'circle-alert',
        color: cs.error,
        title: l10n.addressSearchErrorTitle,
        subtitle: l10n.addressSearchErrorSubtitle,
      );
    }
    if (_suggestions.isEmpty) {
      return AddressPickerEmptyState(
        icon: 'map-pin-off',
        color: cs.onSurfaceVariant,
        title: l10n.addressNoResultsTitle,
        subtitle: l10n.addressNoResultsSubtitle,
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
    AddressData? effectiveAdHoc,
  ) {
    if (state.status == DeliveryAddressStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final l10n = context.l10n;
    final recents = _recents.getAll();
    // Sélection sans correspondance (position GPS brute, ou adresse récente
    // évincée du cache 3 places) : ni enregistrée ni dans les récentes, il
    // lui faut son propre aperçu pour rester visible et éviter de se retromper.
    final adHocNotInList =
        effectiveAdHoc != null && !recents.contains(effectiveAdHoc);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      children: [
        // GPS — accès rapide tout en haut
        _GpsTile(onTap: _onGps),
        const Divider(indent: 20, endIndent: 20, height: 1),
        if (adHocNotInList) ...[
          _RecentAddressRow(
            address: effectiveAdHoc,
            color: cs.secondary,
            icon: isGpsPositionLabel(effectiveAdHoc.label)
                ? 'locate-fixed'
                : 'map-pin',
            selected: true,
            onTap: () {},
          ),
          const Divider(indent: 20, endIndent: 20),
        ],
        if (recents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.md,
              DonySpacing.lg,
              4,
            ),
            child: Text(
              l10n.addressRecentSearchesHeader,
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
              selected: address == effectiveAdHoc,
              onTap: () {
                _setDisplayedLabel(address.label);
                setState(() {
                  _selectedAdHoc = address;
                  _selectedId = null;
                });
              },
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
              l10n.addressSavedAddressesHeader,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.08,
              ),
            ),
          ),
          ...state.addresses.map((address) {
            return _DeliveryAddressRow(
              address: address,
              isSelected: _isSelected(address, effectiveAdHoc),
              activeColor: cs.secondary,
              onTap: () {
                _setDisplayedLabel(_labelOf(address));
                setState(() {
                  _selectedId = address.id;
                  _selectedAdHoc = null;
                });
              },
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
            l10n.addressAddNewTitle,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            l10n.addressAddNewSubtitle,
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
    final l10n = context.l10n;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l10n.addressSearchHint,
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
                tooltip: l10n.commonClose,
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
        context.l10n.addressUseCurrentLocation,
        style: tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.secondary,
        ),
      ),
    );
  }
}

// ── État vide / erreur ─────────────────────────────────────────────────────
// ── Ligne « adresse récente » (cache local, aucun appel API) ───────────────
class _RecentAddressRow extends StatelessWidget {
  const _RecentAddressRow({
    required this.address,
    required this.color,
    required this.onTap,
    this.icon = 'history',
    this.selected = false,
  });

  final AddressData address;
  final Color color;
  final VoidCallback onTap;
  final String icon;
  final bool selected;

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
      tileColor: selected ? color.withValues(alpha: 0.05) : null,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
        child: DonyIcon(icon, size: 18, color: color),
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
      trailing: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color : Colors.transparent,
          border: Border.all(color: selected ? color : cs.outline, width: 2),
        ),
        child: selected
            ? const DonyIcon('check', color: Colors.white, size: 12)
            : null,
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
                context.l10n.addressDefaultBadge,
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
