import 'dart:io';
import 'dart:typed_data';
import '../dart_lv_font_conv_base.dart';
import 'ranger.dart';
import 'font_data_collector.dart';
import 'rle_compressor.dart';

/// Collect font data from multiple sources
Future<FontData> collectFontData(ConversionArgs args) async {
  final collector = FontDataCollector();
  await collector.init();

  // Create font options map for quick access
  final fontsOptions = <String, FontOptions>{};
  for (final font in args.font) {
    fontsOptions[font.sourcePath] = font;
  }

  // Read fonts
  final fontsOpenType = <String, FontFace>{};

  for (final fontOption in args.font) {
    final sourcePath = fontOption.sourcePath;
    
    // Don't load font again if it's specified multiple times
    if (fontsOpenType.containsKey(sourcePath)) continue;

    try {
      Uint8List sourceBin;
      
      if (fontOption.sourceBin != null) {
        sourceBin = fontOption.sourceBin!;
      } else {
        sourceBin = await File(sourcePath).readAsBytes();
      }

      fontsOpenType[sourcePath] = await collector.createFontFace(sourceBin, args.size);
    } catch (e) {
      throw AppError('Cannot load font "$sourcePath": $e');
    }
  }

  // Merge all ranges
  final ranger = Ranger();

  for (final fontOption in args.font) {
    final font = fontsOpenType[fontOption.sourcePath]!;
    
    for (final item in fontOption.ranges) {
      if (item.symbols != null) {
        // Handle symbols
        final chars = ranger.addSymbols(fontOption.sourcePath, item.symbols!);
        bool isEmpty = true;

        for (final code in chars) {
          if (collector.glyphExists(font, code)) {
            isEmpty = false;
            break;
          }
        }

        if (isEmpty) {
          throw AppError('Font "${fontOption.sourcePath}" doesn\'t have any characters included in "${item.symbols}"');
        }
      } else {
        // Handle ranges
        for (int i = item.start; i <= item.end; i += 3) {
          final rangeStart = item.start;
          final rangeEnd = item.end;
          final mappedStart = item.mappedStart;
          
          final chars = ranger.addRange(fontOption.sourcePath, rangeStart, rangeEnd, mappedStart);
          bool isEmpty = true;

          for (final code in chars) {
            if (collector.glyphExists(font, code)) {
              isEmpty = false;
              break;
            }
          }

          if (isEmpty) {
            final a = '0x${rangeStart.toRadixString(16)}';
            final b = '0x${rangeEnd.toRadixString(16)}';
            throw AppError('Font "${fontOption.sourcePath}" doesn\'t have any characters included in range $a-$b');
          }
        }
      }
    }
  }

  final mapping = ranger.get();
  final glyphs = <Glyph>[];
  final allDstCharcodes = mapping.keys.toList()..sort();

  for (final dstCode in allDstCharcodes) {
    final charMapping = mapping[dstCode]!;
    final srcCode = charMapping.code;
    final srcFont = charMapping.font;

    if (!collector.glyphExists(fontsOpenType[srcFont]!, srcCode)) continue;

    final ftResult = await collector.renderGlyph(
      fontsOpenType[srcFont]!,
      srcCode,
      autohintOff: fontsOptions[srcFont]?.autohintOff ?? false,
      autohintStrong: fontsOptions[srcFont]?.autohintStrong ?? false,
      lcd: args.lcd,
      lcdV: args.lcdV,
      mono: !args.lcd && !args.lcdV && args.bpp == 1,
      useColorInfo: args.useColorInfo,
    );

    // Apply compression if enabled
    List<List<int>> processedPixels = ftResult.pixels;
    if (!args.noCompress) {
      // Apply XOR pre-filter if not disabled
      if (!args.noPrefilter) {
        processedPixels = RleCompressor.applyXorFilter(ftResult.pixels);
      }
    }

    // Convert 2D pixel array to 1D
    final flatPixels = <int>[];
    for (final row in processedPixels) {
      flatPixels.addAll(row);
    }

    glyphs.add(Glyph(
      code: dstCode,
      advanceWidth: ftResult.advanceX,
      bbox: BoundingBox(
        x: ftResult.x,
        y: ftResult.y - ftResult.height,
        width: ftResult.width,
        height: ftResult.height,
      ),
      kerning: {},
      freetype: ftResult.freetype,
      pixels: flatPixels,
    ));
  }

  // Process kerning if enabled
  if (!args.noKerning) {
    final existingDstCharcodes = glyphs.map((g) => g.code).toList();

    for (final glyph in glyphs) {
      final charMapping = mapping[glyph.code]!;
      final srcFont = charMapping.font;

      for (final dstCode2 in existingDstCharcodes) {
        // Can't merge kerning values from 2 different fonts
        if (mapping[dstCode2]!.font != srcFont) continue;
        
        // TODO: Implement actual kerning calculation
        // For now, skip kerning
        // final krnValue = getKerning(fontsOpenType[srcFont]!, srcCode, srcCode2);
        // if (krnValue != 0) {
        //   glyph.kerning[dstCode2] = krnValue * args.size / unitsPerEm;
        // }
      }
    }
  }

  final firstFont = fontsOpenType[args.font.first.sourcePath]!;
  final firstFontScale = args.size / firstFont.unitsPerEm;
  final os2Metrics = collector.getOs2Table(firstFont);

  // Cleanup
  for (final font in fontsOpenType.values) {
    collector.destroyFontFace(font);
  }
  collector.destroy();

  return FontData(
    ascent: glyphs.map((g) => g.bbox.y + g.bbox.height).reduce((a, b) => a > b ? a : b),
    descent: glyphs.map((g) => g.bbox.y).reduce((a, b) => a < b ? a : b),
    typoAscent: (os2Metrics.typoAscent * firstFontScale).round(),
    typoDescent: (os2Metrics.typoDescent * firstFontScale).round(),
    typoLineGap: (os2Metrics.typoLineGap * firstFontScale).round(),
    size: args.size,
    glyphs: glyphs,
    underlinePosition: 0, // TODO: Implement from post table
    underlineThickness: 0, // TODO: Implement from post table
  );
}