/// LVGL font wrapper class
library;

import '../../font/font.dart';
import 'lv_table_cmap.dart';
import 'lv_table_glyf.dart';
import 'lv_table_head.dart';
import 'lv_table_kern.dart';

/// LVGL font class that extends the base Font class for LVGL format
class LvFont {
  final Font _font;
  final Map<String, dynamic> _args;
  late final LvTableCmap _lvCmap;
  late final LvTableGlyf _lvGlyf;
  late final LvTableHead _lvHead;
  late final LvTableKern _lvKern;

  LvFont(Map<String, dynamic> fontData, Map<String, dynamic> args)
      : _font = Font(fontData, args),
        _args = args {
    _lvCmap = LvTableCmap(_font.cmap);
    _lvGlyf = LvTableGlyf(_font.glyf);
    _lvHead = LvTableHead(_font.head);
    _lvKern = LvTableKern(_font.kern);
  }

  /// Generate C code for LVGL font
  String toCCode() {
    final buffer = StringBuffer();

    // Write header comment
    _writeHeader(buffer);

    // Write includes
    _writeIncludes(buffer);

    // Write glyph data
    _writeGlyphData(buffer);

    // Write glyph descriptions
    _writeGlyphDescriptions(buffer);

    // Write character map
    _writeCmap(buffer);

    // Write kerning data
    if (_font.hasKerning()) {
      _writeKerning(buffer);
    }

    // Write font structure
    _writeFontStructure(buffer);

    return buffer.toString();
  }

  void _writeHeader(StringBuffer buffer) {
    buffer.writeln('/*******************************************************************************');
    buffer.writeln(' * Size: ${_font.src['size']}px');
    buffer.writeln(' * Bpp: ${_args['bpp']}');
    buffer.writeln(' * Use `lvglconv` to migrate the `lv_font_..._c arrays` to a compiled font file');
    buffer.writeln(' ******************************************************************************/');
    buffer.writeln();
  }

  void _writeIncludes(StringBuffer buffer) {
    buffer.writeln('#ifdef __cplusplus');
    buffer.writeln('extern "C" { /* C-declarations for C++ */');
    buffer.writeln('#endif');
    buffer.writeln();
    buffer.writeln('#include "lvgl.h"');
    buffer.writeln();
  }

  void _writeGlyphData(StringBuffer buffer) {
    final glyphData = _lvGlyf.toCArray();
    buffer.writeln(glyphData);
    buffer.writeln();
  }

  void _writeGlyphDescriptions(StringBuffer buffer) {
    final descriptions = _lvGlyf.toDescriptions();
    buffer.writeln(descriptions);
    buffer.writeln();
  }

  void _writeCmap(StringBuffer buffer) {
    final cmapData = _lvCmap.toCArray();
    buffer.writeln(cmapData);
    buffer.writeln();
  }

  void _writeKerning(StringBuffer buffer) {
    final kernData = _lvKern.toCArray();
    if (kernData.isNotEmpty) {
      buffer.writeln(kernData);
      buffer.writeln();
    }
  }

  void _writeFontStructure(StringBuffer buffer) {
    final fontStruct = _lvHead.toFontStructure();
    buffer.writeln(fontStruct);
  }
}