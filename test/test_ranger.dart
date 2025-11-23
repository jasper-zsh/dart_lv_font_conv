/// Tests for the Ranger class
library;

import 'package:test/test.dart';
import '../lib/ranger.dart';

void main() {
  group('Ranger', () {
    test('Should accept symbols', () {
      final ranger = Ranger();
      expect(ranger.addSymbols('font', 'aba8').length, equals(4));

      final mapping = ranger.get();
      expect(mapping[56]!.font, equals('font'));
      expect(mapping[56]!.code, equals(56));
      expect(mapping[97]!.font, equals('font'));
      expect(mapping[97]!.code, equals(97));
      expect(mapping[98]!.font, equals('font'));
      expect(mapping[98]!.code, equals(98));
    });

    test('Should handle astral characters correctly', () {
      final ranger = Ranger();
      expect(ranger.addSymbols('font', 'a𐌀b𐌁').length, equals(4));

      final mapping = ranger.get();
      expect(mapping[97]!.font, equals('font'));
      expect(mapping[97]!.code, equals(97));
      expect(mapping[98]!.font, equals('font'));
      expect(mapping[98]!.code, equals(98));
      expect(mapping[66304]!.font, equals('font'));
      expect(mapping[66304]!.code, equals(66304));
      expect(mapping[66305]!.font, equals('font'));
      expect(mapping[66305]!.code, equals(66305));
    });

    test('Should merge ranges', () {
      final ranger = Ranger();
      expect(ranger.addRange('font', 42, 44, 42).length, equals(3));
      expect(ranger.addRange('font2', 46, 46, 85).length, equals(1));

      final mapping = ranger.get();
      expect(mapping[42]!.font, equals('font'));
      expect(mapping[42]!.code, equals(42));
      expect(mapping[43]!.font, equals('font'));
      expect(mapping[43]!.code, equals(43));
      expect(mapping[44]!.font, equals('font'));
      expect(mapping[44]!.code, equals(44));
      expect(mapping[85]!.font, equals('font2'));
      expect(mapping[85]!.code, equals(46));
    });
  });
}