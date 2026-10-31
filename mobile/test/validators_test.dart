import 'package:flutter_test/flutter_test.dart';
import 'package:ticketsec_mobile/core/utils/formatters.dart';
import 'package:ticketsec_mobile/core/utils/validators.dart';

void main() {
  group('validators', () {
    test('email', () {
      expect(validateEmail('cliente@demo.com'), isNull);
      expect(validateEmail('sin-arroba'), isNotNull);
      expect(validateEmail(''), isNotNull);
    });

    test('cedula', () {
      expect(validateCedula('1712345678'), isNull);
      expect(validateCedula('123'), isNotNull);
      expect(validateCedula('171234567a'), isNotNull);
    });

    test('password', () {
      expect(validatePassword('Cliente#2026'), isNull);
      expect(validatePassword('corta#1A'), isNotNull);
      expect(validatePassword('sinSimbolo123A'), isNotNull);
      expect(validatePassword('SINSIMBOLO123a'), isNotNull);
    });

    test('otp', () {
      expect(validateOtp('123456'), isNull);
      expect(validateOtp('12345'), isNotNull);
      expect(validateOtp('abcdef'), isNotNull);
    });

    test('card number and luhn', () {
      expect(validateCardNumber('4242 4242 4242 4242'), isNull);
      expect(validateCardNumber('4242 4242 4242 4241'), isNotNull);
      expect(luhn('4242424242424242'), isTrue);
      expect(luhn('4242424242424241'), isFalse);
    });

    test('expiry', () {
      expect(validateExpiry('12/30'), isNull);
      expect(validateExpiry('13/30'), isNotNull);
      expect(validateExpiry('12/20'), isNotNull);
      expect(validateExpiry('1230'), isNotNull);
    });
  });

  group('formatters', () {
    test('money uses two decimals', () {
      expect(money(25), r'$25.00');
      expect(money(12.5), r'$12.50');
    });

    test('card mask groups digits', () {
      expect(maskCardInput('4242424242424242'), '4242 4242 4242 4242');
      expect(maskCardInput('4242-4242-4242-4242'), '4242 4242 4242 4242');
    });

    test('expiry formatting', () {
      expect(formatExpiry('1230'), '12/30');
      expect(formatExpiry('1'), '1');
    });
  });
}
