import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
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
    context.read<RatingBloc>().add(RatingSubmitRequested(
          bidId: widget.bidId,
          stars: _stars,
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

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
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is RatingLoading;

        return Scaffold(
          backgroundColor: DonyColors.bg,
          appBar: AppBar(
            backgroundColor: DonyColors.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: DonySpacing.base,
            title: GestureDetector(
              onTap: () => context.pop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_ios_rounded,
                    size: 16,
                    color: DonyColors.ink900,
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    'Retour',
                    style:
                        tt.bodyMedium?.copyWith(color: DonyColors.ink900),
                  ),
                ],
              ),
            ),
          ),
          body: Builder(builder: (context) {
            final h = DonyLayout.hPadding(context);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  h, DonySpacing.xs, h, DonySpacing.huge),
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
                        color: DonyColors.ink900,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      'Comment s\'est passée votre expérience avec ${widget.travelerName} ?',
                      style: tt.bodyMedium
                          ?.copyWith(color: DonyColors.neutral400),
                    ),
                    const SizedBox(height: DonySpacing.xl),

                    // ── Star selector ────────────────────────────────────
                    _StarSelector(
                      selected: _stars,
                      onSelect: (s) => setState(() => _stars = s),
                    ),
                    const SizedBox(height: DonySpacing.base),
                    if (_stars > 0)
                      Center(
                        child: Text(
                          _starLabel(_stars),
                          style: tt.labelLarge?.copyWith(
                            color: DonyColors.primary,
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
                        hintStyle: tt.bodyMedium
                            ?.copyWith(color: DonyColors.neutral400),
                        filled: true,
                        fillColor: DonyColors.white,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DonyRadius.card),
                          borderSide:
                              const BorderSide(color: DonyColors.neutral200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DonyRadius.card),
                          borderSide:
                              const BorderSide(color: DonyColors.neutral200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DonyRadius.card),
                          borderSide: const BorderSide(
                              color: DonyColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xl),

                    // ── CTA ──────────────────────────────────────────────
                    DonyButton(
                      label: 'Envoyer l\'évaluation',
                      icon: Icons.star_rounded,
                      isLoading: isLoading,
                      onPressed:
                          (_stars > 0 && !isLoading) ? () => _submit(context) : null,
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms).slideY(
                    begin: 0.04, curve: Curves.easeOutCubic),
              ),
            );
          }),
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

// ── Star selector ─────────────────────────────────────────────────────────────

class _StarSelector extends StatelessWidget {
  const _StarSelector({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final index = i + 1;
          final filled = index <= selected;
          return GestureDetector(
            onTap: () => onSelect(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  key: ValueKey(filled),
                  size: 44,
                  color: filled ? const Color(0xFFF59E0B) : DonyColors.neutral200,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
