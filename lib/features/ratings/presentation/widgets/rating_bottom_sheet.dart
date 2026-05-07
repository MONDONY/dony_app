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
  });

  final String bidId;
  final String travelerName;

  static Future<void> show(
    BuildContext context, {
    required String bidId,
    required String travelerName,
  }) {
    return DonyBottomSheet.show(
      context,
      title: 'Évaluer $travelerName',
      subtitle: 'Votre avis aide la communauté dony',
      child: BlocProvider.value(
        value: context.read<RatingBloc>(),
        child: RatingBottomSheet(bidId: bidId, travelerName: travelerName),
      ),
    );
  }

  @override
  State<RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends State<RatingBottomSheet> {
  int _stars = 0;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_stars == 0) {
      return;
    }
    context.read<RatingBloc>().add(RatingSubmitRequested(
      bidId: widget.bidId,
      stars: _stars,
      comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

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
        final isLoading = state is RatingLoading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StarSelector(
              selected: _stars,
              onSelect: (s) => setState(() => _stars = s),
            ),
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
                fillColor: DonyColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  borderSide: const BorderSide(color: DonyColors.neutral200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  borderSide: const BorderSide(color: DonyColors.neutral200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  borderSide: const BorderSide(color: DonyColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.base),
            DonyButton(
              label: 'Envoyer l\'évaluation',
              icon: Icons.star_rounded,
              isLoading: isLoading,
              onPressed: (_stars > 0 && !isLoading) ? () => _submit(context) : null,
            ),
            const SizedBox(height: DonySpacing.base),
          ],
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
      ),
    );
  }
}
