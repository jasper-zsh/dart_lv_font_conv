/// BitStream implementation for writing bits to a buffer
library;

import 'dart:typed_data';

/// BitStream for writing individual bits to a byte buffer
class BitStream implements BitStreamInterface {
  final Uint8List _buffer;
  final bool _bigEndian;
  int _bitIndex = 0;
  int _byteIndex = 0;

  /// Creates a new BitStream with the given buffer
  BitStream(this._buffer, {bool bigEndian = true}) : _bigEndian = bigEndian;

  /// Creates a new BitStream with the given buffer size
  BitStream.size(int size, {bool bigEndian = true})
      : _buffer = Uint8List(size),
        _bigEndian = bigEndian;

  /// Current bit position within the current byte
  int get bitIndex => _bitIndex;

  /// Current byte position in the buffer
  int get byteIndex => _byteIndex + ((_bitIndex + 7) ~/ 8);

  /// Current bit position in the stream
  int get position => _byteIndex * 8 + _bitIndex;

  /// Set current bit position in the stream (for compatibility)
  set position(int value) {
    _byteIndex = value ~/ 8;
    _bitIndex = value % 8;
  }

  /// Whether the stream uses big-endian bit order
  bool get bigEndian => _bigEndian;

  /// Set big-endian mode (for compatibility)
  set bigEndian(bool value) {
    // Note: This doesn't change the actual endian mode during operation
    // but provides API compatibility with the original implementation
  }

  /// Write a single byte (for compatibility)
  void writeByte(int value) {
    writeBits(value, 8);
  }

  /// Read bits from the stream (simplified implementation for compatibility)
  int readBits(int bits, bool signed) {
    if (bits == 0) return 0;

    final currentPos = position;
    int result = 0;

    // Simple implementation - read from buffer at current position
    for (int i = 0; i < bits; i++) {
      final bytePos = (currentPos + i) ~/ 8;
      final bitPos = (currentPos + i) % 8;

      if (bytePos >= _buffer.length) break;

      final bitValue = (_buffer[bytePos] >> (7 - bitPos)) & 1;
      result = (result << 1) | bitValue;
    }

    // Handle signed values
    if (signed && bits > 0 && (result & (1 << (bits - 1))) != 0) {
      result -= (1 << bits);
    }

    return result;
  }

  /// Get the current buffer contents
  Uint8List getBytes() {
    return Uint8List.fromList(_buffer);
  }

  /// Write bits to the stream
  @override
  void writeBits(int value, int bits) {
    if (bits == 0) return;

    value = value & ((1 << bits) - 1);
    int remainingBits = bits;

    while (remainingBits > 0) {
      if (_byteIndex >= _buffer.length) {
        throw Exception('Buffer overflow in BitStream');
      }

      final int bitsAvailable = 8 - _bitIndex;
      final int bitsToWrite = remainingBits < bitsAvailable ? remainingBits : bitsAvailable;

      final int shift = _bigEndian ? (bitsAvailable - bitsToWrite) : _bitIndex;
      final int mask = ((1 << bitsToWrite) - 1) << shift;

      final int currentByte = _buffer[_byteIndex];
      final int newValue = (currentByte & ~mask) | ((value << shift) & mask);
      _buffer[_byteIndex] = newValue & 0xFF;

      if (_bigEndian) {
        value >>= bitsToWrite;
      } else {
        _bitIndex += bitsToWrite;
        if (_bitIndex >= 8) {
          _bitIndex = 0;
          _byteIndex++;
        }
        value <<= bitsAvailable - bitsToWrite;
      }

      remainingBits -= bitsToWrite;

      if (_bigEndian) {
        _bitIndex += bitsToWrite;
        if (_bitIndex >= 8) {
          _bitIndex = 0;
          _byteIndex++;
        }
      }
    }
  }
}

/// Interface for bit stream implementations
abstract class BitStreamInterface {
  void writeBits(int value, int bits);
}