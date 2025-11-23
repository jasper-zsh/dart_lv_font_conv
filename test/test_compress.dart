/// Tests for compression functionality
library;

import 'dart:typed_data';
import 'package:test/test.dart';
import '../lib/font/compress.dart';
import '../lib/font/bit_stream.dart';

void main() {
  group('Compress', () {
    /// Helper function to compress data using the compress function
    List<int> c(List<int> data, Map<String, dynamic> opts) {
      final bufSize = data.length * 2 + 100;
      final bitStream = BitStream.size(bufSize);
      bitStream.bigEndian = true;

      compress(bitStream, data, opts);

      final byteCount = (bitStream.position / 8).ceil();
      return bitStream.getBytes().take(byteCount).toList();
    }

    test('pass through, bpp=8', () {
      final result = c([0x1, 0x2, 0x3, 0x2], {'bpp': 8});
      expect(result, equals([0x1, 0x2, 0x3, 0x2]));
    });

    test('pass through, bpp=4', () {
      final result = c([0x1, 0x2, 0x3, 0x2], {'bpp': 4});
      // 0001 0010 0011 0010
      expect(result, equals([0x12, 0x32]));
    });

    test('pass through, bpp=3', () {
      final result = c([0xFF, 0xF1, 0xFF], {'bpp': 3});
      // 111 001 11|1 0000000
      expect(result, equals([0xE7, 0x80]));
    });

    test('collapse to bit', () {
      final result = c([0x1, 0x3, 0x3, 0x3, 0x1], {'bpp': 4});
      // 0001 0011 | 0011 1 0 00|01 000000
      expect(result, equals([0b00010011, 0b00111000, 0b01000000]));
    });

    test('collapse 10+ repeats with counter', () {
      final data = List.filled(15, 0);
      data[data.length - 1] = 3; // 0b11
      final result = c(data, {'bpp': 2});
      // 00 00 1111|1111111 0|00010 11 0
      expect(result, equals([0b00001111, 0b11111110, 0b00010110]));
    });

    test('split repeats if counter overflows', () {
      final data = List.filled(77, 0);
      data[data.length - 1] = 3;
      final result = c(data, {'bpp': 2});
      // 00 00 1111|1111111 1|11111 00 1|1 0000000
      expect(result, equals([0b00001111, 0b11111111, 0b11111001, 0b10000000]));
    });
  });
}