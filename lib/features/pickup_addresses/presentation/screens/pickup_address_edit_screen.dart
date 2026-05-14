import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
  final _countryCtrl = TextEditingController(text: 'France');
  final _floorCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  bool _isDefault = false;
  bool _initialized = false;

  bool get _isEditing => widget.addressId != null;

  bool get _isValid =>
      _labelCtrl.text.trim().isNotEmpty &&
      _streetCtrl.text.trim().isNotEmpty &&
      _postalCtrl.text.trim().isNotEmpty &&
      _cityCtrl.text.trim().isNotEmpty;

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
    _isDefault = address.isDefault;
  }

  void _submit(BuildContext context) {
    if (!_isValid) {
      return;
    }
    if (_isEditing) {
      context.read<PickupAddressBloc>().add(PickupAddressUpdated(
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
            isDefault: _isDefault,
          ));
    } else {
      context.read<PickupAddressBloc>().add(PickupAddressCreated(
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
            isDefault: _isDefault,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PickupAddressBloc, PickupAddressState>(
      listener: (context, state) {
        if (!_initialized && _isEditing && state.status == PickupAddressStatus.success) {
          final found = state.addresses
              .where((a) => a.id == widget.addressId)
              .firstOrNull;
          if (found != null) {
            _prefill(found);
            _initialized = true;
          }
        }
        // On success after submit, pop back
        if (_initialized && state.status == PickupAddressStatus.success) {
          DonySnackbar.show(
            context,
            message: _isEditing ? 'Adresse mise à jour' : 'Adresse ajoutée',
            type: DonySnackbarType.success,
          );
          context.pop();
        }
        if (state.status == PickupAddressStatus.error && state.error != null) {
          DonySnackbar.show(
            context,
            message: state.error!,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.status == PickupAddressStatus.loading;

        return DonyPageScaffold(
          title: _isEditing ? 'Modifier l\'adresse' : 'Nouvelle adresse',
          stickyBottom: DonyButton(
            label: 'Enregistrer',
            onPressed: isLoading ? null : () => _submit(context),
            isLoading: isLoading,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyTextField(
                controller: _labelCtrl,
                label: 'Libellé',
                hint: 'Ex : Maison, Bureau…',
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              DonyTextField(
                controller: _streetCtrl,
                label: 'Adresse',
                hint: '12 rue de la Paix',
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(delay: 40.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DonyTextField(
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
                      controller: _cityCtrl,
                      label: 'Ville',
                      hint: 'Paris',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 80.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              DonyTextField(
                controller: _floorCtrl,
                label: 'Étage / Appartement',
                hint: 'Optionnel — Ex : Bât. B, 3ème étage',
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(delay: 120.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              TextFormField(
                controller: _instructionsCtrl,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Instructions d\'accès',
                  hintText: 'Optionnel — digicode, horaires…',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.md,
                  ),
                ),
              ).animate().fadeIn(delay: 160.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.xl),
              _DefaultToggle(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ).animate().fadeIn(delay: 200.ms, duration: 280.ms),
            ],
          ),
        );
      },
    );
  }
}

class _DefaultToggle extends StatelessWidget {
  const _DefaultToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: value ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(
            color: value ? cs.primary.withValues(alpha: 0.4) : cs.outline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.star_rounded,
              color: value ? cs.primary : cs.onSurfaceVariant,
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
                    'Pré-sélectionnée lors de tes prochaines demandes',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}
