import 'dart:typed_data';

/// Font conversion options
class FontOptions {
  final String sourcePath;
  final List<Range> ranges;
  final bool autohintOff;
  final bool autohintStrong;
  final Uint8List? sourceBin;

  FontOptions({
    required this.sourcePath,
    required this.ranges,
    this.autohintOff = false,
    this.autohintStrong = false,
    this.sourceBin,
  });
}

/// Represents a character range or symbol mapping
class Range {
  final int start;
  final int end;
  final int mappedStart;
  final String? symbols;

  Range({
    required this.start,
    required this.end,
    required this.mappedStart,
    this.symbols,
  });

  factory Range.fromSymbols(String symbols) {
    return Range(
      start: 0,
      end: 0,
      mappedStart: 0,
      symbols: symbols,
    );
  }
}

/// Bounding box for a glyph
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
}

/// Glyph data
class Glyph {
  final int code;
  final double advanceWidth;
  final BoundingBox bbox;
  final Map<int, double> kerning;
  final dynamic freetype; // Will be replaced with proper type
  final List<int> pixels;

  Glyph({
    required this.code,
    required this.advanceWidth,
    required this.bbox,
    required this.kerning,
    required this.freetype,
    required this.pixels,
  });
}

/// Font data structure
class FontData {
  final int ascent;
  final int descent;
  final int typoAscent;
  final int typoDescent;
  final int typoLineGap;
  final int size;
  final List<Glyph> glyphs;
  final int underlinePosition;
  final int underlineThickness;

  FontData({
    required this.ascent,
    required this.descent,
    required this.typoAscent,
    required this.typoDescent,
    required this.typoLineGap,
    required this.size,
    required this.glyphs,
    required this.underlinePosition,
    required this.underlineThickness,
  });
}

/// Conversion arguments
class ConversionArgs {
  final int size;
  final int bpp;
  final bool lcd;
  final bool lcdV;
  final bool useColorInfo;
  final String format;
  final List<FontOptions> font;
  final String? output;
  final bool noCompress;
  final bool noPrefilter;
  final bool noKerning;
  final int stride;
  final int align;
  final bool fastKerning;
  final String? lvInclude;
  final String? lvFontName;
  final String? lvFallback;
  final bool fullInfo;
  final String optsString;

  ConversionArgs({
    required this.size,
    required this.bpp,
    required this.format,
    required this.font,
    this.output,
    this.lcd = false,
    this.lcdV = false,
    this.useColorInfo = false,
    this.noCompress = false,
    this.noPrefilter = false,
    this.noKerning = false,
    this.stride = 0,
    this.align = 1,
    this.fastKerning = false,
    this.lvInclude,
    this.lvFontName,
    this.lvFallback,
    this.fullInfo = false,
    required this.optsString,
  });
}

/// Exception type for application errors
class AppError extends Error {
  final String message;
  
  AppError(this.message);
  
  @override
  String toString() => message;
}
