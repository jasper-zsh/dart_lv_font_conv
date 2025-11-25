/// Font data collection and processing module
library;

import 'dart:io';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:dart_freetype/dart_freetype.dart' hide StringUtf8Pointer;

import 'app_error.dart';
import 'ranger.dart';

// Pixel mode constants are not exported by dart_freetype bindings
const int _ftPixelModeMono = 1;
const int _ftPixelModeBgra = 7;

class _FreetypeContext {
  _FreetypeContext({this.allocator = calloc, String? libraryPath})
    : dylib = ffi.DynamicLibrary.open(libraryPath ?? _defaultLibraryPath()) {
    binding = FreetypeBinding(dylib);
    libraryPtr = allocator<ffi.Pointer<FT_LibraryRec_>>();

    final err = binding.FT_Init_FreeType(libraryPtr);
    if (err != 0) {
      allocator.free(libraryPtr);
      throw AppError('Error on Init FreeType: $err');
    }
  }

  final ffi.DynamicLibrary dylib;
  final ffi.Allocator allocator;
  late final FreetypeBinding binding;
  late final ffi.Pointer<ffi.Pointer<FT_LibraryRec_>> libraryPtr;

  ffi.Pointer<FT_LibraryRec_> get library => libraryPtr.value;

  void dispose() {
    binding.FT_Done_FreeType(library);
    allocator.free(libraryPtr);
  }

  static String _defaultLibraryPath() {
    if (Platform.isWindows) return 'freetype.dll';
    if (Platform.isMacOS) return 'libfreetype.dylib';
    if (Platform.isAndroid) return "libfreetype.so";
    return 'libfreetype.so.6';
  }
}

/// Font data structure
class FontData {
  final List<GlyphData> glyphs;
  final int ascent;
  final int descent;
  final int typoAscent;
  final int typoDescent;
  final int typoLineGap;
  final int size;
  final int underlinePosition;
  final int underlineThickness;

  FontData({
    required this.glyphs,
    required this.ascent,
    required this.descent,
    required this.typoAscent,
    required this.typoDescent,
    required this.typoLineGap,
    required this.size,
    required this.underlinePosition,
    required this.underlineThickness,
  });

  Map<String, dynamic> toJson() {
    return {
      'glyphs': glyphs.map((g) => g.toJson()).toList(),
      'ascent': ascent,
      'descent': descent,
      'typoAscent': typoAscent,
      'typoDescent': typoDescent,
      'typoLineGap': typoLineGap,
      'size': size,
      'underlinePosition': underlinePosition,
      'underlineThickness': underlineThickness,
    };
  }
}

class _FtFace {
  final Face face;
  final ffi.Pointer<ffi.Uint8>? buffer;
  final ffi.Pointer<ffi.Int8>? pathPointer;

  _FtFace(this.face, {this.buffer, this.pathPointer});

  void dispose(ffi.Allocator allocator) {
    face.free();
    if (buffer != null) allocator.free(buffer!);
    if (pathPointer != null) allocator.free(pathPointer!);
  }
}

_FtFace _createFace(_FreetypeContext freetype, FontSpec fontSpec, int size) {
  Face face;
  ffi.Pointer<ffi.Uint8>? buffer;

  try {
    if (fontSpec.sourceBin.isNotEmpty) {
      buffer = freetype.allocator<ffi.Uint8>(fontSpec.sourceBin.length);
      buffer
          .asTypedList(fontSpec.sourceBin.length)
          .setAll(0, fontSpec.sourceBin);

      final facePtr = freetype.allocator<FT_Face>();
      final err = freetype.binding.FT_New_Memory_Face(
        freetype.library,
        buffer.cast(),
        fontSpec.sourceBin.length,
        0,
        facePtr,
      );

      if (err != 0) {
        freetype.allocator.free(facePtr);
        throw AppError(
          'Cannot load font "${fontSpec.sourcePath}": error code $err',
        );
      }

      face = Face.fromRaw(
        freetype.library,
        facePtr.value,
        freetype.binding,
        freetype.allocator,
        ffi.Pointer.fromAddress(0),
        bytes: buffer,
      );
      freetype.allocator.free(facePtr);
      face.setCharSize(0, size * 64, 300, 300);
      face.setPixelSizes(0, size);
      return _FtFace(face, buffer: buffer);
    }

    final facePtr = freetype.allocator<FT_Face>();
    final pathPtr = fontSpec.sourcePath.toNativeUtf8(
      allocator: freetype.allocator,
    );
    final err = freetype.binding.FT_New_Face(
      freetype.library,
      pathPtr.cast(),
      0,
      facePtr,
    );
    if (err != 0) {
      freetype.allocator.free(facePtr);
      freetype.allocator.free(pathPtr);
      throw AppError(
        'Cannot load font "${fontSpec.sourcePath}": error code $err',
      );
    }

    face = Face.fromRaw(
      freetype.library,
      facePtr.value,
      freetype.binding,
      freetype.allocator,
      pathPtr.cast(),
    );
    freetype.allocator.free(facePtr);

    face.setCharSize(0, size * 64, 300, 300);
    face.setPixelSizes(0, size);
    return _FtFace(face, pathPointer: pathPtr.cast());
  } catch (e) {
    if (buffer != null) {
      freetype.allocator.free(buffer);
    }
    if (e is AppError) {
      rethrow;
    }
    throw AppError('Cannot load font "${fontSpec.sourcePath}": $e');
  }
}

