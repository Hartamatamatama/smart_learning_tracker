import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static String get supabaseUrl {
    final val = dotenv.env['SUPABASE_URL'];
    assert(val != null && val.isNotEmpty, 'SUPABASE_URL tidak ditemukan di .env');
    return val!;
  }

  static String get supabaseAnonKey {
    final val = dotenv.env['SUPABASE_ANON_KEY'];
    assert(val != null && val.isNotEmpty, 'SUPABASE_ANON_KEY tidak ditemukan di .env');
    return val!;
  }

  static String get openRouterApiKey {
    final val = dotenv.env['OPENROUTER_API_KEY'];
    assert(val != null && val.isNotEmpty, 'OPENROUTER_API_KEY tidak ditemukan di .env');
    return val!;
  }
}
