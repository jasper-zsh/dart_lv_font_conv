/// Tests for collect font data functionality
library;

import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import '../lib/collect_font_data.dart';

void main() {
  group('Collect font data', () {
    // NOTE: This test requires a real font file. In the original JS version,
    // it uses 'roboto-fontface/fonts/roboto/Roboto-Black.woff'
    // For Dart, we'll need to adapt or skip these tests unless the font file is available

    test('Should convert range to bitmap', () async {
      // Skip if test font is not available
      final fontFile = File('fonts/Roboto-Black.woff');
      if (!fontFile.existsSync()) {
        return;
      }

      final sourcePath = fontFile.path;
      final sourceBin = await fontFile.readAsBytes();

      final out = await collectFontData({
        'font': [{
          'source_path': sourcePath,
          'source_bin': sourceBin,
          'ranges': [{'range': [0x41, 0x42, 0x80]}]
        }],
        'size': 18
      });

      expect(out.glyphs.length, equals(2));
      expect(out.glyphs[0].code, equals(0x80));
      expect(out.glyphs[1].code, equals(0x81));
    });

    test('Should convert symbols to bitmap', () async {
      final fontFile = File('fonts/Roboto-Black.woff');
      if (!fontFile.existsSync()) {
        return;
      }

      final sourcePath = fontFile.path;
      final sourceBin = await fontFile.readAsBytes();

      final out = await collectFontData({
        'font': [{
          'source_path': sourcePath,
          'source_bin': sourceBin,
          'ranges': [{'symbols': 'AB'}]
        }],
        'size': 18
      });

      expect(out.glyphs.length, equals(2));
      expect(out.glyphs[0].code, equals(0x41));
      expect(out.glyphs[1].code, equals(0x42));
    });

    test('Should not fail on combining characters', () async {
      final fontFile = File('fonts/Roboto-Black.woff');
      if (!fontFile.existsSync()) {
        return;
      }

      final sourcePath = fontFile.path;
      final sourceBin = await fontFile.readAsBytes();

      final out = await collectFontData({
        'font': [{
          'source_path': sourcePath,
          'source_bin': sourceBin,
          'ranges': [{'range': [0x300, 0x300, 0x300]}]
        }],
        'size': 18
      });

      expect(out.glyphs.length, equals(1));
      expect(out.glyphs[0].code, equals(0x300));
      expect(out.glyphs[0].advanceWidth, equals(0));
    });

    test('Should allow specifying same font multiple times', () async {
      final fontFile = File('fonts/Roboto-Black.woff');
      if (!fontFile.existsSync()) {
        return;
      }

      final sourcePath = fontFile.path;
      final sourceBin = await fontFile.readAsBytes();

      final out = await collectFontData({
        'font': [{
          'source_path': sourcePath,
          'source_bin': sourceBin,
          'ranges': [{'range': [0x41, 0x41, 0x41]}]
        }, {
          'source_path': sourcePath,
          'source_bin': sourceBin,
          'ranges': [{'range': [0x51, 0x51, 0x51]}]
        }],
        'size': 18
      });

      expect(out.glyphs.length, equals(2));
    });

    test('Should allow multiple ranges', () async {
      final fontFile = File('fonts/Roboto-Black.woff');
      if (!fontFile.existsSync()) {
        return;
      }

      final sourcePath = fontFile.path;
      final sourceBin = await fontFile.readAsBytes();

      final out = await collectFontData({
        'font': [{
          'source_path': sourcePath,
          'source_bin': sourceBin,
          'ranges': [{'range': [0x41, 0x41, 0x41, 0x51, 0x52, 0x51]}]
        }],
        'size': 18
      });

      expect(out.glyphs.length, equals(3));
    });

    test('Should work with sparse ranges', () async {
      final fontFile = File('fonts/Roboto-Black.woff');
      if (!fontFile.existsSync()) {
        return;
      }

      final sourcePath = fontFile.path;
      final sourceBin = await fontFile.readAsBytes();

      final out = await collectFontData({
        'font': [{
          'source_path': sourcePath,
          'source_bin': sourceBin,
          'ranges': [{'range': [0x3d0, 0x3d8, 0x3d0]}]
        }],
        'size': 10
      });

      expect(out.glyphs.length, equals(3));
      expect(out.glyphs[0].code, equals(0x3d1));
      expect(out.glyphs[1].code, equals(0x3d2));
      expect(out.glyphs[2].code, equals(0x3d6));
    });

    test('Should read kerning values', () async {
      final fontFile = File('fonts/Roboto-Black.woff');
      if (!fontFile.existsSync()) {
        return;
      }

      final sourcePath = fontFile.path;
      final sourceBin = await fontFile.readAsBytes();

      final out = await collectFontData({
        'font': [{
          'source_path': sourcePath,
          'source_bin': sourceBin,
          'ranges': [
            // AVW
            {'range': [0x41, 0x41, 1]},
            {'range': [0x56, 0x57, 2]}
          ]
        }],
        'size': 18
      });

      expect(out.glyphs.length, equals(3));

      // A
      expect(out.glyphs[0].code, equals(1));
      expect(out.glyphs[0].kerning[1], isNull);
      expect(out.glyphs[0].kerning[2]!, lessThan(0));
      expect(out.glyphs[0].kerning[3]!, lessThan(0));

      // V
      expect(out.glyphs[1].code, equals(2));
      expect(out.glyphs[1].kerning[1]!, lessThan(0));
      expect(out.glyphs[1].kerning[2], isNull);
      expect(out.glyphs[1].kerning[3], isNull);

      // W
      expect(out.glyphs[2].code, equals(3));
      expect(out.glyphs[2].kerning[1]!, lessThan(0));
      expect(out.glyphs[2].kerning[2], isNull);
      expect(out.glyphs[2].kerning[3], isNull);
    });

    test('Should error on empty ranges', () async {
      final fontFile = File('fonts/Roboto-Black.woff');
      if (!fontFile.existsSync()) {
        return;
      }

      final sourcePath = fontFile.path;
      final sourceBin = await fontFile.readAsBytes();

      expect(
        () => collectFontData({
          'font': [{
            'source_path': sourcePath,
            'source_bin': sourceBin,
            'ranges': [{'range': [0x3d3, 0x3d5, 0x3d3]}]
          }],
          'size': 18
        }),
        throwsA(contains('doesn\'t have any characters'))
      );
    });

    test('Should error on empty symbol sets', () async {
      final fontFile = File('fonts/Roboto-Black.woff');
      if (!fontFile.existsSync()) {
        return;
      }

      final sourcePath = fontFile.path;
      final sourceBin = await fontFile.readAsBytes();

      expect(
        () => collectFontData({
          'font': [{
            'source_path': sourcePath,
            'source_bin': sourceBin,
            'ranges': [{'symbols': '\u03d3\u03d4\u03d5'}]
          }],
          'size': 18
        }),
        throwsA(contains('doesn\'t have any characters'))
      );
    });

    test('Should error when font format is unknown', () async {
      expect(
        () => collectFontData({
          'font': [{
            'source_path': Platform.script.toFilePath(),
            'source_bin': File(Platform.script.toFilePath()).readAsBytesSync(),
            'ranges': [{'range': [0x20, 0x20, 0x20]}]
          }],
          'size': 18
        }),
        throwsA(matches(RegExp(r'Cannot load font.*(Unknown|Unsupported)')))
      );
    });
  });
}