import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:relay_app/src/core/error/exception.dart';
import 'package:relay_app/src/core/util/code_generator.dart';
import 'package:relay_app/src/feat/onboarding/data/repo/onboarding_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({required OnboardingRepository repository})
    : _repository = repository,
      super(OnboardingInitial()) {
    on<AppStarted>(_onAppStarted);
    on<ProvisionIdentityRequested>(_onProvisionIdentityRequested);
  }

  final OnboardingRepository _repository;

  Future<void> _onAppStarted(
    AppStarted event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(const OnboardingLoading(message: 'Checking your local identity...'));

    final shortCode = _repository.getLocalShortCode();
    if (shortCode != null) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        emit(
          const OnboardingFailure(
            errorMessage:
                'Local identity found, but Supabase session is missing. Please reconnect.',
          ),
        );
        return;
      }

      emit(OnboardingSuccess(shortCode: shortCode, userId: userId));
      return;
    }

    add(const ProvisionIdentityRequested());
  }

  Future<void> _onProvisionIdentityRequested(
    ProvisionIdentityRequested event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(const OnboardingLoading(message: 'Creating secure session...'));

    try {
      final userId = await _repository.signInAnonymously();
      var isRegistered = false;
      String generatedCode = '';

      emit(const OnboardingLoading(message: 'Assigning your Relay ID...'));

      while (!isRegistered) {
        generatedCode = CodeGenerator.generateShortCode();

        try {
          await _repository.registerShortCode(userId, generatedCode);
          isRegistered = true;
        } on ShortCodeCollisionException catch (error) {
          debugPrint(error.toString());
        }
      }

      emit(const OnboardingLoading(message: 'Finalizing setup...'));
      await _repository.saveLocalShortCode(generatedCode);
      emit(OnboardingSuccess(shortCode: generatedCode, userId: userId));
    } on Exception catch (error) {
      emit(OnboardingFailure(errorMessage: error.toString()));
    }
  }
}
