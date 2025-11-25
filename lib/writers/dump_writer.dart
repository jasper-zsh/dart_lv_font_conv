/// Debug/dump format writer
library;

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../app_error.dart';
import '../collect_font_data.dart';
import '../utils.dart';

/// Dump writer that outputs human-readable font data
Map<String, List<int>> dumpWriter(Map<String, dynamic> args, Map<String, dynamic> fontData) {
  if (args['output'] == null) {
    throw AppError('Output is required for "dump" writer');
  }

  final output = args['output'] as String;
  final bpp = args['bpp'] as int? ?? 1;
  final glyphs = (fontData['glyphs'] as List)
      .map<Map<String, dynamic>>(
        (g) => setDepth(Map<String, dynamic>.from(g as Map<String, dynamic>), bpp),
      )
      .toList();

  // If output looks like a directory (no dot), mirror original tool behavior and
  // write per-glyph images + font info.
  if (!p.basename(output).contains('.')) {
    final files = <String, List<int>>{};
    for (final glyph in glyphs) {
      final code = glyph['code'] as int;
      final bbox = glyph['bbox'] as Map<String, dynamic>;
      final bboxX = bbox['x'] as int;
      final bboxY = bbox['y'] as int;
      final bboxWidth = bbox['width'] as int;
      final bboxHeight = bbox['height'] as int;
      final glyphPixels = glyph['pixels'] as List;
      final advanceWidth = (glyph['advanceWidth'] as num).round();
      final minX = bboxX;
      final maxX = (bboxWidth > 0) ? bboxX + bboxWidth - 1 : bboxX;
      final minY = bboxY < (fontData['typoDescent'] as int) ? bboxY : (fontData['typoDescent'] as int);
      final glyphMaxY = bboxY + bboxHeight - 1;
      final maxY = glyphMaxY > (fontData['typoAscent'] as int) ? glyphMaxY : (fontData['typoAscent'] as int);

      final canvasWidth = maxX - minX + 1;
      final canvasHeight = maxY - minY + 1;
      final image = img.Image(width: canvasWidth, height: canvasHeight);

      const normalColor = [255, 255, 255];
      const outsideColor = [255, 127, 184];

      int destY = 0;
      for (int y = maxY; y >= minY; y--, destY++) {
        int destX = 0;
        for (int x = minX; x <= maxX; x++, destX++) {
          int value = 0;
          if (x >= bboxX && x < bboxX + bboxWidth && y >= bboxY && y < bboxY + bboxHeight) {
            final glyphRow = bboxHeight - (y - bboxY) - 1;
            final glyphCol = x - bboxX;
            value = (glyphPixels[glyphRow] as List)[glyphCol] as int;
          }

          final outside = x < 0 || x >= advanceWidth || y < (fontData['typoDescent'] as int) || y > (fontData['typoAscent'] as int);
          final color = outside ? outsideColor : normalColor;
          final factor = (255 - value) / 255.0;

          image.setPixelRgba(
            destX,
            destY,
            (factor * color[0]).round(),
            (factor * color[1]).round(),
            (factor * color[2]).round(),
            255,
          );
        }
      }

      final name = '${code.toRadixString(16)}.png';
      files[p.join(output, name)] = img.encodePng(image);
    }
    final includePixels = args['full_info'] == true;
    final glyphsInfo = glyphs
        .map<Map<String, dynamic>>((g) {
          final copy = Map<String, dynamic>.from(g);
          if (!includePixels) {
            copy.remove('pixels');
          }
          return copy;
        })
        .toList();

    final fontInfo = Map<String, dynamic>.from(fontData)..['glyphs'] = glyphsInfo;
    files[p.join(output, 'font_info.json')] = utf8.encode(jsonEncode(fontInfo));
    return files;
  }

  final buffer = StringBuffer();
  buffer.writeln('# Font Dump');
  buffer.writeln('# Format: ${args['format']}');
  buffer.writeln('# Size: ${fontData['size']}');
  buffer.writeln('');
  buffer.writeln('## Font Metrics');
  buffer.writeln('Ascent: ${fontData['ascent']}');
  buffer.writeln('Descent: ${fontData['descent']}');
  buffer.writeln('Typo Ascent: ${fontData['typoAscent']}');
  buffer.writeln('Typo Descent: ${fontData['typoDescent']}');
  buffer.writeln('Typo Line Gap: ${fontData['typoLineGap']}');
  buffer.writeln('Underline Position: ${fontData['underlinePosition']}');
  buffer.writeln('Underline Thickness: ${fontData['underlineThickness']}');
  buffer.writeln('');
  buffer.writeln('## Glyphs');
  for (int i = 0; i < glyphs.length; i++) {
    final glyph = glyphs[i];
    buffer.writeln('### Glyph $i');
    buffer.writeln('Code: ${glyph['code']} (U+${(glyph['code'] as int).toRadixString(16).padLeft(4, '0')})');
    buffer.writeln('Advance Width: ${glyph['advanceWidth']}');

    final bbox = glyph['bbox'] as Map<String, dynamic>;
    buffer.writeln('Bounding Box: x=${bbox['x']}, y=${bbox['y']}, width=${bbox['width']}, height=${bbox['height']}');

    final kerning = glyph['kerning'] as Map?;
    if (kerning != null && kerning.isNotEmpty) {
      buffer.writeln('Kerning:');
      kerning.forEach((code, value) {
        buffer.writeln('  U+${(code as int).toRadixString(16).padLeft(4, '0')}: $value');
      });
    }

    final pixels = glyph['pixels'] as List;
    buffer.writeln('Pixels (${pixels.length}x${(pixels.isNotEmpty ? (pixels[0] as List).length : 0)}):');
    for (final row in pixels) {
      final pixelRow = (row as List).map((p) => (p as int) > 0 ? '#' : '.').join('');
      buffer.writeln('  $pixelRow');
    }
    buffer.writeln('');
  }

  return {
    output: utf8.encode(buffer.toString()),
  };
}
