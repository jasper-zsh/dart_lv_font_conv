import '../../dart_lv_font_conv_base.dart';
import 'lv_table_head.dart';
import 'lv_table_cmap.dart';
import 'lv_table_glyf.dart';
import 'lv_table_kern.dart';
import 'package:path/path.dart' as path;

/// LVGL Font class
class LvFont {
  final FontData src;
  final ConversionArgs opts;
  final String fontName;
  final String fallback;
  final String fallbackDeclaration;

  late final LvHead head;
  late final LvGlyf glyf;
  late final LvCmap cmap;
  late final LvKern kern;

  // Font properties calculated from data
  late final int subpixelsMode;
  late final double kerningScale;
  late final int advanceWidthFormat;

  LvFont(this.src, this.opts) : fontName = _getFontName(opts), fallback = _getFallback(opts), fallbackDeclaration = _getFallbackDeclaration(opts) {
    _validateOptions();
    _initTables();
  }

  static String _getFontName(ConversionArgs opts) {
    if (opts.lvFontName != null) {
      return opts.lvFontName!;
    }
    return path.basenameWithoutExtension(opts.output ?? 'font');
  }

  static String _getFallback(ConversionArgs opts) {
    if (opts.lvFallback != null) {
      return '&${opts.lvFallback}';
    }
    return 'NULL';
  }

  static String _getFallbackDeclaration(ConversionArgs opts) {
    if (opts.lvFallback != null) {
      return 'extern const lv_font_t ${opts.lvFallback};\n';
    }
    return '';
  }

  void _validateOptions() {
    if (opts.bpp == 3 && !opts.noCompress) {
      throw AppError('LVGL supports "--bpp 3" with compression only');
    }
  }

  void _initTables() {
    head = LvHead(this);
    glyf = LvGlyf(this);
    cmap = LvCmap(this);
    kern = LvKern(this);
    
    // Calculate font properties
    subpixelsMode = opts.lcd ? 1 : (opts.lcdV ? 2 : 0);
    kerningScale = _calculateKerningScale();
    advanceWidthFormat = _calculateAdvanceWidthFormat();
  }

  double _calculateKerningScale() {
    // TODO: Implement actual kerning scale calculation
    return 1.0;
  }

  int _calculateAdvanceWidthFormat() {
    // Determine if we need FP4.4 format based on kerning
    return kern.hasKerning() ? 1 : 0;
  }

  String strideGuard() {
    if (opts.stride > 0) {
      return '''#if !LV_VERSION_CHECK(9, 3, 0)
#error "At least LVGL v9.3 is required to use stride attribute of fonts"
#endif''';
    }
    return '';
  }

  String largeFormatGuard() {
    bool guardRequired = false;
    int glyphsBinSize = 0;

    for (final d in glyf.lvData) {
      glyphsBinSize += d.bin.length;

      if (d.glyph.bbox.width > 255 ||
          d.glyph.bbox.height > 255 ||
          d.glyph.bbox.x.abs() > 127 ||
          d.glyph.bbox.y.abs() > 127 ||
          (d.glyph.advanceWidth * 16).round() > 4096) {
        guardRequired = true;
      }
    }

    if (glyphsBinSize > 1024 * 1024) guardRequired = true;

    if (!guardRequired) return '';

    return '''
#if (LV_FONT_FMT_TXT_LARGE == 0)
#  error "Too large font or glyphs in $fontName.toUpperCase(). Enable LV_FONT_FMT_TXT_LARGE in lv_conf.h")
#endif'''.trimLeft();
  }

  String toLVGL() {
    final guardName = fontName.toUpperCase();

    return '''/*******************************************************************************
 * Size: ${src.size} px
 * Bpp: ${opts.bpp}
 * Opts: ${opts.optsString}
 ******************************************************************************/

#ifdef __has_include
    #if __has_include("lvgl.h")
        #ifndef LV_LVGL_H_INCLUDE_SIMPLE
            #define LV_LVGL_H_INCLUDE_SIMPLE
        #endif
    #endif
#endif

#ifdef LV_LVGL_H_INCLUDE_SIMPLE
    #include "lvgl.h"
#else
    #include "${opts.lvInclude ?? 'lvgl/lvgl.h'}"
#endif

${strideGuard()}

#ifndef $guardName
#define $guardName 1
#endif

#if $guardName

${glyf.toLVGL()}

${cmap.toLVGL()}

${kern.toLVGL()}

${head.toLVGL()}

${largeFormatGuard()}

#endif /*#if $guardName*/
''';
  }
}