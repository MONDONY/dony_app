import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_bloc.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_event.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_state.dart';
import 'package:dony/features/delivery_addresses/data/models/delivery_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  bool _isDefault = false;
  bool _submitted = false;
  bool _initialized = false;

  bool get _isEditing => widget.addressId != null;

  bool get _isValid =>
      _labelCtrl.text.trim().isNotEmpty && _cityCtrl.text.trim().isNotEmpty;

  String get _countryFlag =>
      _kDestinationCountries.firstWhere((c) => c.$1 == _country).$2;

  String get _countryName =>
      _kDestinationCountries.firstWhere((c) => c.$1 == _country).$3;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  void _prefill(DeliveryAddress address) {
    _labelCtrl.text = address.label;
    _streetCtrl.text = address.street ?? '';
    _cityCtrl.text = address.city;
    _country = address.country;
    _instructionsCtrl.text = address.instructions ?? '';
    _isDefault = address.isDefault;
  }

  void _submit(BuildContext context) {
    if (!_isValid) {
      return;
    }
    _submitted = true;
    final label = _labelCtrl.text.trim();
    final street =
        _streetCtrl.text.trim().isEmpty ? null : _streetCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final instructions = _instructionsCtrl.text.trim().isEmpty
        ? null
        : _instructionsCtrl.text.trim();
    if (_isEditing) {
      context.read<DeliveryAddressBloc>().add(DeliveryAddressUpdated(
            id: widget.addressId!,
            label: label,
            street: street,
            city: city,
            country: _country,
            instructions: instructions,
            isDefault: _isDefault,
          ));
    } else {
      context.read<DeliveryAddressBloc>().add(DeliveryAddressCreated(
            label: label,
            street: street,
            city: city,
            country: _country,
            instructions: instructions,
            isDefault: _isDefault,
          ));
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
                ? Icon(Icons.check_rounded, color: cs.primary)
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
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<DeliveryAddressBloc, DeliveryAddressState>(
      listener: (context, state) {
        if (!_initialized &&
            _isEditing &&
            state.status == DeliveryAddressStatus.success) {
          final found = state.addresses
              .where((a) => a.id == widget.addressId)
              .firstOrNull;
          if (found != null) {
            _prefill(found);
            _initialized = true;
            setState(() {});
          }
        }
        if (_submitted && state.status == DeliveryAddressStatus.success) {
          DonySnackbar.show(
            context,
            message: _isEditing ? 'Adresse mise à jour' : 'Adresse ajoutée',
            type: DonySnackbarType.success,
          );
          Navigator.of(context).pop(true);
        }
        if (state.status == DeliveryAddressStatus.error &&
            state.error != null) {
          _submitted = false;
          DonySnackbar.show(
            context,
            message: state.error!,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.status == DeliveryAddressStatus.loading;

        return DonyPageScaffold(
          title: _isEditing ? "Modifier l'adresse" : 'Adresse de livraison',
          stickyBottom: DonyButton(
            label: "Enregistrer l'adresse",
            onPressed: (_isValid && !isLoading) ? () => _submit(context) : null,
            isLoading: isLoading,
            variant: DonyButtonVariant.secondary,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyTextField(
                controller: _labelCtrl,
                label: 'Étiquette',
                hint: 'Ex : Famille Dakar, Dépôt…',
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              GestureDetector(
                onTap: () => _pickCountry(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.md,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outline),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: Row(
                    children: [
                      Text(_countryFlag,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PAYS',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            Text(
                              _countryName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 40.ms, duration: 280.ms)
                  .slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              DonyTextField(
                controller: _cityCtrl,
                label: 'Ville',
                hint: 'Ex : Dakar, Abidjan…',
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(delay: 80.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              DonyTextField(
                controller: _streetCtrl,
                label: 'Adresse / Quartier',
                hint: 'Optionnel — Ex : Rue 10, Almadies',
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(delay: 120.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              TextFormField(
                controller: _instructionsCtrl,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText:
                      "Optionnel — Ex : Appeler à l'arrivée, portail rouge…",
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.md,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 160.ms, duration: 280.ms)
                  .slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.xl),
              _DefaultToggle(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                activeColor: cs.secondary,
              ).animate().fadeIn(delay: 200.ms, duration: 280.ms),
            ],
          ),
        );
      },
    );
  }
}

class _DefaultToggle extends StatelessWidget {
  const _DefaultToggle({
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: value ? activeColor.withValues(alpha: 0.08) : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(
            color: value ? activeColor.withValues(alpha: 0.4) : cs.outline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.star_rounded,
              color: value ? activeColor : cs.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adresse par défaut',
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Pré-sélectionnée lors de tes prochaines annonces',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: activeColor,
            ),
          ],
        ),
      ),
    );
  }
}
