library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../../lib/font/bit_stream.dart';
import '../../lib/font/font.dart';

Uint8List _ascii(String value) => Uint8List.fromList(value.codeUnits);

void main() {
  late Map<String, dynamic> fontData;
  late Map<String, dynamic> fontDataSize200;
  const fontOptions = {'bpp': 2};

  setUp(() async {
    fontData = json.decode(await File('test/font/fixtures/font_info_AV.json').readAsString())
        as Map<String, dynamic>;
    fontDataSize200 =
        json.decode(await File('test/font/fixtures/font_info_AV_size200.json').readAsString())
            as Map<String, dynamic>;
  });

  test('head table', () {
    final font = Font(fontData, fontOptions);
    final bin = Uint8List.fromList(font.head.toBin());
    final data = ByteData.sublistView(bin);

    expect(data.getUint32(0, Endian.little), equals(bin.length));
    expect(bin.length % 4, equals(0));

    expect(data.getUint8(4), equals('h'.codeUnitAt(0)));
    expect(data.getUint8(5), equals('e'.codeUnitAt(0)));
    expect(data.getUint8(6), equals('a'.codeUnitAt(0)));
    expect(data.getUint8(7), equals('d'.codeUnitAt(0)));

    expect(data.getUint32(8, Endian.little), equals(1));
    expect(data.getUint16(12, Endian.little), equals(4));
    expect(data.getUint16(14, Endian.little), equals(fontData['size']));
    expect(data.getUint16(16, Endian.little), equals(fontData['ascent']));
    expect(data.getInt16(18, Endian.little), equals(fontData['descent']));
    expect(data.getUint16(20, Endian.little), equals(fontData['typoAscent']));
    expect(data.getInt16(22, Endian.little), equals(fontData['typoDescent']));
    expect(data.getUint16(24, Endian.little), equals(fontData['typoLineGap']));

    expect(data.getInt16(26, Endian.little), equals(0));
    expect(data.getInt16(28, Endian.little), equals(8));

    expect(data.getUint16(30, Endian.little), equals(0));

    expect(data.getUint16(32, Endian.little), equals((font.kerningScale * 16).round()));

    expect(data.getUint8(34), equals(0));
    expect(data.getUint8(35), equals(0));

    expect(data.getUint8(36), equals(1));
    expect(data.getUint8(37), equals(fontOptions['bpp']));
    expect(data.getUint8(38), equals(1));
    expect(data.getUint8(39), equals(4));
    expect(data.getUint8(40), equals(8));
    expect(data.getUint8(41), equals(1));
    expect(data.getUint8(42), equals(0));
  });

  test('loca table', () {
    final font = Font(fontData, fontOptions);
    final bin = Uint8List.fromList(font.loca.toBin());
    final data = ByteData.sublistView(bin);

    expect(data.getUint16(0, Endian.little), equals(bin.length));
    expect(bin.length % 4, equals(0));
    expect(
      data.getUint32(4, Endian.little),
      equals(ByteData.sublistView(_ascii('loca')).getUint32(0, Endian.little)),
    );

    expect(data.getUint32(8, Endian.little), equals(3));

    expect(data.getUint16(14, Endian.little), equals(font.glyf.getOffset(1)));
    expect(data.getUint16(14, Endian.little), equals(8));
    expect(data.getUint16(16, Endian.little), equals(font.glyf.getOffset(2)));
    expect(data.getUint16(16, Endian.little), equals(25));
  });

  test('glyf table', () {
    final font = Font(fontData, fontOptions);
    final bin = Uint8List.fromList(font.glyf.toBin());
    final data = ByteData.sublistView(bin);

    expect(data.getUint16(0, Endian.little), equals(bin.length));
    expect(bin.length % 4, equals(0));
    expect(
      data.getUint32(4, Endian.little),
      equals(ByteData.sublistView(_ascii('glyf')).getUint32(0, Endian.little)),
    );

    final bits = Uint8List.fromList(bin.sublist(font.glyf.getOffset(2)));
    final bs = BitStream(bits, bigEndian: true);

    expect(
      bs.readBits(font.advanceWidthBits, false),
      equals((fontData['glyphs'][1]['advanceWidth'] as num * 16).round()),
    );
    expect(bs.readBits(font.xyBits, true), equals(fontData['glyphs'][1]['bbox']['x']));
    expect(bs.readBits(font.xyBits, true), equals(fontData['glyphs'][1]['bbox']['y']));
    expect(bs.readBits(font.whBits, false), equals(fontData['glyphs'][1]['bbox']['width']));
    expect(bs.readBits(font.whBits, false), equals(fontData['glyphs'][1]['bbox']['height']));
  });

  test('cmap table', () {
    final font = Font(fontData, fontOptions);
    final bin = Uint8List.fromList(font.cmap.toBin());
    final data = ByteData.sublistView(bin);

    expect(data.getUint16(0, Endian.little), equals(bin.length));
    expect(bin.length % 4, equals(0));
    expect(
      data.getUint32(4, Endian.little),
      equals(ByteData.sublistView(_ascii('cmap')).getUint32(0, Endian.little)),
    );

    expect(data.getUint32(8, Endian.little), equals(1));

    const sub1HeadOffset = 12;
    const sub1DataOffset = 12 + 16;

    expect(data.getUint32(sub1HeadOffset + 0, Endian.little), equals(sub1DataOffset));
    expect(data.getUint32(sub1HeadOffset + 4, Endian.little), equals(65));
    expect(data.getUint16(sub1HeadOffset + 8, Endian.little), equals(22));
    expect(data.getUint16(sub1HeadOffset + 10, Endian.little), equals(1));
    expect(data.getUint16(sub1HeadOffset + 12, Endian.little), equals(2));
    expect(data.getUint8(sub1HeadOffset + 14), equals(3));

    expect(data.getUint16(sub1DataOffset + 0, Endian.little), equals(0));
    expect(data.getUint16(sub1DataOffset + 2, Endian.little), equals(21));
  });

  group('kern table', () {
    test('header', () {
      final font = Font(fontData, fontOptions);
      final bin = Uint8List.fromList(font.kern.toBin());
      final data = ByteData.sublistView(bin);

      expect(data.getUint16(0, Endian.little), equals(bin.length));
      expect(bin.length % 4, equals(0));
      expect(
        data.getUint32(4, Endian.little),
        equals(ByteData.sublistView(_ascii('kern')).getUint32(0, Endian.little)),
      );
      expect(data.getUint8(8), equals(0));
    });

    test('sub format 0', () {
      final font = Font(fontData, fontOptions);
      final bin = Uint8List.fromList(font.kern.toBin());
      final data = ByteData.sublistView(bin);

      expect(data.getUint32(12, Endian.little), equals(2));

      const pairsOffset = 16;
      const valOffset = pairsOffset + 4;

      expect(data.getUint8(pairsOffset + 0), equals(1));
      expect(data.getUint8(pairsOffset + 1), equals(2));
      expect(data.getUint8(pairsOffset + 2), equals(2));
      expect(data.getUint8(pairsOffset + 3), equals(1));

      final avKernFp4 = ((fontData['glyphs'][0]['kerning']['${'V'.codeUnitAt(0)}'] as num) * 16)
          .round();
      expect(data.getInt8(valOffset + 0), equals(avKernFp4));
      final vaKernFp4 = ((fontData['glyphs'][1]['kerning']['${'A'.codeUnitAt(0)}'] as num) * 16)
          .round();
      expect(data.getInt8(valOffset + 1), equals(vaKernFp4));
    });

    test('kerning values scale', () {
      bool isSimilar(double a, double b, double epsilon) => (a - b).abs() < epsilon;

      final font = Font(fontDataSize200, fontOptions);
      final binAll = Uint8List.fromList(font.toBin());
      final binKern = Uint8List.fromList(font.kern.toBin());

      final dataAll = ByteData.sublistView(binAll);
      final dataKern = ByteData.sublistView(binKern);

      final kScaleFp4 = dataAll.getUint16(32, Endian.little);

      const pairsOffset = 16;
      const valOffset = pairsOffset + 4;

      final avKern = fontDataSize200['glyphs'][0]['kerning']['${'V'.codeUnitAt(0)}'] as num;
      expect(
        isSimilar(
          ((dataKern.getInt8(valOffset + 0) * kScaleFp4) >> 4) / 16,
          avKern.toDouble(),
          0.1,
        ),
        isTrue,
      );
      final vaKern = fontDataSize200['glyphs'][1]['kerning']['${'A'.codeUnitAt(0)}'] as num;
      expect(
        isSimilar(
          ((dataKern.getInt8(valOffset + 1) * kScaleFp4) >> 4) / 16,
          vaKern.toDouble(),
          0.1,
        ),
        isTrue,
      );
    });

    test('sub format 3', () {
      final font = Font(fontData, fontOptions);
      final binSub3 = Uint8List.fromList(font.kern.createFormat3Data());
      final data = ByteData.sublistView(binSub3);

      final mapLen = data.getUint16(0, Endian.little);
      expect(mapLen, equals(3));
      final leftLen = data.getUint8(2);
      expect(leftLen, equals(2));
      final rightLen = data.getUint8(3);
      expect(rightLen, equals(2));

      const offsMapLeft = 4;
      const offsMapRight = 4 + 3;
      const offsKArray = 4 + 2 * 3;

      final avKernFp4 = ((fontData['glyphs'][0]['kerning']['${'V'.codeUnitAt(0)}'] as num) * 16)
          .round();
      final aLeft = data.getUint8(font.glyphId[65]! + offsMapLeft) - 1;
      final vRight = data.getUint8(font.glyphId[86]! + offsMapRight) - 1;
      expect(data.getInt8(aLeft * rightLen + vRight + offsKArray), equals(avKernFp4));

      final vaKernFp4 = ((fontData['glyphs'][1]['kerning']['${'A'.codeUnitAt(0)}'] as num) * 16)
          .round();
      final vLeft = data.getUint8(font.glyphId[86]! + offsMapLeft) - 1;
      final aRight = data.getUint8(font.glyphId[65]! + offsMapRight) - 1;
      expect(data.getInt8(vLeft * rightLen + aRight + offsKArray), equals(vaKernFp4));
    });
  });
}
