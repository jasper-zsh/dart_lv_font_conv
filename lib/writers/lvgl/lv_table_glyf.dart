/// LVGL glyph table writer
library;

import '../../font/table_glyf.dart';
import '../../font/bit_stream.dart';
import '../../utils.dart';

/// LVGL glyph table class
class LvTableGlyf extends Glyf {
  List<LvGlyphData> _lvData = [];
  bool _lvCompiled = false;

  LvTableGlyf(Glyf font) : super(font.font);

  /// Generate bitmap data for a glyph
  List<int> _lvBitmap(Map<String, dynamic> glyph) {
    final bufSize = 100 + (widthToStride(glyph['bbox']['width']) * glyph['bbox']['height']) *
                     (font.opts['bpp'] as int) + (font.opts['align'] as int);

    final bitStream = BitStream.size(bufSize.toInt());
    bitStream.bigEndian = true;

    final pixels = pixelsToBpp(glyph['pixels'] as List<List<int>>);
    storePixels(bitStream, pixels);

    int byteCount = (bitStream.position / 8).ceil();
    if (font.opts['align'] != 1) {
      byteCount = (byteCount / (font.opts['align'] as int)).ceil() * (font.opts['align'] as int);
    }

    return bitStream.getBytes().take(byteCount).toList();
  }

  /// Compile LVGL glyph data
  void _lvCompile() {
    if (_lvCompiled) return;
    _lvCompiled = true;

    final f = font;
    _lvData = List.filled(f.lastId, LvGlyphData([], 0, {}));
    int offset = 0;

    for (final glyph in f.src['glyphs'] as List) {
      final id = f.glyphId[glyph['code']]!;
      final bin = _lvBitmap(glyph);
      _lvData[id] = LvGlyphData(bin, offset, glyph);
      offset += bin.length;
    }
  }

  /// Generate C code for glyph bitmaps
  String _toLvBitmaps() {
    _lvCompile();

    final buffer = StringBuffer();

    for (int idx = 1; idx < _lvData.length; idx++) {
      final d = _lvData[idx];
      final codeHex = (d.glyph['code'] as int).toRadixString(16).toUpperCase().padLeft(4, '0');
      final codeStr = '"${String.fromCharCode(d.glyph['code'])}"';

      int cols = 8;
      if (font.opts['stride'] > 0) {
        cols = widthToStride(d.glyph['bbox']['width']);
      }

      buffer.writeln('    /* U+$codeHex $codeStr */');
      buffer.write(longDump(d.bitmap, hex: true, col: cols));

      if (idx < _lvData.length - 1) {
        buffer.writeln(d.bitmap.isNotEmpty ? ',\n\n' : '\n');
      }
    }

    return buffer.toString();
  }

  /// Generate C code for glyph descriptions
  String _toLvGlyphDesc() {
    _lvCompile();

    final result = <String>[];
    result.add('    {.bitmap_index = 0, .adv_w = 0, .box_w = 0, .box_h = 0, .ofs_x = 0, .ofs_y = 0} /* id = 0 reserved */');

    for (final d in _lvData) {
      if (d.bitmap.isEmpty) continue;

      final idx = d.offset;
      final advW = (d.glyph['advanceWidth'] * 16).round();
      final h = d.glyph['bbox']['height'];
      final w = d.glyph['bbox']['width'];
      final x = d.glyph['bbox']['x'];
      final y = d.glyph['bbox']['y'];

      result.add('    {.bitmap_index = $idx, .adv_w = $advW, .box_w = $w, .box_h = $h, .ofs_x = $x, .ofs_y = $y}');
    }

    return result.join(',\n');
  }

  /// Generate C array for LVGL glyph data
  String toCArray() {
    final buffer = StringBuffer();
    buffer.writeln('/*-----------------');
    buffer.writeln(' *    BITMAPS');
    buffer.writeln(' *----------------*/');
    buffer.writeln();
    buffer.writeln('/*Store the image of the glyphs*/');

    if (font.opts['align'] != 1) {
      buffer.write('LV_ATTRIBUTE_MEM_ALIGN ');
    }
    buffer.writeln('LV_ATTRIBUTE_LARGE_CONST const uint8_t glyph_bitmap[] = {');

    buffer.write(_toLvBitmaps());
    buffer.writeln();
    buffer.writeln('};');
    buffer.writeln();
    buffer.writeln('/*---------------------');
    buffer.writeln(' *  GLYPH DESCRIPTION');
    buffer.writeln(' *--------------------*/');
    buffer.writeln();
    buffer.writeln('static const lv_font_fmt_txt_glyph_dsc_t glyph_dsc[] = {');
    buffer.write(_toLvGlyphDesc());
    buffer.writeln();
    buffer.writeln('};');

    return buffer.toString();
  }

  /// Generate glyph descriptions for font structure
  String toDescriptions() {
    return _toLvGlyphDesc();
  }
}

/// LVGL glyph data structure
class LvGlyphData {
  final List<int> bitmap;
  final int offset;
  final Map<String, dynamic> glyph;

  LvGlyphData(this.bitmap, this.offset, this.glyph);
}