/// Find an optimal configuration of cmap tables representing set of codepoints,
/// using simple breadth-first algorithm
///
/// Assume that:
///  - codepoints have one-to-one correspondence to glyph ids
///  - glyph ids are always bigger for bigger codepoints
///  - glyph ids are always consecutive (1..N without gaps)
///
/// This way we can omit glyph ids from all calculations entirely: if codepoints
/// fit in format0, then glyph ids also will.
///
/// format6 is not considered, because if glyph ids can be delta-coded,
/// multiple format0 tables are guaranteed to be smaller than a single format6.
///
/// sparse format is not used because as long as glyph ids are consecutive,
/// sparse_tiny will always be preferred.
library;

/// Estimate format0 tiny table size
int _estimateFormat0TinySize(int startCode, int endCode) {
  return 16;
}

/// Estimate format0 table size
int _estimateFormat0Size(int startCode, int endCode) {
  return 16 + (endCode - startCode + 1);
}

/// Estimate sparse tiny table size
int _estimateSparseTinySize(int count) {
  return 16 + count * 2;
}

/// Split codepoints into optimal cmap subtables
List<List<dynamic>> cmapSplit(List<int> allCodepoints) {
  final sortedCodepoints = List<int>.from(allCodepoints)..sort();

  final minPaths = <_PathInfo>[];

  for (int i = 0; i < sortedCodepoints.length; i++) {
    _PathInfo min = _PathInfo(dist: double.infinity);

    for (int j = 0; j <= i; j++) {
      final prevDist = (j - 1 >= 0) ? minPaths[j - 1].dist : 0;
      int s;

      if (sortedCodepoints[i] - sortedCodepoints[j] < 256) {
        s = _estimateFormat0Size(sortedCodepoints[j], sortedCodepoints[i]);

        if (prevDist + s < min.dist) {
          min = _PathInfo(
            dist: (prevDist + s).toDouble(),
            start: j,
            end: i,
            format: 'format0',
          );
        }
      }

      if (sortedCodepoints[i] - sortedCodepoints[j] < 256 &&
          sortedCodepoints[i] - i == sortedCodepoints[j] - j) {
        s = _estimateFormat0TinySize(sortedCodepoints[j], sortedCodepoints[i]);

        if (prevDist + s < min.dist) {
          min = _PathInfo(
            dist: (prevDist + s).toDouble(),
            start: j,
            end: i,
            format: 'format0_tiny',
          );
        }
      }

      // tiny sparse will always be preferred over full sparse because glyph ids are consecutive
      if (sortedCodepoints[i] - sortedCodepoints[j] < 65536) {
        s = _estimateSparseTinySize(i - j + 1);

        if (prevDist + s < min.dist) {
          min = _PathInfo(
            dist: (prevDist + s).toDouble(),
            start: j,
            end: i,
            format: 'sparse_tiny',
          );
        }
      }
    }

    minPaths.add(min);
  }

  final result = <List<dynamic>>[];

  for (int i = sortedCodepoints.length - 1; i >= 0;) {
    final path = minPaths[i];
    result.insert(0, [
      path.format,
      sortedCodepoints.sublist(path.start, path.end + 1)
    ]);
    i = path.start - 1;
  }

  return result;
}

/// Internal path information for tracking optimal subtable splits
class _PathInfo {
  final double dist;
  final int start;
  final int end;
  final String format;

  _PathInfo({
    required this.dist,
    this.start = 0,
    this.end = 0,
    this.format = '',
  });
}