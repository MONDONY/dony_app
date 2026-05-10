import 'package:dio/dio.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class PackageRequestDetailScreen extends StatefulWidget {
  const PackageRequestDetailScreen({required this.requestId, super.key});
  final String requestId;

  @override
  State<PackageRequestDetailScreen> createState() =>
      _PackageRequestDetailScreenState();
}

class _PackageRequestDetailScreenState
    extends State<PackageRequestDetailScreen> {
  PackageRequest? _request;
  String? _error;
  bool _loading = true;
  bool _cancelling = false;

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
    } on DioException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Erreur');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await getIt<PackageRequestRepository>().cancel(widget.requestId);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kError),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
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
          'Détail',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreenPrimary))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _request == null
                  ? const SizedBox.shrink()
                  : _DetailView(
                      request: _request!,
                      cancelling: _cancelling,
                      onCancel: _cancel,
                      onComplete: () => context.push(
                          '/package-requests/${widget.requestId}/complete-details'),
                    ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({
    required this.request,
    required this.cancelling,
    required this.onCancel,
    required this.onComplete,
  });
  final PackageRequest request;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final canCancel = request.status == PackageRequestStatus.open ||
        request.status == PackageRequestStatus.negotiating;
    final showCompleteCta = request.status == PackageRequestStatus.accepted &&
        request.pickupNeighborhood == null;
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(context).padding.bottom + 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Card(
                title: 'Itinéraire',
                children: [
                  _Row(
                      icon: Icons.flight_takeoff_rounded,
                      label: 'Départ',
                      value: request.departureCity),
                  _Row(
                      icon: Icons.flight_land_rounded,
                      label: 'Arrivée',
                      value: request.arrivalCity),
                  _Row(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value:
                          '${request.desiredDate.day}/${request.desiredDate.month}/${request.desiredDate.year} (±${request.dateToleranceDays}j)'),
                ],
              ),
              const SizedBox(height: 12),
              _Card(
                title: 'Colis',
                children: [
                  _Row(
                      icon: Icons.scale_rounded,
                      label: 'Poids',
                      value: '${request.weightKg} kg'),
                  _Row(
                      icon: Icons.archive_rounded,
                      label: 'Taille',
                      value: request.parcelSize.name.toUpperCase()),
                  _Row(
                      icon: Icons.label_rounded,
                      label: 'Catégorie',
                      value: request.contentCategory),
                  if (request.description != null)
                    _Row(
                        icon: Icons.notes_rounded,
                        label: 'Description',
                        value: request.description!),
                ],
              ),
              if (request.targetPriceEur != null) ...[
                const SizedBox(height: 12),
                _Card(
                  title: 'Budget',
                  children: [
                    _Row(
                        icon: Icons.payments_rounded,
                        label: 'Prix cible',
                        value:
                            '${request.targetPriceEur!.toStringAsFixed(0)} €'),
                  ],
                ),
              ],
            ],
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
        ),
        if (showCompleteCta)
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: DonyButton(
              label: 'Compléter les détails',
              onPressed: onComplete,
            ),
          )
        else if (canCancel)
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: DonyButton(
              label: cancelling ? 'Annulation…' : 'Annuler la demande',
              variant: DonyButtonVariant.destructive,
              isLoading: cancelling,
              onPressed: onCancel,
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: kTextSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: kTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: kError),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            DonyButton(label: 'Réessayer', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
