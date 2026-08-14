import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/presentation/widgets/star_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({
    super.key,
    required this.bidId,
    required this.travelerName,
  });

  final String bidId;
  final String travelerName;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _stars = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_stars == 0) {
      return;
    }
    context.read<RatingBloc>().add(
      RatingSubmitRequested(
        bidId: widget.bidId,
        stars: _stars,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<RatingBloc, RatingState>(
      listener: (context, state) {
        if (state is RatingSuccess) {
          DonySnackbar.show(
            context,
            message: 'Merci pour votre évaluation !',
            type: DonySnackbarType.success,
          );
          context.pop();
        } else if (state is RatingError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      builder: (context, state) {
        final isLoading = state is RatingLoading;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: const DonyAppBar(title: 'Évaluation'),
          body: Builder(
            builder: (context) {
              final h = DonyLayout.hPadding(context);
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  h,
                  DonySpacing.xs,
                  h,
                  DonySpacing.huge,
                ),
                child: DonyLayout.constrained(
                  context,
                  Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Title ───────────────────────────────────────────
                          Text(
                            'Évaluer le voyageur',
                            style: DonyTypography.caveat(
                              fontSize: 28,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: DonySpacing.xs),
                          Text(
                            'Comment s\'est passée votre expérience avec ${widget.travelerName} ?',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: DonySpacing.xl),

                          // ── Star selector ────────────────────────────────────
                          StarSelector(
                            selected: _stars,
                            onSelect: (s) => setState(() => _stars = s),
                          ),
                          const SizedBox(height: DonySpacing.base),
                          if (_stars > 0)
                            Center(
                              child: Text(
                                _starLabel(_stars),
                                style: tt.labelLarge?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ).animate().fadeIn(duration: 200.ms),
                          const SizedBox(height: DonySpacing.xl),

                          // ── Comment field ────────────────────────────────────
                          TextField(
                            controller: _commentController,
                            maxLines: 4,
                            maxLength: 200,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Commentaire (facultatif)',
                              hintText: 'Partagez votre expérience…',
                              hintStyle: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              filled: true,
                              fillColor: cs.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  DonyRadius.card,
                                ),
                                borderSide: BorderSide(color: cs.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  DonyRadius.card,
                                ),
                                borderSide: BorderSide(color: cs.outline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  DonyRadius.card,
                                ),
                                borderSide: BorderSide(
                                  color: cs.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: DonySpacing.xl),

                          // ── CTA ──────────────────────────────────────────────
                          DonyButton(
                            label: 'Envoyer l\'évaluation',
                            iconAsset: 'star',
                            isLoading: isLoading,
                            onPressed: (_stars > 0 && !isLoading)
                                ? () => _submit(context)
                                : null,
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _starLabel(int stars) => switch (stars) {
    1 => 'Très décevant',
    2 => 'Décevant',
    3 => 'Correct',
    4 => 'Bien',
    5 => 'Excellent !',
    _ => '',
  };
}
