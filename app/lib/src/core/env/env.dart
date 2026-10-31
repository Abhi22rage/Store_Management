// Supabase configuration — Smart Store
// Supports 1-line code toggle or CLI flag: --dart-define=ENV=dev / --dart-define=ENV=prod

enum AppEnvironment { dev, prod }

class Env {
  // =========================================================================
  // 🔘 1-CHANGE CODE TOGGLE:
  // Change to AppEnvironment.prod for Production, AppEnvironment.dev for Development
  // =========================================================================
  // static const AppEnvironment _defaultEnv = AppEnvironment.prod;

  static const AppEnvironment _defaultEnv = AppEnvironment.dev;

  // Optional: Compile-time CLI override via: --dart-define=ENV=dev or --dart-define=ENV=prod
  static const String _cliEnv = String.fromEnvironment('ENV', defaultValue: '');

  static AppEnvironment get currentEnvironment {
    final clean = _cliEnv.trim().toLowerCase();
    if (clean == 'dev' || clean == 'development' || clean == 'staging') {
      return AppEnvironment.dev;
    }
    if (clean == 'prod' || clean == 'production') {
      return AppEnvironment.prod;
    }
    return _defaultEnv;
  }

  static bool get isDev => currentEnvironment == AppEnvironment.dev;
  static bool get isProd => currentEnvironment == AppEnvironment.prod;
  static String get environmentName => isProd ? 'Production' : 'Development';

  // -------------------------------------------------------------------------
  // 🛠️ 1. DEVELOPMENT / STAGING SUPABASE PROJECT
  // (Paste your new second Supabase project URL and anon key here)
  // -------------------------------------------------------------------------
  static const String _devSupabaseUrl =
      'https://blqolrbpuqjiihfqjriy.supabase.co';
  static const String _devSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJscW9scmJwdXFqaWloZnFqcml5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ4MTIwMjUsImV4cCI6MjA5MDM4ODAyNX0.M_F6wfoLEFej-KAY5RumBL50MVDab0zqvm5oODlZeB4';
  static const String _devStorageUrl =
      'https://blqolrbpuqjiihfqjriy.supabase.co/storage/v1/object/public/product-images/';

  // -------------------------------------------------------------------------
  // 🚀 2. PRODUCTION SUPABASE PROJECT (Live Store)
  // -------------------------------------------------------------------------
  static const String _prodSupabaseUrl =
      'https://xrbokywhcabxjrssgdbg.supabase.co';
  static const String _prodSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhyYm9reXdoY2FieGpyc3NnZGJnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc2Mzg3NTEsImV4cCI6MjEwMzIxNDc1MX0.ejRXuhj01dLpeA6SMQhg2FPKVm_ytyg2Rjv5ammfQjI';
  static const String _prodStorageUrl =
      'https://xrbokywhcabxjrssgdbg.supabase.co/storage/v1/object/public/product-images/';

  // -------------------------------------------------------------------------
  // 🔄 ACTIVE VALUES (Auto-resolved based on selected environment)
  // -------------------------------------------------------------------------
  static String get supabaseUrl => isProd ? _prodSupabaseUrl : _devSupabaseUrl;
  static String get supabaseAnonKey =>
      isProd ? _prodSupabaseAnonKey : _devSupabaseAnonKey;
  static String get storageUrl => isProd ? _prodStorageUrl : _devStorageUrl;
}
