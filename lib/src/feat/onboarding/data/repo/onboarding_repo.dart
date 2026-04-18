import 'package:relay_app/src/core/constant/shared_prefs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingRepository {
  final SupabaseClient _supabase;
  final SharedPreferences _prefs;

  OnboardingRepository({
    required SupabaseClient supabase,
    required SharedPreferences prefs,
  }) : _supabase = supabase,
      _prefs = prefs;

  String? getLocalShortCode() {
    return _prefs.getString(SharedPrefsConstants.userShortCode);
  }

  // locally save once the code is generated
  Future<void> saveLocalShortCode(String code) async {
    await _prefs.setString(SharedPrefsConstants.userShortCode, code);
  }

  // authenticate anonymously w/ supabase
  Future<String> signInAnonymously() async {
    final response = await _supabase.auth.signInAnonymously();

    if (response.user == null) {
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
        throw ShortCodeCollisionException('Code $shortCode already exists');
      }
      rethrow;
    }
  }
}

class ShortCodeCollisionException implements Exception {
  final String message;
  ShortCodeCollisionException(this.message);
}
