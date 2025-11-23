/// CLI interface for the font converter
library;

import 'dart:io';
import 'dart:typed_data';
import 'convert.dart';
import 'app_error.dart';

/// Font converter CLI class
class FontConverterCLI {
  /// Run the CLI with given arguments
  static Future<void> run(List<String> arguments) async {
    try {
      final args = parseArguments(arguments);
      final files = await convert(args);

      // Write output files
      for (final entry in files.entries) {
        final file = File(entry.key);
        await file.create(recursive: true);
        await file.writeAsBytes(entry.value);
        print('Wrote: ${entry.key}');
      }
    } catch (e) {
      if (e is AppError) {
        print('Error: ${e.message}');
        exit(1);
      } else {
        print('Unexpected error: $e');
        exit(1);
      }
    }
  }

  /// Parse command line arguments (public for testing)
  static Map<String, dynamic> parseArguments(List<String> arguments) {
    if (arguments.isEmpty) {
      _printUsage();
      exit(1);
    }

    final args = <String, dynamic>{
      'font': <Map<String, dynamic>>[],
      'format': 'lvgl',
      'size': 12,
      'bpp': 1,
      'no_kerning': false,
      'lcd': false,
      'lcd_v': false,
      'autohint_off': false,
      'autohint_strong': false,
      'use_color_info': false,
      'fast_kerning': false,
      'output': null,
    };

    int i = 0;
    while (i < arguments.length) {
      final arg = arguments[i];

      switch (arg) {
        case '--font':
          i++;
          if (i >= arguments.length) {
            throw AppError('--font requires a file path');
          }
          final fontPath = arguments[i];
          final fontFile = File(fontPath);
          if (!fontFile.existsSync()) {
            throw AppError('Font file not found: $fontPath');
          }
          final fontBytes = fontFile.readAsBytesSync();
          (args['font'] as List).add({
            'source_path': fontPath,
            'source_bin': Uint8List.fromList(fontBytes),
            'ranges': <Map<String, dynamic>>[],
          });
          break;

        case '--range':
          i++;
          if (i >= arguments.length) {
            throw AppError('--range requires a range specification');
          }
          final rangeSpec = arguments[i];
          final ranges = _parseRange(rangeSpec);
          if (args['font'].isEmpty) {
            throw AppError('--range must come after --font');
          }
          ((args['font'] as List).last as Map)['ranges'].add({'range': ranges});
          break;

        case '--symbols':
          i++;
          if (i >= arguments.length) {
            throw AppError('--symbols requires a string');
          }
          final symbols = arguments[i];
          if (args['font'].isEmpty) {
            throw AppError('--symbols must come after --font');
          }
          ((args['font'] as List).last as Map)['ranges'].add({'symbols': symbols});
          break;

        case '--format':
          i++;
          if (i >= arguments.length) {
            throw AppError('--format requires a format name');
          }
          final format = arguments[i];
          if (!supportedFormats.contains(format)) {
            throw AppError('Unsupported format: $format. Supported: ${supportedFormats.join(', ')}');
          }
          args['format'] = format;
          break;

        case '--size':
          i++;
          if (i >= arguments.length) {
            throw AppError('--size requires a number');
          }
          final size = int.tryParse(arguments[i]);
          if (size == null || size <= 0) {
            throw AppError('--size must be a positive number');
          }
          args['size'] = size;
          break;

        case '--bpp':
          i++;
          if (i >= arguments.length) {
            throw AppError('--bpp requires a number');
          }
          final bpp = int.tryParse(arguments[i]);
          if (bpp == null || bpp < 1 || bpp > 8) {
            throw AppError('--bpp must be between 1 and 8');
          }
          args['bpp'] = bpp;
          break;

        case '-r':
        case '--range':
          i++;
          if (i >= arguments.length) {
            throw AppError('--range requires a range specification');
          }
          if (args['font'].isEmpty) {
            throw AppError('Only allowed after --font');
          }
          final range = arguments[i];
          final parsedRange = parseRange(range);
          ((args['font'] as List).last as Map)['ranges'].add({'range': parsedRange});
          break;

        case '--no-kerning':
          args['no_kerning'] = true;
          break;

        case '--lcd':
          args['lcd'] = true;
          break;

        case '--lcd-v':
          args['lcd_v'] = true;
          break;

        case '--autohint-off':
          args['autohint_off'] = true;
          break;

        case '--autohint-strong':
          args['autohint_strong'] = true;
          break;

        case '--use-color-info':
          args['use_color_info'] = true;
          break;

        case '--fast-kerning':
          args['fast_kerning'] = true;
          break;

        case '--output':
          i++;
          if (i >= arguments.length) {
            throw AppError('--output requires a filename');
          }
          args['output'] = arguments[i];
          break;

        case '--help':
        case '-h':
          _printUsage();
          exit(0);

        default:
          throw AppError('Unknown argument: $arg');
      }

      i++;
    }

    if (args['font'].isEmpty) {
      throw AppError('At least one font file must be specified with --font');
    }

    // Validate that fonts have ranges
    for (final font in args['font'] as List) {
      final ranges = (font as Map)['ranges'] as List;
      if (ranges.isEmpty) {
        throw AppError('Font ${font['source_path']} has no character ranges specified');
      }
    }

    return args;
  }

