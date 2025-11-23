/// GLYF table for glyph data
library;

import 'dart:typed_data';
import 'font.dart';
import 'bit_stream.dart';
import 'compress.dart' as compress;
import '../utils.dart';

// Offset constants
const int oSize = 0;
const int oLabel = oSize + 4;
const int headLength = oLabel + 4;

class Glyf {
  final Font font;
  final String label = 'glyf';

  bool compiled = false;
  final List<Uint8List> binData = [];

  Glyf(this.font);

  List<int> toBin() {
    if (!compiled) compile();

    final buffer = <int>[];
    buffer.addAll(List<int>.filled(headLength, 0));

    for (final data in binData) {
      buffer.addAll(data);
    }

    final aligned = balign4(Uint8List.fromList(buffer));

    // Write header
    _writeUint32(aligned, aligned.length, oSize);
    _writeString(aligned, label, oLabel);

    debugPrint('table size = ${aligned.length}');

    return aligned;
  }

  int getSize() {
    if (!compiled) compile();

    final totalSize = headLength + sum(binData.map<int>((b) => b.length).toList());
    return align4(totalSize);
  }

  int getOffset(int id) {
    if (!compiled) compile();

    int offset = headLength;

    for (int i = 0; i < id; i++) {
      offset += binData[i].length;
    }

    return offset;
  }

  int getCompressionCode() {
    if (font.opts['no_compress'] == true) return 0;
    if (font.opts['bpp'] == 1) return 0;
    if (font.opts['no_prefilter'] == true) return 2;
    return 1;
  }

  /// Convert 8-bit opacity to bpp-bit
  List<List<int>> pixelsToBpp(List<List<int>> pixels) {
    final bpp = (font.opts['bpp'] ?? 1) as int;
    return pixels.map((line) => line.map((p) => p >> (8 - bpp)).toList()).toList();
  }

  int widthToStride(int width) {
    final stride = (font.opts['stride'] ?? 0) as int;
    if (stride > 0) {
      final byteCount = ((width * (font.opts['bpp'] ?? 1) as int) / 8).ceil();
      final finalLength = (byteCount / stride).ceil() * stride;
      return finalLength.toInt();
    }
    return ((width * (font.opts['bpp'] ?? 1) as int) / 8).ceil();
  }

  /// Returns "binary stream" of compiled glyph data
  Uint8List compileGlyph(Map<String, dynamic> glyph) {
    // Allocate memory, enough for every storage formats
    final bboxWidth = glyph['bbox']['width'] as int;
    final bboxHeight = glyph['bbox']['height'] as int;
    final bppValue = (font.opts['bpp'] ?? 1) as int;
    final alignValue = (font.opts['align'] ?? 0) as int;
    int bufSize = 100 + (widthToStride(bboxWidth) * bboxHeight) * bppValue + alignValue;

    if (bufSize.isNaN || bufSize <= 0) {
      bufSize = 128 * 1024; // Fallback for empty glyphs
    }

    final buf = Uint8List(bufSize);
    final bs = BitStream(buf);

    final f = font;

    // Store Width
    if (!f.monospaced) {
      final w = f.widthToInt(glyph['advanceWidth']);
      bs.writeBits(w, f.advanceWidthBits);
    }

    // Store X, Y
    bs.writeBits(glyph['bbox']['x'], f.xyBits);
    bs.writeBits(glyph['bbox']['y'], f.xyBits);
    bs.writeBits(glyph['bbox']['width'], f.whBits);
    bs.writeBits(glyph['bbox']['height'], f.whBits);

    final pixels = pixelsToBpp(
      (glyph['pixels'] as List).map((line) => (line as List).cast<int>()).toList(),
    );

    storePixels(bs, pixels);

    // Shrink size
    final resultLength = font.opts['align'] != null && font.opts['align'] != 1
        ? (bs.byteIndex / (font.opts['align'] as int)).ceil() * (font.opts['align'] as int)
        : bs.byteIndex;

    return Uint8List.fromList(buf.sublist(0, resultLength));
  }

  void storePixels(BitStream bs, List<List<int>> pixels) {
    if (getCompressionCode() == 0 || getCompressionCode() == 3) {
      storePixelsRaw(bs, pixels);
    } else {
      storePixelsCompressed(bs, pixels);
    }
  }

  void addPadding(BitStream bitStream, int pad) {
    final bpp = font.opts['bpp'] ?? 1;
    for (int x = 0; x < pad; x++) {
      bitStream.writeBits(0, bpp);
    }
  }

  void storePixelsRaw(BitStream bitStream, List<List<int>> pixels) {
    if (pixels.isEmpty) return;

    final bpp = font.opts['bpp'] ?? 1;
    int bitPadLine = 0;
    if ((font.opts['stride'] ?? 0) > 0) {
      final bitCount = pixels[0].length * bpp;
      final alignedBitCount = widthToStride(pixels[0].length) * 8;
      bitPadLine = (alignedBitCount - bitCount).toInt();
    }

    for (int y = 0; y < pixels.length; y++) {
      final line = pixels[y];
      for (int x = 0; x < line.length; x++) {
        bitStream.writeBits(line[x], bpp);
      }
      if (bitPadLine > 0) {
        addPadding(bitStream, bitPadLine ~/ bpp);
      }
    }
  }

  void storePixelsCompressed(BitStream bitStream, List<List<int>> pixels) {
    List<int> p;

    if (font.opts['no_prefilter'] == true) {
      p = pixels.expand((line) => line).toList();
    } else {
      p = prefilter(pixels).expand((line) => line).toList();
    }

    final compressor = _CompressorBitStream(bitStream);
    compress.compress(compressor, p, font.opts);
  }

  /// Create internal struct with binary data for each glyph
  /// Needed to calculate offsets & build final result
  void compile() {
    if (compiled) return;
    compiled = true;

    binData.clear();
    binData.add(Uint8List(0)); // Reserve id 0

    final f = font;

    for (final g in f.src['glyphs']) {
      final id = f.glyphId[g['code']] as int;
      if (id != null) {
        final compiledGlyph = compileGlyph(g as Map<String, dynamic>);
        // Ensure binData has enough entries
        while (binData.length <= id) {
          binData.add(Uint8List(0));
        }
        binData[id] = compiledGlyph;
      }
    }
  }

  void _writeUint32(List<int> buf, int value, int offset) {
    buf[offset] = value & 0xFF;
    buf[offset + 1] = (value >> 8) & 0xFF;
    buf[offset + 2] = (value >> 16) & 0xFF;
    buf[offset + 3] = (value >> 24) & 0xFF;
  }

  void _writeString(List<int> buf, String str, int offset) {
    for (int i = 0; i < str.length && i < 4; i++) {
      buf[offset + i] = str.codeUnitAt(i);
    }
  }
}

/// Adapter class to make BitStream compatible with the compress function
class _CompressorBitStream implements compress.BitStreamInterface {
  final BitStream _bitStream;

  _CompressorBitStream(this._bitStream);

  @override
  void writeBits(int value, int bits) {
    _bitStream.writeBits(value, bits);
  }
}

void debugPrint(String message) {
  // print('DEBUG: $message');
}
