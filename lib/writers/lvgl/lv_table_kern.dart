/// LVGL kerning table writer
library;

import '../../font/table_kern.dart';
import '../../utils.dart';

/// LVGL kerning table class
class LvTableKern extends Kern {
  LvTableKern(Kern font) : super(font.font);

  /// Generate C code for kerning pairs (format 0)
  String _toLvFormat0() {
    final f = font;
    final kernPairs = collectFormat0Data();

    final buffer = StringBuffer();
    buffer.writeln('/*-----------------');
    buffer.writeln(' *    KERNING');
    buffer.writeln(' *----------------*/');
    buffer.writeln();
    buffer.writeln();
    buffer.writeln('/*Pair left and right glyphs for kerning*/');
    buffer.writeln('static const ${f.glyphIdFormat == 1 ? 'uint16_t' : 'uint8_t'} kern_pair_glyph_ids[] =');
    buffer.writeln('{');

    for (int i = 0; i < kernPairs.length; i++) {
      final pair = kernPairs[i];
      buffer.writeln('    ${pair[0]}, ${pair[1]}${i < kernPairs.length - 1 ? ',' : ''}');
    }

    buffer.writeln('};');
    buffer.writeln();
    buffer.writeln('/* Kerning between the respective left and right glyphs');
    buffer.writeln(' * 4.4 format which needs to scaled with \`kern_scale\`*/');
    buffer.writeln('static const int8_t kern_pair_values[] =');
    buffer.writeln('{');
    buffer.write(longDump(kernPairs.map((pair) => f.kernToFp(pair[2])).toList()));
    buffer.writeln();
    buffer.writeln('};');
    buffer.writeln();
    buffer.writeln('/*Collect the kern pair\'s data in one place*/');
    buffer.writeln('static const lv_font_fmt_txt_kern_pair_t kern_pairs =');
    buffer.writeln('{');
    buffer.writeln('    .glyph_ids = kern_pair_glyph_ids,');
    buffer.writeln('    .values = kern_pair_values,');
    buffer.writeln('    .pair_cnt = ${kernPairs.length},');
    buffer.writeln('    .glyph_ids_size = ${f.glyphIdFormat}');
    buffer.writeln('};');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate C code for kerning classes (format 3)
  String _toLvFormat3() {
    final f = font;
    final format3Data = collectFormat3Data();

    final buffer = StringBuffer();
    buffer.writeln('/*-----------------');
    buffer.writeln(' *    KERNING');
    buffer.writeln(' *----------------*/');
    buffer.writeln();
    buffer.writeln();
    buffer.writeln('/*Map glyph_ids to kern left classes*/');
    buffer.writeln('static const uint8_t kern_left_class_mapping[] =');
    buffer.writeln('{');
    buffer.write(longDump(format3Data!['leftMapping'] as List<int>));
    buffer.writeln();
    buffer.writeln('};');
    buffer.writeln();
    buffer.writeln('/*Map glyph_ids to kern right classes*/');
    buffer.writeln('static const uint8_t kern_right_class_mapping[] =');
    buffer.writeln('{');
    buffer.write(longDump(format3Data['rightMapping'] as List<int>));
    buffer.writeln();
    buffer.writeln('};');
    buffer.writeln();
    buffer.writeln('/*Kern values between classes*/');
    buffer.writeln('static const int8_t kern_class_values[] =');
    buffer.writeln('{');
    buffer.write(longDump((format3Data['values'] as List<double>).map((v) => f.kernToFp(v)).toList()));
    buffer.writeln();
    buffer.writeln('};');
    buffer.writeln();
    buffer.writeln('/*Collect the kern class\' data in one place*/');
    buffer.writeln('static const lv_font_fmt_txt_kern_classes_t kern_classes =');
    buffer.writeln('{');
    buffer.writeln('    .class_pair_values   = kern_class_values,');
    buffer.writeln('    .left_class_mapping  = kern_left_class_mapping,');
    buffer.writeln('    .right_class_mapping = kern_right_class_mapping,');
    buffer.writeln('    .left_class_cnt      = ${format3Data['leftClasses']},');
    buffer.writeln('    .right_class_cnt     = ${format3Data['rightClasses']},');
    buffer.writeln('};');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate C array for LVGL kerning data
  String toCArray() {
    final f = font;

    if (!f.hasKerning()) {
      return '';
    }

    // Determine which format to use
    if (shouldUseFormat3()) {
      if (f.opts['format3_forced'] == true) {
        // In a real implementation, you might want to log size differences
        print('Forced faster kerning format (via classes).');
      }
      return _toLvFormat3();
    }

    if (f.opts['fast_kerning'] == true) {
      print('Forced faster kerning format (via classes), but data exceeds its limits. Continue use pairs.');
    }

    return _toLvFormat0();
  }
}