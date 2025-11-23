/// Font data collection and processing module
library;

import 'dart:typed_data';
import 'ranger.dart';

/// Font data structure
class FontData {
  final List<GlyphData> glyphs;
  final int ascent;
  final int descent;
  final int typoAscent;
  final int typoDescent;
  final int typoLineGap;
  final int size;
  final int underlinePosition;
  final int underlineThickness;

  FontData({
    required this.glyphs,
    required this.ascent,
    required this.descent,
    required this.typoAscent,
    required this.typoDescent,
    required this.typoLineGap,
    required this.size,
    required this.underlinePosition,
    required this.underlineThickness,
  });

  Map<String, dynamic> toJson() {
    return {
      'glyphs': glyphs.map((g) => g.toJson()).toList(),
      'ascent': ascent,
      'descent': descent,
      'typoAscent': typoAscent,
      'typoDescent': typoDescent,
      'typoLineGap': typoLineGap,
      'size': size,
      'underlinePosition': underlinePosition,
      'underlineThickness': underlineThickness,
    };
  }
}

/// Glyph data structure
class GlyphData {
  final int code;
  final double advanceWidth;
  final BoundingBox bbox;
  final Map<int, double> kerning;
  final List<List<int>> pixels;

  GlyphData({
    required this.code,
    required this.advanceWidth,
    required this.bbox,
    required this.kerning,
    required this.pixels,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'advanceWidth': advanceWidth,
      'bbox': bbox.toJson(),
      'kerning': kerning,
      'pixels': pixels,
    };
  }
}

/// Bounding box structure
class BoundingBox {
  final int x;
  final int y;
  final int width;
  final int height;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }
}

/// Font specification from CLI arguments
class FontSpec {
  final String sourcePath;
  final Uint8List sourceBin;
  final List<RangeItem> ranges;

  FontSpec({
    required this.sourcePath,
    required this.sourceBin,
    required this.ranges,
  });
}

/// Range item (either range or symbols)
class RangeItem {
  final List<int>? range;
  final String? symbols;

  RangeItem({this.range, this.symbols});
}

/// Collect font data from input arguments
Future<Map<String, dynamic>> collectFontData(Map<String, dynamic> args) async {
  // Create font options map for quick access
  final fontsOptions = <String, FontSpec>{};
  for (final font in args['font'] as List) {
    fontsOptions[font['source_path'] as String] = FontSpec(
      sourcePath: font['source_path'] as String,
      sourceBin: font['source_bin'] as Uint8List,
      ranges: (font['ranges'] as List).map((r) => RangeItem(
        range: r['range'] as List<int>?,
        symbols: r['symbols'] as String?,
      )).toList(),
    );
  }

  // For now, we'll use a simplified font loading approach
  // In a real implementation, you would use a font parsing library
  final ranger = Ranger();

  // Process ranges for each font
  for (final fontSpec in fontsOptions.values) {
    for (final item in fontSpec.ranges) {
      if (item.range != null) {
        // Process range (start, end, step)
        final range = item.range!;
        for (int i = 0; i < range.length; i += 3) {
          if (i + 2 < range.length) {
            final start = range[i];
            final end = range[i + 1];
            final step = range[i + 2];
            ranger.addRange(fontSpec.sourcePath, start, end, step);
          }
        }
      }

      if (item.symbols != null) {
        // Process symbols string
        ranger.addSymbols(fontSpec.sourcePath, item.symbols!);
      }
    }
  }

  final mapping = ranger.get();
  final glyphs = <GlyphData>[];
  final allDstCharcodes = mapping.keys.toList()..sort();

  // Generate glyph data
  for (final dstCode in allDstCharcodes) {
    final srcCode = mapping[dstCode]!.code;
    final srcFont = mapping[dstCode]!.font;

    // For now, create placeholder glyph data
    // In a real implementation, you would render actual glyphs
    glyphs.add(GlyphData(
      code: dstCode,
      advanceWidth: (srcCode % 10 + 5).toDouble(), // Placeholder
      bbox: BoundingBox(
        x: 0,
        y: -2,
        width: 8,
        height: 8,
      ),
      kerning: {},
      pixels: _generatePlaceholderPixels(),
    ));
  }

  // Add some kerning if not disabled
  if (!args['no_kerning'] as bool) {
    _addKerning(glyphs, mapping);
  }

  // Calculate font metrics
  final ascent = glyphs.map((g) => g.bbox.y + g.bbox.height).reduce((a, b) => a > b ? a : b);
  final descent = glyphs.map((g) => g.bbox.y).reduce((a, b) => a < b ? a : b);
  final size = args['size'] as int? ?? 12;

  return {
    'glyphs': glyphs.map((g) => g.toJson()).toList(),
    'ascent': ascent,
    'descent': descent,
    'typoAscent': ascent - 2,
    'typoDescent': descent + 2,
    'typoLineGap': 0,
    'size': size,
    'underlinePosition': -1,
    'underlineThickness': 1,
  };
}

/// Generate placeholder pixel data for testing
List<List<int>> _generatePlaceholderPixels() {
  return [
    [1, 0, 0, 0, 0, 0, 0, 1],
    [0, 1, 0, 0, 0, 0, 1, 0],
    [0, 0, 1, 0, 0, 1, 0, 0],
    [0, 0, 0, 1, 1, 0, 0, 0],
    [0, 0, 0, 1, 1, 0, 0, 0],
    [0, 0, 1, 0, 0, 1, 0, 0],
    [0, 1, 0, 0, 0, 0, 1, 0],
    [1, 0, 0, 0, 0, 0, 0, 1],
  ];
}

/// Add basic kerning between glyphs
void _addKerning(List<GlyphData> glyphs, Map<int, CharMapping> mapping) {
  for (final glyph in glyphs) {
    if (glyph.code % 5 == 0) {
      // Add some kerning for every 5th glyph
      glyph.kerning[glyph.code + 1] = -1.0;
    }
  }
}