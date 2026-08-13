import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/core/widgets/address/address_default_toggle.dart';
import 'package:dony/core/widgets/address/address_label_chips.dart';
import 'package:dony/core/widgets/address/address_location_status.dart';
import 'package:dony/core/widgets/address/address_section_label.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_suggest_field.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

const _kLabelChips = ['Maison', 'Bureau', 'Atelier'];

class PickupAddressEditScreen extends StatefulWidget {
  const PickupAddressEditScreen({super.key, this.addressId});

  final String? addressId;

  @override
  State<PickupAddressEditScreen> createState() =>
      _PickupAddressEditScreenState();
}

class _PickupAddressEditScreenState extends State<PickupAddressEditScreen> {
  final _labelCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'FR');
  final _floorCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  double? _lat;
  double? _lng;
  bool _isDefault = false;
  bool _initialized = false;
  bool _hasSubmitted = false;

  bool get _isEditing {
    return widget.addressId != null;
  }

  /// Spec §3: étiquette + ville requis seulement (rue + CP optionnels).
  bool get _isValid =>
      _labelCtrl.text.trim().isNotEmpty && _cityCtrl.text.trim().isNotEmpty;

  AddressLocationState get _locationState {
    if (_streetCtrl.text.trim().isEmpty) {
      return AddressLocationState.hidden;
    }
    return _lat != null
        ? AddressLocationState.localized
        : AddressLocationState.manual;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _streetCtrl.dispose();
    _postalCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _floorCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  void _prefill(PickupAddress address) {
    _labelCtrl.text = address.label;
    _streetCtrl.text = address.street;
    _postalCtrl.text = address.postalCode;
    _cityCtrl.text = address.city;
    _countryCtrl.text = address.country;
    _floorCtrl.text = address.floorApartment ?? '';
    _instructionsCtrl.text = address.instructions ?? '';
    _lat = address.latitude;
    _lng = address.longitude;
    _isDefault = address.isDefault;
  }

  /// Pré-remplissage depuis la suggestion résolue — ne remplace pas si null.
  void _onResolved(AddressData addr) {
    setState(() {
      _lat = addr.lat;
      _lng = addr.lng;
      if (addr.city != null && addr.city!.isNotEmpty) {
        _cityCtrl.text = addr.city!;
      }
      if (addr.postalCode != null && addr.postalCode!.isNotEmpty) {
        _postalCtrl.text = addr.postalCode!;
      }
    });
  }

  void _submit(BuildContext context) {
    if (!_isValid) {
      return;
    }
    setState(() => _hasSubmitted = true);
    if (_isEditing) {
      context.read<PickupAddressBloc>().add(
        PickupAddressUpdated(
          id: widget.addressId!,
          label: _labelCtrl.text.trim(),
          street: _streetCtrl.text.trim(),
          postalCode: _postalCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          country: _countryCtrl.text.trim(),
          floorApartment: _floorCtrl.text.trim().isEmpty
              ? null
              : _floorCtrl.text.trim(),
          instructions: _instructionsCtrl.text.trim().isEmpty
              ? null
              : _instructionsCtrl.text.trim(),
          latitude: _lat,
          longitude: _lng,
          isDefault: _isDefault,
        ),
      );
    } else {
      context.read<PickupAddressBloc>().add(
        PickupAddressCreated(
          label: _labelCtrl.text.trim(),
          street: _streetCtrl.text.trim(),
          postalCode: _postalCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          country: _countryCtrl.text.trim(),
          floorApartment: _floorCtrl.text.trim().isEmpty
              ? null
              : _floorCtrl.text.trim(),
          instructions: _instructionsCtrl.text.trim().isEmpty
              ? null
              : _instructionsCtrl.text.trim(),
          latitude: _lat,
          longitude: _lng,
          isDefault: _isDefault,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PickupAddressBloc, PickupAddressState>(
      listener: (context, state) {
        // Pré-remplissage en mode édition
        if (!_initialized &&
            _isEditing &&
            state.status == PickupAddressStatus.success) {
          final found = state.addresses
              .where((a) => a.id == widget.addressId)
              .firstOrNull;
          if (found != null) {
            _prefill(found);
            _initialized = true;
          }
        }
        // Succès après submit → snackbar + retour
        if (_hasSubmitted && state.status == PickupAddressStatus.success) {
          setState(() => _hasSubmitted = false);
          DonySnackbar.show(
            context,
            message: _isEditing ? 'Adresse mise à jour' : 'Adresse ajoutée',
            type: DonySnackbarType.success,
          );
          context.pop(true);
        }
        if (state.status == PickupAddressStatus.error &&
            state.error != null &&
            _hasSubmitted) {
          setState(() => _hasSubmitted = false);
          DonySnackbar.show(
            context,
            message: state.error!,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.status == PickupAddressStatus.loading;
        final cs = Theme.of(context).colorScheme;

        return DonyPageScaffold(
          title: _isEditing
              ? "Modifier l'adresse"
              : 'Nouvelle adresse de remise',
          stickyBottom: DonyButton(
            label: "Enregistrer l'adresse",
            onPressed: (_isValid && !isLoading) ? () => _submit(context) : null,
            isLoading: isLoading,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                [
                      // ── Étiquette ──────────────────────────────────────
                      const AddressSectionLabel('Étiquette'),
                      DonyTextField(
                        textInputAction: TextInputAction.next,
                        controller: _labelCtrl,
                        label: "Nom de l'adresse",
                        hint: 'Ex : Maison, Bureau…',
                        prefixWidget: DonyIcon(
                          'tag',
                          size: 20,
                          color: cs.primary,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: DonySpacing.sm),
                      AddressLabelChips(
                        controller: _labelCtrl,
                        chips: _kLabelChips,
                        accentColor: cs.primary,
                        onSelected: () => setState(() {}),
                      ),
                      const SizedBox(height: DonySpacing.xl),

                      // ── Adresse ────────────────────────────────────────
                      const AddressSectionLabel('Adresse'),
                      AddressSuggestField(
                        controller: _streetCtrl,
                        service: getIt<AddressAutocompleteService>(),
                        label: 'Rue et numéro',
                        hint: '12 rue de la Paix',
                        prefixIcon: Icons.search_rounded,
                        prefixIconColor: cs.primary,
                        onChanged: (_) => setState(() {}),
                        onResolved: _onResolved,
                        onCoordinatesCleared: () => setState(() {
                          _lat = null;
                          _lng = null;
                        }),
                      ),
                      AddressLocationStatus(state: _locationState),
                      const SizedBox(height: DonySpacing.base),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DonyTextField(
                              textInputAction: TextInputAction.next,
                              controller: _postalCtrl,
                              label: 'Code postal',
                              hint: '75001',
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: DonySpacing.sm),
                          Expanded(
                            flex: 3,
                            child: DonyTextField(
                              textInputAction: TextInputAction.next,
                              controller: _cityCtrl,
                              label: 'Ville',
                              hint: 'Paris',
                              prefixWidget: DonyIcon(
                                'building-2',
                                size: 20,
                                color: cs.primary,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DonySpacing.xl),

                      // ── Étage ──────────────────────────────────────────
                      const AddressSectionLabel('Étage / Appartement'),
                      DonyTextField(
                        textInputAction: TextInputAction.done,
                        controller: _floorCtrl,
                        label: 'Étage / Appartement',
                        hint: 'Optionnel (Ex : Bât. B, 3ème étage)',
                        prefixWidget: DonyIcon(
                          'door-open',
                          size: 20,
                          color: cs.primary,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: DonySpacing.xl),

                      // ── Instructions ───────────────────────────────────
                      const AddressSectionLabel('Instructions'),
                      TextFormField(
                        controller: _instructionsCtrl,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Optionnel : digicode, horaires…',
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
                        activeColor: cs.primary,
                        subtitle: 'Pré-remplie lors de tes prochaines demandes',
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
