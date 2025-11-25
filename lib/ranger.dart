/// Merge ranges into single object
library;

/// Class for managing font character ranges and mappings
class Ranger {
  final Map<int, CharMapping> _data = {};

  /// Add a range of characters to the ranger
  ///
  /// [font] - font identifier
  /// [start] - starting Unicode code point
  /// [end] - ending Unicode code point
  /// [mappedStart] - destination code point for `start` (used for mapping ranges)
  ///
  /// Returns list of added code points
  List<int> addRange(String font, int start, int end, int mappedStart) {
    final offset = mappedStart - start;
    final output = <int>[];

    for (int i = start; i <= end; i++) {
      _setChar(font, i, i + offset);
      output.add(i);
    }

    return output;
  }

  /// Add symbols from a string to the ranger
  ///
  /// [font] - font identifier
  /// [str] - string containing characters to add
  ///
  /// Returns list of added code points
  List<int> addSymbols(String font, String str) {
    final output = <int>[];

    for (final chr in str.runes) {
      final code = chr;
      _setChar(font, code, code);
      output.add(code);
    }

    return output;
  }

  /// Set character mapping
  void _setChar(String font, int code, int mappedTo) {
    _data[mappedTo] = CharMapping(font, code);
  }

  /// Get the character mapping data
  Map<int, CharMapping> get() {
    return Map.unmodifiable(_data);
  }
}

/// Class to store character mapping information
class CharMapping {
  final String font;
  final int code;

  CharMapping(this.font, this.code);
}
