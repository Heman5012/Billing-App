/// Typography configuration for BillWave.
///
/// Uses the platform default typography (San Francisco on iOS/macOS,
/// Roboto/system font on Android, Segoe UI on Windows, etc.) by leaving
/// `fontFamily` unset in Flutter `ThemeData`.
class AppFontConfig {
  AppFontConfig._();

  /// Default platform font family (null allows the host OS to supply its default font).
  static const String? primaryFontFamily = null;

  /// Default font fallbacks (null allows the host OS default font fallback chain).
  static const List<String>? fontFallbacks = null;
}

/// Backwards compatibility alias for existing references
class SystemFontService {
  SystemFontService._();

  static const String? bundledFontFamily = AppFontConfig.primaryFontFamily;
  static const List<String>? fontFallbacks = AppFontConfig.fontFallbacks;

  static String? get activeFontFamily => AppFontConfig.primaryFontFamily;

  static Future<void> initialize() async {
    // Flutter default platform typography is used directly
  }
}
