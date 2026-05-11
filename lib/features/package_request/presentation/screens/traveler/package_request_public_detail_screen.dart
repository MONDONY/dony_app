import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class PackageRequestPublicDetailScreen extends StatefulWidget {
  const PackageRequestPublicDetailScreen({required this.requestId, super.key});
  final String requestId;

  @override
  State<PackageRequestPublicDetailScreen> createState() =>
      _PackageRequestPublicDetailScreenState();
}

class _PackageRequestPublicDetailScreenState
    extends State<PackageRequestPublicDetailScreen> {
  PackageRequest? _request;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await getIt<PackageRequestRepository>().getById(widget.requestId);
      if (mounted) setState(() => _request = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: kGreenPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Demande',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreenPrimary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, color: kError)),
                  ),
                )
              : _request == null
                  ? const SizedBox.shrink()
                  : _buildBody(_request!),
    );
  }

  Widget _buildBody(PackageRequest r) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 24, 20, MediaQuery.of(context).padding.bottom + 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kGreenPrimary, kGreenDark],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.departureCity}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Icon(Icons.arrow_downward_rounded,
                        color: Colors.white70, size: 28),
                    Text(
                      '${r.arrivalCity}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Souhaité le ${r.desiredDate.day}/${r.desiredDate.month}/${r.desiredDate.year} (±${r.dateToleranceDays}j)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _detailCard('Colis', [
                _kv(Icons.scale_rounded, 'Poids', '${r.weightKg} kg'),
                _kv(Icons.archive_rounded, 'Taille',
                    r.parcelSize.name.toUpperCase()),
                _kv(Icons.label_rounded, 'Catégorie', r.contentCategory.label),
                if (r.description != null)
                  _kv(Icons.notes_rounded, 'Description', r.description!),
              ]),
              if (r.targetPriceEur != null) ...[
                const SizedBox(height: 12),
                _detailCard('Budget', [
                  _kv(Icons.payments_rounded, 'Prix cible',
                      '${r.targetPriceEur!.toStringAsFixed(0)} €'),
                ]),
              ],
              if (r.pickupNeighborhood != null ||
                  r.deliveryNeighborhood != null) ...[
                const SizedBox(height: 12),
                _detailCard('Zones', [
                  if (r.pickupNeighborhood != null)
                    _kv(Icons.location_on_rounded, 'Pickup',
                        r.pickupNeighborhood!),
                  if (r.deliveryNeighborhood != null)
                    _kv(Icons.location_on_rounded, 'Livraison',
                        r.deliveryNeighborhood!),
                ]),
              ],
            ],
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
          child: DonyButton(
            label: 'Faire une offre',
            onPressed: () => MakeOfferBottomSheet.show(
              context,
              packageRequestId: r.id,
              targetPriceEur: r.targetPriceEur,
              weightKg: r.weightKg,
              departureCity: r.departureCity,
              arrivalCity: r.arrivalCity,
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kTextSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: kTextSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
