import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/support/bloc/support_contact_cubit.dart';
import 'package:dony/features/support/presentation/widgets/support_whatsapp_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Ligne fine « Écrire au support Yadony » posée sous la bannière du trajet, en
/// haut d'une discussion entre utilisateurs. Un appui ouvre WhatsApp sur
/// l'équipe Yadony, message pré-rempli avec le trajet de la discussion (jamais
/// de nom ni de numéro).
///
/// Une seule ligne de texte, d'une quarantaine de points de haut : elle ne
/// prend pas de place sur un petit écran. Le numéro est réglé dans l'admin :
/// tant qu'il est vide, ou si sa lecture échoue, la ligne n'occupe aucune
/// place. WhatsApp qui ne s'ouvre pas ouvre la feuille de repli du support
/// (Appeler, SMS, Copier).
class ChatSupportLine extends StatelessWidget {
  const ChatSupportLine({super.key, this.tripLabel, this.cubit});

  /// Trajet de la discussion (« Paris → Dakar · 12 janv. · 5 kg »), repris dans
  /// le message pré-rempli. Sans trajet, le message générique du support.
  final String? tripLabel;

  /// Cubit fourni par l'appelant (tests) ; sinon créé et fermé par la ligne.
  final SupportContactCubit? cubit;

  /// Écran qui porte la ligne, pour l'analytics.
  static const source = 'chat';

  @override
  Widget build(BuildContext context) {
    final body = _ChatSupportLineBody(tripLabel: tripLabel);
    final provided = cubit;
    if (provided != null) {
      return BlocProvider.value(value: provided, child: body);
    }
    // Le support est un plus : sans cubit enregistré, la discussion s'affiche
    // sans la ligne plutôt que de planter.
    if (!getIt.isRegistered<SupportContactCubit>()) {
      return const SizedBox.shrink();
    }
    return BlocProvider(
      create: (_) => getIt<SupportContactCubit>()..load(source: source),
      child: body,
    );
  }
}

class _ChatSupportLineBody extends StatelessWidget {
  const _ChatSupportLineBody({required this.tripLabel});

  final String? tripLabel;

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
        final linkColor = theme.brightness == Brightness.dark
            ? kWhatsAppGreen
            : const Color(0xFF12803F);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: l.chatSupportCta,
              excludeSemantics: true,
              child: InkWell(
                key: const Key('chat-support-line'),
                onTap: () => openSupportWhatsApp(
                  context,
                  context.read<SupportContactCubit>(),
                  source: ChatSupportLine.source,
                  message: tripLabel == null
                      ? null
                      : l.chatSupportMessageWithTrip(tripLabel!),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.lg,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: kWhatsAppGreen,
                            borderRadius: BorderRadius.circular(DonyRadius.sm),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/logos/social/whatsapp.svg',
                              width: 13,
                              height: 13,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: DonySpacing.sm),
                        Expanded(
                          child: Text(
                            l.chatSupportCta,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: linkColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
          ],
        );
      },
    );
  }
}
