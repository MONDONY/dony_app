import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({super.key});

  @override
  State<AnnouncementListScreen> createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AnnouncementBloc>().add(AnnouncementListRequested());
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return const Color(0xFF69F0AE); // Light green
      case 'FULL':
        return Colors.orangeAccent;
      case 'COMPLETED':
        return Colors.blueAccent;
      case 'CANCELLED':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'ACTIVE':
        return 'Actif';
      case 'FULL':
        return 'Complet';
      case 'COMPLETED':
        return 'Terminé';
      case 'CANCELLED':
        return 'Annulé';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Mes trajets', style: TextStyle(color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          if (state is AnnouncementLoading || state is AnnouncementInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AnnouncementError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Erreur: ${state.message}', style: const TextStyle(color: Colors.red)),
                  TextButton(
                    onPressed: () {
                      context.read<AnnouncementBloc>().add(AnnouncementListRequested());
                    },
                    child: const Text('Réessayer'),
                  )
                ],
              ),
            );
          }

          if (state is AnnouncementListLoaded) {
            final announcements = state.announcements;
            if (announcements.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Vous n\'avez publié aucun trajet.', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A6B3C)),
                      onPressed: () => context.push('/announcements/create'),
                      child: const Text('Publier un trajet', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<AnnouncementBloc>().add(AnnouncementListRequested());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final item = announcements[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        context.push('/announcements/${item.id}');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.departureCity} ➔ ${item.arrivalCity}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(item.status).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _formatStatus(item.status),
                                    style: TextStyle(color: _getStatusColor(item.status), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(DateFormat('dd/MM/yyyy').format(item.departureDate)),
                                const SizedBox(width: 16),
                                const Icon(Icons.fitness_center, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('${item.availableKg.toStringAsFixed(1)} kg disp.'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.inbox, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  '${item.bidsCount ?? 0} demande${(item.bidsCount ?? 0) != 1 ? 's' : ''} reçue${(item.bidsCount ?? 0) != 1 ? 's' : ''}',
                                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }

          return const SizedBox();
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A6B3C),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          context.push('/announcements/create');
        },
      ),
    );
  }
}
