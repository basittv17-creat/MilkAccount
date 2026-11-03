import 'package:flutter_test/flutter_test.dart';
import 'package:milk_account/utils/phone_number.dart';

void main() {
  group('normalizeInternationalPhone', () {
    test('adds country code and removes domestic leading zero', () {
      expect(
        normalizeInternationalPhone(countryCode: '+92', phoneNumber: '03001234567'),
        '923001234567',
      );
    });

    test('does not duplicate a country code already in the phone field', () {
      expect(
        normalizeInternationalPhone(countryCode: '+44', phoneNumber: '447700900123'),
        '447700900123',
      );
    });

    test('accepts international 00 prefix', () {
      expect(
        normalizeInternationalPhone(countryCode: '+92', phoneNumber: '00447700900123'),
        '447700900123',
      );
    });

    test('returns null for an empty or invalid-length number', () {
      expect(normalizeInternationalPhone(countryCode: '+92', phoneNumber: ''), isNull);
      expect(normalizeInternationalPhone(countryCode: '+92', phoneNumber: '123'), isNull);
    });
  });
}
