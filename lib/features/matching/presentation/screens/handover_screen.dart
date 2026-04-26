import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HandoverScreen extends StatefulWidget {
  final BidModel bid;
  const HandoverScreen({super.key, required this.bid});

  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  DateTime? _windowStart;
  DateTime? _windowEnd;

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('fr'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _windowStart = dt;
        if (_windowEnd != null && !_windowEnd!.isAfter(dt)) {
          _windowEnd = null;
        }
      } else {
        _windowEnd = dt;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_windowStart == null || _windowEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez définir le début et la fin de la fenêtre'),
          backgroundColor: DonyColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_windowEnd!.isAfter(_windowStart!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fin de la fenêtre doit être après le début'),
          backgroundColor: DonyColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.read<BidBloc>().add(BidHandoverRequested(
      bidId: widget.bid.id,
      location: _locationCtrl.text.trim(),
      windowStart: _windowStart!,
      windowEnd: _windowEnd!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BidBloc, BidState>(
      listener: (context, state) {
        if (state is BidHandoverSet) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fenêtre de remise enregistrée. L\'expéditeur a été notifié.'),
              backgroundColor: DonyColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<AnnouncementBloc>().add(AnnouncementListRequested());
          context.go('/announcements');
        } else if (state is BidError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: DonyColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: DonyColors.grey50,
        appBar: AppBar(
          backgroundColor: DonyColors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: DonyColors.blue400),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Fenêtre de remise',
            style: GoogleFonts.sora(
                fontWeight: FontWeight.w700, fontSize: 18, color: DonyColors.dark900),
          ),
          centerTitle: false,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: DonyColors.grey100),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoBanner(),
                const SizedBox(height: 24),
                _Section(
                  title: 'Lieu de remise',
                  child: TextFormField(
                    controller: _locationCtrl,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Lieu requis' : null,
                    decoration: _inputDecoration('Ex: Gare du Nord, Paris — Hall 2'),
                    style: GoogleFonts.sora(fontSize: 14, color: DonyColors.dark900),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'Fenêtre horaire',
                  child: Column(
                    children: [
                      _DateTimeTile(
                        label: 'Début',
                        value: _windowStart,
                        icon: Icons.schedule_rounded,
                        onTap: () => _pickDateTime(true),
                      ),
                      const SizedBox(height: 12),
                      _DateTimeTile(
                        label: 'Fin',
                        value: _windowEnd,
                        icon: Icons.schedule_rounded,
                        onTap: () => _pickDateTime(false),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ),
        ),
        bottomNavigationBar: _SubmitBar(onSubmit: _submit),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.sora(fontSize: 13, color: DonyColors.grey200),
      filled: true,
      fillColor: DonyColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DonyColors.grey100)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DonyColors.grey100)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DonyColors.blue400, width: 1.5)),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DonyColors.blue100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DonyColors.blue400.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: DonyColors.blue400, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'L\'expéditeur recevra une notification avec le lieu et l\'heure de remise dès que vous confirmez.',
              style: GoogleFonts.sora(fontSize: 13, color: DonyColors.blue600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.sora(
                fontSize: 14, fontWeight: FontWeight.w700, color: DonyColors.dark900)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final IconData icon;
  final VoidCallback onTap;
  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value != null ? DonyColors.blue400.withOpacity(0.4) : DonyColors.grey100),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: value != null ? DonyColors.blue400 : DonyColors.grey200),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.sora(fontSize: 11, color: DonyColors.grey200)),
                  const SizedBox(height: 2),
                  Text(
                    value != null
                        ? DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr').format(value!)
                        : 'Sélectionner',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      color: value != null ? DonyColors.dark900 : DonyColors.grey200,
                      fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: DonyColors.grey200, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final VoidCallback onSubmit;
  const _SubmitBar({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BidBloc, BidState>(
      builder: (context, state) {
        final isLoading = state is BidLoading;
        return Container(
          color: DonyColors.white,
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
          child: ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: DonyColors.blue400,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Confirmer la fenêtre de remise',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        );
      },
    );
  }
}
