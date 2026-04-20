import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final String id;

  const AnnouncementDetailScreen({super.key, required this.id});

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AnnouncementBloc>().add(AnnouncementDetailRequested(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Détail du trajet', style: TextStyle(color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      body: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) {
          if (state is AnnouncementError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is AnnouncementLoading || state is AnnouncementInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AnnouncementDetailLoaded) {
            final announcement = state.announcement;
            final bool canEdit = announcement.status == 'ACTIVE' && (announcement.bidsCount ?? 0) == 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flight_takeoff, color: Color(0xFF1A6B3C), size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${announcement.departureCity} ➔ ${announcement.arrivalCity}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          _buildDetailRow(Icons.calendar_today, 'Date de départ', DateFormat('dd MMMM yyyy').format(announcement.departureDate)),
                          const SizedBox(height: 16),
                          _buildDetailRow(Icons.fitness_center, 'Capacité disponible', '${announcement.availableKg.toStringAsFixed(0)} kg'),
                          const SizedBox(height: 16),
                          _buildDetailRow(Icons.euro, 'Prix par kg', '${announcement.pricePerKg.toStringAsFixed(2)} €'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Demandes reçues', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A6B3C),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${announcement.bidsCount ?? 0}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  if (canEdit)
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit, color: Color(0xFF1A6B3C)),
                        label: const Text('Modifier l\'annonce', style: TextStyle(color: Color(0xFF1A6B3C), fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1A6B3C)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          context.push('/announcements/${announcement.id}/edit', extra: announcement);
                        },
                      ),
                    ),
                ],
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}
