import '../dart_lv_font_conv_base.dart';
import 'lvgl/lv_font.dart';

/// Write font in LVGL format
Map<String, String> writeLvglFormat(ConversionArgs args, FontData fontData) {
  if (args.output == null) {
    throw AppError('Output is required for "lvgl" writer');
  }

  final font = LvFont(fontData, args);

  return {
    args.output!: font.toLVGL(),
  };
}