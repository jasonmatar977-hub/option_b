class AppConfig {
  const AppConfig._();

  static const String appName = 'On My Way';
  static const String appShortName = 'OMW';
  static const String appDeliveryName = 'On My Way Delivery';

  static const bool _omwUseFirebase = bool.fromEnvironment('OMW_USE_FIREBASE');
  static const bool _legacyUseFirebase = bool.fromEnvironment(
    'OPTION_B_USE_FIREBASE',
  );
  static const bool useFirebase = _omwUseFirebase || _legacyUseFirebase;

  static const bool _omwUseWhatsAppOtp = bool.fromEnvironment(
    'OMW_USE_WHATSAPP_OTP',
  );
  static const bool _omwDisableWhatsAppOtp = bool.fromEnvironment(
    'OMW_DISABLE_WHATSAPP_OTP',
  );
  static const bool useWhatsAppOtp =
      _omwUseWhatsAppOtp || !_omwDisableWhatsAppOtp;

  static const bool _omwUseGoogleMaps = bool.fromEnvironment(
    'OMW_USE_GOOGLE_MAPS',
  );
  static const bool _legacyUseGoogleMaps = bool.fromEnvironment(
    'OPTION_B_USE_GOOGLE_MAPS',
  );
  static const bool useGoogleMaps = _omwUseGoogleMaps || _legacyUseGoogleMaps;

  static const String _omwGoogleMapsApiKey = String.fromEnvironment(
    'OMW_GOOGLE_MAPS_API_KEY',
  );
  static const String _legacyGoogleMapsApiKey = String.fromEnvironment(
    'OPTION_B_GOOGLE_MAPS_API_KEY',
  );
  static const String googleMapsApiKey = _omwGoogleMapsApiKey != ''
      ? _omwGoogleMapsApiKey
      : _legacyGoogleMapsApiKey;

  static const bool localFallbackEnabled = true;
  static const double defaultCommissionRate = 0.15;
  static const double commissionRate = 0.15;

  // Set via --dart-define=OMW_SUPPORT_WHATSAPP_NUMBER=9611234567
  // Digits only with country code, no + prefix, e.g. 9611234567
  static const String supportWhatsAppNumber = String.fromEnvironment(
    'OMW_SUPPORT_WHATSAPP_NUMBER',
    defaultValue: '',
  );

  // Comma-separated lower-case admin bootstrap emails.
  // Example: --dart-define=OMW_ADMIN_EMAILS=owner@example.com,admin@example.com
  static const String adminEmailsCsv = String.fromEnvironment(
    'OMW_ADMIN_EMAILS',
    defaultValue: '',
  );

  static List<String> get adminEmails => adminEmailsCsv
      .split(',')
      .map((email) => email.trim().toLowerCase())
      .where((email) => email.isNotEmpty)
      .toList(growable: false);

  static bool isAdminEmail(String? email) {
    final normalized = email?.trim().toLowerCase();
    return normalized != null &&
        normalized.isNotEmpty &&
        adminEmails.contains(normalized);
  }

  static bool get hasGoogleMapsApiKey => googleMapsApiKey.isNotEmpty;
  static double platformCommissionFor(num gross) => gross * commissionRate;
  static double workerPayoutFor(num gross) => gross * (1 - commissionRate);
}
