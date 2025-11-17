/// Merge ranges into single object
class Ranger {
  final Map<int, CharMapping> _data = {};

  /// Add range of characters with optional mapping
  /// 
  /// [font] - font path identifier
  /// [start] - starting Unicode code point
  /// [end] - ending Unicode code point  
  /// [mappedStart] - where to map the first character to
  /// Returns list of added character codes
  List<int> addRange(String font, int start, int end, int mappedStart) {
    final offset = mappedStart - start;
    final output = <int>[];

    for (int i = start; i <= end; i++) {
      _setChar(font, i, i + offset);
      output.add(i);
    }

    return output;
  }

  /// Add symbols from string
  /// 
  /// [font] - font path identifier
  /// [str] - string of characters to add
  /// Returns list of added character codes
  List<int> addSymbols(String font, String str) {
    final output = <int>[];

    for (int i = 0; i < str.runes.length; i++) {
      final code = str.runes.elementAt(i);
      _setChar(font, code, code);
      output.add(code);
    }

    return output;
  }

  void _setChar(String font, int code, int mappedTo) {
    _data[mappedTo] = CharMapping(font: font, code: code);
  }

  /// Get the character mapping data
  Map<int, CharMapping> get() => Map.unmodifiable(_data);
}

/// Class to store character mapping information
class CharMapping {
  final String font;
  final int code;

  CharMapping({
    required this.font,
    required this.code,
  });
}