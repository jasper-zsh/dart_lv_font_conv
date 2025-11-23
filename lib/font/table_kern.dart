/// KERN table for kerning information
library;

import 'dart:convert';
import 'dart:typed_data';
import 'font.dart';
import '../utils.dart';

// Offset constants
const int oSize = 0;
const int oLabel = oSize + 4;
const int oFormat = oLabel + 4;
const int headLength = 12; // align4(O_FORMAT + 1)

class Kern {
  final Font font;
  final String label = 'kern';
  bool format3Forced = false;

  Kern(this.font);

  List<int> toBin() {
    if (!font.hasKerning()) return [];

    final format0Data = _createFormat0Data();
    final format3Data = _createFormat3Data();

    final header = List<int>.filled(headLength, 0);
    List<int> data = format0Data;
    header[oFormat] = 0;

    if (_shouldUseFormat3(format0Data, format3Data)) {
      data = format3Data ?? [];
      header[oFormat] = 3;

      if (format3Forced) {
        final diff = (format3Data?.length ?? 0) - format0Data.length;
        print('Forced faster kerning format (via classes). Size increase is $diff bytes.');
      }
    } else if (font.opts['fast_kerning'] == true) {
      print('Forced faster kerning format (via classes), but data exceeds its limits. Continue use pairs.');
    }

    _writeUint32(header, header.length + data.length, oSize);
    _writeString(header, label, oLabel);

    final result = <int>[];
    result.addAll(header);
    result.addAll(data);

    return result;
  }

  bool _shouldUseFormat3(List<int> format0Data, List<int>? format3Data) {
    if (!font.hasKerning()) return false;

    if (format3Data != null && format3Data.length <= format0Data.length) return true;

    if (font.opts['fast_kerning'] == true && format3Data != null) {
      format3Forced = true;
      return true;
    }

    return false;
  }

  /// Public wrapper for _shouldUseFormat3
  bool shouldUseFormat3() {
    final format0Data = _createFormat0Data();
    final format3Data = _createFormat3Data();
    return _shouldUseFormat3(format0Data, format3Data);
  }

  List<List<dynamic>> _collectFormat0Data() {
    final f = font;
    final glyphs = sortBy<Map<String, dynamic>>(
      (f.src['glyphs'] as List).cast<Map<String, dynamic>>(),
      (g) => (f.glyphId[g['code']] ?? 0) as int,
    );

    final kernSorted = <List<dynamic>>[];

    for (final g in glyphs) {
      final kerning = g['kerning'] as Map?;
      if (kerning == null || kerning.isEmpty) continue;

      final glyphId = (f.glyphId[g['code']]!) as int;
      final paired = sortBy<int>(
        kerning.keys.map((code) => int.parse(code.toString())).toList(),
        (code) => (f.glyphId[code] ?? 0) as int,
      );

      for (final code in paired) {
        final glyphId2 = (f.glyphId[code] ?? 0) as int;
        kernSorted.add([glyphId, glyphId2, kerning['$code'] as num]);
      }
    }

    return kernSorted;
  }

  List<int> _createFormat0Data() {
    final f = font;
    final kernSorted = _collectFormat0Data();

    final count = kernSorted.length;

    final subheader = List<int>.filled(4, 0);
    _writeUint32(subheader, count, 0);

    final pairsBufferLength = ((f.glyphIdFormat == 1) ? 4 : 2) * count;
    final pairsBuf = List<int>.filled(pairsBufferLength, 0);

    // Write kerning pairs
    for (int i = 0; i < count; i++) {
      if (f.glyphIdFormat == 0) {
        pairsBuf[2 * i] = kernSorted[i][0];
        pairsBuf[2 * i + 1] = kernSorted[i][1];
      } else {
        _writeUint16(pairsBuf, kernSorted[i][0], 4 * i);
        _writeUint16(pairsBuf, kernSorted[i][1], 4 * i + 2);
      }
    }

    final valuesBuf = List<int>.filled(count, 0);

    // Write kerning values
    for (int i = 0; i < count; i++) {
      valuesBuf[i] = f.kernToFp(kernSorted[i][2]); // FP4.4
    }

    final buffer = <int>[];
    buffer.addAll(subheader);
    buffer.addAll(pairsBuf);
    buffer.addAll(valuesBuf);

    final aligned = balign4(Uint8List.fromList(buffer));

    debugPrint('table format0 size = ${aligned.length}');
    return aligned;
  }

