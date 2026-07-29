part of 'faq_bloc.dart';

final class FaqState extends Equatable {
  const FaqState({this.query = ''});

  final String query;

  FaqState copyWith({String? query}) {
    return FaqState(query: query ?? this.query);
  }

  @override
  List<Object?> get props => [query];
}
