import 'lv_font.dart';

/// LVGL Character Map table
class LvCmap {
  final LvFont font;

  LvCmap(this.font);

  int get cmapNum {
    // TODO: Implement actual cmap number calculation
    return 1;
  }

  String toLVGL() {
    // TODO: Implement actual LVGL cmap table output
    return '''
/*---------------------
 *  CHARACTER MAPPING
 *--------------------*/

/*Collect the unicode lists and glyph_id offsets*/
static const lv_font_fmt_txt_cmap_t cmaps[] =
{
    {
        .range_start = 0x20, .range_length = 0x5F, .glyph_id_start = 1,
        .unicode_list = NULL, .glyph_id_ofs_list = NULL, .list_length = 0, .type = LV_FONT_FMT_TXT_CMAP_FORMAT0_TINY
    }
};
''';
  }
}