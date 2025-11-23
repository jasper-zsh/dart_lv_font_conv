/// Tests for cmap build subtables functionality
library;

import 'package:test/test.dart';
import '../lib/font/cmap_build_subtables.dart';

void main() {
  group('Cmap build subtables', () {
    /// Helper function to create a range of integers
    List<int> range(int from, int to) {
      return List.generate(to - from + 1, (i) => from + i);
    }

    test('Should represent a single character as format0', () {
      final result = cmapSplit([42]);
      expect(result, equals([['format0_tiny', [42]]]));
    });

    test('Should represent two characters as sparse', () {
      final result = cmapSplit([10, 100]);
      expect(result, equals([['sparse_tiny', [10, 100]]]));
    });

    test('Should split ranges', () {
      final input = [1, ...range(100, 140), 200];
      final expected = [
        ['format0_tiny', [1]],
        ['format0_tiny', range(100, 140)],
        ['format0_tiny', [200]]
      ];

      final result = cmapSplit(input);
      expect(result, equals(expected));
    });

    test('Should split more than 256 characters into multiple ranges', () {
      final input = range(1, 257);
      final expected = [
        ['format0_tiny', [1]],
        ['format0_tiny', range(2, 257)]
      ];

      final result = cmapSplit(input);
      expect(result, equals(expected));
    });

    test('Should split en+de+ru set optimally', () {
      final set = [
        ...range(65, 90), // A-Z (en + de uppercase)
        ...range(97, 122), // a-z (en + de lowercase)
        196, 214, 220, 223, 228, 246, 252, // German umlauts and eszett
        1025, ...range(1040, 1103), 1105, // Russian letters
        7838 // German capital eszett
      ];

      final expected = [
        ['format0_tiny', range(65, 90)], // A-Z
        ['format0_tiny', range(97, 122)], // a-z
        ['sparse_tiny', [196, 214, 220, 223, 228, 246, 252, 1025]], // German umlauts + Russian yo
        ['format0_tiny', range(1040, 1103)], // Russian А-Я
        ['sparse_tiny', [1105, 7838]] // Russian ё + German capital eszett
      ];

      final result = cmapSplit(set);
      expect(result, equals(expected));
    });

    test('Should split sparse set with >65535 gap', () {
      final set = [
        1, 11, 21, 31, 41, 51, 61, // Dense cluster
        65531, 65541, 65551, 65561, 65571, 65581 // Another cluster near Unicode limit
      ];

      final expected = [
        ['sparse_tiny', [1, 11, 21, 31, 41]], // First cluster
        ['sparse_tiny', [51, 61, 65531, 65541, 65551, 65561, 65571, 65581]] // Second cluster
      ];

      final result = cmapSplit(set);
      expect(result, equals(expected));
    });
  });
}