  /// Parse range specification (public for testing)
  static List<int> parseRange(String rangeSpec) {
    final result = <int>[];

    for (final part in rangeSpec.split(',')) {
      final match = RegExp(r'^(.+?)(?:-(.+?))?(?:=>(.+?))?$').firstMatch(part.trim());
      if (match == null) {
        throw AppError('Invalid range specification: $part');
      }

      final startStr = match.group(1)!;
      final endStr = match.group(2) ?? startStr;
      final mappedStartStr = match.group(3) ?? startStr;

      final start = _parseUnicodePoint(startStr);
      final end = _parseUnicodePoint(endStr);
      final mappedStart = _parseUnicodePoint(mappedStartStr);

      if (start > end) {
        throw AppError('Range start cannot be greater than end: $start > $end');
      }

      result.addAll([start, end, mappedStart]);
    }

    return result;
  }

  /// Parse unicode point (decimal or hex)
  static int _parseUnicodePoint(String str) {
    final trimmed = str.trim();
    final hexMatch = RegExp(r'^0x([0-9a-f]+)$', caseSensitive: false).firstMatch(trimmed);
    final decMatch = RegExp(r'^([0-9]+)$').firstMatch(trimmed);

    int value;
    if (hexMatch != null) {
      value = int.parse(hexMatch.group(1)!, radix: 16);
    } else if (decMatch != null) {
      value = int.parse(decMatch.group(1)!);
    } else {
      throw AppError('$str is not a valid number');
    }

    if (value > 0x10FFFF) {
      throw AppError('$str is out of unicode range');
    }

    return value;
  }

  /// Print usage information
  static void _printUsage() {
    print('''
Dart LVGL Font Converter

Usage: dart_lv_font_conv [options]

Required:
  --font FILE               Font file to process
  --range RANGE             Character range (e.g., 0x20-0x7F,65-90=>65)
  --symbols STRING          Specific characters to include

Output options:
  --format FORMAT           Output format: dump, bin, lvgl (default: lvgl)
  --output FILE             Output filename (without extension)

Font options:
  --size N                  Font size in pixels (default: 12)
  --bpp N                   Bits per pixel (1-8, default: 1)
  --no-kerning              Disable kerning
  --lcd                     Enable horizontal subpixel rendering
  --lcd-v                   Enable vertical subpixel rendering
  --autohint-off            Disable autohinting
  --autohint-strong         Enable strong autohinting
  --use-color-info          Use color information
  --fast-kerning            Use faster kerning format (classes)

Examples:
  dart_lv_font_conv --font Arial.ttf --range 0x20-0x7F --size 16
  dart_lv_font_conv --font font.ttf --symbols "HelloWorld" --format dump
  dart_lv_font_conv --font font.ttf --range 65-90 --format lvgl --output my_font
''');
  }
}