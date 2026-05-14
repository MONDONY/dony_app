import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CommissionCardPreview extends StatelessWidget {
  final CommissionMethod card;

  const CommissionCardPreview({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade700, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BrandLogo(brand: card.brand),
          const SizedBox(height: 24),
          Text(
            card.maskedNumber,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Expire le ${card.formattedExpiry}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  final String brand;

  const _BrandLogo({required this.brand});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: Key('brand-logo-$brand'),
      height: 32,
      child: Text(
        brand.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