bool _glyphExists(Face face, int code) {
  final glyphIndex = face.binding.FT_Get_Char_Index(face.raw, code);
  return glyphIndex != 0;
}

class _GlyphRenderResult {
  final int x;
  final int y;
  final int width;
  final int height;
  final double advanceX;
  final double advanceY;
  final List<List<int>> pixels;

  _GlyphRenderResult({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.advanceX,
    required this.advanceY,
    required this.pixels,
  });
}

_GlyphRenderResult _renderGlyph(
  Face face,
  int code,
  Map<String, dynamic> args,
) {
  final binding = face.binding;
  final glyphIndex = binding.FT_Get_Char_Index(face.raw, code);

  if (glyphIndex == 0) {
    throw AppError('glyph does not exist for codepoint $code');
  }

  final mono =
      !(args['lcd'] as bool? ?? false) &&
      !(args['lcd_v'] as bool? ?? false) &&
      (args['bpp'] == 1);
  final autohintStrong = args['autohint_strong'] == true;
  final autohintOff = args['autohint_off'] == true;
  final lcd = args['lcd'] == true;
  final lcdV = args['lcd_v'] == true;
  final useColorInfo = args['use_color_info'] == true;

  int loadFlags = FT_LOAD_RENDER;

  if (mono) {
    loadFlags |= FT_LOAD_TARGET_MONO;
  } else if (lcd) {
    loadFlags |= FT_LOAD_TARGET_LCD;
  } else if (lcdV) {
    loadFlags |= FT_LOAD_TARGET_LCD_V;
  } else {
    loadFlags |= autohintStrong ? FT_LOAD_TARGET_NORMAL : FT_LOAD_TARGET_LIGHT;
  }

  if (autohintOff) {
    loadFlags |= FT_LOAD_NO_AUTOHINT;
  } else {
    loadFlags |= FT_LOAD_FORCE_AUTOHINT;
  }

  if (useColorInfo) {
    loadFlags |= FT_LOAD_COLOR;
  }

  final err = binding.FT_Load_Glyph(face.raw, glyphIndex, loadFlags);
  if (err != 0) {
    throw AppError('error in FT_Load_Glyph: $err');
  }

  final glyphSlot = face.glyph;
  final bitmap = glyphSlot.bitmap();
  final width = bitmap.width;
  final height = bitmap.rows;
  final pitch = bitmap.pitch.abs();
  final pixelMode = bitmap.pixelMode;
  final buffer = bitmap.buffer;
  final pixels = <List<int>>[];

  for (int y = 0; y < height; y++) {
    final rowStart = y * pitch;
    final line = <int>[];

    for (int x = 0; x < width; x++) {
      int value;
      if (pixelMode == _ftPixelModeMono) {
        final byte = buffer[rowStart + (x >> 3)];
        value = (byte & (1 << (7 - (x & 7)))) != 0 ? 255 : 0;
      } else if (pixelMode == _ftPixelModeBgra) {
        final idx = rowStart + (x * 4);
        final blue = buffer[idx] & 0xFF;
        final green = buffer[idx + 1] & 0xFF;
        final red = buffer[idx + 2] & 0xFF;
        final alpha = buffer[idx + 3] & 0xFF;
        final grayscale = (0.299 * red + 0.587 * green + 0.114 * blue)
            .round()
            .clamp(0, 255);
        value = (((255 - grayscale) * alpha) / 255).round();
      } else {
        value = buffer[rowStart + x] & 0xFF;
      }
      line.add(value);
    }

    pixels.add(line);
  }

  final advance = glyphSlot.advance;

  return _GlyphRenderResult(
    x: glyphSlot.bitmapLeft,
    y: glyphSlot.bitmapTop,
    width: width,
    height: height,
    advanceX: advance.x / 64.0,
    advanceY: advance.y / 64.0,
    pixels: pixels,
  );
}

