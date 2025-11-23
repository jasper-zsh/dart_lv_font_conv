/// Tests for utility functions
library;

import 'package:test/test.dart';
import '../lib/utils.dart';

void main() {
  group('Utils', () {
    group('set_depth', () {
      test('Should reduce glyph to depth=1', () {
        final input = [0, 127, 128, 255]; // 0b00000000, 0b01111111, 0b10000000, 0b11111111
        final expected = [0, 0, 255, 255]; // 0b00000000, 0b00000000, 0b11111111, 0b11111111
        const depth = 1;

        final glyph = {
          'bbox': {'x': 0, 'y': 0, 'width': input.length, 'height': 1},
          'pixels': [input]
        };

        final result = setDepth(glyph, depth);

        expect(result['pixels'][0], equals(expected));
      });

      test('Should reduce glyph to depth=2', () {
        final input = [63, 64, 191, 192]; // 0b00111111, 0b01000000, 0b10111111, 0b11000000
        final expected = [0, 85, 170, 255]; // 0b00000000, 0b01010101, 0b10101010, 0b11111111
        const depth = 2;

        final glyph = {
          'bbox': {'x': 0, 'y': 0, 'width': input.length, 'height': 1},
          'pixels': [input]
        };

        final result = setDepth(glyph, depth);

        expect(result['pixels'][0], equals(expected));
      });

      test('Should reduce glyph to depth=3', () {
        final input = [
          63, 64, 79, 96, 127, // 0b00111111, 0b01000000, 0b01011111, 0b01100000, 0b01111111
          128, 159, 160, 191, 192 // 0b10000000, 0b10011111, 0b10100000, 0b10111111, 0b11000000
        ];
        final expected = [
          36, 73, 73, 109, 109, // 0b00100100, 0b01001001, 0b01001001, 0b01101101, 0b01101101
          146, 146, 182, 182, 219 // 0b10010010, 0b10010010, 0b10110110, 0b10110110, 0b11011011
        ];
        const depth = 3;

        final glyph = {
          'bbox': {'x': 0, 'y': 0, 'width': input.length, 'height': 1},
          'pixels': [input]
        };

        final result = setDepth(glyph, depth);

        expect(result['pixels'][0], equals(expected));
      });

      test('Should reduce glyph to depth=8', () {
        final input = [201, 15, 218, 162]; // 0b11001001, 0b00001111, 0b11011010, 0b10100010
        final expected = [201, 15, 218, 162]; // 0b11001001, 0b00001111, 0b11011010, 0b10100010
        const depth = 8;

        final glyph = {
          'bbox': {'x': 0, 'y': 0, 'width': input.length, 'height': 1},
          'pixels': [input]
        };

        final result = setDepth(glyph, depth);

        expect(result['pixels'][0], equals(expected));
      });
    });
  });
}