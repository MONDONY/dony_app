import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/address_suggestion.dart';

class AddressPickerField extends FormField<AddressData> {
  AddressPickerField({
    super.key,
    required this.fieldLabel,
    required this.autocompleteService,
    this.showGpsButton = true,
    this.onChanged,
    this.prefixIconColor,
    bool isRequired = false,
    super.initialValue,
    super.onSaved,
    FormFieldValidator<AddressData>? validator,
    super.autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : super(
         validator:
             validator ??
             (isRequired
                 ? (v) => v == null ? 'Adresse obligatoire' : null
                 : null),
         builder: (_) => const SizedBox.shrink(),
       );

  final String fieldLabel;
  final AddressAutocompleteService autocompleteService;
  final bool showGpsButton;
  final void Function(AddressData?)? onChanged;

  /// Couleur sémantique de l'icône de préfixe à l'état neutre (non confirmé,
  /// non focalisé). Passer `colorScheme.primary` pour un champ « départ »,
  /// `colorScheme.secondary` pour un champ « arrivée ».
  ///
  /// `null` (défaut) → `cs.onSurfaceVariant` (comportement historique).
  final Color? prefixIconColor;

  @override
  FormFieldState<AddressData> createState() => _AddressPickerFieldState();
}

class _AddressPickerFieldState extends FormFieldState<AddressData> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  AddressData? _committed;
  List<AddressSuggestion> _suggestions = [];
  bool _loading = false;
  bool _resolvingPlace = false;
  bool _showFallback = false;
  bool _offline = false;
  Timer? _debounce;
  bool _suppressListener = false;

  // Tracks the last text value we acted on, to distinguish real keystrokes from
  // cursor/selection changes (which also fire the TextEditingController listener
  // but must NOT trigger a new autocomplete search).
  String _lastSearchedText = '';

  // Session token lifecycle: generated on first keystroke, reset after
  // resolvePlace() or when the field is cleared/disposed.
  // Regenerate after 3 min inactivity to avoid billing outside session discount.
  String? _sessionToken;
  DateTime? _sessionTokenCreatedAt;

  AddressPickerField get _w => widget as AddressPickerField;

  @override
  void initState() {
    super.initState();
    _committed = widget.initialValue;
    final initialText = widget.initialValue?.label ?? '';
    _ctrl = TextEditingController(text: initialText);
    _lastSearchedText = initialText;
    _focus = FocusNode()..addListener(_onFocusChange);
    _ctrl.addListener(_onCtrlChanged);
  }

  void _onCtrlChanged() {
    if (_suppressListener) return;
    final text = _ctrl.text;
    // TextEditingController fires for selection changes too (cursor repositioning
    // on focus restoration). Ignore if the text itself hasn't changed.
    if (text == _lastSearchedText) return;
    _lastSearchedText = text;
    _onTyped(text);
  }

  void _setCtrlText(String text) {
    _suppressListener = true;
    try {
      _ctrl.text = text;
      _lastSearchedText =
          text; // keep in sync so focus-restore doesn't re-search
    } finally {
      _suppressListener = false;
    }
  }

  String _getOrCreateSessionToken() {
    final now = DateTime.now();
    if (_sessionToken == null ||
        _sessionTokenCreatedAt == null ||
        now.difference(_sessionTokenCreatedAt!) > const Duration(minutes: 3)) {
      _sessionToken = const Uuid().v4();
      _sessionTokenCreatedAt = now;
    }
    return _sessionToken!;
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      _debounce?.cancel();
      _setCtrlText(_committed?.label ?? '');
      _removeOverlay();
      setState(() {
        _suggestions = [];
        _showFallback = false;
      });
    } else {
      setState(() {}); // rebuild for border/label color update
    }
  }

