import 'package:jcs/jcs.dart';
import 'package:test/test.dart';

void main() {
  group('JCS number formatting', () {
    const encoder = JcsEncoder();

    test('uses ECMAScript fixed and exponent notation thresholds', () {
      expect(encoder.convert(1e-6), '0.000001');
      expect(encoder.convert(1e-7), '1e-7');
      expect(encoder.convert(1e20), '100000000000000000000');
      expect(encoder.convert(1e21), '1e+21');
    });

    test('preserves shortest round-trip digits', () {
      expect(encoder.convert(333333333.33333329), '333333333.3333333');
      expect(encoder.convert(1.0000000000000002), '1.0000000000000002');
      expect(encoder.convert(9007199254740993), '9007199254740992');
    });

    test('normalizes zero and signs', () {
      expect(encoder.convert(-0.0), '0');
      expect(encoder.convert(-1e21), '-1e+21');
    });

    test('converts integers like ECMAScript doubles', () {
      expect(encoder.convert(-9223372036854775808), '-9223372036854776000');
      expect(encoder.convert(9223372036854775807), '9223372036854776000');
    });
  });
}
