/// Tests for the Font class and tables
library;

import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import '../lib/font/font.dart';
import '../lib/font/bit_stream.dart';

void main() {
  group('Font', () {
    late Map<String, dynamic> fontData;
    late Map<String, dynamic> fontDataSize200;
    late Map<String, dynamic> fontOptions;

    setUp(() async {
      // Read the font data from JSON fixtures (matching original exactly)
      final fontInfoAv = await File('test/font/fixtures/font_info_AV.json').readAsString();
      final fontInfoAvSize200 = await File('test/font/fixtures/font_info_AV_size200.json').readAsString();

      fontData = json.decode(fontInfoAv) as Map<String, dynamic>;
      fontDataSize200 = json.decode(fontInfoAvSize200) as Map<String, dynamic>;

      fontOptions = {'bpp': 2};
    });

    test('head table', () {
      final font = Font(fontData, fontOptions);
      final bin = font.head.toBin();

      final byteData = ByteData.view(Uint8List.fromList(bin).buffer);

      expect(byteData.getUint32(0, Endian.little), equals(bin.length));
      expect(bin.length % 4, equals(0));

      // Make sure name chars order is proper
      expect(byteData.getUint8(4), equals('h'.codeUnitAt(0)));
      expect(byteData.getUint8(5), equals('e'.codeUnitAt(0)));
      expect(byteData.getUint8(6), equals('a'.codeUnitAt(0)));
      expect(byteData.getUint8(7), equals('d'.codeUnitAt(0)));

      expect(byteData.getUint32(8, Endian.little), equals(1)); // version
      expect(byteData.getUint16(12, Endian.little), equals(4)); // amount of next tables
      expect(byteData.getUint16(14, Endian.little), equals(fontData['size']));
      expect(byteData.getUint16(16, Endian.little), equals(fontData['ascent']));
      expect(byteData.getInt16(18, Endian.little), equals(fontData['descent']));
      expect(byteData.getUint16(20, Endian.little), equals(fontData['typoAscent']));
      expect(byteData.getInt16(22, Endian.little), equals(fontData['typoDescent']));
      expect(byteData.getUint16(24, Endian.little), equals(fontData['typoLineGap']));

      expect(byteData.getInt16(26, Endian.little), equals(0)); // minY
      expect(byteData.getInt16(28, Endian.little), equals(8)); // maxY

      // Default advanceWidth 0 for proportional fonts
      expect(byteData.getUint16(30, Endian.little), equals(0));

      expect(byteData.getUint16(32, Endian.little), equals((font.kerningScale * 16).round()));

      expect(byteData.getUint8(34), equals(0)); // indexToLocFormat
      expect(byteData.getUint8(35), equals(0)); // glyphIdFormat

      expect(byteData.getUint8(36), equals(1)); // advanceWidthFormat (with fractional)
      expect(byteData.getUint8(37), equals(fontOptions['bpp']));
      expect(byteData.getUint8(38), equals(1)); // xy_bits
      expect(byteData.getUint8(39), equals(4)); // wh_bits
      expect(byteData.getUint8(40), equals(8)); // advanceWidth bits (FP4.4)
      expect(byteData.getUint8(41), equals(1)); // compression id
      expect(byteData.getUint8(42), equals(0)); // no subpixels
    });

    test('loca table', () {
      final font = Font(fontData, fontOptions);
      final bin = font.loca.toBin();

      final byteData = ByteData.view(Uint8List.fromList(bin).buffer);

      expect(byteData.getUint16(0, Endian.little), equals(bin.length));
      expect(bin.length % 4, equals(0));

      // Check 'loca' label
      final locaLabel = byteData.getUint32(4, Endian.little);
      expect(locaLabel, equals(ByteData.view('loca'.codeUnits.buffer).getUint32(0, Endian.little)));

      // Entries (2 chars + reserved 'zero')
      expect(byteData.getUint32(8, Endian.little), equals(3));

      // Check glyph data offsets
      // Offset = 12 is for `zero`, start check from 14
      expect(byteData.getUint16(14, Endian.little), equals(font.glyf.getOffset(1))); // for "A"
      expect(byteData.getUint16(14, Endian.little), equals(8));
      expect(byteData.getUint16(16, Endian.little), equals(font.glyf.getOffset(2))); // for "V"
      expect(byteData.getUint16(16, Endian.little), equals(25));
    });

    test('glyf table', () {
      final font = Font(fontData, fontOptions);
      final bin = font.glyf.toBin();

      final byteData = ByteData.view(Uint8List.fromList(bin).buffer);

      expect(byteData.getUint16(0, Endian.little), equals(bin.length));
      expect(bin.length % 4, equals(0));

      // Check 'glyf' label
      final glyfLabel = byteData.getUint32(4, Endian.little);
      expect(glyfLabel, equals(ByteData.view('glyf'.codeUnits.buffer).getUint32(0, Endian.little)));

      // Test 'V' glyph properties (ID = 2)
      // Extract data
      final bits = Uint8List(bin.length - font.glyf.getOffset(2));
      for (int i = 0; i < bits.length; i++) {
        bits[i] = bin[font.glyf.getOffset(2) + i];
      }

      // Create bits loader
      final bs = BitStream.size(bits.length);
      for (int i = 0; i < bits.length; i++) {
        bs.writeByte(bits[i]);
      }
      bs.position = 0;
      bs.bigEndian = true;

      expect(
        bs.readBits(font.advanceWidthBits, false),
        equals((fontData['glyphs'][1]['advanceWidth'] as double) * 16).round()
      );
      expect(bs.readBits(font.xyBits, true), equals(fontData['glyphs'][1]['bbox']['x']));
      expect(bs.readBits(font.xyBits, true), equals(fontData['glyphs'][1]['bbox']['y']));
      expect(bs.readBits(font.whBits, false), equals(fontData['glyphs'][1]['bbox']['width']));
      expect(bs.readBits(font.whBits, false), equals(fontData['glyphs'][1]['bbox']['height']));
    });

    test('cmap table', () {
      final font = Font(fontData, fontOptions);
      final bin = font.cmap.toBin();

      final byteData = ByteData.view(Uint8List.fromList(bin).buffer);

      expect(byteData.getUint16(0, Endian.little), equals(bin.length));
      expect(bin.length % 4, equals(0));

      // Check 'cmap' label
      final cmapLabel = byteData.getUint32(4, Endian.little);
      expect(cmapLabel, equals(ByteData.view('cmap'.codeUnits.buffer).getUint32(0, Endian.little)));

      expect(byteData.getUint32(8, Endian.little), equals(1)); // subtables count

      const SUB1_HEAD_OFFSET = 12;
      const SUB1_DATA_OFFSET = 12 + 16;

      // Check subtable header
      expect(byteData.getUint32(SUB1_HEAD_OFFSET + 0, Endian.little), equals(SUB1_DATA_OFFSET));
      expect(byteData.getUint32(SUB1_HEAD_OFFSET + 4, Endian.little), equals(65)); // "A"
      expect(byteData.getUint16(SUB1_HEAD_OFFSET + 8, Endian.little), equals(22));  // Range length, 86-65+1
      expect(byteData.getUint16(SUB1_HEAD_OFFSET + 10, Endian.little), equals(1)); // Glyph ID offset
      expect(byteData.getUint16(SUB1_HEAD_OFFSET + 12, Endian.little), equals(2)); // Entries count
      expect(byteData.getUint8(SUB1_HEAD_OFFSET + 14), equals(3)); // Subtable type

      // Check IDs (sparse subtable)
      expect(byteData.getUint16(SUB1_DATA_OFFSET + 0, Endian.little), equals(0)); // 'A' => 65+0 => 65
      expect(byteData.getUint16(SUB1_DATA_OFFSET + 2, Endian.little), equals(21)); // 'W' => 65+21 => 86
    });

    group('kern table', () {
      test('header', () {
        final font = Font(fontData, fontOptions);
        final bin = font.kern.toBin();

        final byteData = ByteData.view(Uint8List.fromList(bin).buffer);

        expect(byteData.getUint16(0, Endian.little), equals(bin.length));
        expect(bin.length % 4, equals(0));

        // Check 'kern' label
        final kernLabel = byteData.getUint32(4, Endian.little);
        expect(kernLabel, equals(ByteData.view('kern'.codeUnits.buffer).getUint32(0, Endian.little)));

        expect(byteData.getUint8(8), equals(0)); // format
      });

      test('sub format 0', () {
        final font = Font(fontData, fontOptions);
        final bin = font.kern.toBin();

        final byteData = ByteData.view(Uint8List.fromList(bin).buffer);

        // Entries
        expect(byteData.getUint32(12, Endian.little), equals(2));

        const PAIRS_OFFSET = 16;
        const VAL_OFFSET = PAIRS_OFFSET + 2 * 2; // 2 pairs * 2 bytes

        // Pairs of IDs
        // [ AV ] => [ 1, 2 ]
        expect(byteData.getUint8(PAIRS_OFFSET + 0), equals(1));
        expect(byteData.getUint8(PAIRS_OFFSET + 1), equals(2));
        // [ VA ] => [ 2, 1 ]
        expect(byteData.getUint8(PAIRS_OFFSET + 2), equals(2));
        expect(byteData.getUint8(PAIRS_OFFSET + 3), equals(1));

        // Values
        final avKernFp4 = ((fontData['glyphs'][0]['kerning']['V'] as double) * 16).round();
        expect(byteData.getInt8(VAL_OFFSET + 0), equals(avKernFp4));
        final vaKernFp4 = ((fontData['glyphs'][1]['kerning']['A'] as double) * 16).round();
        expect(byteData.getInt8(VAL_OFFSET + 1), equals(vaKernFp4));
      });

      test('kerning values scale', () {
        bool isSimilar(double a, double b, double epsilon) {
          return (a - b).abs() < epsilon;
        }

        final font = Font(fontDataSize200, fontOptions);
        final binAll = font.toBin();
        final binKern = font.kern.toBin();

        final byteDataAll = ByteData.view(Uint8List.fromList(binAll).buffer);
        final byteDataKern = ByteData.view(Uint8List.fromList(binKern).buffer);

        final kScaleFp4 = byteDataAll.getUint16(32, Endian.little);

        const PAIRS_OFFSET = 16;
        const VAL_OFFSET = PAIRS_OFFSET + 2 * 2; // 2 pairs * 2 bytes

        final avKern = fontDataSize200['glyphs'][0]['kerning']['V'] as double;
        expect(
          isSimilar(
            ((byteDataKern.getInt8(VAL_OFFSET + 0) * kScaleFp4) >> 4) / 16,
            avKern,
            0.1
          ),
          isTrue
        );

        final vaKern = fontDataSize200['glyphs'][1]['kerning']['A'] as double;
        expect(
          isSimilar(
            ((byteDataKern.getInt8(VAL_OFFSET + 1) * kScaleFp4) >> 4) / 16,
            vaKern,
            0.1
          ),
          isTrue
        );
      });

      test('sub format 3', () {
        final font = Font(fontData, fontOptions);
        final binSub3 = font.kern.createFormat3Data();

        final byteData = ByteData.view(Uint8List.fromList(binSub3).buffer);

        final mapLen = byteData.getUint16(0, Endian.little);
        expect(mapLen, equals(3));
        final leftLen = byteData.getUint8(2);
        expect(leftLen, equals(2));
        final rightLen = byteData.getUint8(3);
        expect(rightLen, equals(2));

        const offsMapLeft = 4;
        const offsMapRight = 4 + mapLen;
        const offsKArray = 4 + 2 * mapLen;

        // Values
        final avKernFp4 = ((fontData['glyphs'][0]['kerning']['V'] as double) * 16).round();
        final aLeft = byteData.getUint8(font.glyphId[65] + offsMapLeft) - 1;
        final vRight = byteData.getUint8(font.glyphId[86] + offsMapRight) - 1;
        expect(
          byteData.getInt8(aLeft * rightLen + vRight + offsKArray),
          equals(avKernFp4)
        );

        final vaKernFp4 = ((fontData['glyphs'][1]['kerning']['A'] as double) * 16).round();
        final vLeft = byteData.getUint8(font.glyphId[86] + offsMapLeft) - 1;
        final aRight = byteData.getUint8(font.glyphId[65] + offsMapRight) - 1;
        expect(
          byteData.getInt8(vLeft * rightLen + aRight + offsKArray),
          equals(vaKernFp4)
        );
      });
    });
  });
}