  void _onTyped(String val) {
    _debounce?.cancel();
    if (val.trim().isEmpty) {
      _removeOverlay();
      _sessionToken = null;
      _sessionTokenCreatedAt = null;
      setState(() {
        _suggestions = [];
        _showFallback = false;
        _offline = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetch(val));
  }

  Future<void> _fetch(String query) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _offline = false;
      _showFallback = false;
    });
    try {
      final token = _getOrCreateSessionToken();
      final results = await _w.autocompleteService.search(query, token);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _showFallback = results.isEmpty;
        _loading = false;
      });
      // Guard: if focus was lost while the HTTP request was in flight (e.g.
      // user opened the preview sheet before the response arrived), don't
      // re-show the overlay — _onFocusChange already cleaned up.
      if (_focus.hasFocus) {
        results.isNotEmpty ? _showOverlay() : _removeOverlay();
      } else {
        _removeOverlay();
      }
    } on DioException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = true;
      });
      _removeOverlay();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = true;
      });
      _removeOverlay();
    }
  }

  Future<void> _resolveAndSelect(AddressSuggestion suggestion) async {
    _removeOverlay();
    if (!mounted) return;
    setState(() => _resolvingPlace = true);
    try {
      final token = _sessionToken ?? _getOrCreateSessionToken();
      final addr = await _w.autocompleteService.resolvePlace(
        suggestion.placeId,
        token,
      );
      _sessionToken = null;
      _sessionTokenCreatedAt = null;
      if (!mounted) return;
      _select(addr);
    } catch (_) {
      _sessionToken = null;
      _sessionTokenCreatedAt = null;
      if (!mounted) return;
      setState(() {
        _resolvingPlace = false;
        _offline = true;
      });
    }
  }

  void _select(AddressData addr) {
    _committed = addr;
    _setCtrlText(addr.label);
    didChange(addr);
    _w.onChanged?.call(addr);
    setState(() {
      _suggestions = [];
      _showFallback = false;
      _resolvingPlace = false;
    });
  }

  Future<void> _onGps() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      _showSheet(
        _PermissionSheet(
          permanent: permission == LocationPermission.deniedForever,
        ),
      );
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final addr = await _w.autocompleteService.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      _select(
        addr ??
            AddressData(
              label:
                  'Position GPS (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})',
              lat: pos.latitude,
              lng: pos.longitude,
            ),
      );
    } catch (_) {
      if (!mounted) return;
      _showSheet(const _GpsDisabledSheet());
    }
  }

  void _showSheet(Widget sheet) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      builder: (_) => sheet,
    );
  }

  void _showOverlay() {
    _removeOverlay();
    _overlay = OverlayEntry(
      builder: (ctx) => CompositedTransformFollower(
        link: _layerLink,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          shadowColor: DonyColors.shadow,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
                itemCount: _suggestions.length,
                separatorBuilder: (sepCtx, __) => Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(sepCtx).colorScheme.outline,
                  indent: 48,
                ),
                itemBuilder: (innerCtx, i) {
                  final s = _suggestions[i];
                  final tt = Theme.of(innerCtx).textTheme;
                  final ics = Theme.of(innerCtx).colorScheme;
                  return InkWell(
                    onTap: () => _resolveAndSelect(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base,
                        vertical: DonySpacing.md,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: ics.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                DonyRadius.sm,
                              ),
                            ),
                            child: DonyIcon(
                              'map-pin',
                              size: 16,
                              color: ics.primary,
                            ),
                          ),
                          const SizedBox(width: DonySpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  s.mainText,
                                  style: tt.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (s.secondaryText.isNotEmpty)
                                  Text(
                                    s.secondaryText,
                                    style: tt.bodySmall?.copyWith(
                                      color: ics.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    _debounce?.cancel();
    _sessionToken = null;
    _ctrl.removeListener(_onCtrlChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final confirmed = value != null;
    final hasErr = errorText != null;
    final isLoading = _loading || _resolvingPlace;
    final isFocused = _focus.hasFocus;

    final borderColor = hasErr
        ? cs.error
        : isFocused
        ? cs.primary
        : confirmed
        ? cs.success
        : cs.outline;
    final borderWidth = (hasErr || isFocused || confirmed) ? 1.5 : 1.0;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Input container ──────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(color: borderColor, width: borderWidth),
              color: cs.surface,
            ),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              // Assez d'espace bas pour que l'overlay et le clavier soient visibles ensemble
              scrollPadding: const EdgeInsets.only(bottom: 280),
              decoration: InputDecoration(
                labelText: _w.fieldLabel,
                labelStyle: tt.bodyMedium?.copyWith(
                  color: isFocused ? cs.primary : cs.onSurfaceVariant,
                ),
                floatingLabelStyle: tt.bodySmall?.copyWith(
                  color: isFocused
                      ? cs.primary
                      : confirmed
                      ? cs.success
                      : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                // Hint visible uniquement après que le label a flotté
                hintText: isFocused
                    ? 'Tapez pour rechercher une adresse…'
                    : null,
                hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(
                  DonySpacing.base,
                  DonySpacing.lg,
                  DonySpacing.base,
                  DonySpacing.md,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(
                    left: DonySpacing.md,
                    right: DonySpacing.xs,
                  ),
                  child: DonyIcon(
                    'map-pin',
                    size: 18,
                    color: confirmed
                        ? cs.success
                        : isFocused
                        ? cs.primary
                        : _w.prefixIconColor ?? cs.onSurfaceVariant,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 0,
                ),
                suffixIcon: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(DonySpacing.md),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        ),
                      )
                    : confirmed && !isFocused
                    ? Padding(
                        padding: const EdgeInsets.only(right: DonySpacing.md),
                        child: DonyIcon(
                          'circle-check',
                          color: cs.success,
                          size: 20,
                        ),
                      )
                    : null,
              ),
            ),
          ),

          // ── GPS pill button — séparé du champ, masquable via showGpsButton ──
          if (_w.showGpsButton) ...[
            const SizedBox(height: DonySpacing.sm),
            GestureDetector(
              onTap: _onGps,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(DonyRadius.sm),
                      ),
                      child: DonyIcon(
                        'locate-fixed',
                        size: 14,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Text(
                      'Utiliser ma position actuelle',
                      style: tt.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Erreur validation ────────────────────────────────────────
          if (hasErr)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                errorText!,
                style: TextStyle(color: cs.error, fontSize: 12),
              ),
            ),

          // ── Hors ligne ───────────────────────────────────────────────
          if (_offline)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DonyIcon('wifi-off', size: 12, color: cs.warning),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    'Connexion requise pour la recherche d\'adresse',
                    style: TextStyle(color: cs.warning, fontSize: 12),
                  ),
                ],
              ),
            ),

          // ── Aucun résultat ───────────────────────────────────────────
          if (_showFallback && !_offline)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Aucun résultat, essayez "Ma position actuelle"',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Permission sheet ─────────────────────────────────────────────────────────

