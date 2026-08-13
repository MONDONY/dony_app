import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

const _kDestinationCountries = [
  ('SN', '🇸🇳', 'Sénégal'),
  ('CI', '🇨🇮', "Côte d'Ivoire"),
  ('ML', '🇲🇱', 'Mali'),
  ('CM', '🇨🇲', 'Cameroun'),
  ('GN', '🇬🇳', 'Guinée'),
  ('BF', '🇧🇫', 'Burkina Faso'),
  ('BJ', '🇧🇯', 'Bénin'),
  ('TG', '🇹🇬', 'Togo'),
];

const _kLabelChips = ['Famille', 'Maison', 'Boutique'];

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
  String _country = 'SN';
  double? _lat;
  double? _lng;
  bool _isDefault = false;
  bool _initialized = false;
  bool _hasSubmitted = false;

  bool get _isEditing => widget.addressId != null;

  bool get _isValid =>
      _labelCtrl.text.trim().isNotEmpty && _cityCtrl.text.trim().isNotEmpty;

  String get _countryFlag =>
      _kDestinationCountries.firstWhere((c) => c.$1 == _country).$2;

  String get _countryName =>
      _kDestinationCountries.firstWhere((c) => c.$1 == _country).$3;

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
    _cityCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  /// Pré-remplissage depuis la suggestion résolue.
  /// addr.country est intentionnellement ignoré — la liste pays est fermée (spec §6).
  void _onResolved(AddressData addr) {
    setState(() {
      _lat = addr.lat;
      _lng = addr.lng;
      if (addr.city != null && addr.city!.isNotEmpty) {
        _cityCtrl.text = addr.city!;
      }
      // addr.country ignoré — liste fermée diaspora (spec §6)
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
    final cs = Theme.of(context).colorScheme;
    final picked = await DonyBottomSheet.show<String>(
      context,
      title: 'Pays de destination',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _kDestinationCountries.map((c) {
          final isSelected = c.$1 == _country;
          return ListTile(
            leading: Text(c.$2, style: const TextStyle(fontSize: 24)),
            title: Text(
              c.$3,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            trailing: isSelected
                ? DonyIcon('check', color: cs.secondary)
                : null,
            onTap: () => Navigator.of(context, rootNavigator: true).pop(c.$1),
          );
        }).toList(),
      ),
    );
    if (picked != null && picked != _country) {
      setState(() {
        _country = picked;
      });
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
            message: _isEditing ? 'Adresse mise à jour' : 'Adresse ajoutée',
            type: DonySnackbarType.success,
          );
          context.pop(true);
        }
        if (state.status == DeliveryAddressStatus.error &&
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
        final isLoading = state.status == DeliveryAddressStatus.loading;
        final cs = Theme.of(context).colorScheme;

        return DonyPageScaffold(
          title: _isEditing
              ? "Modifier l'adresse"
              : 'Nouvelle adresse de livraison',
          stickyBottom: DonyButton(
            label: "Enregistrer l'adresse",
            variant: DonyButtonVariant.secondary,
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
                        hint: 'Ex : Famille Dakar, Dépôt…',
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
                        chips: _kLabelChips,
                        accentColor: cs.secondary,
                        onSelected: () => setState(() {}),
                      ),
                      const SizedBox(height: DonySpacing.xl),

                      // ── Pays ───────────────────────────────────────────
                      const AddressSectionLabel('Pays'),
                      GestureDetector(
                        onTap: () => _pickCountry(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.base,
                            vertical: DonySpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            border: Border.all(color: cs.outline),
                            borderRadius: BorderRadius.circular(DonyRadius.md),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _countryFlag,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: DonySpacing.md),
                              Expanded(
                                child: Text(
                                  _countryName,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              DonyIcon(
                                'chevron-right',
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xl),

                      // ── Adresse ────────────────────────────────────────
                      const AddressSectionLabel('Adresse'),
                      DonyTextField(
                        textInputAction: TextInputAction.done,
                        controller: _cityCtrl,
                        label: 'Ville',
                        hint: 'Ex : Dakar, Abidjan, Bamako…',
                        prefixWidget: DonyIcon(
                          'building-2',
                          size: 20,
                          color: cs.secondary,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: DonySpacing.base),
                      AddressSuggestField(
                        controller: _streetCtrl,
                        service: getIt<AddressAutocompleteService>(),
                        label: 'Rue, quartier',
                        hint: 'Optionnel (ex : Rue 10, Almadies)',
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
                      const SizedBox(height: DonySpacing.xl),

                      // ── Instructions ───────────────────────────────────
                      const AddressSectionLabel('Instructions'),
                      TextFormField(
                        controller: _instructionsCtrl,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              "Optionnel : appeler à l'arrivée, portail rouge…",
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
                        subtitle: 'Pré-remplie lors de tes prochaines annonces',
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
