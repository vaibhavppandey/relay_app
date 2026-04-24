import 'package:relay_app/src/core/constant/shared_prefs.dart';
import 'package:relay_app/src/core/error/exception.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingRepository {
  final SupabaseClient _supabase;
  final SharedPreferences _prefs;
  final Logger _logger;

  OnboardingRepository({
    required SupabaseClient supabase,
    required SharedPreferences prefs,
    required Logger logger,
  }) : _supabase = supabase,
       _prefs = prefs,
       _logger = logger;

  String? getLocalShortCode() {
    return _prefs.getString(SharedPrefsConstants.userShortCode);
  }

  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  // locally save once the code is generated
  Future<void> saveLocalShortCode(String code) async {
    await _prefs.setString(SharedPrefsConstants.userShortCode, code);
  }

  // authenticate anonymously w/ supabase
  Future<String> signInAnonymously() async {
    final response = await _supabase.auth.signInAnonymously();

    if (response.user == null) {
      _logger.e('Anonymous sign-in failed: Supabase returned no user object.');
      throw Exception('Failed to provision anonymous identity.');
    }

    return response.user!.id;
  }

  // register the generated code to supabase, w/ userid
  Future<void> registerShortCode(String userId, String shortCode) async {
    try {
      await _supabase.from('users').insert({
        'id': userId,
        'short_code': shortCode,
      });
    } on PostgrestException catch (e) {
      // postgres for unique constraint violation is 23505
      if (e.code == '23505') {
        _logger.w(
          'Short-code collision while registering identity.',
          error: e,
          stackTrace: StackTrace.current,
        );
        throw ShortCodeCollisionException('Code $shortCode already exists');
      }

      _logger.e(
        'Supabase postgrest error during short-code registration.',
        error: e,
        stackTrace: StackTrace.current,
      );
      rethrow;
    } catch (e, st) {
      _logger.e(
        'Unexpected error during short-code registration.',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
