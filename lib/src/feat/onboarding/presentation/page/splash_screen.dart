import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:relay_app/src/core/widget/actionable_error.dart';
import 'package:relay_app/src/feat/onboarding/bloc/onboarding_bloc.dart';
import 'package:relay_app/src/feat/home/presentation/home_screen.dart';
import 'package:relay_app/src/feat/onboarding/presentation/widgets/splash_loading.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<OnboardingBloc, OnboardingState>(
        listener: (ctx, state) {
          if (state is OnboardingSuccess) {
            Navigator.of(ctx).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
            );
          }
        },
        builder: (ctx, state) {
          if (state is OnboardingLoading || state is OnboardingInitial) {
            return const SplashLoadingWidget();
          }

          if (state is OnboardingFailure) {
            return ActionableErrorWidget(
              errorMessage: state.errorMessage,
              onRetry: () {
                ctx.read<OnboardingBloc>().add(
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
