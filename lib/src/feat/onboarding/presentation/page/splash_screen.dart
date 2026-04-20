import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:relay_app/src/core/widget/actionable_error.dart';
import 'package:relay_app/src/feat/onboarding/bloc/onboarding_bloc.dart';
import 'package:relay_app/src/feat/onboarding/presentation/widgets/splash_loading.dart';
import 'package:relay_app/src/feat/transfer/presentation/page/home_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<OnboardingBloc, OnboardingState>(
        listener: (context, state) {
          if (state is OnboardingSuccess) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
            );
          }
        },
        builder: (context, state) {
          if (state is OnboardingLoading || state is OnboardingInitial) {
            return const SplashLoadingWidget();
          }

          if (state is OnboardingFailure) {
            return ActionableErrorWidget(
              errorMessage: state.errorMessage,
              onRetry: () {
                context.read<OnboardingBloc>().add(
                  const ProvisionIdentityRequested(),
                );
              },
            );
          }

          return const SplashLoadingWidget();
        },
      ),
    );
  }
}
