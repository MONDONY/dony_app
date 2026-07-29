part of 'faq_bloc.dart';

sealed class FaqEvent extends Equatable {
  const FaqEvent();

  @override
  List<Object?> get props => [];
}

final class FaqSearchChanged extends FaqEvent {
  const FaqSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class FaqQuestionOpened extends FaqEvent {
  const FaqQuestionOpened({required this.categoryId, required this.questionId});

  final String categoryId;
  final String questionId;

  @override
  List<Object?> get props => [categoryId, questionId];
}

final class FaqContactRequested extends FaqEvent {
  const FaqContactRequested();
}
