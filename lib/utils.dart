/// Utility functions for font processing
library;

import 'dart:typed_data';

/// Set byte depth for pixel values
int Function(int) setByteDepth(int depth) {
  return (int byte) {
    // calculate significant bits, e.g. for depth=2 it's 0, 1, 2 or 3
    int value = byte ~/ (256 >> depth);

    // spread those bits around 0..255 range, e.g. for depth=2 it's 0, 85, 170 or 255
    int scale = (2 << (depth - 1)) - 1;

    return ((value * 0xFFFF) ~/ scale) >> 8;
  };
}

/// Set depth for glyph pixels
List<List<int>> setDepth(Map<String, dynamic> glyph, int depth) {
  final pixels = <List<int>>[];
  final fn = setByteDepth(depth);

  for (int y = 0; y < glyph['bbox']['height']; y++) {
    pixels.add(List<int>.from(glyph['pixels'][y].map<int>(fn)));
  }

  return pixels;
}

/// Count bits in value
int countBits(int val) {
  int count = 0;
  int v = val;

  while (v != 0) {
    count++;
    v >>= 1;
  }

  return count;
}

/// Minimal number of bits to store unsigned value
int unsignedBits(int val) => countBits(val);

/// Minimal number of bits to store signed value
int signedBits(int val) {
  if (val >= 0) return countBits(val) + 1;
  return countBits((val.abs()) - 1) + 1;
}

/// Align value to 4x - useful to create word-aligned arrays
int align4(int size) {
  if (size % 4 == 0) return size;
  return size + 4 - (size % 4);
}

/// Align buffer length to 4x (returns copy with zero-filled tail)
Uint8List balign4(Uint8List buf) {
  final bufAligned = Uint8List(align4(buf.length));
  bufAligned.setRange(0, buf.length, buf);
  return bufAligned;
}

/// Pre-filter image to improve compression ratio
/// In this case - XOR lines, because it's very effective
/// in decompressor and does not depend on bpp.
List<List<int>> prefilter(List<List<int>> pixels) {
  return pixels.asMap().entries.map((entry) {
    final lIdx = entry.key;
    final line = entry.value;
    
    if (lIdx == 0) return List<int>.from(line);
    
    return line.asMap().entries.map((e) => 
      e.value ^ pixels[lIdx - 1][e.key]
    ).toList();
  }).toList();
}

/// Convert array with uint16 data to buffer
Uint8List bFromA16(List<int> arr) {
  final buf = Uint8List(arr.length * 2);
  
  for (int i = 0; i < arr.length; i++) {
    final value = arr[i];
    buf[i * 2] = value & 0xFF;
    buf[i * 2 + 1] = (value >> 8) & 0xFF;
  }
  
  return buf;
}

/// Convert array with uint32 data to buffer
Uint8List bFromA32(List<int> arr) {
  final buf = Uint8List(arr.length * 4);
  
  for (int i = 0; i < arr.length; i++) {
    final value = arr[i];
    buf[i * 4] = value & 0xFF;
    buf[i * 4 + 1] = (value >> 8) & 0xFF;
    buf[i * 4 + 2] = (value >> 16) & 0xFF;
    buf[i * 4 + 3] = (value >> 24) & 0xFF;
  }
  
  return buf;
}

/// Chunk array into smaller pieces
List<List<T>> chunk<T>(List<T> arr, int size) {
  final result = <List<T>>[];
  for (int i = 0; i < arr.length; i += size) {
    final end = (i + size).clamp(0, arr.length);
    result.add(arr.sublist(i, end));
  }
  return result;
}

/// Dump long array to multiline format with X columns and Y indent
String longDump(List<int> arr, {int col = 8, int indent = 4, bool hex = false}) {
  final indentStr = ' ' * indent;
  
  return chunk(arr, col)
    .map((l) => l.map((v) => hex ? '0x${v.toRadixString(16).padLeft(2, '0')}' : v.toString()))
    .map((l) => '$indentStr${l.join(', ')}')
    .join(',\n');
}

/// Stable sort by pick() result
List<T> sortBy<T>(List<T> arr, int Function(T) pick) {
  final indexed = arr.asMap().entries.map((e) => _IndexedItem<T>(e.value, e.key)).toList();
  indexed.sort((a, b) {
    final pickDiff = pick(a.el) - pick(b.el);
    if (pickDiff != 0) return pickDiff;
    return a.idx - b.idx;
  });
  return indexed.map((e) => e.el).toList();
}

class _IndexedItem<T> {
  final T el;
  final int idx;
  _IndexedItem(this.el, this.idx);
}

/// Sum array values
int sum(List<int> arr) {
  return arr.fold(0, (a, v) => a + v);
}