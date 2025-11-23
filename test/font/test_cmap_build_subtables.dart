library;

import 'package:test/test.dart';
import '../../lib/font/cmap_build_subtables.dart';

List<int> range(int from, int to) => List.generate(to - from + 1, (i) => from + i);

void main() {
  group('Cmap build subtables', () {

    test('Should represent a single character as format0', () {
      expect(cmapSplit([42]), equals([
        ['format0_tiny', [42]]
      ]));
    });

    test('Should represent two characters as sparse', () {
      expect(cmapSplit([10, 100]), equals([
        ['sparse_tiny', [10, 100]]
      ]));
    });

    test('Should split ranges', () {
      expect(cmapSplit([1, ...range(100, 140), 200]), equals([
        ['format0_tiny', [1]],
        ['format0_tiny', range(100, 140)],
        ['format0_tiny', [200]]
      ]));
    });

    test('Should split more than 256 characters into multiple ranges', () {
      expect(cmapSplit(range(1, 257)), equals([
        ['format0_tiny', [1]],
        ['format0_tiny', range(2, 257)]
      ]));
    });

    test('Should split en+de+ru set optimally', () {
      final set = [
        ...range(65, 90),
        ...range(97, 122),
        196,
        214,
        220,
        223,
        228,
        246,
        252,
        1025,
        ...range(1040, 1103),
        1105,
        7838
      ];

      expect(cmapSplit(set), equals([
        ['format0_tiny', range(65, 90)],
        ['format0_tiny', range(97, 122)],
        ['sparse_tiny', [196, 214, 220, 223, 228, 246, 252, 1025]],
        ['format0_tiny', range(1040, 1103)],
        ['sparse_tiny', [1105, 7838]]
      ]));
    });

    test('Should split sparse set with >65535 gap', () {
      final set = [
        1,
        11,
        21,
        31,
        41,
        51,
        61,
        65531,
        65541,
        65551,
        65561,
        65571,
        65581
      ];

      expect(cmapSplit(set), equals([
        ['sparse_tiny', [1, 11, 21, 31, 41]],
        ['sparse_tiny', [51, 61, 65531, 65541, 65551, 65561, 65571, 65581]]
      ]));
    });
  });
}
