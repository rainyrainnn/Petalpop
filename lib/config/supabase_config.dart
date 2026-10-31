abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static String get cleanUrl => url.trim();
  static String get cleanPublishableKey => publishableKey.trim();

  static bool get isConfigured =>
      cleanUrl.isNotEmpty && cleanPublishableKey.isNotEmpty;
}