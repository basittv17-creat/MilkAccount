import 'package:flutter/material.dart';

/// Central language metadata and direction rules for the multilingual rollout.
/// Only languages with complete translations are active in the picker today.
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.isRtl,
    this.isTranslated = false,
  });

  final String code;
  final String nativeName;
  final String englishName;
  final bool isRtl;
  final bool isTranslated;
}

class LanguageSupport {
  LanguageSupport._();

  static const languages = <AppLanguage>[
    AppLanguage(code: 'ur', nativeName: 'اردو', englishName: 'Urdu', isRtl: true, isTranslated: true),
    AppLanguage(code: 'en', nativeName: 'English', englishName: 'English', isRtl: false, isTranslated: true),
    AppLanguage(code: 'hi', nativeName: 'हिन्दी', englishName: 'Hindi', isRtl: false, isTranslated: true),
    AppLanguage(code: 'ar', nativeName: 'العربية', englishName: 'Arabic', isRtl: true),
    AppLanguage(code: 'zh', nativeName: '中文', englishName: 'Chinese', isRtl: false),
    AppLanguage(code: 'pa', nativeName: 'ਪੰਜਾਬੀ', englishName: 'Punjabi', isRtl: false),
    AppLanguage(code: 'ps', nativeName: 'پښتو', englishName: 'Pashto', isRtl: true),
    AppLanguage(code: 'skr', nativeName: 'سرائیکی', englishName: 'Saraiki', isRtl: true),
    AppLanguage(code: 'fa', nativeName: 'فارسی', englishName: 'Persian', isRtl: true),
    AppLanguage(code: 'bn', nativeName: 'বাংলা', englishName: 'Bengali', isRtl: false),
    AppLanguage(code: 'tr', nativeName: 'Türkçe', englishName: 'Turkish', isRtl: false),
    AppLanguage(code: 'fr', nativeName: 'Français', englishName: 'French', isRtl: false),
    AppLanguage(code: 'de', nativeName: 'Deutsch', englishName: 'German', isRtl: false),
    AppLanguage(code: 'es', nativeName: 'Español', englishName: 'Spanish', isRtl: false),
    AppLanguage(code: 'ru', nativeName: 'Русский', englishName: 'Russian', isRtl: false),
    AppLanguage(code: 'ja', nativeName: '日本語', englishName: 'Japanese', isRtl: false),
    AppLanguage(code: 'ko', nativeName: '한국어', englishName: 'Korean', isRtl: false),
  ];

  static const activeLocales = <Locale>[
    Locale('ur'),
    Locale('en'),
    Locale('hi'),
  ];

  static AppLanguage? find(String code) {
    for (final language in languages) {
      if (language.code == code) return language;
    }
    return null;
  }

  static bool isRtl(String code) => find(code)?.isRtl ?? false;

  static bool isAvailable(String code) => find(code)?.isTranslated ?? false;

  /// Prevents unsupported or incomplete locales from being persisted as active.
  static String safeCode(String code) =>
      isAvailable(code) ? code : 'en';
}
