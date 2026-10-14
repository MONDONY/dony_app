import 'dart:async';

import 'package:dony/core/currency/country_flag.dart';
import 'package:dony/core/currency/country_picker.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/core/widgets/address/address_country_tile.dart';
import 'package:dony/core/widgets/address/address_default_toggle.dart';
import 'package:dony/core/widgets/address/address_label_chips.dart';
import 'package:dony/core/widgets/address/address_location_status.dart';
import 'package:dony/core/widgets/address/address_section_label.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_bloc.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_event.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_suggest_field.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Pays proposé à la création quand ni l'adresse ni le profil n'en donnent :
/// destination la plus fréquente de la diaspora.
const _kFallbackCountry = 'SN';

/// Suggestions d'étiquette — préremplissent le champ libre, l'utilisateur
/// enregistre ensuite la valeur affichée (donc traduite pour un anglophone).
List<String> _labelChips(AppLocalizations l) => [
  l.deliveryAddressChipFamily,
  l.deliveryAddressChipHome,
  l.deliveryAddressChipShop,
];

class DeliveryAddressEditScreen extends StatefulWidget {
  const DeliveryAddressEditScreen({super.key, this.addressId});

  final String? addressId;

  @override
  State<DeliveryAddressEditScreen> createState() =>
      _DeliveryAddressEditScreenState();
}

class _DeliveryAddressEditScreenState extends State<DeliveryAddressEditScreen> {
  final _labelCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  late String _country;
  double? _lat;
  double? _lng;
  bool _isDefault = false;
  bool _initialized = false;
  bool _hasSubmitted = false;

  bool get _isEditing => widget.addressId != null;

  bool get _isValid =>
      _labelCtrl.text.trim().isNotEmpty && _cityCtrl.text.trim().isNotEmpty;

  /// Pays du profil (Réglages › pays de résidence) s'il est chargé, sinon
  /// [_kFallbackCountry]. Lecture tolérante : l'écran peut être monté sans
  /// les préférences (tests isolés). En édition, l'adresse chargée l'écrase.
  String _initialCountry() {
    final profile = context
        .read<BusinessPrefsBloc?>()
        ?.state
        .country
        ?.trim()
        .toUpperCase();
    return (profile != null && countryFlagEmoji(profile) != null)
        ? profile
        : _kFallbackCountry;
  }

  AddressLocationState get _locationState {
    if (_streetCtrl.text.trim().isEmpty) {
      return AddressLocationState.hidden;
    }
    return _lat != null
        ? AddressLocationState.localized
        : AddressLocationState.manual;
  }

