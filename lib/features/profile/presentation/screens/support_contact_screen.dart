import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/bloc/support_contact_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

const _categories = <String>[
  'Paiement',
  'Vérification d\'identité',
  'Livraison',
  'Litige',
  'Bug technique',
  'Autre',
];

class SupportContactScreen extends StatefulWidget {
  const SupportContactScreen({super.key});

  @override
  State<SupportContactScreen> createState() => _SupportContactScreenState();
}

class _SupportContactScreenState extends State<SupportContactScreen> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _openMailto(
    BuildContext context,
    SupportContactState state,
  ) async {
    final subject = Uri.encodeComponent(
      '[${state.category}] ${state.subject.trim()}',
    );
    final body = Uri.encodeComponent(
      '${state.message.trim()}\n\n---\nEnvoyé depuis dony app',
    );
    final uri = Uri.parse(
      'mailto:support@dony.app?subject=$subject&body=$body',
    );

    if (!await launchUrl(uri)) {
      if (context.mounted) {
        DonySnackbar.show(
          context,
          message:
              'Impossible d\'ouvrir le client mail. Écris-nous à support@dony.app',
          type: DonySnackbarType.error,
        );
      }
      return;
    }

    context.read<SupportContactBloc>().add(const SupportSubmitRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SupportContactBloc, SupportContactState>(
      listener: (context, state) {
        if (state.submitStatus == SupportSubmitStatus.success) {
          DonySnackbar.show(
            context,
            message: 'Email ouvert dans ton client mail',
            type: DonySnackbarType.success,
          );
          context.pop();
        }
      },
      builder: (context, state) {
        return DonyPageScaffold(
          title: 'Contacter le support',
          stickyBottom: DonyButton(
            label: 'Envoyer un message',
            onPressed: state.isValid ? () => _openMailto(context, state) : null,
            isLoading: state.isSubmitting,
          ),
          body:
              Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoCard(),
                      const SizedBox(height: DonySpacing.xl),
                      _buildForm(context, state),
                    ],
                  )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        );
      },
    );
  }

  Widget _buildForm(BuildContext context, SupportContactState state) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Catégorie', style: tt.labelLarge?.copyWith(color: cs.onSurface)),
        const SizedBox(height: DonySpacing.sm),
        _CategoryDropdown(selected: state.category),
        const SizedBox(height: DonySpacing.base),
        Text('Sujet', style: tt.labelLarge?.copyWith(color: cs.onSurface)),
        const SizedBox(height: DonySpacing.sm),
        DonyTextField(
          controller: _subjectCtrl,
          hint: 'Résume ton problème en quelques mots',
          onChanged: (v) =>
              context.read<SupportContactBloc>().add(SupportSubjectChanged(v)),
        ),
        const SizedBox(height: DonySpacing.base),
        Text('Message', style: tt.labelLarge?.copyWith(color: cs.onSurface)),
        const SizedBox(height: DonySpacing.sm),
        TextFormField(
          controller: _messageCtrl,
          maxLines: 6,
          onChanged: (v) =>
              context.read<SupportContactBloc>().add(SupportMessageChanged(v)),
          decoration: InputDecoration(
            hintText: 'Décris ta situation avec le maximum de détails',
            hintStyle: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        if (state.message.trim().length < 20 && state.message.isNotEmpty)
          Text(
            'Au moins 20 caractères requis (${state.message.trim().length}/20)',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Row(
        children: [
          DonyIcon('headset', color: cs.primary, size: 28),
          const SizedBox(width: DonySpacing.base),
          Expanded(
            child: Text(
              'Notre équipe répond sous 24 h en moyenne.',
              style: tt.bodySmall?.copyWith(color: cs.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected.isEmpty ? null : selected,
          isExpanded: true,
          hint: Text(
            'Choisir une catégorie',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          items: _categories
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, style: tt.bodyMedium),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              context.read<SupportContactBloc>().add(
                SupportCategorySelected(v),
              );
            }
          },
        ),
      ),
    );
  }
}