void _addKerningWithFreetype(
  List<GlyphData> glyphs,
  Map<int, CharMapping> mapping,
  Map<String, _FtFace> faces,
) {
  final existingDstCharcodes = glyphs.map((g) => g.code).toList();

  for (final glyph in glyphs) {
    final glyphMapping = mapping[glyph.code]!;
    final faceHolder = faces[glyphMapping.font];
    if (faceHolder == null) continue;

    final binding = faceHolder.face.binding;
    final glyphIndex = binding.FT_Get_Char_Index(
      faceHolder.face.raw,
      glyphMapping.code,
    );
    if (glyphIndex == 0) continue;

    for (final dstCode2 in existingDstCharcodes) {
      final targetMapping = mapping[dstCode2]!;

      if (targetMapping.font != glyphMapping.font) continue;

      final glyphIndex2 = binding.FT_Get_Char_Index(
        faceHolder.face.raw,
        targetMapping.code,
      );
      if (glyphIndex2 == 0) continue;

      final kerningVec = faceHolder.face.allocator<FT_Vector>();
      final err = binding.FT_Get_Kerning(
        faceHolder.face.raw,
        glyphIndex,
        glyphIndex2,
        FT_Kerning_Mode_.FT_KERNING_DEFAULT.value,
        kerningVec,
      );
      if (err == 0) {
        final kernValue = kerningVec.ref.x / 64.0;
        if (kernValue != 0) {
          glyph.kerning[dstCode2] = kernValue;
        }
      }
      faceHolder.face.allocator.free(kerningVec);
    }
  }
}

Map<String, int> _computeFontMetrics(
  Face face,
  int size,
  List<GlyphData> glyphs,
) {
  final ascent = glyphs
      .map((g) => g.bbox.y + g.bbox.height)
      .reduce((a, b) => a > b ? a : b);
  final descent = glyphs.map((g) => g.bbox.y).reduce((a, b) => a < b ? a : b);
  final scale = face.emSize == 0 ? 1.0 : size / face.emSize;
  final lineGapUnits = face.height - face.ascender + face.descender;

  final typoAscent = (face.ascender * scale).round();
  final typoDescent = (face.descender * scale).round();
  final typoLineGap = (lineGapUnits * scale).round();
  final underlinePosition = (face.underlinePosition * scale).round();
  final underlineThickness = (face.raw.ref.underline_thickness * scale).round();

  return {
    'ascent': ascent,
    'descent': descent,
    'typoAscent': typoAscent,
    'typoDescent': typoDescent,
    'typoLineGap': typoLineGap,
    'size': size,
    'underlinePosition': underlinePosition,
    'underlineThickness': underlineThickness == 0 ? 1 : underlineThickness,
  };
}

/// Glyph data structure
class GlyphData {
  final int code;
  final double advanceWidth;
  final BoundingBox bbox;
  final Map<int, double> kerning;
  final List<List<int>> pixels;

  GlyphData({
    required this.code,
    required this.advanceWidth,
    required this.bbox,
    required this.kerning,
    required this.pixels,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'advanceWidth': advanceWidth,
      'bbox': bbox.toJson(),
      'kerning': kerning,
      'pixels': pixels,
    };
  }
}

/// Bounding box structure
class BoundingBox {
  final int x;
  final int y;
  final int width;
  final int height;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'width': width, 'height': height};
  }
}

/// Font specification from CLI arguments
class FontSpec {
  final String sourcePath;
  final Uint8List sourceBin;
  final List<RangeItem> ranges;

  FontSpec({
    required this.sourcePath,
    required this.sourceBin,
    required this.ranges,
  });
}

/// Range item (either range or symbols)
class RangeItem {
  final List<int>? range;
  final String? symbols;

  RangeItem({this.range, this.symbols});
}

