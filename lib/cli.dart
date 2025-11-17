import 'dart:io';
import 'package:args/args.dart';
import 'package:dart_lv_font_conv/dart_lv_font_conv.dart';

/// Command line interface for font converter
class FontConverterCLI {
  late ArgParser _parser;

  FontConverterCLI() {
    _setupParser();
  }

  /// Setup argument parser
  void _setupParser() {
    _parser = ArgParser()
      ..addOption('size', abbr: 's', help: 'Output font size, pixels.', mandatory: true)
      ..addOption('bpp', help: 'Bits per pixel, for antialiasing.', allowed: ['1', '2', '3', '4', '8'], mandatory: true)
      ..addFlag('lcd', help: 'Enable subpixel rendering (horizontal pixel layout).', defaultsTo: false)
      ..addFlag('lcd-v', help: 'Enable subpixel rendering (vertical pixel layout).', defaultsTo: false)
      ..addFlag('use-color-info', help: 'Try to use glyph color info from font to create grayscale icons.', defaultsTo: false)
      ..addOption('format', help: 'Output format.', allowed: FontConverter.supportedFormats, mandatory: true)
      ..addMultiOption('font', help: 'Source font path. Can be used multiple times to merge glyphs from different fonts.')
      ..addMultiOption('range', abbr: 'r', help: 'Range of glyphs to copy. Can be used multiple times.')
      ..addMultiOption('symbols', help: 'List of characters to copy.')
      ..addFlag('autohint-off', help: 'Disable autohinting for previously declared font')
      ..addFlag('autohint-strong', help: 'Use more strong autohinting for previously declared font')
      ..addFlag('force-fast-kern-format', help: 'Always use kern classes instead of pairs (might be larger but faster).', defaultsTo: false)
      ..addFlag('no-compress', help: 'Disable built-in RLE compression.', defaultsTo: false)
      ..addFlag('no-prefilter', help: 'Disable bitmap lines filter (XOR), used to improve compression ratio.', defaultsTo: false)
      ..addFlag('no-kerning', help: 'Drop kerning info to reduce size (not recommended).', defaultsTo: false)
      ..addFlag('byte-align', help: 'Pad bitmap line endings to whole bytes.', defaultsTo: false)
      ..addOption('stride', help: 'Align each glyph\'s stride to the specified number of bytes.', allowed: ['0', '1', '4', '8', '16', '32', '64'], defaultsTo: '0')
      ..addOption('align', help: 'Align each glyph address to the specified number of bytes.', allowed: ['1', '4', '8', '16', '32', '64', '128', '256', '512', '1024'], defaultsTo: '1')
      ..addOption('lv-include', help: 'Set alternate "lvgl.h" path (for --format lvgl).')
      ..addOption('lv-font-name', help: 'Variable name of the lvgl font structure.')
      ..addOption('lv-fallback', help: 'Variable name of the lvgl font structure to use as fallback for this font.')
      ..addFlag('full-info', help: 'Don\'t shorten "font_info.json" (include pixels data).', defaultsTo: false)
      ..addOption('output', abbr: 'o', help: 'Output path.')
      ..addFlag('help', abbr: 'h', help: 'Show usage information.', negatable: false)
      ..addFlag('version', help: 'Show version information.', negatable: false);
  }

  /// Parse command line arguments and run conversion
  Future<void> run(List<String> arguments) async {
    try {
      final results = _parser.parse(arguments);

      if (results['help'] as bool) {
        _printUsage();
        return;
      }

      if (results['version'] as bool) {
        print('dart_lv_font_conv version 1.0.0');
        return;
      }

      final args = _parseArgs(results, arguments);
      final converter = FontConverter();
      final files = await converter.convert(args);

      // Write output files
      for (final entry in files.entries) {
        final file = File(entry.key);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.value);
        print('Wrote: ${entry.key}');
      }
    } on FormatException catch (e) {
      print('Error: ${e.message}');
      _printUsage();
      exit(1);
    } on AppError catch (e) {
      print('Error: ${e.message}');
      exit(1);
    } catch (e) {
      print('Unexpected error: $e');
      exit(1);
    }
  }

  /// Parse parsed arguments into ConversionArgs
  ConversionArgs _parseArgs(ArgResults results, List<String> arguments) {
    final fontPaths = results['font'] as List<String>;
    if (fontPaths.isEmpty) {
      throw AppError('At least one font file must be specified with --font');
    }

    final fonts = <FontOptions>[];
    for (final fontPath in fontPaths) {
      // TODO: Handle ranges and symbols properly
      fonts.add(FontOptions(
        sourcePath: fontPath,
        ranges: [],
      ));
    }

    return ConversionArgs(
      size: int.parse(results['size'] as String),
      bpp: int.parse(results['bpp'] as String),
      format: results['format'] as String,
      font: fonts,
      output: results['output'] as String?,
      lcd: results['lcd'] as bool,
      lcdV: results['lcd-v'] as bool,
      useColorInfo: results['use-color-info'] as bool,
      noCompress: results['no-compress'] as bool,
      noPrefilter: results['no-prefilter'] as bool,
      noKerning: results['no-kerning'] as bool,
      stride: int.parse(results['stride'] as String),
      align: int.parse(results['align'] as String),
      fastKerning: results['force-fast-kern-format'] as bool,
      lvInclude: results['lv-include'] as String?,
      lvFontName: results['lv-font-name'] as String?,
      lvFallback: results['lv-fallback'] as String?,
      fullInfo: results['full-info'] as bool,
      optsString: arguments.join(' '),
    );
  }

  /// Print usage information
  void _printUsage() {
    print('Dart LVGL Font Converter');
    print('');
    print('Usage: dart_lv_font_conv [options]');
    print('');
    print(_parser.usage);
  }
}