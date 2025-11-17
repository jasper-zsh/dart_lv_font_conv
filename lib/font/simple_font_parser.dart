import 'dart:typed_data';
import '../dart_lv_font_conv_base.dart';

/// Simple font parser for basic TTF/OTF fonts
class SimpleFontParser {
  late final Uint8List _fontData;
  late final int _numTables;
  late final Map<String, _TableEntry> _tables;
  
  /// Font metrics
  late final int unitsPerEm;
  late final int ascender;
  late final int descender;
  late final int lineGap;

  SimpleFontParser();

  /// Parse font from binary data
  Future<void> parseFont(Uint8List fontData) async {
    _fontData = fontData;
    
    // Read SFNT version
    final version = _readUint32(0);
    if (version != 0x00010000 && version != 0x74727565) { // 'true'
      throw AppError('Invalid font format: not a TrueType/OpenType font');
    }

    // Read table directory
    _numTables = _readUint16(4);
    _readUint16(6); // searchRange
    _readUint16(8); // entrySelector
    _readUint16(10); // rangeShift

    // Read table entries
    _tables = {};
    int offset = 12;
    for (int i = 0; i < _numTables; i++) {
      final tag = String.fromCharCodes([
        _readUint8(offset++),
        _readUint8(offset++),
        _readUint8(offset++),
        _readUint8(offset++)
      ]);
      final checksum = _readUint32(offset);
      offset += 4;
      final tableOffset = _readUint32(offset);
      offset += 4;
      final length = _readUint32(offset);
      offset += 4;

      _tables[tag] = _TableEntry(checksum, tableOffset, length);
    }

    // Parse required tables
    await _parseHeadTable();
    await _parseMaxpTable();
    await _parseCmapTable();
  }

  /// Parse head table for global metrics
  Future<void> _parseHeadTable() async {
    final headEntry = _tables['head'];
    if (headEntry == null) {
      throw AppError('Missing required head table');
    }

    final offset = headEntry.offset;
    unitsPerEm = _readUint16(offset + 18);
    ascender = _readInt16(offset + 4);
    descender = _readInt16(offset + 6);
    lineGap = _readInt16(offset + 8);
  }

  /// Parse maxp table for glyph count
  Future<void> _parseMaxpTable() async {
    final maxpEntry = _tables['maxp'];
    if (maxpEntry == null) {
      throw AppError('Missing required maxp table');
    }

    final offset = maxpEntry.offset;
    final version = _readUint32(offset);
    if (version != 0x00010000) {
      throw AppError('Unsupported maxp version');
    }

    final numGlyphs = _readUint16(offset + 4);
    // Store glyph count for later use
    _tables['maxp'] = _TableEntry(0, offset, numGlyphs);
  }

  /// Parse cmap table for character mapping
  Future<void> _parseCmapTable() async {
    final cmapEntry = _tables['cmap'];
    if (cmapEntry == null) {
      throw AppError('Missing required cmap table');
    }

    final offset = cmapEntry.offset;
    final numSubtables = _readUint16(offset + 2);

    // Find a suitable subtable (Unicode BMP)
    int bestSubtable = -1;

    for (int i = 0; i < numSubtables; i++) {
      final subtableOffset = offset + 4 + i * 8;
      final platform = _readUint16(subtableOffset);
      final encoding = _readUint16(subtableOffset + 2);
      
      if (platform == 3 && encoding == 1) { // Unicode BMP
        bestSubtable = i;
        break;
      } else if (platform == 0 && bestSubtable == -1) { // Unicode
        bestSubtable = i;
      }
    }

    if (bestSubtable == -1) {
      throw AppError('No suitable Unicode cmap subtable found');
    }

    final subtableOffset = _readUint32(offset + 4 + bestSubtable * 8 + 4);
    // Store cmap info for character lookup
    _tables['cmap_data'] = _TableEntry(0, subtableOffset, 0);
  }

  /// Get glyph index for character code
  int getGlyphIndex(int charCode) {
    final cmapData = _tables['cmap_data'];
    if (cmapData == null) return 0;

    // Simple format 4 subtable parsing (most common)
    final offset = cmapData.offset;
    final format = _readUint16(offset);
    
    if (format == 4) {
      return _getCmapIndexFormat4(charCode, offset);
    } else if (format == 6) {
      return _getCmapIndexFormat6(charCode, offset);
    }

    return 0; // Not found
  }

  /// Get glyph index from format 4 cmap subtable
  int _getCmapIndexFormat4(int charCode, int offset) {
    final segCountX2 = _readUint16(offset + 6);

    int start = offset + 14;

    // Binary search in segments
    int min = 0;
    int max = segCountX2 ~/ 2 - 1;

    while (min <= max) {
      int mid = (min + max) ~/ 2;
      int segStart = _readUint16(start + mid * 2 + segCountX2 + 2);
      int segEnd = _readUint16(start + mid * 2);

      if (charCode < segStart) {
        max = mid - 1;
      } else if (charCode > segEnd) {
        min = mid + 1;
      } else {
        // Found segment
        int idDelta = _readInt16(start + segCountX2 + 2 + segCountX2 + mid * 2);
        int idRangeOffset = _readUint16(start + segCountX2 + 2 + segCountX2 + segCountX2 + mid * 2);

        if (idRangeOffset == 0) {
          return (charCode + idDelta) & 0xFFFF;
        } else {
          int glyphIndexOffset = start + segCountX2 * 4 + idRangeOffset + (charCode - segStart) * 2;
          return (_readUint16(glyphIndexOffset) + idDelta) & 0xFFFF;
        }
      }
    }

    return 0; // Not found
  }

  /// Get glyph index from format 6 cmap subtable
  int _getCmapIndexFormat6(int charCode, int offset) {
    final firstCode = _readUint16(offset + 6);
    final entryCount = _readUint16(offset + 8);

    if (charCode < firstCode || charCode >= firstCode + entryCount) {
      return 0;
    }

    return _readUint16(offset + 10 + (charCode - firstCode) * 2);
  }

  /// Get basic glyph metrics
  GlyphMetrics getGlyphMetrics(int glyphIndex) {
    // This is a simplified implementation
    // In a real implementation, we'd parse the 'glyf' and 'hmtx' tables
    return GlyphMetrics(
      advanceWidth: unitsPerEm ~/ 2, // Estimate
      leftSideBearing: 0,
      width: unitsPerEm ~/ 2, // Estimate
      height: unitsPerEm, // Estimate
    );
  }

  // Helper methods for reading binary data
  int _readUint8(int offset) => _fontData[offset];
  int _readUint16(int offset) => _fontData[offset] | (_fontData[offset + 1] << 8);
  int _readInt16(int offset) {
    final value = _readUint16(offset);
    return value >= 0x8000 ? value - 0x10000 : value;
  }
  int _readUint32(int offset) => 
      _fontData[offset] |
      (_fontData[offset + 1] << 8) |
      (_fontData[offset + 2] << 16) |
      (_fontData[offset + 3] << 24);
}

/// Table entry information
class _TableEntry {
  final int checksum;
  final int offset;
  final int length;
  
  _TableEntry(this.checksum, this.offset, this.length);
}

/// Basic glyph metrics
class GlyphMetrics {
  final int advanceWidth;
  final int leftSideBearing;
  final int width;
  final int height;

  GlyphMetrics({
    required this.advanceWidth,
    required this.leftSideBearing,
    required this.width,
    required this.height,
  });
}