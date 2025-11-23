/// CMAP table for character-to-glyph mapping
library;

import 'dart:typed_data';
import 'font.dart';
import 'cmap_build_subtables.dart';
import '../utils.dart';

// Offset constants
const int oSize = 0;
const int oLabel = oSize + 4;
const int oCount = oLabel + 4;

const int headLength = oCount + 4;

// Subtable format constants
const int subFormat0 = 0;
const int subFormat0Tiny = 2;
const int subFormatSparse = 1;
const int subFormatSparseTiny = 3;

class Cmap {
  final Font font;
  final String label = 'cmap';

  final List<List<int>> subHeads = [];
  final List<List<int>> subData = [];

  bool compiled = false;

  Cmap(this.font);

  List<int> toBin() {
    if (!compiled) compile();

    final result = <int>[];

    // Add header space
    result.addAll(List<int>.filled(headLength, 0));

    // Add sub-headers
    for (final head in subHeads) {
      result.addAll(head);
    }

    // Add sub-data
    for (final data in subData) {
      result.addAll(data);
    }

    debugPrint('table size = ${result.length}');

    // Write header
    _writeUint32(result, result.length, oSize);
    _writeString(result, label, oLabel);
    _writeUint32(result, subHeads.length, oCount);

    return result;
  }

  void compile() {
    if (compiled) return;
    compiled = true;

    final f = font;

    final List<List<dynamic>> subtablesPlan = cmapSplit(
        f.src['glyphs'].map<int>((g) => g['code'] as int).toList());

    final countFormat0 = subtablesPlan.where((s) => s[0] == 'format0').length;
    final countSparse = subtablesPlan.length - countFormat0;
    debugPrint('${subtablesPlan.length} subtable(s): $countFormat0 "format 0", $countSparse "sparse"');

    for (final subtable in subtablesPlan) {
      final format = subtable[0] as String;
      final codepoints = subtable[1] as List<int>;

      final g = glyphByCode(codepoints[0])!;
      final startGlyphId = (f.glyphId[g['code']]!) as int;
      final minCode = codepoints[0];
      final maxCode = codepoints[codepoints.length - 1];
      int entriesCount = maxCode - minCode + 1;
      int formatCode = 0;

      List<int> data;

      if (format == 'format0_tiny') {
        formatCode = subFormat0Tiny;
        data = [];
      } else if (format == 'format0') {
        formatCode = subFormat0;
        data = createFormat0Data(minCode, maxCode, startGlyphId);
      } else if (format == 'sparse_tiny') {
        entriesCount = codepoints.length;
        formatCode = subFormatSparseTiny;
        data = createSparseTinyData(codepoints, startGlyphId);
      } else { // assume format == 'sparse'
        entriesCount = codepoints.length;
        formatCode = subFormatSparse;
        data = createSparseData(codepoints, startGlyphId);
      }

      subData.add(data);
      subHeads.add(createSubHeader(
        minCode,
        maxCode - minCode + 1,
        startGlyphId,
        entriesCount,
        formatCode
      ));
    }

    subHeaderUpdateAllOffsets();
  }

  List<int> createSubHeader(int rangeStart, int rangeLen, int glyphIdOffset, int total, int type) {
    final buf = List<int>.filled(16, 0);

    // buf.writeUInt32LE(offset, 0); offset unknown at this moment
    _writeUint32(buf, rangeStart, 4);
    _writeUint16(buf, rangeLen, 8);
    _writeUint16(buf, glyphIdOffset, 10);
    _writeUint16(buf, total, 12);
    buf[14] = type;

    return buf;
  }

  void subHeaderUpdateOffset(List<int> header, int val) {
    _writeUint32(header, val, 0);
  }

  void subHeaderUpdateAllOffsets() {
    for (int i = 0; i < subHeads.length; i++) {
      final offset = headLength +
          sum(subHeads.map<int>((h) => h.length).toList()) +
          sum(subData.sublist(0, i).map<int>((d) => d.length).toList());

      subHeaderUpdateOffset(subHeads[i], offset);
    }
  }

  Map<String, dynamic>? glyphByCode(int code) {
    for (final g in font.src['glyphs']) {
      if (g['code'] == code) return g;
    }
    return null;
  }

  List<int> collectFormat0Data(int minCode, int maxCode, int startGlyphId) {
    final data = <int>[];

    for (int i = minCode; i <= maxCode; i++) {
      final g = glyphByCode(i);

      if (g == null) {
        data.add(0);
        continue;
      }

      final idDelta = (font.glyphId[g['code']]! as int) - startGlyphId;

      if (idDelta < 0 || idDelta > 255) {
        throw Exception('Glyph ID delta out of Format 0 range');
      }

      data.add(idDelta);
    }

    return data;
  }

  List<int> createFormat0Data(int minCode, int maxCode, int startGlyphId) {
    final data = collectFormat0Data(minCode, maxCode, startGlyphId);
    return balign4(Uint8List.fromList(data));
  }

  SparseData collectSparseData(List<int> codepoints, int startGlyphId) {
    final codepointsList = <int>[];
    final idsList = <int>[];

    for (final code in codepoints) {
      final g = glyphByCode(code)!;
      final id = font.glyphId[g['code']]! as int;

      final codeDelta = code - codepoints[0];
      final idDelta = id - startGlyphId;

      if (codeDelta < 0 || codeDelta > 65535) {
        throw Exception('Codepoint delta out of range');
      }
      if (idDelta < 0 || idDelta > 65535) {
        throw Exception('Glyph ID delta out of range');
      }

      codepointsList.add(codeDelta);
      idsList.add(idDelta);
    }

    return SparseData(codes: codepointsList, ids: idsList);
  }

  List<int> createSparseData(List<int> codepoints, int startGlyphId) {
    final data = collectSparseData(codepoints, startGlyphId);

    final buffer = <int>[];
    buffer.addAll(bFromA16(data.codes));
    buffer.addAll(bFromA16(data.ids));

    return balign4(Uint8List.fromList(buffer));
  }

  List<int> createSparseTinyData(List<int> codepoints, int startGlyphId) {
    final data = collectSparseData(codepoints, startGlyphId);
    return balign4(bFromA16(data.codes));
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

  void _writeString(List<int> buf, String str, int offset) {
    for (int i = 0; i < str.length && i < 4; i++) {
      buf[offset + i] = str.codeUnitAt(i);
    }
  }
}

/// Internal data structure for sparse table data
class SparseData {
  final List<int> codes;
  final List<int> ids;

  SparseData({required this.codes, required this.ids});
}

void debugPrint(String message) {
  // print('DEBUG: $message');
}