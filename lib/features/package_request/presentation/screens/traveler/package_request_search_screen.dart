import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class PackageRequestSearchScreen extends StatelessWidget {
  const PackageRequestSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<PackageRequestSearchBloc>()..add(const SearchFiltersChanged()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _depCtrl = TextEditingController();
  final _arrCtrl = TextEditingController();

  void _applyFilters() {
    context.read<PackageRequestSearchBloc>().add(
          SearchFiltersChanged(
            departure:
                _depCtrl.text.trim().isEmpty ? null : _depCtrl.text.trim(),
            arrival:
                _arrCtrl.text.trim().isEmpty ? null : _arrCtrl.text.trim(),
          ),
        );
  }

  @override
  void dispose() {
    _depCtrl.dispose();
    _arrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        title: Text(
          'Demandes ouvertes',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _depCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Départ',
                      prefixIcon: Icon(Icons.flight_takeoff_rounded, size: 18),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _arrCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Arrivée',
                      prefixIcon: Icon(Icons.flight_land_rounded, size: 18),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: _applyFilters,
                  style: IconButton.styleFrom(
                    backgroundColor: kGreenPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorder),
          Expanded(
            child: BlocBuilder<PackageRequestSearchBloc,
                PackageRequestSearchState>(
              builder: (context, state) {
                if (state.status == SearchStatus.loading) {
                  return const Center(
                      child: CircularProgressIndicator(color: kGreenPrimary));
                }
                if (state.status == SearchStatus.error) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        state.errorMessage ?? 'Erreur',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: kError,
                        ),
                      ),
                    ),
                  );
                }
                if (state.results.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_rounded,
                              size: 64, color: kTextHint),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune demande ne correspond à votre filtre',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels >=
                            n.metrics.maxScrollExtent - 200 &&
                        state.status == SearchStatus.loaded &&
                        state.hasMore) {
                      context
                          .read<PackageRequestSearchBloc>()
                          .add(const SearchLoadMore());
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    color: kGreenPrimary,
                    onRefresh: () async {
                      context
                          .read<PackageRequestSearchBloc>()
                          .add(const SearchRefresh());
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                      itemCount: state.results.length +
                          (state.status == SearchStatus.loadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i >= state.results.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: kGreenPrimary),
                            ),
                          );
                        }
                        final r = state.results[i];
                        return _PublicRequestCard(request: r)
                            .animate()
                            .fadeIn(duration: 200.ms, delay: (40 * i).ms)
                            .slideY(begin: 0.04);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicRequestCard extends StatelessWidget {
  const _PublicRequestCard({required this.request});
  final PackageRequestSearchItem request;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push('/package-requests/${request.id}/public'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${request.departureCity} → ${request.arrivalCity}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kGreenLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      request.parcelSize.name.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kGreenDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _Pill(
                    icon: Icons.calendar_today_rounded,
                    label:
                        '${request.desiredDate.day}/${request.desiredDate.month} ±${request.dateToleranceDays}j',
                  ),
                  _Pill(
                    icon: Icons.scale_rounded,
                    label: '${request.weightKg} kg',
                  ),
                  _Pill(
                    icon: Icons.label_rounded,
                    label: request.contentCategory.label,
                  ),
                ],
              ),
              if (request.targetPriceEur != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Budget: ${request.targetPriceEur!.toStringAsFixed(0)} €',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kGreenPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: kTextSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: kTextSecondary,
          ),
        ),
      ],
    );
  }
}
