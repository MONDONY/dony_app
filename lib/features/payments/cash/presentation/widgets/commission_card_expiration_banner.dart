import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CommissionCardExpirationBanner extends StatelessWidget {
  final ExpirationStatus status;
  final String formattedExpiry;

  const CommissionCardExpirationBanner({
    super.key,
    required this.status,
    required this.formattedExpiry,
  });

  @override
  Widget build(BuildContext context) {
    if (status == ExpirationStatus.valid) return const SizedBox.shrink();
    final isExpired = status == ExpirationStatus.expired;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isExpired ? Colors.red.shade50 : Colors.amber.shade50,
        border: Border.all(color: isExpired ? Colors.red : Colors.amber),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          DonyIcon(
            isExpired ? 'circle-alert' : 'triangle-alert',
            color: isExpired ? Colors.red : Colors.amber.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isExpired
                  ? 'Votre carte a expiré. Remplacez-la pour réactiver le paiement en espèces.'
                  : 'Votre carte expire le $formattedExpiry. Pensez à la remplacer.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
