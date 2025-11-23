/// Utility functions for font processing
library;

import 'dart:typed_data';

/// Set byte depth for glyph pixels
Map<String, dynamic> setDepth(Map<String, dynamic> glyph, int depth) {
  final pixels = <List<int>>[];
  final fn = _setByteDepth(depth);

  for (int y = 0; y < glyph['bbox']['height']; y++) {
    pixels.add(List<int>.from(glyph['pixels'][y].map<int>(fn)));
  }

  // Return new glyph object with updated pixels (same as JavaScript)
  return Map<String, dynamic>.from(glyph)..['pixels'] = pixels;
}

/// Calculate significant bits for a given depth
int Function(int) _setByteDepth(int depth) {
  return (int byte) {
    // Calculate significant bits, e.g. for depth=2 it's 0, 1, 2 or 3
    int value = (byte / (256 >> depth)).floor();

    // Spread those bits around 0..255 range, e.g. for depth=2 it's 0, 85, 170 or 255
    int scale = (2 << (depth - 1)) - 1;

    return ((value * 0xFFFF ~/ scale) >> 8);
  };
}

/// Count the number of bits set in a value
int countBits(int val) {
  int count = 0;
  val = val.floor();

  while (val != 0) {
    count++;
    val >>= 1;
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

    return line.asMap().entries.map((pixelEntry) {
      final idx = pixelEntry.key;
      final p = pixelEntry.value;
      return p ^ pixels[lIdx - 1][idx];
    }).toList();
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

/// Split array into chunks of given size
List<List<T>> chunk<T>(List<T> arr, int size) {
  final result = <List<T>>[];
  for (int i = 0; i < arr.length; i += size) {
    result.add(arr.sublist(i, (i + size > arr.length) ? arr.length : i + size));
  }
  return result;
}

/// Dump long array to multiline format with X columns and Y indent
String longDump(List<int> arr, {
  int col = 8,
  int indent = 4,
  bool hex = false,
}) {
  final indentStr = ' ' * indent;

  return chunk(arr, col)
      .map((l) => l.map((v) => hex ? '0x${v.toRadixString(16).padLeft(2, '0')}' : v.toString()).toList())
      .map((l) => '$indentStr${l.join(', ')}')
      .join(',\n');
}

/// Stable sort by pick() result
List<T> sortBy<T>(List<T> arr, int Function(T) pick) {
  final indexedEntries = arr.asMap().entries.map((entry) => _IndexedEntry(entry.value, entry.key)).toList();

  indexedEntries.sort((a, b) {
    final pickResult = pick(a.element) - pick(b.element);
    if (pickResult != 0) return pickResult;
    return a.index - b.index;
  });

  return indexedEntries.map((entry) => entry.element).toList();
}

class _IndexedEntry<T> {
  final T element;
  final int index;

  _IndexedEntry(this.element, this.index);
}

/// Sum all values in an array
int sum(List<int> arr) {
  if (arr.isEmpty) return 0;
  return arr.reduce((a, v) => a + v);
}