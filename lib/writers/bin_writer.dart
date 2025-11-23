/// Binary format writer
library;

import '../app_error.dart';
import '../font/font.dart';
import '../collect_font_data.dart';

/// Binary writer that outputs font data in binary format
Map<String, List<int>> binWriter(Map<String, dynamic> args, Map<String, dynamic> fontData) {
  if (args['output'] == null) {
    throw AppError('Output is required for "bin" writer');
  }

  final font = Font(fontData, args);
  final binData = font.toBin();

  final headBytes = 'head'.codeUnits;
  if (binData.length >= 8) {
    for (int i = 0; i < 4; i++) {
      binData[4 + i] = headBytes[i];
    }
  }

  // Generate output filename based on input
  String outputName = args['output'] as String? ?? 'font.bin';

  return {
    outputName: binData,
  };
}
