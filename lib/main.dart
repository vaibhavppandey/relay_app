import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:relay_app/src/app/app.dart';
import 'package:relay_app/src/core/constant/key.dart';
import 'package:relay_app/src/feat/onboarding/data/repo/onboarding_repo.dart';
import 'package:relay_app/src/feat/transfer/data/repo/transfer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        RepositoryProvider<TransferRepository>(
          create: (context) => TransferRepository(),
        ),
      ],
      child: const RelayApp(),
    ),
  );
}
