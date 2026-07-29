import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/bloc/support_contact_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

const _supportEmail = 'support@yadony.com';

String _encodeQueryParameters(Map<String, String> parameters) {
  return parameters.entries
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}='
            '${Uri.encodeComponent(entry.value)}',
      )
      .join('&');
}

Uri buildSupportMailtoUri(SupportContactState state) {
  return Uri(
    scheme: 'mailto',
    path: _supportEmail,
    query: _encodeQueryParameters({
      'subject': '[${state.category}] ${state.subject.trim()}',
      'body': '${state.message.trim()}\n\n---\nEnvoyé depuis Yadony',
    }),
  );
}

const _categories = <String>[
  'Paiement',
  'Annulation et remboursement',
  'Vérification d\'identité',
  'Compte et sécurité',
  'Livraison',
  'Litige',
  'Signalement ou fraude',
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
    final bloc = context.read<SupportContactBloc>();
    bloc.add(const SupportSubmitRequested());

    final uri = buildSupportMailtoUri(state);

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        bloc.add(
          const SupportEmailComposerFailed(reason: 'mail_client_unavailable'),
        );
        return;
      }
      bloc.add(const SupportEmailComposerOpened());
    } catch (_) {
      bloc.add(
        const SupportEmailComposerFailed(reason: 'mail_launch_exception'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SupportContactBloc, SupportContactState>(
      listener: (context, state) {
        if (state.submitStatus == SupportSubmitStatus.success) {
          DonySnackbar.show(
            context,
            message: 'Brouillon ouvert dans ton application Mail',
            type: DonySnackbarType.success,
          );
        } else if (state.submitStatus == SupportSubmitStatus.error) {
          DonySnackbar.show(
            context,
            message:
                state.errorMessage ??
                'Impossible d\'ouvrir l\'application Mail.',
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        return DonyPageScaffold(
          title: 'Contacter le support',
          stickyBottom: DonyButton(
            label: 'Continuer dans l\'app Mail',
            iconAsset: 'mail',
            onPressed: state.isValid && !state.isSubmitting
                ? () => _openMailto(context, state)
                : null,
            isLoading: state.isSubmitting,
          ),
          body:
              Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _InfoCard(),
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
        _RequiredFieldLabel(
          label: 'Catégorie',
          textStyle: tt.labelLarge?.copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: DonySpacing.sm),
        _CategoryDropdown(selected: state.category),
        const SizedBox(height: DonySpacing.base),
        _RequiredFieldLabel(
          label: 'Sujet',
          textStyle: tt.labelLarge?.copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyTextField(
          controller: _subjectCtrl,
          hint: 'Résume ton problème en quelques mots',
          onChanged: (v) =>
              context.read<SupportContactBloc>().add(SupportSubjectChanged(v)),
        ),
        const SizedBox(height: DonySpacing.base),
        _RequiredFieldLabel(
          label: 'Message',
          textStyle: tt.labelLarge?.copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyTextField(
          controller: _messageCtrl,
          maxLines: 6,
          hint: 'Décris ta situation avec le maximum de détails',
          onChanged: (v) =>
              context.read<SupportContactBloc>().add(SupportMessageChanged(v)),
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

class _RequiredFieldLabel extends StatelessWidget {
  const _RequiredFieldLabel({required this.label, required this.textStyle});

  final String label;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, obligatoire',
      excludeSemantics: true,
      child: Row(
        children: [
          Text(label, style: textStyle),
          Text(
            ' *',
            style: textStyle?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (context.mounted) {
      DonySnackbar.show(
        context,
        message: 'Adresse email copiée',
        type: DonySnackbarType.success,
      );
    }
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('headset', color: cs.primary, size: 28),
          const SizedBox(width: DonySpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notre équipe répond sous 24 h en moyenne.',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _supportEmail,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copier l\'adresse email',
                      onPressed: () => _copyEmail(context),
                      icon: DonyIcon('copy', color: cs.primary, size: 20),
                    ),
                  ],
                ),
              ],
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
