import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/utils/phone_dialer.dart';
import 'package:dony/features/support/bloc/support_contact_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Vert de la marque WhatsApp, pour le bouton et la pastille du logo.
const Color kWhatsAppGreen = Color(0xFF1FA855);

/// Carte « Écrire sur WhatsApp » posée en tête de l'écran Support et du Centre
/// d'aide, avant tout le reste : c'est le canal le plus rapide pour joindre
/// l'équipe Yadony.
///
/// Le numéro est réglé dans l'admin (`support_whatsapp_number`). Tant qu'il
/// est vide, ou si sa lecture échoue, la carte n'occupe aucune place.
/// WhatsApp qui ne s'ouvre pas (pas installé) ouvre une feuille avec le numéro,
/// Appeler, SMS et Copier.
class SupportWhatsAppCard extends StatelessWidget {
  const SupportWhatsAppCard({
    super.key,
    required this.source,
    this.faqVariant = false,
    this.cubit,
  });

  /// Écran qui porte la carte, pour l'analytics : `support` ou `faq`.
  final String source;

  /// Titre « Besoin d'un humain ? » du Centre d'aide au lieu de celui du Support.
  final bool faqVariant;

  /// Cubit fourni par l'appelant (tests) ; sinon créé et fermé par la carte.
  final SupportContactCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    final body = _SupportWhatsAppCardBody(
      source: source,
      faqVariant: faqVariant,
    );
    if (provided != null) {
      return BlocProvider.value(value: provided, child: body);
    }
    return BlocProvider(
      create: (_) => getIt<SupportContactCubit>()..load(source: source),
      child: body,
    );
  }
}

class _SupportWhatsAppCardBody extends StatelessWidget {
  const _SupportWhatsAppCardBody({
    required this.source,
    required this.faqVariant,
  });

  final String source;
  final bool faqVariant;

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<SupportContactCubit>();
    final l = context.l10n;
    final opened = await cubit.openWhatsApp(
      message: l.supportWhatsappMessage,
      source: source,
    );
    if (opened || !context.mounted) return;
    await _showFallbackSheet(context, cubit);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportContactCubit, SupportContactState>(
      builder: (context, state) {
        if (state.status != SupportContactStatus.ready) {
          return const SizedBox.shrink();
        }
        final l = context.l10n;
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: DonyCard(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kWhatsAppGreen,
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/logos/social/whatsapp.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          semanticsLabel: 'WhatsApp',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            faqVariant
                                ? l.supportWhatsappFaqTitle
                                : l.supportWhatsappTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.supportWhatsappSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    key: const ValueKey('support-whatsapp-cta'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kWhatsAppGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                      ),
                    ),
                    onPressed: () => _open(context),
                    child: Text(
                      l.supportWhatsappCta,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  state.whatsappNumber ?? '',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Feuille de repli : le numéro en clair, puis Appeler, SMS et Copier, empilés
/// en pleine largeur dans le `stickyBottom` (libellés sur une ligne).
Future<void> _showFallbackSheet(
  BuildContext context,
  SupportContactCubit cubit,
) {
  final number = cubit.state.whatsappNumber ?? '';
  return DonyBottomSheet.show<void>(
    context,
    title: context.l10n.supportContactSheetTitle,
    subtitle: context.l10n.supportContactSheetBody,
    analyticsName: 'support/contact-fallback',
    child: Builder(
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: SelectableText(
            number,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    ),
    stickyBottom: Builder(
      builder: (sheetContext) {
        final l = sheetContext.l10n;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              label: l.supportContactCall,
              iconAsset: 'phone',
              onPressed: () {
                cubit.trackCall();
                dialPhoneNumber(sheetContext, number);
              },
            ),
            const SizedBox(height: 10),
            DonyButton(
              label: l.supportContactSms,
              iconAsset: 'message-circle',
              variant: DonyButtonVariant.secondary,
              onPressed: () async {
                final opened = await cubit.sendSms(l.supportWhatsappMessage);
                if (opened || !sheetContext.mounted) return;
                DonySnackbar.show(
                  sheetContext,
                  message: l.supportContactOpenError,
                  type: DonySnackbarType.warning,
                );
              },
            ),
            const SizedBox(height: 10),
            DonyButton(
              label: l.commonCopy,
              iconAsset: 'copy',
              variant: DonyButtonVariant.ghost,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: number));
                cubit.trackCopy();
                if (!sheetContext.mounted) return;
                DonySnackbar.show(
                  sheetContext,
                  message: l.supportContactCopied,
                  type: DonySnackbarType.success,
                );
              },
            ),
          ],
        );
      },
    ),
  );
}
