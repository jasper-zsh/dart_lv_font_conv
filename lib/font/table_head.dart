/// Head table for font
library;

import 'font.dart';

// Offset constants
const int O_SIZE = 0;
const int O_LABEL = O_SIZE + 4;
const int O_VERSION = O_LABEL + 4;
const int O_TABLES = O_VERSION + 4;
const int O_FONT_SIZE = O_TABLES + 2;
const int O_ASCENT = O_FONT_SIZE + 2;
const int O_DESCENT = O_ASCENT + 2;
const int O_TYPO_ASCENT = O_DESCENT + 2;
const int O_TYPO_DESCENT = O_TYPO_ASCENT + 2;
const int O_TYPO_LINE_GAP = O_TYPO_DESCENT + 2;
const int O_MIN_Y = O_TYPO_LINE_GAP + 2;
const int O_MAX_Y = O_MIN_Y + 2;
const int O_DEF_ADVANCE_WIDTH = O_MAX_Y + 2;
const int O_KERNING_SCALE = O_DEF_ADVANCE_WIDTH + 2;
const int O_INDEX_TO_LOC_FORMAT = O_KERNING_SCALE + 2;
const int O_GLYPH_ID_FORMAT = O_INDEX_TO_LOC_FORMAT + 1;
const int O_ADVANCE_WIDTH_FORMAT = O_GLYPH_ID_FORMAT + 1;
const int O_BITS_PER_PIXEL = O_ADVANCE_WIDTH_FORMAT + 1;
const int O_XY_BITS = O_BITS_PER_PIXEL + 1;
const int O_WH_BITS = O_XY_BITS + 1;
const int O_ADVANCE_WIDTH_BITS = O_WH_BITS + 1;
const int O_COMPRESSION_ID = O_ADVANCE_WIDTH_BITS + 1;
const int O_SUBPIXELS_MODE = O_COMPRESSION_ID + 1;
const int O_TMP_RESERVED1 = O_SUBPIXELS_MODE + 1;
const int O_UNDERLINE_POSITION = O_TMP_RESERVED1 + 1;
const int O_UNDERLINE_THICKNESS = O_UNDERLINE_POSITION + 2;
const int HEAD_LENGTH = 88; // align4(O_UNDERLINE_THICKNESS + 2);

/// Head table containing font metadata
class Head {
  final Font font;
  final String label = 'head';
  final int version = 1;

  Head(this.font);

  List<int> toBin() {
    final buf = List<int>.filled(HEAD_LENGTH, 0);
    debugPrint('table size = ${buf.length}');

    // Write size
    _writeUint32(buf, HEAD_LENGTH, O_SIZE);

    // Write label
    _writeString(buf, label, O_LABEL);

    // Write version
    _writeUint32(buf, version, O_VERSION);

    final f = font;

    final tablesCount = f.hasKerning() ? 4 : 3;
    _writeUint16(buf, tablesCount, O_TABLES);

    _writeUint16(buf, f.src['size'], O_FONT_SIZE);
    _writeUint16(buf, f.src['ascent'], O_ASCENT);
    _writeInt16(buf, f.src['descent'], O_DESCENT);

    _writeUint16(buf, f.src['typoAscent'], O_TYPO_ASCENT);
    _writeInt16(buf, f.src['typoDescent'], O_TYPO_DESCENT);
    _writeUint16(buf, f.src['typoLineGap'], O_TYPO_LINE_GAP);

    _writeInt16(buf, f.minY, O_MIN_Y);
    _writeInt16(buf, f.maxY, O_MAX_Y);

    if (f.monospaced) {
      _writeUint16(buf, f.widthToInt(f.src['glyphs'][0]['advanceWidth']), O_DEF_ADVANCE_WIDTH);
    } else {
      _writeUint16(buf, 0, O_DEF_ADVANCE_WIDTH);
    }

    _writeUint16(buf, (f.kerningScale * 16).round(), O_KERNING_SCALE); // FP12.4

    buf[O_INDEX_TO_LOC_FORMAT] = f.indexToLocFormat;
    buf[O_GLYPH_ID_FORMAT] = f.glyphIdFormat;
    buf[O_ADVANCE_WIDTH_FORMAT] = f.advanceWidthFormat;

    buf[O_BITS_PER_PIXEL] = f.opts['bpp'] ?? 1;
    buf[O_XY_BITS] = f.xyBits;
    buf[O_WH_BITS] = f.whBits;

    if (f.monospaced) {
      buf[O_ADVANCE_WIDTH_BITS] = 0;
    } else {
      buf[O_ADVANCE_WIDTH_BITS] = f.advanceWidthBits;
    }

    buf[O_COMPRESSION_ID] = f.glyf.getCompressionCode();

    buf[O_SUBPIXELS_MODE] = f.subpixelsMode;

    _writeInt16(buf, f.src['underlinePosition'], O_UNDERLINE_POSITION);
    _writeUint16(buf, f.src['underlineThickness'], O_UNDERLINE_THICKNESS);

    return buf;
  }

  void _writeUint32(List<int> buf, int value, int offset) {
    buf[offset] = value & 0xFF;
    buf[offset + 1] = (value >> 8) & 0xFF;
    buf[offset + 2] = (value >> 16) & 0xFF;
    buf[offset + 3] = (value >> 24) & 0xFF;
  }

  void _writeUint16(List<int> buf, int value, int offset) {
    buf[offset] = value & 0xFF;
    buf[offset + 1] = (value >> 8) & 0xFF;
  }

  void _writeInt16(List<int> buf, int value, int offset) {
    final signedValue = value.toSigned(16);
    buf[offset] = signedValue & 0xFF;
    buf[offset + 1] = (signedValue >> 8) & 0xFF;
  }

  void _writeString(List<int> buf, String str, int offset) {
    for (int i = 0; i < str.length && i < 4; i++) {
      buf[offset + i] = str.codeUnitAt(i);
    }
  }
}

void debugPrint(String message) {
  // print('DEBUG: $message');
}