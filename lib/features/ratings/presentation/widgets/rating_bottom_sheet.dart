import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/presentation/rating_labels.dart';
import 'package:dony/features/ratings/presentation/widgets/star_selector.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RatingBottomSheet extends StatefulWidget {
  const RatingBottomSheet({
    super.key,
    required this.bidId,
    this.travelerName,
    this.starsNotifier,
    this.onSubmitReady,
    this.isTravelerRating = false,
  });

  final String bidId;
  // Nullable : un appelant qui évalue l'expéditeur (isTravelerRating: true)
  // n'a pas besoin de fournir de nom, le titre complet vient de F3.
  final String? travelerName;
  final ValueNotifier<int>? starsNotifier;
  final void Function(VoidCallback)? onSubmitReady;
  final bool isTravelerRating;

  static Future<void> show(
    BuildContext context, {
    required String bidId,
    String? travelerName,
    bool isTravelerRating = false,
  }) {
    final ratingBloc = context.read<RatingBloc>();
    final l = context.l10n;
    final starsNotifier = ValueNotifier<int>(0);
    VoidCallback? submit;
    return DonyBottomSheet.show(
      context,
      title: isTravelerRating
          ? l.ratingRateSender
          : l.ratingRateTraveler(travelerName!),
      subtitle: l.ratingSubtitle,
      wrapper: (child) => BlocProvider.value(value: ratingBloc, child: child),
      stickyBottom: ValueListenableBuilder<int>(
        valueListenable: starsNotifier,
        builder: (ctx, stars, _) => BlocBuilder<RatingBloc, RatingState>(
          builder: (ctx, state) {
            final isLoading = state is RatingLoading;
            return DonyButton(
              label: l.ratingSubmitAction,
              iconAsset: 'star',
              isLoading: isLoading,
              onPressed: (stars > 0 && !isLoading)
                  ? () => submit?.call()
                  : null,
            );
          },
        ),
      ),
      child: RatingBottomSheet(
        bidId: bidId,
        travelerName: travelerName,
        starsNotifier: starsNotifier,
        onSubmitReady: (fn) => submit = fn,
        isTravelerRating: isTravelerRating,
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
    final comment = _commentCtrl.text.trim().isEmpty
        ? null
        : _commentCtrl.text.trim();
    if (widget.isTravelerRating) {
      context.read<RatingBloc>().add(
        TravelerRatingSubmitRequested(
          bidId: widget.bidId,
          stars: _stars,
          comment: comment,
        ),
      );
    } else {
      context.read<RatingBloc>().add(
        RatingSubmitRequested(
          bidId: widget.bidId,
          stars: _stars,
          comment: comment,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return BlocConsumer<RatingBloc, RatingState>(
      listener: (context, state) {
        if (state is RatingSuccess) {
          Navigator.of(context).pop();
          DonySnackbar.show(
            context,
            message: l.ratingThanksSnackbar,
            type: DonySnackbarType.success,
          );
        } else if (state is RatingError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      builder: (context, state) {
        return ValueListenableBuilder<int>(
          valueListenable: widget.starsNotifier ?? ValueNotifier(0),
          builder: (ctx, stars, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StarSelector(
                // Marge verticale que portait l'ancien sélecteur local du
                // sheet, absente de celui de l'écran.
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
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
                    ratingStarLabel(l, stars),
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
                  labelText: l.ratingCommentLabel,
                  hintText: l.ratingCommentHint,
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
}
