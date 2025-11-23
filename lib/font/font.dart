/// Font class to generate tables
library;

import '../utils.dart';
import 'table_head.dart';
import 'table_cmap.dart';
import 'table_glyf.dart';
import 'table_loca.dart';
import 'table_kern.dart';

/// Font class that manages font data and generates font tables
class Font {
  /// Source font data
  final Map<String, dynamic> src;

  /// Font options
  final Map<String, dynamic> opts;

  /// Map chars to glyph IDs (zero is reserved)
  final Map<int, int> glyphId = {0: 0};

  /// Last assigned glyph ID
  int lastId = 1;

  /// Font tables
  late final Head head;
  late final Glyf glyf;
  late final Cmap cmap;
  late final Loca loca;
  late final Kern kern;

  /// Font metrics and properties
  late final int minY;
  late final int maxY;
  late final int glyphIdFormat;
  late final double kerningScale;
  late final int advanceWidthFormat;
  late final int xyBits;
  late final int whBits;
  late final int advanceWidthBits;
  late final bool monospaced;
  late final int indexToLocFormat;
  late final int subpixelsMode;

  /// Creates a new Font instance
  Font(this.src, this.opts) {
    createIDs();
    debugPrint('last_id: $lastId');

    initTables();

    minY = src['glyphs'].map<int>((g) => (g['bbox']['y'] as int)).reduce((int a, int b) => a < b ? a : b);
    debugPrint('minY: $minY');

    maxY = src['glyphs'].map<int>((g) => (g['bbox']['y'] as int) + (g['bbox']['height'] as int)).reduce((int a, int b) => a > b ? a : b);
    debugPrint('maxY: $maxY');

    // 0 => 1 byte, 1 => 2 bytes
    glyphIdFormat = glyphId.values.reduce((int a, int b) => a > b ? a : b) > 255 ? 1 : 0;
    debugPrint('glyphIdFormat: $glyphIdFormat');

    // 1.0 by default, will be stored in font as FP12.4
    kerningScale = 1.0;
    final kerningMax = src['glyphs']
        .map<num>((g) {
          final kerning = g['kerning'] as Map?;
          if (kerning == null || kerning.isEmpty) return 0.0;
          return kerning.values.map((v) => (v as num).abs()).reduce((num a, num b) => a > b ? a : b);
        })
        .reduce((num a, num b) => a > b ? a : b);
    if (kerningMax >= 7.5) {
      kerningScale = (kerningMax / 7.5 * 16).ceil() / 16;
    }
    debugPrint('kerningScale: $kerningScale');

    // 0 => int, 1 => FP4
    advanceWidthFormat = hasKerning() ? 1 : 0;
    debugPrint('advanceWidthFormat: $advanceWidthFormat');

    xyBits = src['glyphs'].map<int>((g) => [
      signedBits(g['bbox']['x'] as int),
      signedBits(g['bbox']['y'] as int)
    ].reduce((int a, int b) => a > b ? a : b)).reduce((int a, int b) => a > b ? a : b);
    debugPrint('xy_bits: $xyBits');

    whBits = src['glyphs'].map<int>((g) => [
      unsignedBits(g['bbox']['width'] as int),
      unsignedBits(g['bbox']['height'] as int)
    ].reduce((int a, int b) => a > b ? a : b)).reduce((int a, int b) => a > b ? a : b);
    debugPrint('wh_bits: $whBits');

    advanceWidthBits = src['glyphs'].map<int>((g) =>
      signedBits(widthToInt(g['advanceWidth'] as num))
    ).reduce((int a, int b) => a > b ? a : b);
    debugPrint('advanceWidthBits: $advanceWidthBits');

    final glyphs = src['glyphs'] as List;
    final firstAdvanceWidth = glyphs[0]['advanceWidth'];
    monospaced = glyphs.every((g) => g['advanceWidth'] == firstAdvanceWidth);
    debugPrint('monospaced: $monospaced');

    // This should stay in the end, because depends on previous variables
    // 0 => 2 bytes, 1 => 4 bytes
    indexToLocFormat = glyf.getSize() > 65535 ? 1 : 0;
    debugPrint('indexToLocFormat: $indexToLocFormat');

    subpixelsMode = (opts['lcd'] == true) ? 1 : ((opts['lcd_v'] == true) ? 2 : 0);
    debugPrint('subpixels_mode: $subpixelsMode');
  }

  /// Initialize font tables
  void initTables() {
    head = Head(this);
    glyf = Glyf(this);
    cmap = Cmap(this);
    loca = Loca(this);
    kern = Kern(this);
  }

  /// Create glyph IDs for all glyphs
  void createIDs() {
    // Simplified, don't check dupes
    lastId = 1;

    for (int i = 0; i < src['glyphs'].length; i++) {
      // reserve zero for special cases
      glyphId[src['glyphs'][i]['code']] = lastId;
      lastId++;
    }
  }

  /// Check if font has kerning information
  bool hasKerning() {
    if (opts['no_kerning'] == true) return false;

    for (final glyph in src['glyphs']) {
      final kerning = glyph['kerning'] as Map?;
      if (kerning != null && kerning.isNotEmpty) return true;
    }
    return false;
  }

  /// Returns integer width, depending on format
  int widthToInt(num val) {
    if (advanceWidthFormat == 0) return val.round();
    return (val * 16).round();
  }

  /// Convert kerning to FP4.4, usable for writer. Apply `kerningScale`.
  int kernToFp(num val) {
    return (val / kerningScale * 16).round();
  }

  /// Convert font to binary format
  List<int> toBin() {
    final result = <int>[];

    result.addAll(head.toBin());
    result.addAll(cmap.toBin());
    result.addAll(loca.toBin());
    result.addAll(glyf.toBin());
    result.addAll(kern.toBin());

    debugPrint('font size: ${result.length}');

    return result;
  }
}

/// Simple debug print function (can be enhanced with proper logging)
void debugPrint(String message) {
  // In a real implementation, you might want to use proper logging
  // print('DEBUG: $message');
}