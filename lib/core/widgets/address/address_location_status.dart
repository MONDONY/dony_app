import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

enum AddressLocationState { localized, manual, hidden }

class AddressLocationStatus extends StatelessWidget {
  const AddressLocationStatus({super.key, required this.state});

  final AddressLocationState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (state == AddressLocationState.hidden) {
      return const SizedBox.shrink();
    }
    final localized = state == AddressLocationState.localized;
    final color = localized ? cs.success : cs.onSurfaceVariant;
    final icon = localized
        ? Icons.check_circle_rounded
        : Icons.edit_location_alt_outlined;
    final text = localized
        ? 'Adresse localisée'
        : 'Adresse non localisée — tu peux la saisir à la main';

    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.sm, left: DonySpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: DonySpacing.xs),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
