import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RatingBottomSheet extends StatefulWidget {
  const RatingBottomSheet({
    super.key,
    required this.bidId,
    required this.travelerName,
    this.starsNotifier,
    this.onSubmitReady,
  });

  final String bidId;
  final String travelerName;
  final ValueNotifier<int>? starsNotifier;
  final void Function(VoidCallback)? onSubmitReady;

  static Future<void> show(
    BuildContext context, {
    required String bidId,
    required String travelerName,
  }) {
    final ratingBloc = context.read<RatingBloc>();
    final starsNotifier = ValueNotifier<int>(0);
    VoidCallback? submit;
    return DonyBottomSheet.show(
      context,
      title: 'Évaluer $travelerName',
      subtitle: 'Votre avis aide la communauté dony',
      wrapper: (child) => BlocProvider.value(value: ratingBloc, child: child),
      stickyBottom: ValueListenableBuilder<int>(
        valueListenable: starsNotifier,
        builder: (ctx, stars, _) => BlocBuilder<RatingBloc, RatingState>(
          builder: (ctx, state) {
            final isLoading = state is RatingLoading;
            return DonyButton(
              label: "Envoyer l'évaluation",
              icon: Icons.star_rounded,
              isLoading: isLoading,
              onPressed: (stars > 0 && !isLoading) ? () => submit?.call() : null,
            );
          },
        ),
      ),
      child: RatingBottomSheet(
        bidId: bidId,
        travelerName: travelerName,
        starsNotifier: starsNotifier,
        onSubmitReady: (fn) => submit = fn,
      ),
    ).whenComplete(starsNotifier.dispose);
  }

  @override
  State<RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends State<RatingBottomSheet> {
  final _commentCtrl = TextEditingController();

  int get _stars => widget.starsNotifier?.value ?? 0;

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_submit);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_stars == 0) return;
    context.read<RatingBloc>().add(RatingSubmitRequested(
      bidId: widget.bidId,
      stars: _stars,
      comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<RatingBloc, RatingState>(
      listener: (context, state) {
        if (state is RatingSuccess) {
          Navigator.of(context).pop();
          DonySnackbar.show(context, message: 'Merci pour votre évaluation !', type: DonySnackbarType.success);
        } else if (state is RatingError) {
          DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
        }
      },
      builder: (context, state) {
        return ValueListenableBuilder<int>(
          valueListenable: widget.starsNotifier ?? ValueNotifier(0),
          builder: (ctx, stars, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StarSelector(
                selected: stars,
                onSelect: (s) {
                  if (widget.starsNotifier != null) {
                    widget.starsNotifier!.value = s;
                  }
                },
              ),
              if (stars > 0)
                Center(
                  child: Text(
                    _starLabel(stars),
                    style: tt.labelLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate().fadeIn(duration: 200.ms),
              const SizedBox(height: DonySpacing.base),
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                maxLength: 200,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Commentaire (facultatif)',
                  hintText: 'Partagez votre expérience…',
                  filled: true,
                  fillColor: cs.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                    borderSide: BorderSide(color: cs.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                    borderSide: BorderSide(color: cs.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _starLabel(int s) => switch (s) {
    1 => 'Très décevant',
    2 => 'Décevant',
    3 => 'Correct',
    4 => 'Bien',
    5 => 'Excellent !',
    _ => '',
  };
}

class _StarSelector extends StatelessWidget {
  const _StarSelector({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final idx = i + 1;
            final filled = idx <= selected;
            return GestureDetector(
              onTap: () => onSelect(idx),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Builder(
                    builder: (context) => Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      key: ValueKey(filled),
                      size: 44,
                      color: filled
                          ? const Color(0xFFF59E0B)
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