  _Format3Data? _collectFormat3Data() {
    final f = font;
    final glyphs = sortBy<Map<String, dynamic>>(
      (f.src['glyphs'] as List).cast<Map<String, dynamic>>(),
      (g) => (f.glyphId[g['code']] ?? 0) as int,
    );

    // Extract kerning pairs for each character
    final leftKernings = <int, Map<String, num>>{};
    final rightKernings = <int, Map<String, num>>{};

    for (final g in glyphs) {
      final kerning = g['kerning'] as Map?;
      if (kerning == null || kerning.isEmpty) continue;

      final code = g['code'] as int;
      final paired = kerning.keys.map((k) => int.parse(k.toString())).toList();

      leftKernings[code] = kerning.map((key, value) => MapEntry(key.toString(), value as num));

      for (final codeKey in paired) {
        final rightCode = codeKey;
        rightKernings[rightCode] = rightKernings[rightCode] ?? {};
        rightKernings[rightCode]![code.toString()] = kerning[codeKey.toString()] as num;
      }
    }

    // Build classes from kerning patterns
    final leftClasses = _buildClasses(leftKernings);
    debugPrint('unique left classes: ${leftClasses.length}');

    final rightClasses = _buildClasses(rightKernings);
    debugPrint('unique right classes: ${rightClasses.length}');

    if (leftClasses.length >= 255 || rightClasses.length >= 255) {
      debugPrint('too many classes for format3 subtable');
      return null;
    }

    return _Format3Data(
      leftClasses: leftClasses.length,
      rightClasses: rightClasses.length,
      leftMapping: _kernClassMapping(leftClasses),
      rightMapping: _kernClassMapping(rightClasses),
      values: _kernClassValues(leftClasses, rightClasses, leftKernings),
    );
  }

  List<List<int>> _buildClasses(Map<int, Map<String, num>> kernings) {
    final classes = <List<int>>[];

    for (final code in kernings.keys) {
      // Create hash representing the kerning pattern
      final hash = jsonEncode(kernings[code]);

      // Find existing class with same pattern or create new one
      bool found = false;
      for (final classList in classes) {
        if (jsonEncode(_getClassPattern(kernings, classList)) == hash) {
          classList.add(code);
          found = true;
          break;
        }
      }
      if (!found) {
        classes.add([code]);
      }
    }

    return classes;
  }

  Map<String, num> _getClassPattern(Map<int, Map<String, num>> kernings, List<int> classList) {
    if (classList.isEmpty) return {};
    return kernings[classList.first] ?? {};
  }

  List<int> _kernClassMapping(List<List<int>> classes) {
    final arr = List<int>.filled(font.lastId, 0);

    for (int idx = 0; idx < classes.length; idx++) {
      for (final code in classes[idx]) {
        final glyphId = font.glyphId[code];
        if (glyphId != null) {
          arr[glyphId] = idx + 1;
        }
      }
    }

    return arr;
  }

  List<num> _kernClassValues(
    List<List<int>> leftClasses,
    List<List<int>> rightClasses,
    Map<int, Map<String, num>> leftKernings,
  ) {
    final arr = <num>[];

    for (final leftClass in leftClasses) {
      for (final rightClass in rightClasses) {
        final code1 = leftClass.first;
        final code2 = rightClass.first;
        final value = leftKernings[code1]?[code2.toString()] ?? 0;
        arr.add(value);
      }
    }

    return arr;
  }

  List<int>? _createFormat3Data() {
    final format3Data = _collectFormat3Data();
    if (format3Data == null) return null;

    final subheader = List<int>.filled(4, 0);
    _writeUint16(subheader, font.lastId, 0);
    subheader[2] = format3Data.leftClasses;
    subheader[3] = format3Data.rightClasses;

    final buffer = <int>[];
    buffer.addAll(subheader);
    buffer.addAll(format3Data.leftMapping);
    buffer.addAll(format3Data.rightMapping);
    buffer.addAll(format3Data.values.map((v) => font.kernToFp(v)));

    final aligned = balign4(Uint8List.fromList(buffer));

    debugPrint('table format3 size = ${aligned.length}');
    return aligned;
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

  /// Public wrapper for _collectFormat0Data
  List<List<dynamic>> collectFormat0Data() {
    return _collectFormat0Data();
  }

  /// Public wrapper for _collectFormat3Data
  Map<String, dynamic>? collectFormat3Data() {
    final data = _collectFormat3Data();
    if (data == null) return null;

    return {
      'leftClasses': data.leftClasses,
      'rightClasses': data.rightClasses,
      'leftMapping': data.leftMapping,
      'rightMapping': data.rightMapping,
      'values': data.values,
    };
  }

  /// Public wrapper for format3 binary generation (for tests)
  List<int> createFormat3Data() {
    return _createFormat3Data() ?? <int>[];
  }
}

/// Data structure for format3 kerning table
class _Format3Data {
  final int leftClasses;
  final int rightClasses;
  final List<int> leftMapping;
  final List<int> rightMapping;
  final List<num> values;

  _Format3Data({
    required this.leftClasses,
    required this.rightClasses,
    required this.leftMapping,
    required this.rightMapping,
    required this.values,
  });
}

void debugPrint(String message) {
  // print('DEBUG: $message');
}
