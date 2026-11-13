import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Une dimension de colis en centimètres : entier de 1 à 400. Partagé par la
/// demande d'envoi (étape « Le colis ») et la réservation d'un trajet au m³.
class ParcelDimensionField extends StatelessWidget {
  const ParcelDimensionField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.validator,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DonySpacing.xs),
        DonyReplayMask(
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            scrollPadding: kDonyKeyboardScrollPadding,
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
            validator: validator,
            decoration: InputDecoration(
              filled: true,
              fillColor: cs.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.md,
                vertical: DonySpacing.md,
              ),
              suffixText: 'cm',
              suffixStyle: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant,
              ),
              errorMaxLines: 2,
              errorStyle: tt.bodySmall?.copyWith(color: DonyColors.error),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: BorderSide(color: cs.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: const BorderSide(
                  color: DonyColors.error,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: const BorderSide(color: DonyColors.error, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
