import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

enum _BubbleStyle { assistant, user, live }

/// Bulle du dialogue. `live` : transcription en cours, bordure en pointillés.
class AiChatBubble extends StatelessWidget {
  const AiChatBubble.assistant({super.key, required this.text})
    : _style = _BubbleStyle.assistant,
      label = null;

  const AiChatBubble.user({super.key, required this.text})
    : _style = _BubbleStyle.user,
      label = null;

  const AiChatBubble.live({
    super.key,
    required this.text,
    required String this.label,
  }) : _style = _BubbleStyle.live;

  final String text;
  final String? label;
  final _BubbleStyle _style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isUser = _style == _BubbleStyle.user;
    final background = switch (_style) {
      _BubbleStyle.assistant => cs.surfaceContainerHigh,
      _BubbleStyle.user => cs.primaryContainer,
      _BubbleStyle.live => cs.surface,
    };
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label case final caption?)
          Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.xs),
            child: Text(
              caption,
              style: tt.labelSmall?.copyWith(color: cs.primary),
            ),
          ),
        Text(
          text.isEmpty && _style == _BubbleStyle.live ? '…' : text,
          style: tt.bodyMedium?.copyWith(
            color: isUser ? cs.onPrimaryContainer : cs.onSurface,
          ),
        ),
      ],
    );
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: content,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: _style == _BubbleStyle.live
            ? CustomPaint(
                foregroundPainter: _DashedBorderPainter(cs.primary),
                child: bubble,
              )
            : bubble,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(DonyRadius.card),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
