/// Binary format writer
library;

import '../font/font.dart';
import '../collect_font_data.dart';

/// Binary writer that outputs font data in binary format
Map<String, List<int>> binWriter(Map<String, dynamic> args, Map<String, dynamic> fontData) {
  final font = Font(fontData, args);
  final binData = font.toBin();

  // Generate output filename based on input
  String outputName = 'font.bin';
  if (args['output'] != null) {
    outputName = args['output'] as String;
    if (!outputName.endsWith('.bin')) {
      outputName += '.bin';
    }
  }

  return {
    outputName: binData,
  };
}