  @override
  void initState() {
    super.initState();
    _country = _initialCountry();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  /// Une recherche suffit (retour FLUTTER-PE) : la suggestion choisie remplit
  /// d'un coup la rue (déjà écrite par [AddressSuggestField], son libellé
  /// court), la ville, le pays et les coordonnées. Le pays n'est repris que
  /// s'il est connu de l'app (catalogue ou nom traduit) : sinon on garde le
  /// pays courant, que l'utilisateur corrige au besoin.
  void _onResolved(AddressData addr) {
    final country = knownCountryCode(context.l10n, addr.country);
    setState(() {
      _lat = addr.lat;
      _lng = addr.lng;
      if (addr.city != null && addr.city!.trim().isNotEmpty) {
        _cityCtrl.text = addr.city!.trim();
      }
      if (country != null) {
        _country = country;
      }
    });
  }

  void _submit(BuildContext context) {
    if (!_isValid) {
      return;
    }
    setState(() => _hasSubmitted = true);
    final label = _labelCtrl.text.trim();
    final street = _streetCtrl.text.trim().isEmpty
        ? null
        : _streetCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final instructions = _instructionsCtrl.text.trim().isEmpty
        ? null
        : _instructionsCtrl.text.trim();
    final lat = street == null ? null : _lat;
    final lng = street == null ? null : _lng;
    if (_isEditing) {
      context.read<DeliveryAddressBloc>().add(
        DeliveryAddressUpdated(
          id: widget.addressId!,
          label: label,
          street: street,
          city: city,
          country: _country,
          instructions: instructions,
          latitude: lat,
          longitude: lng,
          isDefault: _isDefault,
        ),
      );
    } else {
      context.read<DeliveryAddressBloc>().add(
        DeliveryAddressCreated(
          label: label,
          street: street,
          city: city,
          country: _country,
          instructions: instructions,
          latitude: lat,
          longitude: lng,
          isDefault: _isDefault,
        ),
      );
    }
  }

  Future<void> _pickCountry(BuildContext context) async {
    final picked = await showCountryPicker(
      context,
      title: context.l10n.deliveryAddressCountryPickerTitle,
      selectedCode: _country,
    );
    if (picked != null && picked != _country && mounted) {
      setState(() => _country = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DeliveryAddressBloc, DeliveryAddressState>(
      listener: (context, state) {
        // Pré-remplissage en mode édition
        if (!_initialized &&
            _isEditing &&
            state.status == DeliveryAddressStatus.success) {
          final found = state.addresses
              .where((a) => a.id == widget.addressId)
              .firstOrNull;
          if (found != null) {
            _initialized = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _labelCtrl.text = found.label;
                  _streetCtrl.text = found.street ?? '';
                  _cityCtrl.text = found.city;
                  _country = found.country;
                  _lat = found.latitude;
                  _lng = found.longitude;
                  _instructionsCtrl.text = found.instructions ?? '';
                  _isDefault = found.isDefault;
                });
              }
            });
          }
        }
        // Succès après submit → snackbar + retour
        if (_hasSubmitted && state.status == DeliveryAddressStatus.success) {
          setState(() => _hasSubmitted = false);
          DonySnackbar.show(
            context,
            message: _isEditing
                ? context.l10n.deliveryAddressUpdatedMessage
                : context.l10n.deliveryAddressAddedMessage,
            type: DonySnackbarType.success,
          );
          context.pop(true);
        }
        if (state.status == DeliveryAddressStatus.error &&
            state.error != null &&
            _hasSubmitted) {
          setState(() => _hasSubmitted = false);
          unawaited(ErrorPresenter.show(context, state.error));
        }
      },
      builder: (context, state) {
        final isLoading = state.status == DeliveryAddressStatus.loading;
        final cs = Theme.of(context).colorScheme;
        final l = context.l10n;

        return DonyPageScaffold(
          title: _isEditing
              ? l.deliveryAddressEditTitle
              : l.deliveryAddressCreateTitle,
          stickyBottom: DonyButton(
            label: l.deliveryAddressSaveButton,
            variant: DonyButtonVariant.secondary,
            onPressed: (_isValid && !isLoading) ? () => _submit(context) : null,
            isLoading: isLoading,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                [
                      // ── Étiquette ──────────────────────────────────────
                      AddressSectionLabel(l.deliveryAddressLabelSectionTitle),
                      DonyTextField(
                        textInputAction: TextInputAction.next,
                        controller: _labelCtrl,
                        label: l.deliveryAddressNameFieldLabel,
                        hint: l.deliveryAddressNameFieldHint,
                        prefixWidget: DonyIcon(
                          'tag',
                          size: 20,
                          color: cs.secondary,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: DonySpacing.sm),
                      AddressLabelChips(
                        controller: _labelCtrl,
                        chips: _labelChips(l),
                        accentColor: cs.secondary,
                        onSelected: () => setState(() {}),
                      ),
                      const SizedBox(height: DonySpacing.xl),

                      // ── Adresse ────────────────────────────────────────
                      // Une seule recherche remplit rue, ville, pays et
                      // position (FLUTTER-PE). Pays et ville restent
                      // modifiables, la rue garde la saisie libre pour les
                      // quartiers mal couverts par Google.
                      AddressSectionLabel(l.deliveryAddressAddressSectionTitle),
                      AddressSuggestField(
                        controller: _streetCtrl,
                        service: getIt<AddressAutocompleteService>(),
                        label: l.deliveryAddressStreetFieldLabel,
                        hint: l.deliveryAddressStreetFieldHint,
                        prefixIcon: Icons.search_rounded,
                        prefixIconColor: cs.secondary,
                        onChanged: (_) => setState(() {}),
                        onResolved: _onResolved,
                        onCoordinatesCleared: () => setState(() {
                          _lat = null;
                          _lng = null;
                        }),
                      ),
                      AddressLocationStatus(state: _locationState),
                      const SizedBox(height: DonySpacing.base),
                      AddressCountryTile(
                        countryCode: _country,
                        label: l.deliveryAddressCountrySectionTitle,
                        onTap: () => _pickCountry(context),
                      ),
                      const SizedBox(height: DonySpacing.base),
                      DonyTextField(
                        textInputAction: TextInputAction.done,
                        controller: _cityCtrl,
                        label: l.deliveryAddressCityFieldLabel,
                        hint: l.deliveryAddressCityFieldHint,
                        prefixWidget: DonyIcon(
                          'building-2',
                          size: 20,
                          color: cs.secondary,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: DonySpacing.xl),

                      // ── Instructions ───────────────────────────────────
                      AddressSectionLabel(
                        l.deliveryAddressInstructionsSectionTitle,
                      ),
                      TextFormField(
                        controller: _instructionsCtrl,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: l.deliveryAddressInstructionsHint,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(
                              left: DonySpacing.md,
                              right: DonySpacing.xs,
                            ),
                            child: DonyIcon(
                              'message-circle',
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.base,
                            vertical: DonySpacing.md,
                          ),
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xl),

                      // ── Par défaut ─────────────────────────────────────
                      AddressDefaultToggle(
                        value: _isDefault,
                        onChanged: (v) => setState(() => _isDefault = v),
                        activeColor: cs.secondary,
                        subtitle: l.deliveryAddressDefaultSubtitle,
                      ),
                    ]
                    .animate(interval: 40.ms)
                    .fadeIn(duration: 280.ms)
                    .slideY(begin: 0.03, curve: Curves.easeOutCubic),
          ),
        );
      },
    );
  }
}
