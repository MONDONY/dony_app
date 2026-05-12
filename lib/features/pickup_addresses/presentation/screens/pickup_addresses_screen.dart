import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PickupAddressesScreen extends StatelessWidget {
  const PickupAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DonyPageScaffold(
      title: 'Mes adresses de pickup',
      scrollable: false,
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: 'Ajouter une adresse',
          onPressed: () => context.push('/profile/addresses/new'),
        ),
      ],
      body: BlocBuilder<PickupAddressBloc, PickupAddressState>(
        builder: (context, state) {
          if (state.status == PickupAddressStatus.loading &&
              state.addresses.isEmpty) {
            return const DonyEmptyState(
              type: DonyEmptyStateType.loading,
              title: '',
            );
          }
          if (state.status == PickupAddressStatus.error &&
              state.addresses.isEmpty) {
            return DonyEmptyState(
              type: DonyEmptyStateType.error,
              icon: Icons.error_outline_rounded,
              title: 'Erreur de chargement',
              description: state.error ?? 'Une erreur est survenue.',
              actionLabel: 'Réessayer',
              onAction: () =>
                  context.read<PickupAddressBloc>().add(const PickupAddressLoaded()),
            );
          }
          if (state.addresses.isEmpty) {
            return DonyEmptyState(
              icon: Icons.location_on_outlined,
              title: 'Aucune adresse enregistrée',
              description:
                  'Ajoute ta première adresse de pickup pour accélérer tes prochaines demandes.',
              actionLabel: 'Ajouter ma première adresse',
              onAction: () => context.push('/profile/addresses/new'),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              MediaQuery.paddingOf(context).bottom + 100,
            ),
            itemCount: state.addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: DonySpacing.sm),
            itemBuilder: (context, i) {
              final address = state.addresses[i];
              return _PickupAddressCard(address: address)
                  .animate()
                  .fadeIn(delay: (i * 60).ms, duration: 280.ms)
                  .slideY(begin: 0.03, curve: Curves.easeOutCubic);
            },
          );
        },
      ),
    );
  }
}

class _PickupAddressCard extends StatelessWidget {
  const _PickupAddressCard({required this.address});

  final PickupAddress address;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(
          color: address.isDefault
              ? cs.primary.withValues(alpha: 0.4)
              : cs.outline,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/profile/addresses/${address.id}'),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(DonySpacing.sm),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: cs.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address.label,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (address.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DonySpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.success.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(DonyRadius.full),
                              border: Border.all(
                                color: cs.success.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              'Par défaut',
                              style: tt.labelSmall?.copyWith(
                                color: cs.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      [address.street, address.postalCode, address.city]
                          .join(', '),
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (address.floorApartment != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        address.floorApartment!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _KebabMenu(address: address),
            ],
          ),
        ),
      ),
    );
  }
}

class _KebabMenu extends StatelessWidget {
  const _KebabMenu({required this.address});

  final PickupAddress address;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<_AddressAction>(
      icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant, size: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      onSelected: (action) async {
        switch (action) {
          case _AddressAction.setDefault:
            context
                .read<PickupAddressBloc>()
                .add(PickupAddressSetDefault(address.id));
          case _AddressAction.edit:
            unawaited(context.push('/profile/addresses/${address.id}'));
          case _AddressAction.delete:
            final confirmed = await DonyDialog.show(
              context,
              title: 'Supprimer l\'adresse',
              message:
                  'Es-tu sûr de vouloir supprimer "${address.label}" ? Cette action est irréversible.',
              icon: Icons.delete_outline_rounded,
              confirmLabel: 'Supprimer',
              variant: DonyDialogVariant.destructive,
              cancelLabel: 'Annuler',
            );
            if ((confirmed ?? false) && context.mounted) {
              context
                  .read<PickupAddressBloc>()
                  .add(PickupAddressDeleted(address.id));
            }
        }
      },
      itemBuilder: (_) => [
        if (!address.isDefault)
          const PopupMenuItem(
            value: _AddressAction.setDefault,
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 18),
                SizedBox(width: DonySpacing.sm),
                Text('Définir par défaut'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: _AddressAction.edit,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: DonySpacing.sm),
              Text('Modifier'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _AddressAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 18, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: DonySpacing.sm),
              Text(
                'Supprimer',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _AddressAction { setDefault, edit, delete }
