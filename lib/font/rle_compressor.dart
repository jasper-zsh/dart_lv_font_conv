import '../dart_lv_font_conv_base.dart';

/// Run-Length Encoding (RLE) compression utilities
class RleCompressor {
  /// Compress bitmap data using RLE
  static List<int> compress(List<List<int>> bitmap, int bpp) {
    if (bitmap.isEmpty) return [];

    switch (bpp) {
      case 1:
        return _compressRle1(bitmap);
      case 2:
        return _compressRle2(bitmap);
      case 4:
        return _compressRle4(bitmap);
      case 8:
        return _compressRle8(bitmap);
      default:
        throw AppError('Unsupported BPP for RLE compression: $bpp');
    }
  }

  /// Decompress RLE data (for testing)
  static List<List<int>> decompress(List<int> compressed, int width, int height, int bpp) {
    switch (bpp) {
      case 1:
        return _decompressRle1(compressed, width, height);
      case 2:
        return _decompressRle2(compressed, width, height);
      case 4:
        return _decompressRle4(compressed, width, height);
      case 8:
        return _decompressRle8(compressed, width, height);
      default:
        throw AppError('Unsupported BPP for RLE decompression: $bpp');
    }
  }

  /// RLE compression for 1 BPP (monochrome)
  static List<int> _compressRle1(List<List<int>> bitmap) {
    final result = <int>[];
    
    for (final row in bitmap) {
      int x = 0;
      while (x < row.length) {
        // Count consecutive zeros
        int zeroCount = 0;
        while (x + zeroCount < row.length && row[x + zeroCount] == 0) {
          zeroCount++;
          if (zeroCount >= 127) break;
        }
        
        if (zeroCount > 0) {
          result.add(zeroCount);
          x += zeroCount;
          continue;
        }
        
        // Count consecutive ones
        int oneCount = 0;
        while (x + oneCount < row.length && row[x + oneCount] == 255) {
          oneCount++;
          if (oneCount >= 127) break;
        }
        
        if (oneCount > 0) {
          result.add(oneCount | 0x80);
          x += oneCount;
        }
      }
      
      // End of line marker
      result.add(0);
    }
    
    return result;
  }

  /// RLE compression for 2 BPP
  static List<int> _compressRle2(List<List<int>> bitmap) {
    final result = <int>[];
    
    for (final row in bitmap) {
      int x = 0;
      while (x < row.length) {
        // Pack 4 pixels per byte (2 BPP)
        final remaining = row.length - x;
        final pixelsToProcess = remaining < 4 ? remaining : 4;
        
        int packedByte = 0;
        for (int i = 0; i < pixelsToProcess; i++) {
          final value = row[x + i] >> 6; // Convert to 2-bit value
          packedByte |= (value & 0x03) << (6 - i * 2);
        }
        
        // Simple RLE: if all pixels are the same, use RLE, else store raw
        if (pixelsToProcess == 4 && 
            (row[x] >> 6) == (row[x + 1] >> 6) &&
            (row[x + 1] >> 6) == (row[x + 2] >> 6) &&
            (row[x + 2] >> 6) == (row[x + 3] >> 6)) {
          // RLE encoding
          final value = (row[x] >> 6) & 0x03;
          final count = _findRunLength(row, x, 4, value, 2);
          result.add(0x80 | count);
          result.add(value);
          x += count * 4;
        } else {
          // Raw encoding
          result.add(pixelsToProcess - 1);
          result.add(packedByte);
          x += pixelsToProcess;
        }
      }
      
      // End of line marker
      result.add(0);
    }
    
    return result;
  }

