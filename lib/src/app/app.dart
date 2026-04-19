import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/feat/onboarding/bloc/onboarding_bloc.dart';
import 'package:relay_app/src/feat/onboarding/data/repo/onboarding_repo.dart';
import 'package:relay_app/src/feat/onboarding/presentation/page/splash_screen.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer_bloc.dart';
import 'package:relay_app/src/feat/transfer/data/repo/transfer_repository.dart';

class RelayApp extends StatelessWidget {
  const RelayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<OnboardingBloc>(
          create: (context) =>
              OnboardingBloc(repository: context.read<OnboardingRepository>())
                ..add(const AppStarted()),
        ),
        BlocProvider<TransferBloc>(
          create: (context) =>
              TransferBloc(repository: context.read<TransferRepository>()),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        splitScreenMode: true,
        child: const SplashScreen(),
        builder: (ctx, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Relay',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
            ),
            home: child,
          );
        },
      ),
    );
  }
}