class _PermissionSheet extends StatelessWidget {
  const _PermissionSheet({required this.permanent});
  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.lg,
        DonySpacing.lg,
        MediaQuery.of(context).padding.bottom + DonySpacing.lg,
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
            child: DonyIcon('map-pin-off', size: 24, color: cs.warning),
          ),
          const SizedBox(height: DonySpacing.base),
          Text(
            permanent
                ? 'Localisation définitivement refusée'
                : 'Localisation refusée',
            style: tt.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Activez la localisation dans vos paramètres pour utiliser cette fonctionnalité.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openAppSettings();
              },
              child: const Text('Ouvrir les paramètres'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GPS désactivé sheet ──────────────────────────────────────────────────────

class _GpsDisabledSheet extends StatelessWidget {
  const _GpsDisabledSheet();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.lg,
        DonySpacing.lg,
        MediaQuery.of(context).padding.bottom + DonySpacing.lg,
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
            child: DonyIcon('map-pin-off', size: 24, color: cs.warning),
          ),
          const SizedBox(height: DonySpacing.base),
          Text(
            'GPS désactivé',
            style: tt.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Activez la géolocalisation dans vos paramètres système.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openAppSettings();
              },
              child: const Text('Ouvrir les paramètres'),
            ),
          ),
        ],
      ),
    );
  }
}
