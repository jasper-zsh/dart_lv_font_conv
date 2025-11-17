import 'dart:convert';
import '../dart_lv_font_conv_base.dart';

/// Write font in dump format (JSON)
Map<String, String> writeDumpFormat(ConversionArgs args, FontData fontData) {
  final output = args.output ?? 'font_info.json';
  
  final fontInfo = {
    'ascent': fontData.ascent,
    'descent': fontData.descent,
    'typoAscent': fontData.typoAscent,
    'typoDescent': fontData.typoDescent,
    'typoLineGap': fontData.typoLineGap,
    'size': fontData.size,
    'underlinePosition': fontData.underlinePosition,
    'underlineThickness': fontData.underlineThickness,
    'glyphs': fontData.glyphs.map((glyph) => {
      'code': glyph.code,
      'advanceWidth': glyph.advanceWidth,
      'bbox': {
        'x': glyph.bbox.x,
        'y': glyph.bbox.y,
        'width': glyph.bbox.width,
        'height': glyph.bbox.height,
      },
      'kerning': glyph.kerning,
      if (!args.fullInfo) 'pixels': '<pixels data omitted>',
      if (args.fullInfo) 'pixels': glyph.pixels,
    }).toList(),
  };

  return {
    output: const JsonEncoder.withIndent('  ').convert(fontInfo),
  };
}