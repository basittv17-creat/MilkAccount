import 'package:flutter_test/flutter_test.dart';
import 'package:milk_account/l10n/language_support.dart';

void main() {
  test('active locales are limited to fully translated languages', () {
    expect(LanguageSupport.activeLocales.map((locale) => locale.languageCode),
        containsAll(['ur', 'en', 'hi']));
    expect(LanguageSupport.isAvailable('ur'), isTrue);
    expect(LanguageSupport.isAvailable('ar'), isFalse);
  });

  test('right-to-left metadata covers Arabic-script languages', () {
    for (final code in ['ur', 'ar', 'ps', 'skr', 'fa']) {
      expect(LanguageSupport.isRtl(code), isTrue, reason: code);
    }
    expect(LanguageSupport.isRtl('zh'), isFalse);
    expect(LanguageSupport.isRtl('pa'), isFalse);
  });

  test('unsupported incomplete languages safely fall back to English', () {
    expect(LanguageSupport.safeCode('ar'), 'en');
    expect(LanguageSupport.safeCode('hi'), 'hi');
  });

  test('language catalog contains requested regional and international languages', () {
    final codes = LanguageSupport.languages.map((language) => language.code);
    expect(codes, containsAll(['ar', 'zh', 'pa', 'ps', 'skr', 'fa', 'bn', 'ja', 'ko']));
  });
}
