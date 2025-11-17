import '../../dart_lv_font_conv_base.dart';
import 'lv_font.dart';
import '../../font/rle_compressor.dart';

/// LVGL Glyph table
class LvGlyf {
  final LvFont font;

  LvGlyf(this.font);

  List<LvGlyphData> get lvData {
    final glyphData = <LvGlyphData>[];
    
    for (final glyph in font.src.glyphs) {
      // Convert 1D pixel array back to 2D for processing
      final pixels2D = <List<int>>[];
      final stride = _calculateStride(glyph.bbox.width);
      
      for (int y = 0; y < glyph.bbox.height; y++) {
        final row = <int>[];
        for (int x = 0; x < glyph.bbox.width; x++) {
          final pixelIndex = y * glyph.bbox.width + x;
          row.add(pixelIndex < glyph.pixels.length ? glyph.pixels[pixelIndex] : 0);
        }
        
        // Apply stride padding if needed
        while (row.length < stride) {
          row.add(0);
        }
        
        pixels2D.add(row);
      }
      
      // Apply compression if enabled
      List<int> compressedData;
      
      if (font.opts.noCompress) {
        // No compression - just flatten the 2D array
        compressedData = pixels2D.expand((row) => row).toList();
      } else {
        // Apply RLE compression
        compressedData = RleCompressor.compress(pixels2D, font.opts.bpp);
      }
      
      glyphData.add(LvGlyphData(
        glyph: glyph,
        bin: compressedData,
      ));
    }
    
    return glyphData;
  }

  int _calculateStride(int width) {
    if (font.opts.stride > 0) {
      return font.opts.stride;
    }
    
    // Calculate natural stride based on BPP
    switch (font.opts.bpp) {
      case 1:
        return (width + 7) ~/ 8;
      case 2:
        return (width + 3) ~/ 4;
      case 4:
        return (width + 1) ~/ 2;
      case 8:
        return width;
      default:
        return width;
    }
  }

  int getCompressionCode() {
    return _getCompressionCode(font.opts.bpp);
  }

  int _getCompressionCode(int bpp) {
    switch (bpp) {
      case 1:
        return 1; // LV_FONT_FMT_TXT_COMPRESS_ZLIB
      case 2:
        return 2; // LV_FONT_FMT_TXT_COMPRESS_LZ4
      case 4:
        return 3; // LV_FONT_FMT_TXT_COMPRESS_RLE
      case 8:
        return 3; // LV_FONT_FMT_TXT_COMPRESS_RLE
      default:
        return 0; // No compression
    }
  }

  String toLVGL() {
    final glyphData = lvData;
    final bitmapData = glyphData.expand((data) => data.bin).toList();
    
    // Generate glyph bitmap array
    final bitmapArray = _generateBitmapArray(bitmapData);
    
    // Generate glyph descriptions
    final glyphDescriptions = _generateGlyphDescriptions(glyphData);

    return '''
/*--------------------
 *  GLYPH BITMAP
 *--------------------*/

static const uint8_t glyph_bitmap[] = {
$bitmapArray
};

/*--------------------
 *  GLYPH DESCRIPTION
 *--------------------*/

static const lv_font_fmt_txt_glyph_dsc_t glyph_dsc[] = {
$glyphDescriptions
};
''';
  }

  String _generateBitmapArray(List<int> bitmapData) {
    final buffer = StringBuffer();
    final bytesPerLine = 16;
    
    for (int i = 0; i < bitmapData.length; i += bytesPerLine) {
      buffer.write('    ');
      for (int j = 0; j < bytesPerLine && i + j < bitmapData.length; j++) {
        buffer.write('0x${bitmapData[i + j].toRadixString(16).padLeft(2, '0')}');
        if (i + j + 1 < bitmapData.length) {
          buffer.write(', ');
        }
      }
      if (i + bytesPerLine < bitmapData.length) {
        buffer.write(',\n');
      }
    }
    
    return buffer.toString();
  }

  String _generateGlyphDescriptions(List<LvGlyphData> glyphData) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < glyphData.length; i++) {
      final data = glyphData[i];
      final glyph = data.glyph;
      
      buffer.write('    {\n');
      buffer.write('        .bitmap_index = ${_calculateBitmapIndex(glyphData, i)},\n');
      buffer.write('        .adv_w = ${_formatAdvanceWidth(glyph.advanceWidth)},\n');
      buffer.write('        .box_w = ${glyph.bbox.width},\n');
      buffer.write('        .box_h = ${glyph.bbox.height},\n');
      buffer.write('        .ofs_x = ${glyph.bbox.x},\n');
      buffer.write('        .ofs_y = ${glyph.bbox.y}\n');
      buffer.write('    }');
      
      if (i < glyphData.length - 1) {
        buffer.write(',');
      }
      buffer.write('\n');
    }
    
    return buffer.toString();
  }

  int _calculateBitmapIndex(List<LvGlyphData> glyphData, int currentIndex) {
    int index = 0;
    for (int i = 0; i < currentIndex; i++) {
      index += glyphData[i].bin.length;
    }
    return index;
  }

  String _formatAdvanceWidth(double advanceWidth) {
    // Format based on whether we need FP4.4 format
    if (font.advanceWidthFormat == 1) {
      return '${(advanceWidth * 16).round()}';
    } else {
      return '${advanceWidth.round()}';
    }
  }
}

/// LV glyph data
class LvGlyphData {
  final Glyph glyph;
  final List<int> bin;

  LvGlyphData({
    required this.glyph,
    required this.bin,
  });
}