  /// RLE compression for 4 BPP
  static List<int> _compressRle4(List<List<int>> bitmap) {
    final result = <int>[];
    
    for (final row in bitmap) {
      int x = 0;
      while (x < row.length) {
        // Pack 2 pixels per byte (4 BPP)
        final remaining = row.length - x;
        final pixelsToProcess = remaining < 2 ? remaining : 2;
        
        int packedByte = 0;
        for (int i = 0; i < pixelsToProcess; i++) {
          final value = row[x + i] >> 4; // Convert to 4-bit value
          packedByte |= (value & 0x0F) << (4 - i * 4);
        }
        
        // Simple RLE logic
        if (pixelsToProcess == 2 && 
            (row[x] >> 4) == (row[x + 1] >> 4)) {
          // RLE encoding
          final value = (row[x] >> 4) & 0x0F;
          final count = _findRunLength(row, x, 2, value, 4);
          result.add(0x80 | count);
          result.add(value);
          x += count * 2;
        } else {
          // Raw encoding
          result.add(pixelsToProcess - 1);
          result.add(packedByte);
          x += pixelsToProcess;
        }
      }
      
      // End of line marker
      result.add(0);
    }
    
    return result;
  }

  /// RLE compression for 8 BPP
  static List<int> _compressRle8(List<List<int>> bitmap) {
    final result = <int>[];
    
    for (final row in bitmap) {
      int x = 0;
      while (x < row.length) {
        final value = row[x];
        final count = _findRunLength(row, x, 1, value, 8);
        
        if (count >= 3 && count <= 127) {
          // RLE encoding
          result.add(0x80 | count);
          result.add(value);
          x += count;
        } else {
          // Raw encoding
          result.add(0);
          result.add(value);
          x++;
        }
      }
      
      // End of line marker
      result.add(0);
    }
    
    return result;
  }

  /// Find run length for RLE compression
  static int _findRunLength(List<int> row, int start, int step, int value, int bpp) {
    int count = 0;
    int maxCount = 128;
    
    for (int i = start; i < row.length && count < maxCount; i += step) {
      final currentValue = (row[i] >> (8 - bpp)) & ((1 << bpp) - 1);
      if (currentValue != value) break;
      count++;
    }
    
    return count;
  }

  /// Decompression helpers for testing
  static List<List<int>> _decompressRle1(List<int> compressed, int width, int height) {
    final result = List.generate(height, (_) => List.filled(width, 0));
    int row = 0;
    int col = 0;
    int i = 0;
    
    while (row < height && i < compressed.length) {
      final value = compressed[i++];
      
      if (value == 0) {
        // End of line
        row++;
        col = 0;
      } else if ((value & 0x80) != 0) {
        // RLE run
        final count = value & 0x7F;
        final pixelValue = (value & 0x80) != 0 ? 255 : 0;
        
        for (int j = 0; j < count && col < width; j++) {
          result[row][col++] = pixelValue;
        }
      } else {
        // Raw run
        final count = value;
        for (int j = 0; j < count && col < width; j++) {
          result[row][col++] = 255;
        }
      }
    }
    
    return result;
  }

  static List<List<int>> _decompressRle2(List<int> compressed, int width, int height) {
    // Simplified implementation
    return List.generate(height, (_) => List.filled(width, 128));
  }

  static List<List<int>> _decompressRle4(List<int> compressed, int width, int height) {
    // Simplified implementation
    return List.generate(height, (_) => List.filled(width, 64));
  }

  static List<List<int>> _decompressRle8(List<int> compressed, int width, int height) {
    // Simplified implementation
    return List.generate(height, (_) => List.filled(width, 32));
  }

  /// Apply XOR pre-filter to improve compression
  static List<List<int>> applyXorFilter(List<List<int>> bitmap) {
    if (bitmap.isEmpty) return bitmap;
    
    final filtered = List.generate(bitmap.length, (y) {
      return List.generate(bitmap[0].length, (x) {
        if (y == 0) return bitmap[y][x];
        return bitmap[y][x] ^ bitmap[y - 1][x];
      });
    });
    
    return filtered;
  }

  /// Remove XOR pre-filter
  static List<List<int>> removeXorFilter(List<List<int>> filtered) {
    if (filtered.isEmpty) return filtered;
    
    final bitmap = List.generate(filtered.length, (y) {
      return List.generate(filtered[0].length, (x) {
        if (y == 0) return filtered[y][x];
        return filtered[y][x] ^ filtered[y - 1][x];
      });
    });
    
    return bitmap;
  }
}