import 'dart:math';

class CodeGenerator {
  static const String _alpha = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String generateShortCode({int length = 6}) {
    final random = Random.secure();
    final buffer = StringBuffer();

    for (int i = 0; i < length; i++) {
      buffer.write(_alpha[random.nextInt(_alpha.length)]);
    }

    return buffer.toString();
  }
}
