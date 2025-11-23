/// Internal API to convert input data into output font data
/// Used by both CLI and Web wrappers.
library;

import 'collect_font_data.dart';
import 'writers/dump_writer.dart';
import 'writers/bin_writer.dart';
import 'writers/lvgl_writer.dart';

/// Main convert function that orchestrates the font conversion process
///
/// Input:
/// - args like from CLI (optionally extended with binary content of files)
///
/// Output:
/// - { name1: bin_data1, name2: bin_data2, ... }
///
/// Returns hash with files to write
Future<Map<String, List<int>>> convert(Map<String, dynamic> args) async {
  final fontData = await collectFontData(args);

  late final Map<String, List<int>> files;
  switch (args['format'] as String) {
    case 'dump':
      files = dumpWriter(args, fontData);
      break;
    case 'bin':
      files = binWriter(args, fontData);
      break;
    case 'lvgl':
      files = lvglWriter(args, fontData);
      break;
    default:
      throw Exception('Unsupported format: ${args['format']}');
  }

  return files;
}

/// List of supported output formats
List<String> get supportedFormats => ['dump', 'bin', 'lvgl'];