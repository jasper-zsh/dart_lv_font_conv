import 'dart:typed_data';
import 'simple_font_parser.dart';
import 'bitmap_rasterizer.dart';

/// Font data collector
class FontDataCollector {
  bool _initialized = false;
  final Map<String, SimpleFontParser> _parsers = {};
  final Map<String, BitmapRasterizer> _rasterizers = {};

  /// Initialize the font collector
  Future<void> init() async {
    if (_initialized) return;
    
    _initialized = true;
  }

  /// Create a font face from binary data
  Future<FontFace> createFontFace(Uint8List fontData, int size) async {
    if (!_initialized) {
      await init();
    }

    final parser = SimpleFontParser();
    await parser.parseFont(fontData);
    
    final rasterizer = BitmapRasterizer(parser, size, 8); // Default to 8 BPP
    final fontKey = fontData.length.toString(); // Use data length as key
    
    _parsers[fontKey] = parser;
    _rasterizers[fontKey] = rasterizer;

    return FontFace(
      parser: parser,
      rasterizer: rasterizer,
      fontData: fontData,
      size: size,
    );
  }

  /// Get OS/2 table metrics
  Os2Metrics getOs2Table(FontFace face) {
    return Os2Metrics(
      typoAscent: face.parser.ascender,
      typoDescent: face.parser.descender,
      typoLineGap: face.parser.lineGap,
    );
  }

  /// Check if glyph exists for character code
  bool glyphExists(FontFace face, int code) {
    return face.parser.getGlyphIndex(code) != 0;
  }

  /// Render glyph to bitmap
  Future<BitmapGlyphRenderResult> renderGlyph(
    FontFace face,
    int code, {
    bool autohintOff = false,
    bool autohintStrong = false,
    bool lcd = false,
    bool lcdV = false,
    bool mono = false,
    bool useColorInfo = false,
  }) async {
    return face.rasterizer.rasterizeGlyph(
      code,
      mono: mono,
      lcd: lcd,
      lcdV: lcdV,
    );
  }

  /// Destroy font face
  void destroyFontFace(FontFace face) {
    final fontKey = face.fontData.length.toString();
    _parsers.remove(fontKey);
    _rasterizers.remove(fontKey);
  }

  /// Cleanup resources
  void destroy() {
    _parsers.clear();
    _rasterizers.clear();
    _initialized = false;
  }
}

/// Font face representation
class FontFace {
  final SimpleFontParser parser;
  final BitmapRasterizer rasterizer;
  final Uint8List fontData;
  final int size;

  FontFace({
    required this.parser,
    required this.rasterizer,
    required this.fontData,
    required this.size,
  });

  int get unitsPerEm => parser.unitsPerEm;
  int get ascender => parser.ascender;
  int get descender => parser.descender;
  int get height => parser.lineGap + parser.ascender - parser.descender;
}

/// OS/2 table metrics
class Os2Metrics {
  final int typoAscent;
  final int typoDescent;
  final int typoLineGap;

  Os2Metrics({
    required this.typoAscent,
    required this.typoDescent,
    required this.typoLineGap,
  });
}