import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:flutter/material.dart';

class RebookButton extends StatelessWidget {
  const RebookButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DonyButton(
      label: 'Réserver à nouveau',
      icon: Icons.refresh_rounded,
      variant: DonyButtonVariant.secondary,
      isLoading: isLoading,
      fullWidth: false,
      onPressed: onPressed,
    );
  }
}
