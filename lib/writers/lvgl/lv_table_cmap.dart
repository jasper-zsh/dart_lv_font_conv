/// LVGL character map table writer
library;

import '../../font/table_cmap.dart';
import '../../font/cmap_build_subtables.dart';
import '../../utils.dart';

/// LVGL character map table class
class LvTableCmap extends Cmap {
  bool _lvCompiled = false;
  final List<LvSubtable> _lvSubtables = [];

  LvTableCmap(Cmap font) : super(font.font);

  /// Convert LVGL format name to enum
  String _lvFormat2Enum(String name) {
    switch (name) {
      case 'format0_tiny':
        return 'LV_FONT_FMT_TXT_CMAP_FORMAT0_TINY';
      case 'format0':
        return 'LV_FONT_FMT_TXT_CMAP_FORMAT0_FULL';
      case 'sparse_tiny':
        return 'LV_FONT_FMT_TXT_CMAP_SPARSE_TINY';
      case 'sparse':
        return 'LV_FONT_FMT_TXT_CMAP_SPARSE_FULL';
      default:
        throw Exception('Unknown subtable format: $name');
    }
  }

  /// Compile LVGL character map
  void _lvCompile() {
    if (_lvCompiled) return;
    _lvCompiled = true;

    final f = font;
    final glyphCodes = (f.src['glyphs'] as List).map((g) => g['code'] as int).toList();
    final subtablesPlan = cmapSplit(glyphCodes);
    int idx = 0;

    for (final entry in subtablesPlan) {
      final format = entry[0] as String;
      final codepoints = entry[1] as List<int>;

      final g = glyphByCode(codepoints.first);
      if (g == null) continue;
      final startGlyphId = f.glyphId[g['code']]!;
      final minCode = codepoints.first;
      final maxCode = codepoints.last;

      bool hasCharcodes = false;
      bool hasIds = false;
      String defs = '';
      int entriesCount = 0;

      if (format == 'format0_tiny') {
        // use default empty values
      } else if (format == 'format0') {
        hasIds = true;
        final d = collectFormat0Data(minCode, maxCode, startGlyphId);
        entriesCount = d.length;

        defs = '''
static const uint8_t glyph_id_ofs_list_${idx}[] = {
${longDump(d)}
};
''';
      } else if (format == 'sparse_tiny') {
        hasCharcodes = true;
        final d = collectSparseData(codepoints, startGlyphId);
        entriesCount = d.codes.length;

        defs = '''
static const uint16_t unicode_list_${idx}[] = {
${longDump(d.codes, hex: true)}
};
''';
      } else {
        // assume format === 'sparse'
        hasCharcodes = true;
        hasIds = true;
        final d = collectSparseData(codepoints, startGlyphId);
        entriesCount = d.codes.length;

        defs = '''
static const uint16_t unicode_list_${idx}[] = {
${longDump(d.codes, hex: true)}
};
static const uint16_t glyph_id_ofs_list_${idx}[] = {
${longDump(d.ids)}
};
''';
      }

      final uList = hasCharcodes ? 'unicode_list_$idx' : 'NULL';
      final idList = hasIds ? 'glyph_id_ofs_list_$idx' : 'NULL';

      final head = '''    {
        .range_start = $minCode, .range_length = ${maxCode - minCode + 1}, .glyph_id_start = $startGlyphId,
        .unicode_list = $uList, .glyph_id_ofs_list = $idList, .list_length = $entriesCount, .type = ${_lvFormat2Enum(format)}
    }''';

      _lvSubtables.add(LvSubtable(defs, head));
      idx++;
    }
  }

  /// Generate C array for LVGL
  String toCArray() {
    _lvCompile();

    final buffer = StringBuffer();
    buffer.writeln('/*---------------------');
    buffer.writeln(' *  CHARACTER MAPPING');
    buffer.writeln(' *--------------------*/');
    buffer.writeln();

    // Write definitions
    for (final subtable in _lvSubtables) {
      if (subtable.defs.isNotEmpty) {
        buffer.writeln(subtable.defs);
        buffer.writeln();
      }
    }

    buffer.writeln('/*Collect the unicode lists and glyph_id offsets*/');
    buffer.writeln('static const lv_font_fmt_txt_cmap_t cmaps[] =');
    buffer.writeln('{');

    // Write subtable headers
    for (int i = 0; i < _lvSubtables.length; i++) {
      buffer.write(_lvSubtables[i].head);
      if (i < _lvSubtables.length - 1) {
        buffer.writeln(',');
      } else {
        buffer.writeln();
      }
    }

    buffer.writeln('};');

    return buffer.toString();
  }
}

/// LVGL subtable data structure
class LvSubtable {
  final String defs;
  final String head;

  LvSubtable(this.defs, this.head);
}