library;

import 'dart:io';

import 'package:test/test.dart';

import '../lib/collect_font_data.dart';

void main() {
  final fontFile = File('fonts/NotoSansSC-Regular.ttf');
  late String sourcePath;
  late List<int> sourceBin;

  setUpAll(() {
    if (!fontFile.existsSync()) {
      fail('Test font not found: ${fontFile.path}');
    }
    sourcePath = fontFile.path;
    sourceBin = fontFile.readAsBytesSync();
  });

  group('Collect font data', () {
    test('Should convert range to bitmap', () async {
      final out = await collectFontData({
        'font': [
          {
            'source_path': sourcePath,
            'source_bin': sourceBin,
            'ranges': [
              {
                'range': [0x41, 0x42, 0x80],
              },
            ],
          },
        ],
        'size': 18,
      });

      final glyphs = out['glyphs'] as List;
      expect(glyphs.length, equals(2));
      expect((glyphs[0] as Map)['code'], equals(0x80));
      expect((glyphs[1] as Map)['code'], equals(0x81));
    });

    test('Should convert symbols to bitmap', () async {
      final out = await collectFontData({
        'font': [
          {
            'source_path': sourcePath,
            'source_bin': sourceBin,
            'ranges': [
              {'symbols': 'AB'},
            ],
          },
        ],
        'size': 18,
      });

      final glyphs = out['glyphs'] as List;
      expect(glyphs.length, equals(2));
      expect((glyphs[0] as Map)['code'], equals(0x41));
      expect((glyphs[1] as Map)['code'], equals(0x42));
    });

    test('Should not fail on combining characters', () async {
      final out = await collectFontData({
        'font': [
          {
            'source_path': sourcePath,
            'source_bin': sourceBin,
            'ranges': [
              {
                'range': [0x300, 0x300, 0x300],
              },
            ],
          },
        ],
        'size': 18,
      });

      final glyphs = out['glyphs'] as List;
      expect(glyphs.length, equals(1));
      expect((glyphs[0] as Map)['code'], equals(0x300));
      expect((glyphs[0] as Map)['advanceWidth'], equals(0));
    });

    test('Should allow specifying same font multiple times', () async {
      final out = await collectFontData({
        'font': [
          {
            'source_path': sourcePath,
            'source_bin': sourceBin,
            'ranges': [
              {
                'range': [0x41, 0x41, 0x41],
              },
            ],
          },
          {
            'source_path': sourcePath,
            'source_bin': sourceBin,
            'ranges': [
              {
                'range': [0x51, 0x51, 0x51],
              },
            ],
          },
        ],
        'size': 18,
      });

      final glyphs = out['glyphs'] as List;
      expect(glyphs.length, equals(2));
    });

    test('Should allow multiple ranges', () async {
      final out = await collectFontData({
        'font': [
          {
            'source_path': sourcePath,
            'source_bin': sourceBin,
            'ranges': [
              {
                'range': [0x41, 0x41, 0x41, 0x51, 0x52, 0x51],
              },
            ],
          },
        ],
        'size': 18,
      });

      final glyphs = out['glyphs'] as List;
      expect(glyphs.length, equals(3));
    });

    test('Should work with sparse ranges', () async {
      final out = await collectFontData({
        'font': [
          {
            'source_path': sourcePath,
            'source_bin': sourceBin,
            'ranges': [
              {
                'range': [0x3d0, 0x3d8, 0x3d0],
              },
            ],
          },
        ],
        'size': 10,
      });

      final glyphs = out['glyphs'] as List;
      expect(glyphs.length, equals(3));
      expect((glyphs[0] as Map)['code'], equals(0x3d1));
      expect((glyphs[1] as Map)['code'], equals(0x3d2));
      expect((glyphs[2] as Map)['code'], equals(0x3d6));
    });

    test('Should read kerning values', () async {
      final out = await collectFontData({
        'font': [
          {
            'source_path': sourcePath,
            'source_bin': sourceBin,
            'ranges': [
              {
                'range': [0x41, 0x41, 1],
              },
              {
                'range': [0x56, 0x57, 2],
              },
            ],
          },
        ],
        'size': 18,
      });

      final glyphs = out['glyphs'] as List;
      expect(glyphs.length, equals(3));

      final gA = glyphs[0] as Map;
      final gV = glyphs[1] as Map;
      final gW = glyphs[2] as Map;

      expect(gA['code'], equals(1));
      expect((gA['kerning'] as Map)[1], isNull);
      expect((gA['kerning'] as Map)[2], lessThan(0));
      expect((gA['kerning'] as Map)[3], lessThan(0));

      expect(gV['code'], equals(2));
      expect((gV['kerning'] as Map)[1], lessThan(0));
      expect((gV['kerning'] as Map)[2], isNull);
      expect((gV['kerning'] as Map)[3], isNull);

      expect(gW['code'], equals(3));
      expect((gW['kerning'] as Map)[1], lessThan(0));
      expect((gW['kerning'] as Map)[2], isNull);
      expect((gW['kerning'] as Map)[3], isNull);
    });

    test('Should error on empty ranges', () async {
      await expectLater(
        collectFontData({
          'font': [
            {
              'source_path': sourcePath,
              'source_bin': sourceBin,
              'ranges': [
                {
                  'range': [0x3d3, 0x3d5, 0x3d3],
                },
              ],
            },
          ],
          'size': 18,
        }),
        throwsA(
          predicate(
            (e) => e.toString().contains("doesn't have any characters"),
          ),
        ),
      );
    });

    test('Should error on empty symbol sets', () async {
      await expectLater(
        collectFontData({
          'font': [
            {
              'source_path': sourcePath,
              'source_bin': sourceBin,
              'ranges': [
                {'symbols': '\u03d3\u03d4\u03d5'},
              ],
            },
          ],
          'size': 18,
        }),
        throwsA(
          predicate(
            (e) => e.toString().contains("doesn't have any characters"),
          ),
        ),
      );
    });

    test('Should error when font format is unknown', () async {
      await expectLater(
        collectFontData({
          'font': [
            {
              'source_path': Platform.script.toFilePath(),
              'source_bin': File(
                Platform.script.toFilePath(),
              ).readAsBytesSync(),
              'ranges': [
                {
                  'range': [0x20, 0x20, 0x20],
                },
              ],
            },
          ],
          'size': 18,
        }),
        throwsA(
          predicate(
            (e) => RegExp(
              r'Cannot load font.*(Unknown|Unsupported)',
            ).hasMatch('$e'),
          ),
        ),
      );
    });
  });
}
