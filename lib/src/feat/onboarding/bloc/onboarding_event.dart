part of 'onboarding_bloc.dart';

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

final class AppStarted extends OnboardingEvent {
  const AppStarted();
}

final class ProvisionIdentityRequested extends OnboardingEvent {
  const ProvisionIdentityRequested();
}