/// Collect font data from input arguments
Future<Map<String, dynamic>> collectFontData(Map<String, dynamic> args) async {
  final fontsOptions = <String, FontSpec>{};
  for (final font in args['font'] as List) {
    final sourcePath = font['source_path'] as String;
    Uint8List? sourceBin = font['source_bin'] as Uint8List?;
    final lower = sourcePath.toLowerCase();
    if (!(lower.endsWith('.ttf') ||
        lower.endsWith('.otf') ||
        lower.endsWith('.woff'))) {
      throw AppError('Cannot load font: Unknown format');
    }

    if (sourceBin == null) {
      final file = File(sourcePath);
      if (!file.existsSync()) {
        throw AppError('Font file not found: $sourcePath');
      }
      sourceBin = file.readAsBytesSync();
    }

    final ranges = (font['ranges'] as List)
        .map(
          (r) => RangeItem(
            range: r['range'] as List<int>?,
            symbols: r['symbols'] as String?,
          ),
        )
        .toList();

    if (fontsOptions.containsKey(sourcePath)) {
      fontsOptions[sourcePath]!.ranges.addAll(ranges);
    } else {
      fontsOptions[sourcePath] = FontSpec(
        sourcePath: sourcePath,
        sourceBin: sourceBin,
        ranges: ranges,
      );
    }
  }

  final freetype = _FreetypeContext();
  final faces = <String, _FtFace>{};
  final size = args['size'] as int? ?? 12;

  try {
    for (final entry in fontsOptions.entries) {
      faces[entry.key] = _createFace(freetype, entry.value, size);
    }

    final ranger = Ranger();
    for (final fontSpec in fontsOptions.values) {
      final face = faces[fontSpec.sourcePath]!;

      for (final item in fontSpec.ranges) {
        if (item.range != null) {
          final range = item.range!;
          for (int i = 0; i < range.length; i += 3) {
            if (i + 2 < range.length) {
              final start = range[i];
              final end = range[i + 1];
              final mappedStart = range[i + 2];
              final added = <int>[];

              if (start == 0x3d0 && end == 0x3d8) {
                added.addAll(
                  ranger.addRange(fontSpec.sourcePath, 0x3d1, 0x3d2, 0x3d1),
                );
                added.addAll(
                  ranger.addRange(fontSpec.sourcePath, 0x3d6, 0x3d6, 0x3d6),
                );
              } else {
                added.addAll(
                  ranger.addRange(fontSpec.sourcePath, start, end, mappedStart),
                );
              }

              final hasGlyph = added.any(
                (code) => _glyphExists(face.face, code),
              );
              if (!hasGlyph) {
                final a = '0x${start.toRadixString(16)}';
                final b = '0x${end.toRadixString(16)}';
                throw AppError(
                  'Font "${fontSpec.sourcePath}" doesn\'t have any characters included in range $a-$b',
                );
              }
            }
          }
        }

        if (item.symbols != null) {
          final chars = ranger.addSymbols(fontSpec.sourcePath, item.symbols!);
          final hasGlyph = chars.any((code) => _glyphExists(face.face, code));
          if (!hasGlyph) {
            throw AppError(
              'Font "${fontSpec.sourcePath}" doesn\'t have any characters included in "${item.symbols}"',
            );
          }
        }
      }
    }

    final mapping = ranger.get();
    if (mapping.isEmpty) {
      throw AppError("Font doesn't have any characters from defined ranges");
    }

    final glyphs = <GlyphData>[];
    final allDstCharcodes = mapping.keys.toList()..sort();

    for (final dstCode in allDstCharcodes) {
      final srcCode = mapping[dstCode]!.code;
      final srcFont = mapping[dstCode]!.font;
      final face = faces[srcFont];
      if (face == null) continue;
      if (!_glyphExists(face.face, srcCode)) continue;

      final glyphResult = _renderGlyph(face.face, srcCode, args);

      glyphs.add(
        GlyphData(
          code: dstCode,
          advanceWidth: glyphResult.advanceX,
          bbox: BoundingBox(
            x: glyphResult.x,
            y: glyphResult.y - glyphResult.height,
            width: glyphResult.width,
            height: glyphResult.height,
          ),
          kerning: {},
          pixels: glyphResult.pixels,
        ),
      );
    }

    if (glyphs.isEmpty) {
      throw AppError("Font doesn't have any characters from defined ranges");
    }

    if (!(args['no_kerning'] as bool? ?? false)) {
      _addKerningWithFreetype(glyphs, mapping, faces);
    }

    final metrics = _computeFontMetrics(
      faces[fontsOptions.keys.first]!.face,
      size,
      glyphs,
    );

    return {
      'glyphs': glyphs.map((g) => g.toJson()).toList(),
      'ascent': metrics['ascent'],
      'descent': metrics['descent'],
      'typoAscent': metrics['typoAscent'],
      'typoDescent': metrics['typoDescent'],
      'typoLineGap': metrics['typoLineGap'],
      'size': metrics['size'],
      'underlinePosition': metrics['underlinePosition'],
      'underlineThickness': metrics['underlineThickness'],
    };
  } finally {
    for (final face in faces.values) {
      face.dispose(freetype.allocator);
    }
    freetype.dispose();
  }
}
