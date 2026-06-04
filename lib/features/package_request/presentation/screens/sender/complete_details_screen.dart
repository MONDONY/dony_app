import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/complete_details_bloc.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CompleteDetailsScreen extends StatelessWidget {
  const CompleteDetailsScreen({required this.requestId, super.key});
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CompleteDetailsBloc>(
      create: (_) => getIt<CompleteDetailsBloc>(),
      child: _CompleteDetailsView(requestId: requestId),
    );
  }
}

class _CompleteDetailsView extends StatefulWidget {
  const _CompleteDetailsView({required this.requestId});
  final String requestId;

  @override
  State<_CompleteDetailsView> createState() => _CompleteDetailsViewState();
}

class _CompleteDetailsViewState extends State<_CompleteDetailsView> {
  final _form = GlobalKey<FormState>();
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  final _recipientCityCtrl = TextEditingController();

  @override
  void dispose() {
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _recipientCityCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final city = _recipientCityCtrl.text.trim();
    context.read<CompleteDetailsBloc>().add(CompleteDetailsSubmitted(
          requestId: widget.requestId,
          recipientName: _recipientNameCtrl.text.trim(),
          recipientPhone: _recipientPhoneCtrl.text.trim(),
          recipientCity: city.isEmpty ? null : city,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CompleteDetailsBloc, CompleteDetailsState>(
      listener: (context, state) {
        if (state.status == CompleteDetailsStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Détails enregistrés'),
              backgroundColor: kSuccess,
            ),
          );
          context.pop(true);
        } else if (state.status == CompleteDetailsStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Erreur'),
              backgroundColor: kError,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const DonyAppBar(title: 'Détails de livraison'),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  DonySpacing.lg, DonySpacing.xl, DonySpacing.lg, MediaQuery.of(context).padding.bottom + 100),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section('Destinataire'),
                    TextFormField(
                      controller: _recipientNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Nom complet'),
                      validator: _required,
                    ),
                    const SizedBox(height: DonySpacing.md),
                    TextFormField(
                      controller: _recipientPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        hintText: '+221771234567',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requis';
                        if (!RegExp(r'^\+[1-9]\d{6,14}$')
                            .hasMatch(v.trim())) {
                          return 'Format E.164 (+221…)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: DonySpacing.md),
                    TextFormField(
                      controller: _recipientCityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ville / commune',
                        hintText: 'Ex. Dakar (optionnel)',
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
              child: BlocBuilder<CompleteDetailsBloc, CompleteDetailsState>(
                builder: (context, state) => DonyButton(
                  label: state.isLoading ? 'Envoi…' : 'Confirmer',
                  isLoading: state.isLoading,
                  onPressed: state.isLoading ? null : _submit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: DonySpacing.sm),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: kTextSecondary,
            letterSpacing: 1.2,
          ),
        ),
      );

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requis' : null;
}
