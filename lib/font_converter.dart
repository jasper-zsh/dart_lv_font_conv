import 'dart:typed_data';
import 'dart:convert';
import 'dart_lv_font_conv_base.dart';
import 'font/collect_font_data.dart';
import 'writers/lvgl_writer.dart';
import 'writers/bin_writer.dart';
import 'writers/dump_writer.dart';

/// Main font converter class
class FontConverter {
  /// Convert fonts based on the provided arguments
  /// Returns a map of filename to binary data
  Future<Map<String, Uint8List>> convert(ConversionArgs args) async {
    final fontData = await collectFontData(args);
    return _writeOutput(args, fontData);
  }

  /// Write output in the specified format
  Map<String, Uint8List> _writeOutput(ConversionArgs args, FontData fontData) {
    switch (args.format.toLowerCase()) {
      case 'lvgl':
        return _writeLvglFormat(args, fontData);
      case 'bin':
        return _writeBinFormat(args, fontData);
      case 'dump':
        return _writeDumpFormat(args, fontData);
      default:
        throw AppError('Unsupported output format: ${args.format}');
    }
  }

  /// Write LVGL format output
  Map<String, Uint8List> _writeLvglFormat(ConversionArgs args, FontData fontData) {
    final stringData = writeLvglFormat(args, fontData);
    return stringData.map((key, value) => MapEntry(key, utf8.encode(value)));
  }

  /// Write binary format output
  Map<String, Uint8List> _writeBinFormat(ConversionArgs args, FontData fontData) {
    final stringData = writeBinFormat(args, fontData);
    return stringData.map((key, value) => MapEntry(key, utf8.encode(value)));
  }

  /// Write dump format output
  Map<String, Uint8List> _writeDumpFormat(ConversionArgs args, FontData fontData) {
    final stringData = writeDumpFormat(args, fontData);
    return stringData.map((key, value) => MapEntry(key, utf8.encode(value)));
  }

  /// Get list of supported output formats
  static List<String> get supportedFormats => ['lvgl', 'bin', 'dump'];
}