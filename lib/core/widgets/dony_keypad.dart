import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DonyKeypad extends StatelessWidget {
  const DonyKeypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
    this.enabled = true,
  });

  final void Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KeypadKey(
              onTap: onBiometric,
              enabled: enabled && onBiometric != null,
              child: onBiometric != null
                  ? const Icon(Icons.fingerprint, size: 28)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 12),
            _KeypadKey(
              onTap: () => onDigit('0'),
              enabled: enabled,
              child: const Text('0', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 12),
            _KeypadKey(
              onTap: onDelete,
              enabled: enabled,
              child: const Icon(Icons.backspace_outlined, size: 24),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05);
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          _KeypadKey(
            onTap: () => onDigit(digits[i]),
            enabled: enabled,
            child: Text(digits[i], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
          ),
        ],
      ],
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({required this.child, required this.onTap, this.enabled = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        onTap: (enabled && onTap != null) ? onTap : null,
        borderRadius: BorderRadius.circular(40),
        splashColor: const Color(0xFF1E88E5).withValues(alpha: 0.15),
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? const Color(0xFFF8F9FA) : Colors.grey.shade100,
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: enabled ? const Color(0xFF1A1A2E) : Colors.grey.shade400,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
            child: IconTheme(
              data: IconThemeData(
                color: enabled ? const Color(0xFF1A1A2E) : Colors.grey.shade400,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
