/// LVGL header table writer
library;

import '../../font/table_head.dart';

/// LVGL header table class
class LvTableHead extends Head {
  LvTableHead(Head font) : super(font.font);

  /// Get kerning reference information
  Map<String, String> _kernRef() {
    final f = font;

    if (!f.hasKerning()) {
      return {
        'scale': '0',
        'dsc': 'NULL',
        'classes': '0',
      };
    }

    // Check if we should use format3 (classes)
    if (!f.kern.shouldUseFormat3()) {
      return {
        'scale': '${(f.kerningScale * 16).round()}',
        'dsc': '&kern_pairs',
        'classes': '0',
      };
    }

    return {
      'scale': '${(f.kerningScale * 16).round()}',
      'dsc': '&kern_classes',
      'classes': '1',
    };
  }

  /// Get stride alignment string
  String _getStrideAlign() {
    if (font.opts['stride'] != null && font.opts['stride'] > 0) {
      return '    .stride = ${font.opts['stride']}';
    }
    return '';
  }

  /// Generate font structure for LVGL
  String toFontStructure() {
    final f = font;
    final kern = _kernRef();
    final subpixels = f.subpixelsMode == 0
        ? 'LV_FONT_SUBPX_NONE'
        : f.subpixelsMode == 1
            ? 'LV_FONT_SUBPX_HOR'
            : 'LV_FONT_SUBPX_VER';

    final staticBitmap = f.glyf.getCompressionCode() == 0 ? '1' : '0';
    final strideAlign = _getStrideAlign();

    final buffer = StringBuffer();
    buffer.writeln('/*--------------------');
    buffer.writeln(' *  ALL CUSTOM DATA');
    buffer.writeln(' *--------------------*/');
    buffer.writeln();

    buffer.writeln('#if LVGL_VERSION_MAJOR == 8');
    buffer.writeln('/*Store all the custom data of the font*/');
    buffer.writeln('static  lv_font_fmt_txt_glyph_cache_t cache;');
    buffer.writeln('#endif');
    buffer.writeln();

    buffer.writeln('#if LVGL_VERSION_MAJOR >= 8');
    buffer.writeln('static const lv_font_fmt_txt_dsc_t font_dsc = {');
    buffer.writeln('#else');
    buffer.writeln('static lv_font_fmt_txt_dsc_t font_dsc = {');
    buffer.writeln('#endif');

    // Font descriptor content
    buffer.writeln('    .glyph_bitmap = glyph_bitmap,');
    buffer.writeln('    .glyph_dsc = glyph_dsc,');
    buffer.writeln('    .cmaps = cmaps,');
    buffer.writeln('    .kern_dsc = ${kern['dsc']},');
    buffer.writeln('    .kern_scale = ${kern['scale']},');
    buffer.writeln('    .cmap_num = ${f.cmap.toBin().sublist(8, 12).reduce((a, b) => a + b)},');
    buffer.writeln('    .bpp = ${f.opts['bpp']},');
    buffer.writeln('    .kern_classes = ${kern['classes']},');
    buffer.writeln('    .bitmap_format = ${f.glyf.getCompressionCode()},');
    buffer.writeln('#if LVGL_VERSION_MAJOR == 8');
    buffer.writeln('    .cache = &cache');
    buffer.writeln('#endif');

    if (strideAlign.isNotEmpty) {
      buffer.writeln(strideAlign);
    }

    buffer.writeln('};');
    buffer.writeln();

    // Fallback declaration (if needed)
    if (f.opts['fallback'] != null) {
      buffer.writeln('extern const lv_font_t ${f.opts['fallback']};');
      buffer.writeln();
    }

    buffer.writeln('/*-----------------');
    buffer.writeln(' *  PUBLIC FONT');
    buffer.writeln(' *----------------*/');
    buffer.writeln();
    buffer.writeln('/*Initialize a public general font descriptor*/');

    final fontName = f.opts['font_name'] as String? ?? 'custom_font';

    buffer.writeln('#if LVGL_VERSION_MAJOR >= 8');
    buffer.writeln('const lv_font_t $fontName = {');
    buffer.writeln('#else');
    buffer.writeln('lv_font_t $fontName = {');
    buffer.writeln('#endif');

    buffer.writeln('    .get_glyph_dsc = lv_font_get_glyph_dsc_fmt_txt,    /*Function pointer to get glyph\'s data*/');
    buffer.writeln('    .get_glyph_bitmap = lv_font_get_bitmap_fmt_txt,    /*Function pointer to get glyph\'s bitmap*/');
    buffer.writeln('    .line_height = ${f.src['ascent'] - f.src['descent']},          /*The maximum line height required by the font*/');
    buffer.writeln('    .base_line = ${-f.src['descent']},             /*Baseline measured from the bottom of the line*/');
    buffer.writeln('#if !(LVGL_VERSION_MAJOR == 6 && LVGL_VERSION_MINOR == 0)');
    buffer.writeln('    .subpx = $subpixels,');
    buffer.writeln('#endif');
    buffer.writeln('#if LV_VERSION_CHECK(7, 4, 0) || LVGL_VERSION_MAJOR >= 8');
    buffer.writeln('    .underline_position = ${f.src['underlinePosition']},');
    buffer.writeln('    .underline_thickness = ${f.src['underlineThickness']},');
    buffer.writeln('#endif');
    buffer.writeln();
    buffer.writeln('#if LV_VERSION_CHECK(9, 3, 0)');
    buffer.writeln('    .static_bitmap = $staticBitmap,    /*Bitmaps are stored as const so they are always static if not compressed */');
    buffer.writeln('#endif');
    buffer.writeln();
    buffer.writeln('    .dsc = &font_dsc,          /*The custom font data. Will be accessed by \`get_glyph_bitmap/dsc\` */');
    buffer.writeln('#if LV_VERSION_CHECK(8, 2, 0) || LVGL_VERSION_MAJOR >= 9');
    buffer.writeln('    .fallback = ${f.opts['fallback'] ?? 'NULL'},');
    buffer.writeln('#endif');
    buffer.writeln('    .user_data = NULL,');
    buffer.writeln('};');

    return buffer.toString();
  }
}