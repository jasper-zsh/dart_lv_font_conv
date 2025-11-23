/// LOCA table for glyph location offsets
library;

import 'dart:typed_data';
import 'font.dart';
import '../utils.dart';

// Offset constants
const int oSize = 0;
const int oLabel = oSize + 4;
const int oCount = oLabel + 4;
const int headLength = oCount + 4;

class Loca {
  final Font font;
  final String label = 'loca';

  Loca(this.font);

  List<int> toBin() {
    final f = font;

    final offsets = List<int>.generate(f.lastId, (i) => f.glyf.getOffset(i));

    final buffer = <int>[];
    buffer.addAll(List<int>.filled(headLength, 0));

    if (f.indexToLocFormat == 1) {
      buffer.addAll(bFromA32(offsets));
    } else {
      buffer.addAll(bFromA16(offsets));
    }

    final aligned = balign4(Uint8List.fromList(buffer));

    // Write header
    _writeUint32(aligned, aligned.length, oSize);
    _writeString(aligned, label, oLabel);
    _writeUint32(aligned, f.lastId, oCount);

    debugPrint('table size = ${aligned.length}');

    return aligned;
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

void debugPrint(String message) {
  // print('DEBUG: $message');
}