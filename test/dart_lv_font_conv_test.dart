import 'package:dart_lv_font_conv/dart_lv_font_conv.dart';
import 'package:test/test.dart';

void main() {
  group('Font Converter Tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('Supported formats', () {
      final formats = FontConverter.supportedFormats;
      expect(formats, contains('lvgl'));
      expect(formats, contains('bin'));
      expect(formats, contains('dump'));
    });

    test('FontOptions creation', () {
      final options = FontOptions(
        sourcePath: '/path/to/font.ttf',
        ranges: [Range(start: 0x20, end: 0x7F, mappedStart: 0x20)],
      );
      expect(options.sourcePath, equals('/path/to/font.ttf'));
      expect(options.ranges, hasLength(1));
    });

    test('AppError', () {
      final error = AppError('Test error');
      expect(error.toString(), equals('Test error'));
    });

    test('Ranger functionality', () {
      final ranger = Ranger();
      
      // Test adding range
      final rangeChars = ranger.addRange('font1.ttf', 0x41, 0x43, 0x41); // A-C
      expect(rangeChars, equals([0x41, 0x42, 0x43]));
      
      // Test adding symbols
      final symbolChars = ranger.addSymbols('font2.ttf', '123');
      expect(symbolChars, equals([0x31, 0x32, 0x33])); // '1', '2', '3'
      
      // Test mapping
      final mapping = ranger.get();
      expect(mapping[0x41]!.font, equals('font1.ttf'));
      expect(mapping[0x41]!.code, equals(0x41));
      expect(mapping[0x31]!.font, equals('font2.ttf'));
      expect(mapping[0x31]!.code, equals(0x31));
    });

    test('Range from symbols', () {
      final range = Range.fromSymbols('ABC');
      expect(range.symbols, equals('ABC'));
    });

    test('FontData creation', () {
      final glyph = Glyph(
        code: 0x41, // 'A'
        advanceWidth: 10.0,
        bbox: BoundingBox(x: 0, y: -8, width: 8, height: 8),
        kerning: {},
        freetype: null,
        pixels: List.generate(64, (_) => 0), // 8x8 bitmap
      );

      final fontData = FontData(
        ascent: 12,
        descent: -3,
        typoAscent: 10,
        typoDescent: -2,
        typoLineGap: 2,
        size: 16,
        glyphs: [glyph],
        underlinePosition: -1,
        underlineThickness: 1,
      );

      expect(fontData.glyphs, hasLength(1));
      expect(fontData.glyphs.first.code, equals(0x41));
      expect(fontData.size, equals(16));
    });
  });
}
