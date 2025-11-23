/// LVGL format writer
library;

import 'lvgl/lv_font.dart';

/// LVGL writer that outputs C code compatible with LVGL
Map<String, List<int>> lvglWriter(Map<String, dynamic> args, Map<String, dynamic> fontData) {
  final lvFont = LvFont(fontData, args);
  final cCode = lvFont.toCCode();

  // Generate output filename based on input
  String outputName = 'font.c';
  if (args['output'] != null) {
    outputName = args['output'] as String;
    if (!outputName.endsWith('.c')) {
      outputName += '.c';
    }
  }

  return {
    outputName: cCode.codeUnits,
  };
}