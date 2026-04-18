part of 'onboarding_bloc.dart';

abstract class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object?> get props => [];
}

final class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();
}

final class OnboardingLoading extends OnboardingState {
  const OnboardingLoading();
}

final class OnboardingSuccess extends OnboardingState {
  const OnboardingSuccess({required this.shortCode, required this.userId});

  final String shortCode;
  final String userId;

  @override
  List<Object?> get props => [shortCode, userId];
}

final class OnboardingFailure extends OnboardingState {
  const OnboardingFailure({required this.errorMessage});

  final String errorMessage;

  @override
  List<Object?> get props => [errorMessage];
}
