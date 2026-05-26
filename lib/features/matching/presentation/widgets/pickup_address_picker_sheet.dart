import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_picker_field.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PickupAddressPickerSheet extends StatefulWidget {
  const PickupAddressPickerSheet({super.key, this.current});

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
            getIt<PickupAddressBloc>()..add(const PickupAddressLoaded()),
        child: PickupAddressPickerSheet(current: current),
      ),
    );
  }

  @override
  State<PickupAddressPickerSheet> createState() =>
      _PickupAddressPickerSheetState();
}

class _PickupAddressPickerSheetState extends State<PickupAddressPickerSheet> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
          ),
          child: BlocBuilder<PickupAddressBloc, PickupAddressState>(
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
                        Text('📦  Adresse de remise',
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                              backgroundColor: cs.surfaceContainerHighest),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Body
                  Expanded(
                    child: state.status == PickupAddressStatus.loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            controller: scrollController,
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.paddingOf(context).bottom + 80),
                            children: [
                              if (state.addresses.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      DonySpacing.lg,
                                      DonySpacing.md,
                                      DonySpacing.lg,
                                      4),
                                  child: Text('MES ADRESSES ENREGISTRÉES',
                                      style: tt.labelSmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          letterSpacing: 0.08)),
                                ),
                                ...state.addresses.map((address) {
                                  final isSelected = _selectedId == address.id ||
                                      (_selectedId == null && address.isDefault);
                                  return _AddressRow(
                                    address: address,
                                    isSelected: isSelected,
                                    activeColor: cs.primary,
                                    onTap: () => setState(
                                        () => _selectedId = address.id),
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
                                  child: const Icon(Icons.search_rounded),
                                ),
                                title: Text('Chercher une autre adresse',
                                    style: tt.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Text('Recherche via Google Maps',
                                    style: tt.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant)),
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  final result =
                                      await _showGooglePickerSheet(context);
                                  if (result != null && context.mounted) {
                                    Navigator.of(context, rootNavigator: true)
                                        .pop(result);
                                  }
                                },
                              ),
                              ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(DonyRadius.md),
                                  ),
                                  child: const Icon(Icons.add_rounded),
                                ),
                                title: Text('Ajouter une adresse',
                                    style: tt.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    'Enregistrer pour la prochaine fois',
                                    style: tt.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant)),
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  // ignore: use_build_context_synchronously
                                  await context
                                      .push<bool>('/profile/addresses/new');
                                },
                              ),
                            ],
                          ),
                  ),
                  // Bouton confirmer
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(DonySpacing.lg,
                          DonySpacing.sm, DonySpacing.lg, DonySpacing.md),
                      child: DonyButton(
                        label: 'Confirmer cette adresse',
                        onPressed: state.addresses.isEmpty
                            ? null
                            : () {
                                final address = _selectedId != null
                                    ? state.addresses.firstWhere(
                                        (a) => a.id == _selectedId,
                                        orElse: () => state.addresses.first)
                                    : state.addresses.firstWhere(
                                        (a) => a.isDefault,
                                        orElse: () => state.addresses.first);
                                Navigator.of(context).pop(
                                  AddressData(
                                    label: [
                                      address.label,
                                      address.street,
                                      address.postalCode,
                                      address.city,
                                    ]
                                        .where((s) => s.isNotEmpty)
                                        .join(', '),
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

  Future<AddressData?> _showGooglePickerSheet(BuildContext ctx) {
    return showModalBottomSheet<AddressData>(
      context: ctx,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
        ),
        padding: EdgeInsets.only(
          top: DonySpacing.md,
          left: DonySpacing.lg,
          right: DonySpacing.lg,
          bottom: MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: DonySpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: AddressPickerField(
                fieldLabel: 'Adresse de remise',
                autocompleteService: getIt<AddressAutocompleteService>(),
                onChanged: (address) {
                  if (address != null) {
                    Navigator.of(ctx).pop(address);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.address,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final PickupAddress address;
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
        child: Icon(Icons.home_rounded,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        [address.street, address.postalCode, address.city]
            .where((s) => s.isNotEmpty)
            .join(', '),
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
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
            : null,
      ),
    );
  }
}
