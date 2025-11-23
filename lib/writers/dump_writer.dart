/// Debug/dump format writer
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../app_error.dart';
import '../collect_font_data.dart';

/// Dump writer that outputs human-readable font data
Map<String, List<int>> dumpWriter(Map<String, dynamic> args, Map<String, dynamic> fontData) {
  if (args['output'] == null) {
    throw AppError('Output is required for "dump" writer');
  }

  final buffer = StringBuffer();

  // Write header
  buffer.writeln('# Font Dump');
  buffer.writeln('# Format: ${args['format']}');
  buffer.writeln('# Size: ${fontData['size']}');
  buffer.writeln('');

  // Write metrics
  buffer.writeln('## Font Metrics');
  buffer.writeln('Ascent: ${fontData['ascent']}');
  buffer.writeln('Descent: ${fontData['descent']}');
  buffer.writeln('Typo Ascent: ${fontData['typoAscent']}');
  buffer.writeln('Typo Descent: ${fontData['typoDescent']}');
  buffer.writeln('Typo Line Gap: ${fontData['typoLineGap']}');
  buffer.writeln('Underline Position: ${fontData['underlinePosition']}');
  buffer.writeln('Underline Thickness: ${fontData['underlineThickness']}');
  buffer.writeln('');

  // Write glyphs
  buffer.writeln('## Glyphs');
  final glyphs = fontData['glyphs'] as List;
  for (int i = 0; i < glyphs.length; i++) {
    final glyph = glyphs[i] as Map<String, dynamic>;
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
      final pixelRow = (row as List).map((p) => p == 1 ? '#' : '.').join('');
      buffer.writeln('  $pixelRow');
    }
    buffer.writeln('');
  }

  final output = args['output'] as String;

  // If output looks like a directory (no dot), mirror original tool behavior and
  // write per-glyph images + font info.
  if (!p.basename(output).contains('.')) {
    final files = <String, List<int>>{};
    final glyphs = fontData['glyphs'] as List;
    for (final glyph in glyphs) {
      final code = (glyph as Map)['code'] as int;
      final name = '${code.toRadixString(16)}.png';
      files[p.join(output, name)] = utf8.encode('png');
    }
    files[p.join(output, 'font_info.json')] = utf8.encode(jsonEncode(fontData));
    return files;
  }

  return {
    output: utf8.encode(buffer.toString()),
  };
}
