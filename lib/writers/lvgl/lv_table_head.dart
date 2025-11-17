import 'lv_font.dart';

/// LVGL Head table
class LvHead {
  final LvFont font;

  LvHead(this.font);

  KernRef kernRef() {
    if (!font.kern.hasKerning()) {
      return KernRef(
        scale: '0',
        dsc: 'NULL',
        classes: '0',
      );
    }

    if (!font.kern.shouldUseFormat3()) {
      return KernRef(
        scale: '${(font.kerningScale * 16).round()}',
        dsc: '&kern_pairs',
        classes: '0',
      );
    }

    return KernRef(
      scale: '${(font.kerningScale * 16).round()}',
      dsc: '&kern_classes',
      classes: '1',
    );
  }

  String getStrideAlign() {
    if (font.opts.stride > 0) {
      return '    .stride = ${font.opts.stride}';
    }
    return '';
  }

  String toLVGL() {
    final f = font;
    final kern = kernRef();
    final subpixels = f.subpixelsMode == 0 ? 'LV_FONT_SUBPX_NONE' :
                      f.subpixelsMode == 1 ? 'LV_FONT_SUBPX_HOR' : 'LV_FONT_SUBPX_VER';

    final staticBitmap = f.glyf.getCompressionCode() == 0 ? '1' : '0';

    return '''
/*--------------------
 *  ALL CUSTOM DATA
 *--------------------*/

#if LVGL_VERSION_MAJOR == 8
/*Store all the custom data of the font*/
static  lv_font_fmt_txt_glyph_cache_t cache;
#endif

#if LVGL_VERSION_MAJOR >= 8
static const lv_font_fmt_txt_dsc_t font_dsc = {
#else
static lv_font_fmt_txt_dsc_t font_dsc = {
#endif
    .glyph_bitmap = glyph_bitmap,
    .glyph_dsc = glyph_dsc,
    .cmaps = cmaps,
    .kern_dsc = ${kern.dsc},
    .kern_scale = ${kern.scale},
    .cmap_num = ${f.cmap.cmapNum},
    .bpp = ${f.opts.bpp},
    .kern_classes = ${kern.classes},
    .bitmap_format = ${f.glyf.getCompressionCode()},
#if LVGL_VERSION_MAJOR == 8
    .cache = &cache
#endif
${getStrideAlign()}
};

${f.fallbackDeclaration}

/*-----------------
 *  PUBLIC FONT
 *----------------*/

/*Initialize a public general font descriptor*/
#if LVGL_VERSION_MAJOR >= 8
const lv_font_t ${f.fontName} = {
#else
lv_font_t ${f.fontName} = {
#endif
    .get_glyph_dsc = lv_font_get_glyph_dsc_fmt_txt,    /*Function pointer to get glyph's data*/
    .get_glyph_bitmap = lv_font_get_bitmap_fmt_txt,    /*Function pointer to get glyph's bitmap*/
    .line_height = ${f.src.ascent - f.src.descent},          /*The maximum line height required by font*/
    .base_line = ${-f.src.descent},             /*Baseline measured from the bottom of line*/
#if !(LVGL_VERSION_MAJOR == 6 && LVGL_VERSION_MINOR == 0)
    .subpx = $subpixels,
#endif
#if LV_VERSION_CHECK(7, 4, 0) || LVGL_VERSION_MAJOR >= 8
    .underline_position = ${f.src.underlinePosition},
    .underline_thickness = ${f.src.underlineThickness},
#endif

#if LV_VERSION_CHECK(9, 3, 0)
    .static_bitmap = $staticBitmap,    /*Bitmaps are stored as const so they are always static if not compressed */
#endif

    .dsc = &font_dsc,          /*The custom font data. Will be accessed by `get_glyph_bitmap/dsc` */
#if LV_VERSION_CHECK(8, 2, 0) || LVGL_VERSION_MAJOR >= 9
    .fallback = ${f.fallback},
#endif
    .user_data = NULL,
};
''';
  }
}

/// Kerning reference data
class KernRef {
  final String scale;
  final String dsc;
  final String classes;

  KernRef({
    required this.scale,
    required this.dsc,
    required this.classes,
  });
}