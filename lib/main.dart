import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:relay_app/src/app/app.dart';
import 'package:relay_app/src/core/constant/key.dart';
import 'package:relay_app/src/core/native/bg_service.dart';
import 'package:relay_app/src/feat/nearby/data/repo/nearby_repository.dart';
import 'package:relay_app/src/feat/onboarding/data/repo/onboarding_repo.dart';
import 'package:relay_app/src/feat/transfer/data/repo/transfer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bgServiceManager = BgServiceManager();
  await bgServiceManager.init();
  await dotenv.load(fileName: KeyConstants.env);
  final prefs = await SharedPreferences.getInstance();
  await Supabase.initialize(
    url: dotenv.env[KeyConstants.supabaseUrl] ?? '',
    anonKey: dotenv.env[KeyConstants.supabaseAnonKey] ?? '',
  );
  final supabase = Supabase.instance.client;
  final logger = Logger();
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<OnboardingRepository>(
          create: (context) => OnboardingRepository(
            supabase: supabase,
            prefs: prefs,
            logger: logger,
          ),
        ),
        RepositoryProvider<NearbyRepository>(
          create: (context) => NearbyRepository(),
        ),
        RepositoryProvider<TransferRepository>(
          create: (context) => TransferRepository(
            supabase: supabase,
            dio: Dio(),
            uuid: Uuid(),
            bg: bgServiceManager,
          ),
        ),
      ],
      child: const RelayApp(),
    ),
  );
}
