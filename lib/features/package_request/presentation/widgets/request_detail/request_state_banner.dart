import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

enum RequestBannerTone { neutral, warning, info }

class RequestStateBanner extends StatelessWidget {
  const RequestStateBanner({
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final RequestBannerTone tone;
  final String icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Même table de tons que RequestPillTone (request_status_pill.dart) :
    // couleurs lues dans le ColorScheme, jamais de primitive DonyColors figée.
    final (bg, fg) = switch (tone) {
      RequestBannerTone.neutral => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      RequestBannerTone.warning => (cs.warningLight, cs.warning),
      RequestBannerTone.info => (cs.primaryContainer, cs.primary),
    };
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(DonyRadius.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(10)),
            child: Center(child: DonyIcon(icon, size: 18, color: fg)),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 2),
                Text(message, style: TextStyle(fontSize: 13, height: 1.45, color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
