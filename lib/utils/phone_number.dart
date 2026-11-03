/// Converts a country code and a local or already-international phone number
/// into the digits-only format required by https://wa.me.
String? normalizeInternationalPhone({
  required String? countryCode,
  required String? phoneNumber,
}) {
  var code = (countryCode ?? '+92').replaceAll(RegExp(r'[^0-9]'), '');
  var number = (phoneNumber ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (number.isEmpty) return null;
  if (code.isEmpty) code = '92';

  if (number.startsWith('00')) {
    number = number.substring(2);
    return number.length >= 8 && number.length <= 15 ? number : null;
  }
  if (number.startsWith(code) && number.length > 10) {
    // The phone field already contains the full international number.
    return number.length <= 15 ? number : null;
  }
  if (number.startsWith('0')) {
    // Remove the domestic trunk prefix before adding the country code.
    number = number.substring(1);
  }

  final result = '$code$number';
  if (result.length < 8 || result.length > 15) return null;
  return result;
}
