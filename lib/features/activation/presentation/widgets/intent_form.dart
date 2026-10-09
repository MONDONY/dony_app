import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/phone/phone_country.dart';
import 'package:dony/core/utils/text_search.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/widgets/intent_other_country_sheet.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Corridors de lancement, toujours affichés en tête dans cet ordre.
const List<String> kIntentLeadDestinations = ['SN', 'CI', 'ML', 'CM'];

/// Les 14 pays UEMOA + CEMAC acceptés par le serveur comme destination
/// principale (`ActivationService.declareIntent` → `CountryCatalog`) ;
/// « Autre » en plus.
const List<String> kIntentDestinations = [
  ...kIntentLeadDestinations,
  'BJ',
  'BF',
  'GW',
  'NE',
  'TG',
  'CF',
  'TD',
  'CG',
  'GQ',
  'GA',
];

/// Ordre d'affichage : [kIntentLeadDestinations] puis les autres pays par
/// ordre alphabétique de leur nom dans la langue de [l] (accents ignorés).
List<String> orderedIntentDestinations(AppLocalizations l) {
  final others =
      kIntentDestinations
          .where((code) => !kIntentLeadDestinations.contains(code))
          .toList()
        ..sort(
          (a, b) => normalizeSearch(
            countryName(l, a),
          ).compareTo(normalizeSearch(countryName(l, b))),
        );
  return [...kIntentLeadDestinations, ...others];
}

/// « Vous utilisez Yadony pour… » + « Votre destination principale », lu et écrit dans [IntentCubit].
class IntentForm extends StatelessWidget {
  const IntentForm({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = context.watch<IntentCubit>().state;
    final cubit = context.read<IntentCubit>();
    final options = [
      (UserIntent.sender, '📦', l.intentSender, l.intentSenderHint, 'sender'),
      (
        UserIntent.traveler,
        '✈️',
        l.intentTraveler,
        l.intentTravelerHint,
        'traveler',
      ),
      (UserIntent.both, '🔁', l.intentBoth, l.intentBothHint, 'both'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (intent, emoji, title, hint, key) in options) ...[
          _IntentOption(
            key: Key('intent-option-$key'),
            emoji: emoji,
            title: title,
            hint: hint,
            selected: state.intent == intent,
            onTap: () => cubit.selectIntent(intent),
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
        const SizedBox(height: DonySpacing.base),
        Text(
          l.intentDestinationTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.intentDestinationHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: [
            for (final code in orderedIntentDestinations(l))
              DonyChip(
                key: Key('intent-destination-$code'),
                label: _countryLabel(l, code),
                selected: state.destination == code,
                onTap: () => cubit.selectDestination(code),
              ),
            DonyChip(
              key: const Key('intent-destination-$kIntentOtherDestination'),
              label: isIntentOtherCountry(state.destination)
                  ? _countryLabel(l, state.destination!)
                  : l.intentDestinationOther,
              selected:
                  state.destination == kIntentOtherDestination ||
                  isIntentOtherCountry(state.destination),
              onTap: () => _pickOtherCountry(context, cubit),
            ),
          ],
        ),
      ],
    );
  }
}

/// Drapeau + nom localisé d'un pays.
String _countryLabel(AppLocalizations l, String code) =>
    '${phoneCountryForCode(code)?.flag ?? ''} ${countryName(l, code)}'.trim();

/// « Autre » ouvre le sélecteur des 24 autres pays du catalogue (FLUTTER-H9).
/// Fermer sans choisir garde un pays déjà choisi derrière « Autre » ; sinon
/// « Autre » est retenu sans pays précis (comportement d'avant).
Future<void> _pickOtherCountry(BuildContext context, IntentCubit cubit) async {
  final current = cubit.state.destination;
  final picked = await IntentOtherCountrySheet.show(
    context,
    selectedCode:
        isIntentOtherCountry(current) || current == kIntentOtherDestination
        ? current
        : null,
  );
  if (cubit.isClosed) return;
  final latest = cubit.state.destination;
  cubit.selectDestination(
    picked ??
        (isIntentOtherCountry(latest) ? latest! : kIntentOtherDestination),
  );
}

class _IntentOption extends StatelessWidget {
  const _IntentOption({
    super.key,
    required this.emoji,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(DonyRadius.card);
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      excludeSemantics: true,
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
            child: Padding(
              padding: const EdgeInsets.all(DonySpacing.base),
              child: Row(
                children: [
                  Text(emoji, style: text.headlineSmall), // i18n-ignore
                  const SizedBox(width: DonySpacing.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          hint,
                          style: text.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(Icons.check_circle, color: cs.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
