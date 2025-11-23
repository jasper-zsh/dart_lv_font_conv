/// Compression functionality for font data
library;

/// Count consecutive identical values in array starting from offset
int countSame(List<int> arr, int offset) {
  int same = 1;
  int val = arr[offset];

  for (int i = offset + 1; i < arr.length; i++) {
    if (arr[i] != val) break;
    same++;
  }

  return same;
}

/// Compress pixels with RLE-like algorithm (modified I3BN)
///
/// 1. Require minimal repeat count (1) to enter I3BN mode
/// 2. Increased 1-bit-replaced repeat limit (2 => 10)
/// 3. Length of direct repetition counter reduced (8 => 6 bits).
///
/// [bitStream] - bit stream to write compressed data to
/// [pixels] - flat array of pixels (one per entry)
/// [options] - compression options including bpp (bits per pixel)
void compress(dynamic bitStream, List<int> pixels, Map<String, dynamic> options) {
  final opts = <String, dynamic>{'repeat': 1, ...options};

  // Minimal repetitions count to enable RLE mode.
  const int rleSkipCount = 1;
  // Number of repeats, when `1` used to replace data
  // If more - write as number
  const int rleBitCollapsedCount = 10;

  const int rleCounterBits = 6; // (2^bits - 1) - max value
  const int rleCounterMax = (1 << rleCounterBits) - 1;
  // Force flush if counter density exceeded.
  const int rleMaxRepeats = rleCounterMax + rleBitCollapsedCount + 1;

  int offset = 0;

  while (offset < pixels.length) {
    final int p = pixels[offset];

    int same = countSame(pixels, offset);

    // Clamp value because RLE counter density is limited
    if (same > rleMaxRepeats + rleSkipCount) {
      same = rleMaxRepeats + rleSkipCount;
    }

    // debugPrint('offset: $offset, count: $same, pixel: $p');

    offset += same;

    // If not enough for RLE - write as is.
    if (same <= rleSkipCount) {
      for (int i = 0; i < same; i++) {
        bitStream.writeBits(p, opts['bpp'] ?? 1);
        // debugPrint('==> ${opts['bpp']} bits');
      }
      continue;
    }

    // First, write "skipped" head as is.
    for (int i = 0; i < rleSkipCount; i++) {
      bitStream.writeBits(p, opts['bpp'] ?? 1);
      // debugPrint('==> ${opts['bpp']} bits');
    }

    same -= rleSkipCount;

    // Not reached state to use counter => dump bit-extended
    if (same <= rleBitCollapsedCount) {
      bitStream.writeBits(p, opts['bpp'] ?? 1);
      // debugPrint('==> ${opts['bpp']} bits (val)');
      for (int i = 0; i < same; i++) {
        if (i < same - 1) {
          bitStream.writeBits(1, 1);
          // debugPrint('==> 1 bit (rle repeat)');
        } else {
          bitStream.writeBits(0, 1);
          // debugPrint('==> 1 bit (rle repeat last)');
        }
      }
      continue;
    }

    same -= rleBitCollapsedCount + 1;

    bitStream.writeBits(p, opts['bpp'] ?? 1);
    // debugPrint('==> ${opts['bpp']} bits (val)');

    for (int i = 0; i < rleBitCollapsedCount + 1; i++) {
      bitStream.writeBits(1, 1);
      // debugPrint('==> 1 bit (rle repeat)');
    }
    bitStream.writeBits(same, rleCounterBits);
    // debugPrint('==> 4 bits (rle repeat count $same)');
  }
}

/// BitStream interface for compression
abstract class BitStreamInterface {
  void writeBits(int value, int bits);
}

void debugPrint(String message) {
  // print('DEBUG: $message');
}